import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/isolate.dart';
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
    this.hdate = prettyDate(date, showMonth: true);
  }
}

/// List of PhotoEntry from station
class RemoteList {
  Entry entry;
  List<Entry> items;

  /// initial value is items' length
  int length;

  RemoteList(this.entry, this.items) {
    this.length = items.length;
  }

  /// increace RemoteList's length by one
  fakeAdd() {
    length += 1;
  }
}

/// manager of photo backup
class BackupWorker {
  Apis apis;
  BackupWorker(this.apis, this.backupViaCellular);
  String machineId;
  String deviceName;
  CancelToken cancelToken;

  CancelIsolate cancelUpload;
  CancelIsolate cancelHash;
  Status status = Status.idle;

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

  /// use cellular to backup items
  bool backupViaCellular = false;

  /// get all local photos and videos
  Future<List<AssetEntity>> getAssetList() async {
    final result = await PhotoManager.requestPermission();
    if (!result) return [];
    List<AssetPathEntity> pathList = await PhotoManager.getAssetPathList();
    List<AssetEntity> localAssetList = await pathList[0].assetList;
    localAssetList.sort((a, b) => b.createTime - a.createTime);
    return localAssetList;
  }

  Future<Drive> getBackupDrive() async {
    final res = await apis.req('drives', null);
    // get current drives data
    List<Drive> drives = List.from(
      res.data.map((drive) => Drive.fromMap(drive)),
    );

    Drive backupDrive = drives.firstWhere(
      (d) => d?.client?.id == machineId,
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

    final photosDir =
        rawEntries.firstWhere((e) => e.name == '照片', orElse: () => null);
    return photosDir;
  }

  Future<Entry> getDir() async {
    Drive backupDrive = await getBackupDrive();

    if (backupDrive == null) {
      // create backupDrive
      final args = {
        'op': 'backup',
        'label': deviceName,
        'client': {
          'id': machineId,
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
        'dirname': '照片',
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

  Future<Entry> getTargetDir(
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

        // increase length
        remoteList.fakeAdd();
        return targetDir;
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
    newRemoteList.fakeAdd();
    remoteDirs.add(newRemoteList);

    return targetDir;
  }

  /// get Hash from hashViaIsolate or shared_preferences
  /// use AssetEntity.id + createTime as the photo's identity
  Future<String> getHash(String id, AssetEntity entity) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String hash = prefs.getString(id);
    if (hash == null) {
      cancelHash = CancelIsolate();
      File file = await entity.originFile;
      String filePath = file.path;
      hash = await hashViaIsolate(filePath, cancelIsolate: cancelHash);
      if (hash == null) throw 'hash error';
      await prefs.setString(id, hash);
    }
    return hash;
  }

  Future<void> uploadSingle(
      AssetEntity entity, List<RemoteList> remoteDirs, Entry rootDir) async {
    // final time = getNow();

    String id = entity.id;
    int mtime = entity.createTime;

    // print('before hash: $id, ${getNow() - time}');
    String hash = await getHash('$id+$mtime', entity);

    // print('after hash, ${getNow() - time}');
    final photoEntry = PhotoEntry(id, hash, mtime);

    final targetDir = await getTargetDir(remoteDirs, photoEntry, rootDir);

    // already backuped, continue next
    if (targetDir == null) {
      finished += 1;
      ignored += 1;
      // print('backup ignore: $id, ${getNow() - time}');
      return;
    }

    // check network status
    final isMobile = await apis.isMobile();
    if (isMobile && backupViaCellular != true) {
      status = Status.paused;
      return;
    }

    // print('before upload: $id, ${getNow() - time}');
    // update cancelIsolate
    cancelUpload = CancelIsolate();

    // upload photo
    File file = await entity.originFile;
    String filePath = file.path;

    await uploadViaIsolate(apis, targetDir, filePath, hash, mtime,
        cancelIsolate: cancelUpload);

    // delete tmp file, only in iOS
    if (Platform.isIOS) {
      await file.delete();
    }

    // print('backup success: $id in ${DateTime.now().millisecondsSinceEpoch - time} ms');
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
    final isMobile = await apis.isMobile();
    if (isMobile && backupViaCellular != true) {
      status = Status.paused;
      return;
    }

    status = Status.running;
    final data = await getMachineId();
    deviceName = data['deviceName'];
    machineId = data['machineId'];
    final Entry rootDir = await getDir();
    assert(rootDir is Entry);
    List<AssetEntity> assetList = await getAssetList();
    total = assetList.length;
    final remoteDirs = await getRemoteDirs(rootDir);
    for (AssetEntity entity in assetList) {
      if (status == Status.running) {
        try {
          await uploadSingle(entity, remoteDirs, rootDir);
        } catch (e) {
          print('backup failed: ${entity.id}');
          print(e);
        }
      } else if (status == Status.paused) {
        return;
      }
    }
    // TODO: handle error
    if (finished == total) {
      print('upload all assetList');
      await updateStatus(rootDir);
      print('updateStatus finished');
      status = Status.finished;
      finished = 0;
      ignored = 0;
    } else {
      print('not all upload success');
      status = Status.failed;
      retryLater();
    }
  }

  void start() {
    if (status == Status.running) return;
    startAsync().catchError((e) {
      print(e);
      retryLater();
    });
    print('backup started');
  }

  void abort() {
    if (status == Status.running) {
      try {
        cancelUpload?.cancel();
        cancelHash?.cancel();
      } catch (e) {
        print(e);
      }
    }
    finished = 0;
    ignored = 0;
    retry = 0;
    status = Status.aborted;
    print('backup aborted');
  }

  /// used in toggle shouldBackupViaCellular
  void restart() {
    this.abort();
    this.start();
  }

  /// retry after backup failed in `retry * retry` minutes
  void retryLater() {
    retry += 1;
    Future.delayed(Duration(minutes: retry * retry), () {
      this.start();
    });
  }

  void updateConfig({bool shouldBackupViaCellular}) {
    this.backupViaCellular = shouldBackupViaCellular;
  }

  bool get isIdle => status == Status.idle;
  bool get isRunning => status == Status.running;
  bool get isFinished => status == Status.finished;
  bool get isFailed => status == Status.failed;
  bool get isPaused => status == Status.paused;
  bool get isAborted => status == Status.aborted;
  bool get isDiffing => isRunning && ignored != finished;

  String get progress => '$finished / $total';
}
