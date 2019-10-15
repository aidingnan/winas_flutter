import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:async/async.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart' as synchronized;

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/isolate.dart';
import '../common/eventBus.dart';

enum TransType {
  shared,
  upload,
  download,
}

class Task {
  final AsyncMemoizer lock = AsyncMemoizer();
  final String name;
  Task(this.name);
}

class TransferItem {
  String uuid;
  Entry entry;
  Entry targetDir;
  TransType transType;
  String speed = '';
  List<int> deltaSizeList = [];
  List<int> deltaTimeList = [];
  String error;
  int finishedTime = -1;
  int startTime = -1;
  int finishedSize = 0;
  String filePath = '';

  CancelToken cancelToken;
  Function callback;

  /// status of TransferItem: init, working, paused, finished, failed;
  String status = 'init';

  TransferItem({this.entry, this.transType, this.filePath, this.targetDir})
      : this.uuid = Uuid().v4();

  TransferItem.fromMap(Map m) {
    this.entry = Entry.fromMap(jsonDecode(m['entry']));
    this.uuid = m['uuid'];
    this.status =
        ['working', 'init'].contains(m['status']) ? 'paused' : m['status'];
    this.finishedTime = m['finishedTime'];
    this.startTime = m['startTime'];
    this.finishedSize = m['finishedSize'] ?? 0;
    this.filePath = m['filePath'];
    this.targetDir = m['targetDir'] is String
        ? Entry.fromMap(jsonDecode(m['targetDir']))
        : null;
    switch (m['transType']) {
      case 'TransType.shared':
        this.transType = TransType.shared;
        break;
      case 'TransType.download':
        this.transType = TransType.download;
        break;
      case 'TransType.upload':
        this.transType = TransType.upload;
        break;
      default:
    }
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'entry': entry,
      'targetDir': targetDir,
      'uuid': uuid,
      'status': status,
      'finishedTime': finishedTime,
      'startTime': startTime,
      'finishedSize': finishedSize,
      'filePath': filePath,
      'error': error,
      'transType': transType.toString()
    };
    return jsonEncode(m);
  }

  String toJson() => toString();

  void setFilePath(String path) {
    this.filePath = path;
  }

  void update(int size) {
    this.finishedSize = size;
    int now = DateTime.now().millisecondsSinceEpoch;

    this.deltaSizeList.insert(0, size);
    this.deltaTimeList.insert(0, now);

    final deltaSize = this.deltaSizeList.first - this.deltaSizeList.last;

    // add 40 to avoid show a mistake large speed
    final deltaTime = this.deltaTimeList.first - this.deltaTimeList.last + 40;

    final speed = deltaSize / deltaTime * 1000;
    this.speed = '${prettySize(speed)}/s';

    // get average value of up to last 4 seconds or 256 update-data
    if (deltaTime > 4 * 1000 || this.deltaSizeList.length > 256) {
      this.deltaSizeList.removeLast();
      this.deltaTimeList.removeLast();
    }
  }

  void start(CancelToken cancelToken, Function cleanAndSave) {
    this.callback = cleanAndSave;
    this.cancelToken = cancelToken;
    this.startTime = DateTime.now().millisecondsSinceEpoch;
    this.status = 'working';
  }

  void reload(Function cleanAndSave) {
    this.callback = cleanAndSave;
  }

  void pause() {
    if (this.cancelToken != null && this.cancelToken?.isCancelled != true) {
      this.cancelToken.cancel("cancelled");
    }

    this.speed = '';
    this.status = 'paused';
  }

  void clean() {
    this.pause();
    if (this.callback is Function) {
      this.callback();
    }
  }

  void resume() {
    this.speed = '';
    this.error = '';
    this.status = 'working';
  }

  void finish() {
    this.finishedTime = DateTime.now().millisecondsSinceEpoch;
    this.status = 'finished';

    // send event to trigger refresh
    if (this.transType != TransType.download) {
      eventBus.fire(RefreshEvent(this.targetDir.uuid));
    }
  }

  void fail(dynamic error) {
    this.status = 'failed';
    // convert dynamic error to String
    this.error = converError(error);
  }

  /// sort order
  int get order {
    switch (status) {
      case 'init':
        return 60;
      case 'working':
        return 100;
      case 'paused':
        return 50;
      case 'finished':
        return 10;
      case 'failed':
        return 20;
    }
    return 1000;
  }

  bool get isShare => transType == TransType.shared;
}

class TransferManager {
  static TransferManager _instance;
  static TransferManager getInstance() {
    return _instance;
  }

  static List<TransferItem> transferList = [];
  static List<TransferItem> getList() {
    return transferList;
  }

  TransferManager._();

  /// local user uuid
  static String userUUID;

  static AppState state;

  /// init and load TransferItems
  static Future<void> init(String uuid, AppState appState) async {
    assert(uuid != null);

    TransferManager newInstance = TransferManager._();
    _instance = newInstance;

    // current user
    userUUID = uuid;

    // update current appState
    state = appState;

    // mkdir
    Directory root = await getApplicationDocumentsDirectory();
    _instance._rootDir = root.path;

    await Directory(_instance._transDir()).create(recursive: true);
    await Directory(_instance._downloadDir()).create(recursive: true);

    if (Platform.isAndroid) {
      Directory public = await getExternalStorageDirectory();
      _instance._publicRoot = public.path;
    }

    try {
      transferList = await _instance._load();
      // reload transferItem
      for (TransferItem item in transferList) {
        if (item.transType == TransType.download) {
          // TransType.download
          if (Platform.isAndroid) {
            item.reload(() => {});
          } else {
            item.reload(
                () => _instance._cleanDir(item.filePath).catchError(debug));
          }
        } else {
          // TransType.shared or isIOS, need to update to the correct filePath
          final pathList = item.filePath.split('/');

          if (item.transType == TransType.shared || Platform.isIOS) {
            final truePath = _instance._transDir() +
                pathList[pathList.length - 2] +
                '/' +
                pathList.last;
            item.filePath = truePath;
          }

          item.reload(() => _instance._save().catchError(debug));
        }
      }
    } catch (error) {
      transferList = [];
    }
    return;
  }

  String _rootDir;

  String _transDir() {
    return _rootDir + '/trans/';
  }

  String _downloadDir() {
    return _rootDir + '/download/' + userUUID + '/';
  }

  String _publicRoot;

  String _publicDownload() {
    if (Platform.isAndroid) {
      return _publicRoot + '/Download/PocketDrive/';
    } else {
      return _rootDir + '/download/' + userUUID + '/';
    }
  }

  Future<List<TransferItem>> _load() async {
    String path = _downloadDir() + 'list.json';
    File file = File(path);
    String json = await file.readAsString();

    List<TransferItem> list = List.from(
      jsonDecode(json).map((item) => TransferItem.fromMap(jsonDecode(item))),
    );

    return list;
  }

  static synchronized.Lock _lock = synchronized.Lock();

  // sync data to disk
  void syncData() {
    _save().catchError(debug);
  }

  // async method of save data
  Future<void> _save() async {
    await _lock.synchronized(() async {
      String json = jsonEncode(transferList);
      String path = _downloadDir() + 'list.json';
      String transPath = _transDir() + Uuid().v4();
      File file = File(transPath);
      await file.writeAsString(json);
      await file.rename(path);
    });
  }

  Future<void> _cleanDir(String path) async {
    File file = File(path);
    try {
      await file.delete(recursive: true);
    } catch (e) {
      debug(e);
    }

    await _save();
  }

  Future<Entry> getTargetDir(Drive drive, String dirname) async {
    final uuid = drive.uuid;
    final listNav = await state.apis.req('listNavDir', {
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
        rawEntries.firstWhere((e) => e.name == dirname, orElse: () => null);
    return photosDir;
  }

  /// TODO: upload file in Isolate
  Future<void> _uploadAsync(
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

      final args = {
        'driveUUID': targetDir.pdrv,
        'dirUUID': targetDir.uuid,
        'fileName': fileName,
        "file": [
          MultipartFile(
            file.openRead(part.start, max(part.end, 0)),
            size,
            filename: jsonEncode(formDataOptions),
          )
        ],
      };

      await state.apis
          .uploadAsync(args, cancelToken: cancelToken, onProgress: onProgress);
    }
  }

  // call _uploadAsync, need clean files in trans
  Future<void> uploadSharedFile(TransferItem item) async {
    final filePath = item.filePath;
    CancelToken cancelToken = CancelToken();
    item.start(cancelToken, () => _instance._save().catchError(debug));
    try {
      await _save();

      // get target dir
      final targetDirName = i18n('Folder Name For Shared Files From Other App');

      final Drive drive =
          state.drives.firstWhere((d) => d.tag == 'home', orElse: () => null);
      Entry targetDir = await getTargetDir(drive, targetDirName);

      if (targetDir == null) {
        // make backup root directory
        await state.apis.req('mkdir', {
          'dirname': targetDirName,
          'dirUUID': drive.uuid,
          'driveUUID': drive.uuid,
        });

        // retry getPhotosDir
        targetDir = await getTargetDir(drive, targetDirName);
      }
      // update targetDir
      item.targetDir = targetDir;

      final parts = await hashViaIsolate(filePath);

      // upload async
      await _uploadAsync(targetDir, filePath, parts, cancelToken,
          (int a, int b) => item.update(a));

      // delete cache in trans
      await File(filePath).parent.delete(recursive: true);

      item.finish();

      await _save();

      schedule();
    } catch (error) {
      debug(error);
      // DioErrorType.CANCEL is not error
      if (error is! DioError || (error?.type != DioErrorType.CANCEL)) {
        item.fail(error);
      }
      schedule();
    }
  }

  // call _uploadAsync
  Future<void> uploadFile(TransferItem item) async {
    final filePath = item.filePath;
    CancelToken cancelToken = CancelToken();
    item.start(cancelToken, () => _instance._save().catchError(debug));
    try {
      await _save();

      // get target dir
      Entry targetDir = item.targetDir;

      final parts = await hashViaIsolate(filePath);

      // upload async
      await _uploadAsync(targetDir, filePath, parts, cancelToken,
          (int a, int b) => item.update(a));

      item.finish();

      await _save();
      schedule();
    } catch (error) {
      // DioErrorType.CANCEL is not error
      if (error is! DioError || (error?.type != DioErrorType.CANCEL)) {
        debug(error);
        item.fail(error);
      }
      schedule();
    }
  }

  // call state.apis.download
  Future<void> downloadIOSFile(TransferItem item) async {
    Entry entry = item.entry;

    // use unique transferItem uuid
    String entryDir = _downloadDir() + item.uuid + '/';
    String entryPath = entryDir + entry.name;
    String transPath = _transDir() + Uuid().v4();
    item.setFilePath(entryPath);
    CancelToken cancelToken = CancelToken();
    item.start(cancelToken, () => _cleanDir(entryDir).catchError(debug));

    final ep = 'drives/${entry.pdrv}/dirs/${entry.pdir}/entries/${entry.uuid}';
    final qs = {'name': entry.name, 'hash': entry.hash};
    try {
      await _save();
      // mkdir
      await Directory(entryDir).create(recursive: true);
      // download
      await state.apis.download(ep, qs, transPath, cancelToken: cancelToken,
          onProgress: (int a, int b) {
        item.update(a);
      });
      // rename
      await File(transPath).rename(entryPath);
      item.finish();
      await _save();

      schedule();
    } catch (error) {
      debug(error);
      // DioErrorType.CANCEL is not error
      if (error is DioError && (error?.type != DioErrorType.CANCEL)) {
        item.fail(error);
      }
      schedule();
    }
  }

  // call state.apis.download
  Future<void> downloadAndroidFile(TransferItem item) async {
    CancelToken cancelToken = CancelToken();
    item.start(cancelToken, () => {});

    Entry entry = item.entry;

    String entryDir = _publicDownload();

    final result = await PhotoManager.requestPermission();

    if (!result) return;

    final list = await Directory(entryDir).list().toList();
    print(list.map((d) => d.path));
    // TODO: auto rename

    String entryPath = entryDir + entry.name;
    // String transPath = entryDir + entry.name + '.download';
    item.setFilePath(entryPath);

    final ep = 'drives/${entry.pdrv}/dirs/${entry.pdir}/entries/${entry.uuid}';
    final qs = {'name': entry.name, 'hash': entry.hash};
    try {
      await _save();
      // mkdir
      await Directory(entryDir).create(recursive: true);
      // download
      await state.apis.download(ep, qs, entryPath, cancelToken: cancelToken,
          onProgress: (int a, int b) {
        item.update(a);
      });
      // rename
      // await File(transPath).rename(entryPath);
      item.finish();
      await _save();

      schedule();
    } catch (error) {
      debug(error);
      // DioErrorType.CANCEL is not error
      if (error is DioError && (error?.type != DioErrorType.CANCEL)) {
        item.fail(error);
      }
      schedule();
    }
  }

  static List<TransferItem> taskQueue = [];
  final taskLimit = 2;

  void addToTaskQueue(TransferItem item) {
    taskQueue.add(item);
    schedule();
  }

  void schedule() {
    // remove finished
    taskQueue.removeWhere((t) => !['working', 'init'].contains(t.status));

    taskQueue.sort((a, b) {
      if (b.order != a.order) return b.order - a.order;
      if (b.startTime != a.startTime) return b.startTime - a.startTime;
      return b.entry.name.compareTo(a.entry.name);
    });

    // calc number of task left to run
    int freeNum =
        taskLimit - taskQueue.where((t) => t.status == 'working').length;

    // run pending tasks
    if (freeNum > 0) {
      taskQueue.where((t) => t.status == 'init').take(freeNum).forEach((t) {
        // TransferItem.run()
        switch (t.transType) {
          case TransType.download:
            if (Platform.isAndroid) {
              downloadAndroidFile(t);
            } else {
              downloadIOSFile(t);
            }

            break;
          case TransType.upload:
            uploadFile(t);
            break;
          case TransType.shared:
            uploadSharedFile(t);
            break;
          default:
        }
      });
    }
  }

  /// creat a new download task
  void newDownload(Entry entry, AppState newState) {
    // update current appState
    state = newState;

    TransferItem item = TransferItem(
      entry: entry,
      transType: TransType.download,
    );
    transferList.add(item);
    addToTaskQueue(item);
    Future.delayed(Duration.zero, () => schedule());
  }

  /// creat a new upload task
  void newUploadFile(String filePath, Entry targetDir, AppState newState) {
    // update current appState
    state = newState;
    File(filePath)
      ..stat().then(
        (stat) {
          String name = filePath.split('/').last;
          TransferItem item = TransferItem(
            entry: Entry(name: name, size: stat.size),
            transType: TransType.upload,
            filePath: filePath,
            targetDir: targetDir,
          );

          if (stat.type != FileSystemEntityType.notFound) {
            transferList.add(item);
            addToTaskQueue(item);
          } else {
            item.fail(i18n('Target File Not Found'));
            transferList.add(item);
          }
        },
      ).catchError(debug);
  }

  /// creat a new shared task. handle shared file from other app
  void newUploadSharedFile(String filePath, AppState newState) {
    // update current appState
    state = newState;

    File(filePath)
      ..stat().then(
        (stat) {
          String name = filePath.split('/').last;
          TransferItem item = TransferItem(
            entry: Entry(name: name, size: stat.size),
            transType: TransType.shared,
            filePath: filePath,
          );
          if (stat.type != FileSystemEntityType.notFound) {
            transferList.add(item);
            addToTaskQueue(item);
          } else {
            item.fail(i18n('Target File Not Found'));
            transferList.add(item);
          }
        },
      ).catchError(debug);
  }
}
