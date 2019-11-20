import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity/connectivity.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/isolate.dart';
import '../common/eventBus.dart';
import '../common/appConfig.dart';
import '../common/stationApis.dart';

/// `idle`: init state
///
/// `running`: working
///
/// `paused`: isMobile and backupViaCellular == false
///
/// `aborted`: autoBackup disabled
///
/// `failed`: backup error occured
///
/// `finished`: backup success
enum Status { idle, running, paused, aborted, failed, finished }

/// Max file count in single directory
const MAX_FILE = 1000;

class PhotoEntry {
  String id;
  String hash;
  int date;
  String hdate;

  PhotoEntry(this.id, this.hash, this.date) {
    this.hdate =
        date == 0 ? i18n('Unknown Date') : prettyDate(date, showMonth: true);
  }
}

/// List of PhotoEntry from station
class RemoteList {
  Entry entry;
  List<Entry> items;

  /// initial value is items' length
  int get length => items.length;

  RemoteList(this.entry, this.items);

  void add(Entry entry) {
    items.add(entry);
  }
}

/// single photo backup worker
class Worker {
  Apis apis;
  Worker(this.apis);
  String machineId;
  String deviceName;
  String deviceId;

  CancelToken cancelToken;
  CancelIsolate cancelUpload;
  CancelIsolate cancelHash;
  Status status = Status.idle;

  /// latest error
  dynamic latestError;

  /// retry times
  int retry = 0;

  /// total items to upload
  int total = 0;

  /// uploaded items' count
  ///
  /// finished = trueUpload + ignored
  int finished = 0;

  /// already backuped items' count
  int ignored = 0;

  bool uploading = false;

  bool get isAborted => status == Status.aborted;

  String speed = '';

  void updateSpeed(speedValue) {
    this.speed = '${prettySize(speedValue)}/s';
  }

  List<int> deltaSizeList = [];
  List<int> deltaTimeList = [];

  void onLargeFileProgress(int size, int total) {
    int now = DateTime.now().millisecondsSinceEpoch;

    this.deltaSizeList.insert(0, size);
    this.deltaTimeList.insert(0, now);

    final deltaSize = this.deltaSizeList.first - this.deltaSizeList.last;

    // add 1000 to avoid show a mistake large speed
    int deltaTime = this.deltaTimeList.first - this.deltaTimeList.last;
    if (deltaTime < 1000) deltaTime = 1000;

    final speed = deltaSize / deltaTime * 1000;
    this.speed = '${prettySize(speed)}/s';

    // get average value of up to last 4 seconds or 256 update-data
    if (deltaTime > 4 * 1000 || this.deltaSizeList.length > 256) {
      this.deltaSizeList.removeLast();
      this.deltaTimeList.removeLast();
    }
  }

  /// get all local photos and videos
  Future<List<AssetEntity>> getAssetList() async {
    if (isAborted) return [];
    final result = await PhotoManager.requestPermission();
    if (!result) return [];
    List<AssetPathEntity> pathList =
        await PhotoManager.getAssetPathList(type: RequestType.all);
    List<AssetEntity> localAssetList = await pathList[0].assetList;

    /// older(small) first
    localAssetList.sort((a, b) => getMtime(a) - getMtime(b));

    return localAssetList;
  }

  Future<Drive> getBackupDrive() async {
    final res = await apis.req('drives', null);
    // get current drives data
    List<Drive> drives = List.from(
      res.data.map((drive) => Drive.fromMap(drive)),
    );

    Drive backupDrive = drives.firstWhere(
      (d) =>
          d?.client?.id == machineId ||
          (d?.client?.idList is List && d.client.idList.contains(machineId)) ||
          (d?.client?.didList is List && d.client.didList.contains(deviceId)),
      orElse: () => null,
    );

    return backupDrive;
  }

  Future<Entry> getPhotosDir(Drive backupDrive) async {
    final uuid = backupDrive.uuid;
    final listNav = await apis.req('listNavDir', {
      'driveUUID': uuid,
      'dirUUID': uuid,
    });
    final currentNode = Node(
      name: 'Backup',
      driveUUID: uuid,
      dirUUID: uuid,
      tag: 'backup',
      location: 'backup',
    );
    List<Entry> rawEntries = List.from(listNav.data['entries']
        .map((entry) => Entry.mixNode(entry, currentNode)));

    // Folder Name in Photos Backup: 照片 or Photos
    final photosDir = rawEntries.firstWhere(
        (e) => e.name == '照片' || e.name == 'Photos',
        orElse: () => null);
    return photosDir;
  }

  /// get root backup dir
  Future<Entry> getDir() async {
    Drive backupDrive = await getBackupDrive();

    if (backupDrive == null) {
      // create backupDrive
      final args = {
        'op': 'backup',
        'label': deviceName,
        'client': {
          'id': machineId,
          'idList': [machineId],
          'didList': [deviceId],
          'status': 'Idle',
          'disabled': false,
          'lastBackupTime': 0,
          'type': Platform.isIOS ? 'Mobile-iOS' : 'Mobile-Android',
        }
      };

      await apis.req('createDrive', args);

      // retry get backupDrive
      backupDrive = await getBackupDrive();
    }

    assert(backupDrive is Drive);

    Entry photosDir = await getPhotosDir(backupDrive);

    if (photosDir == null) {
      // make backup root directory
      await apis.req('mkdir', {
        'dirname': i18n('Folder Name in Photos Backup'),
        'dirUUID': backupDrive.uuid,
        'driveUUID': backupDrive.uuid,
      });

      // retry getPhotosDir
      photosDir = await getPhotosDir(backupDrive);
    }

    return photosDir;
  }

  /// Get backup directory's content
  ///
  /// backup directory's structure is
  ///
  /// `backupDrive(device name)/照片/datetime`
  ///
  /// each directory has up to 1000 photos
  ///
  /// such as:
  ///
  /// Nexus 6P/照片/2019-01
  /// Nexus 6P/照片/2019-02
  /// Nexus 6P/照片/2019-02_02
  /// Nexus 6P/照片/2019-02_03
  /// Nexus 6P/照片/2019-03

  Future<List<RemoteList>> getRemoteDirs(Entry rootDir) async {
    final res = await apis.req(
      'listNavDir',
      {'driveUUID': rootDir.pdrv, 'dirUUID': rootDir.uuid},
    );

    final currentNode = Node(
      name: rootDir.name,
      driveUUID: rootDir.pdrv,
      dirUUID: rootDir.uuid,
      location: rootDir.location,
      tag: 'dir',
    );

    List<Entry> photoDirs = List.from(
      (res.data['entries'] as List)
          .map((entry) => Entry.mixNode(entry, currentNode))
          .where((entry) => entry.type == 'directory' && entry.deleted != true),
    );

    final List<Future> reqs = List.from(
      photoDirs.map((dir) => apis.req(
            'listNavDir',
            {'driveUUID': dir.pdrv, 'dirUUID': dir.uuid},
          )),
    );

    final listNavs = await Future.wait(reqs);

    List<RemoteList> remoteDirs = [];
    for (int i = 0; i < listNavs.length; i++) {
      List<Entry> photoItmes = List.from(
        listNavs[i]
            .data['entries']
            .map((entry) => Entry.mixNode(entry, currentNode))
            .where((entry) => entry.deleted != true),
      );
      remoteDirs.add(RemoteList(photoDirs[i], photoItmes));
    }
    remoteDirs.sort((a, b) => b.entry.name.compareTo(a.entry.name));
    return remoteDirs;
  }

  /// get remote targetDir's list
  Future<RemoteList> getTargetList(
      List<RemoteList> remoteDirs, PhotoEntry photoEntry, Entry rootDir) async {
    // get all dirs with matched hdate
    final List<RemoteList> dirsMatchDate = List.from(
        remoteDirs.where((rd) => rd.entry.name.startsWith(photoEntry.hdate)));

    Entry targetDir;

    if (dirsMatchDate.length > 0) {
      List<Entry> allItems = [];
      for (RemoteList rl in dirsMatchDate) {
        allItems.addAll(rl.items);
      }

      // photo already backup
      if (allItems.any((entry) => entry.hash == photoEntry.hash)) {
        return null;
      }
      // found target dir which length < MAX_FILE
      final index = dirsMatchDate.indexWhere((rd) => rd.length < MAX_FILE);
      if (index > -1) {
        final remoteList = dirsMatchDate[index];

        targetDir = remoteList.entry;

        return remoteList;
      }
    }

    // not found, create new dir
    String dirName = photoEntry.hdate;
    int flag = 1;

    // check name, add flag
    while (remoteDirs.any((rl) => rl.entry.name == dirName)) {
      flag += 1;
      dirName = '${photoEntry.hdate}_$flag';
    }

    // create dir
    final mkdirRes = await apis.req('mkdir', {
      'dirname': dirName,
      'dirUUID': rootDir.uuid,
      'driveUUID': rootDir.pdrv,
    });

    final currentNode = Node(
      name: rootDir.name,
      driveUUID: rootDir.pdrv,
      dirUUID: rootDir.uuid,
      location: rootDir.location,
      tag: 'dir',
    );

    targetDir = Entry.mixNode(mkdirRes.data[0]['data'], currentNode);

    final newRemoteList = RemoteList(targetDir, []);

    remoteDirs.add(newRemoteList);

    return newRemoteList;
  }

  /// remove cached Hash in shared_preferences
  ///
  /// use AssetEntity.id + createTime as the photo's identity
  Future<void> cleanHash(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(id, null);
  }

  int getMtime(AssetEntity entity) =>
      (entity.createDtSecond ?? entity.modifiedDateSecond ?? 0) * 1000;

  Future<void> _uploadLargeFileAsync(
      Entry targetDir,
      String filePath,
      List<FilePart> parts,
      CancelToken cancelToken,
      Function onProgress) async {
    /// file stat
    File file = File(filePath);
    final FileStat stat = await file.stat();

    /// file name
    final fileName = filePath.split('/').last;

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final size = part.end - part.start + 1;
      Map<String, Object> formDataOptions;
      if (i == 0) {
        formDataOptions = {
          'op': 'newfile',
          'size': size,
          'sha256': part.sha,
          'bctime': stat.modified.millisecondsSinceEpoch,
          'bmtime': stat.modified.millisecondsSinceEpoch,
          'policy': ['rename', 'rename'],
        };
      } else {
        formDataOptions = {
          'op': 'append',
          'size': size,
          'sha256': part.sha,
          'hash': part.target,
        };
      }

      if (parts.length > 1) {
        formDataOptions['fingerprint'] = parts.last.fingerprint;
      }

      final args = {
        'driveUUID': targetDir.pdrv,
        'dirUUID': targetDir.uuid,
        'fileName': fileName,
        'file': MultipartFile(
          file.openRead(part.start, part.end + 1),
          size,
          filename: jsonEncode(formDataOptions),
        ),
      };

      await apis.uploadAsync(
        args,
        cancelToken: cancelToken,
        onProgress: (int a, int b) =>
            onProgress(a + part.start, b + part.start),
      );
    }
  }

  String getName(
      String filePath, int mtime, AssetType type, RemoteList remoteList) {
    String fileName = filePath.split('/').last;

    String ext = fileName.contains('.') ? fileName.split('.').last : '';
    if (Platform.isIOS) {
      // tofix mtime == 0 or null bug
      DateTime time = (mtime == 0 || mtime == null)
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(mtime);
      String prefix = type == AssetType.image
          ? 'IMG'
          : type == AssetType.video ? 'VID' : 'File';
      fileName = ext == ''
          ? '${prefix}_${getTimeString(time)}'
          : '${prefix}_${getTimeString(time)}.$ext';
    }

    // autorename, compare fileName with names in remoteList
    int i = 1;
    String newName = fileName;
    while (remoteList.items.any((e) => e.name == newName)) {
      String pureName;
      if (fileName.contains('.')) {
        final list = fileName.split('.');
        list.removeLast();
        pureName = list.join('.');
      } else {
        pureName = fileName;
      }
      newName = ext == '' ? '${pureName}_$i' : '${pureName}_$i.$ext';
      i += 1;
    }
    return newName;
  }

  Future<void> uploadSingle(
      AssetEntity entity, List<RemoteList> remoteDirs, Entry rootDir) async {
    // final time = getNow();

    String id = entity.id;
    int mtime = getMtime(entity);

    /// get Hash from hashViaIsolate or shared_preferences
    ///
    /// use AssetEntity.id + createTime as the photo's identity
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String hash = prefs.getString('$id+$mtime');
    int size;
    File file;
    List<FilePart> parts;

    if (hash == null) {
      cancelHash = CancelIsolate();
      file = await entity.originFile.timeout(Duration(seconds: 60));
      size = (await file.stat()).size;

      parts = await hashViaIsolate(file.path, cancelIsolate: cancelHash)
          .timeout(Duration(minutes: 60));

      hash = parts.last.fingerprint;
      if (hash == null) throw 'hash error';
      await prefs.setString('$id+$mtime', hash);
    }

    final photoEntry = PhotoEntry(id, hash, mtime);

    final remoteList = await getTargetList(remoteDirs, photoEntry, rootDir);

    // already backuped, continue next
    if (remoteList == null) {
      finished += 1;
      ignored += 1;
      return;
    }

    // upload photo
    if (file == null || size == null) {
      file = await entity.originFile.timeout(Duration(seconds: 60));
      size = (await file.stat()).size;
    }

    // get filePath and name
    String filePath = file.path;
    String fileName = getName(filePath, mtime, entity.type, remoteList);

    remoteList.add(Entry(name: fileName, hash: hash));

    if (isAborted) {
      return;
    }

    // upload via _uploadLargeFileAsync or _uploadViaIsolate
    final targetDir = remoteList.entry;
    if (size > 1073741824) {
      // get fileParts
      cancelHash = CancelIsolate();
      parts ??= await hashViaIsolate(file.path, cancelIsolate: cancelHash)
          .timeout(Duration(minutes: 60));

      // for calculate speed
      this.deltaSizeList = [];
      this.deltaTimeList = [];

      cancelToken = CancelToken();

      uploading = true;
      await _uploadLargeFileAsync(
          targetDir, filePath, parts, cancelToken, onLargeFileProgress);
    } else {
      cancelUpload = CancelIsolate();

      uploading = true;
      await uploadViaIsolate(apis, targetDir, filePath, hash, mtime, fileName,
          cancelIsolate: cancelUpload, updateSpeed: updateSpeed);
    }

    // delete tmp file, only in iOS
    if (Platform.isIOS) {
      await file.delete();
    }

    // trigger generating thumbnails
    apis.thumbTrigger(hash);

    // send Backup Event
    eventBus.fire(BackupEvent(rootDir.pdrv));

    finished += 1;
  }

  Future<void> updateStatus(Entry rootDir) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final res = await apis.req(
      'drive',
      {'uuid': rootDir.pdrv},
    );
    final client = res.data['client'];

    final props = {
      'op': 'backup',
      'client': {
        'status': 'Idle',
        'lastBackupTime': now,
        'id': client['id'],
        'idList': client['idList'],
        'didList': client['didList'],
        'disabled': false,
        'type': client['type'],
      }
    };

    await apis.req('updateDrive', {
      'uuid': rootDir.pdrv,
      'props': props,
    });

    final dirProps = {
      'op': 'updateAttr',
      'metadata': {
        'disabled': false,
        'status': 'Idle',
        'lastBackupTime': now,
      }
    };

    await apis.req('updateBackupAttr', {
      'driveUUID': rootDir.pdrv,
      'dirUUID': rootDir.pdrv,
      'bname': rootDir.uuid,
      'props': dirProps,
    });
  }

  Future<void> startAsync() async {
    status = Status.running;
    final data = await getMachineId();
    deviceName = data['deviceName'];
    machineId = data['machineId'];
    deviceId = await AppConfig.getDeviceUUID();

    final Entry rootDir = await getDir();
    assert(rootDir is Entry);

    final remoteDirs = await getRemoteDirs(rootDir);

    if (isAborted) return;

    List<AssetEntity> assetList = await getAssetList();
    total = assetList.length;

    List<AssetEntity> uploadList = [];

    // filter uploaded entity
    for (AssetEntity entity in assetList) {
      if (status == Status.running) {
        try {
          String id = entity.id;

          int mtime = getMtime(entity);

          SharedPreferences prefs = await SharedPreferences.getInstance();
          String hash = prefs.getString('$id+$mtime');

          if (hash == null) {
            uploadList.add(entity);
            continue;
          }

          final photoEntry = PhotoEntry(id, hash, mtime);

          final targetList =
              await getTargetList(remoteDirs, photoEntry, rootDir);

          // already backuped, continue next
          if (targetList == null) {
            finished += 1;
            ignored += 1;
          } else {
            uploadList.add(entity);
          }
        } catch (e) {
          uploadList.add(entity);
          continue;
        }
      } else {
        return;
      }
    }
    if (assetList.length == uploadList.length) {
      infoLog(apis.userUUID, 'PhotoCount', total.toString());
    }
    dynamic error;
    // upload photo one by one
    for (AssetEntity entity in uploadList) {
      if (status == Status.running) {
        try {
          await uploadSingle(entity, remoteDirs, rootDir);
        } catch (e) {
          if (error == null) {
            debug('backup failed ${e.toString()}');
            error = e;
          } else {
            print('backup failed ${e.toString()}');
          }

          String id = entity.id;
          int mtime = getMtime(entity);

          /// clean hash cache
          cleanHash('$id+$mtime').catchError(debug);
        }
      } else {
        return;
      }
    }

    if (finished == total) {
      print('upload all assetList');
      await updateStatus(rootDir);
      print('updateStatus finished');
      status = Status.finished;
      finished = 0;
      ignored = 0;
      uploading = false;
      total = 0;
    } else {
      print('not all upload success');
      if (error != null) throw error;
      throw 'backup failed, finished != total';
    }
  }

  void abort() {
    try {
      cancelUpload?.cancel();
      cancelHash?.cancel();
      cancelToken?.cancel();
    } catch (e) {
      debug(e);
    }

    status = Status.aborted;

    finished = 0;
    ignored = 0;
    uploading = false;
    retry = 0;
  }

  void start() {
    finished = 0;
    ignored = 0;
    total = 0;
    uploading = false;
    latestError = null;
    this.startAsync().catchError((e) {
      status = Status.failed;
      latestError = e;
      debug('backup failed, ${e.toString()}');
      retryLater();
    });
  }

  /// retry after backup failed in `retry * retry` minutes
  void retryLater() {
    retry += 1;
    Future.delayed(Duration(minutes: retry * retry), () {
      if (isAborted) return;
      this.start();
    });
  }
}

/// manager of photo backup
class BackupWorker {
  Apis apis;

  // keep singleton
  static BackupWorker _instance;

  static BackupWorker getInstance() {
    if (_instance == null) {
      _instance = BackupWorker._();
    }
    return _instance;
  }

  void init(Apis apis, bool backupViaCellular) {
    this.apis = apis;
    this.backupViaCellular = backupViaCellular;
    if (status != Status.idle) {
      this.abort();
    }
  }

  BackupWorker._();

  StreamSubscription<ConnectivityResult> sub;
  Worker worker;
  Status status = Status.idle;

  /// use cellular to backup items
  bool backupViaCellular = false;

  bool isMobile = false;

  monitorStart() {
    sub = Connectivity().onConnectivityChanged.listen((ConnectivityResult res) {
      if (res == ConnectivityResult.wifi) {
        isMobile = false;
      } else if (res == ConnectivityResult.mobile) {
        isMobile = true;
      } else {
        // ConnectivityResult.none
        return;
      }
      // pause or start backup
      if (status == Status.running && isMobile && backupViaCellular != true) {
        this.paused();
      } else if (status == Status.paused && !isMobile) {
        this.start(isMobile);
      }
    });
  }

  monitorCancel() {
    try {
      sub?.cancel();
    } catch (e) {
      debug(e);
    }
  }

  void start(bool isMobile) {
    if (status == Status.running) return;
    if (isMobile && backupViaCellular != true) {
      this.paused();
    } else {
      status = Status.running;
      monitorStart();
      worker = Worker(apis);
      worker.start();
    }
  }

  void abort() {
    worker?.abort();
    worker = null;
    monitorCancel();
    status = Status.aborted;
  }

  /// pause backup
  void paused() {
    this.abort();
    status = Status.paused;
    monitorStart();
  }

  void updateConfig({bool shouldBackupViaCellular, bool autoBackup}) async {
    this.backupViaCellular = shouldBackupViaCellular;
    // backup is disabled
    if (autoBackup != true) return;

    isMobile = await apis.isMobile();
    if (isMobile && backupViaCellular != true) {
      this.paused();
    } else {
      // restart
      this.abort();
      this.start(isMobile);
    }
  }

  bool get isIdle => worker?.status == Status.idle;
  bool get isRunning => worker?.status == Status.running;
  bool get isFinished => worker?.status == Status.finished;
  bool get isFailed => worker?.status == Status.failed;

  bool get isPaused => status == Status.paused;
  bool get isAborted => status == Status.aborted;

  bool get isDiffing => isRunning && !worker.uploading;

  String get progress => worker == null
      ? ''
      : isDiffing
          ? '${(worker.finished / (worker.total + 1) * 100).floor()}%'
          : '${worker.finished} / ${worker.total}   ${worker.speed ?? ''}';

  bool get hasError => isFailed && error != null;

  String get error => worker?.latestError?.toString();
}
