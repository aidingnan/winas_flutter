import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pocket_drive/common/eventBus.dart';
import 'package:uuid/uuid.dart';
import 'package:async/async.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart' as synchronized;

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/isolate.dart';

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
  Function deleteFile;

  /// status of TransferItem: init, working, paused, finished, failed;
  String status = 'init';

  TransferItem({this.entry, this.transType, this.filePath, this.targetDir})
      : this.uuid = Uuid().v4();

  TransferItem.fromMap(Map m) {
    this.entry = Entry.fromMap(jsonDecode(m['entry']));
    this.uuid = m['uuid'];
    this.status = m['status'] == 'working' ? 'paused' : m['status'];
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

  void start(CancelToken cancelToken, Function deleteFile) {
    this.deleteFile = deleteFile;
    this.cancelToken = cancelToken;
    this.startTime = DateTime.now().millisecondsSinceEpoch;
    this.status = 'working';
  }

  void reload(Function deleteFile) {
    this.deleteFile = deleteFile;
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
    this.deleteFile();
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
        return 30;
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

  /// init and load TransferItems
  static Future<void> init(String uuid) async {
    assert(uuid != null);

    TransferManager newInstance = TransferManager._();
    _instance = newInstance;

    // current user
    userUUID = uuid;

    // mkdir
    Directory root = await getApplicationDocumentsDirectory();
    _instance._rootDir = root.path;

    await Directory(_instance._transDir()).create(recursive: true);
    await Directory(_instance._downloadDir()).create(recursive: true);

    try {
      transferList = await _instance._load();
      // reload transferItem
      for (TransferItem item in transferList) {
        if (item.transType == TransType.download) {
          item.reload(
              () => _instance._cleanDir(item.filePath).catchError(debug));
        } else {
          // update to the correct filePath
          final pathList = item.filePath.split('/');
          final truePath = _instance._transDir() +
              pathList[pathList.length - 2] +
              '/' +
              pathList.last;
          item.filePath = truePath;
          item.reload(() => {});
        }
      }
    } catch (error) {
      debug('load TransferItem error: $error');
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
    await file.delete(recursive: true);
    await _save();
  }

  Future<void> _downloadFile(TransferItem item, AppState state) async {
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
    } catch (error) {
      debug(error);
      // DioErrorType.CANCEL is not error
      if (error is DioError && (error?.type != DioErrorType.CANCEL)) {
        item.fail(error);
      }
    }
  }

  /// creat a new download task
  newDownload(Entry entry, AppState state) {
    TransferItem item = TransferItem(
      entry: entry,
      transType: TransType.download,
    );
    transferList.add(item);
    _downloadFile(item, state).catchError((onError) => item.fail(onError));
  }

  Future<Entry> getTargetDir(
      AppState state, Drive drive, String dirname) async {
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

  /// upload file in Isolate
  Future<void> uploadAsync(AppState state, Entry targetDir, String filePath,
      String hash, CancelToken cancelToken, Function onProgress) async {
    final fileName = filePath.split('/').last;
    File file = File(filePath);
    final FileStat stat = await file.stat();

    final formDataOptions = {
      'op': 'newfile',
      'size': stat.size,
      'sha256': hash,
      'bctime': stat.modified.millisecondsSinceEpoch,
      'bmtime': stat.modified.millisecondsSinceEpoch,
      'policy': ['rename', 'rename'],
    };

    final args = {
      'driveUUID': targetDir.pdrv,
      'dirUUID': targetDir.uuid,
      'fileName': fileName,
      'file': UploadFileInfo(file, jsonEncode(formDataOptions)),
    };

    await state.apis
        .uploadAsync(args, cancelToken: cancelToken, onProgress: onProgress);
  }

  Future<void> uploadSharedFile(TransferItem item, AppState state) async {
    final filePath = item.filePath;
    CancelToken cancelToken = CancelToken();
    item.start(cancelToken, () => {});
    try {
      await _save();

      // get target dir
      final targetDirName = i18n('Folder Name For Shared Files From Other App');

      final Drive drive =
          state.drives.firstWhere((d) => d.tag == 'home', orElse: () => null);
      Entry targetDir = await getTargetDir(state, drive, targetDirName);

      if (targetDir == null) {
        // make backup root directory
        await state.apis.req('mkdir', {
          'dirname': targetDirName,
          'dirUUID': drive.uuid,
          'driveUUID': drive.uuid,
        });

        // retry getPhotosDir
        targetDir = await getTargetDir(state, drive, targetDirName);
      }
      // update targetDir
      item.targetDir = targetDir;

      // hash
      final hash = await hashViaIsolate(filePath);

      // upload async
      await uploadAsync(state, targetDir, filePath, hash, cancelToken,
          (int a, int b) => item.update(a));

      item.finish();

      await _save();
    } catch (error) {
      debug(error);
      // DioErrorType.CANCEL is not error
      if (error is! DioError || (error?.type != DioErrorType.CANCEL)) {
        item.fail(error);
      }
    }
  }

  /// creat a new shared task. handle shared file from other app
  newUploadSharedFile(String filePath, AppState state) {
    File(filePath)
      ..stat().then(
        (stat) {
          debug('newUploadSharedFile $stat');
          if (stat.type != FileSystemEntityType.notFound) {
            String name = filePath.split('/').last;
            TransferItem item = TransferItem(
              entry: Entry(name: name, size: stat.size),
              transType: TransType.shared,
              filePath: filePath,
            );
            transferList.add(item);
            uploadSharedFile(item, state).catchError((error) {
              debug(error);
              // DioErrorType.CANCEL is not error
              if (error is! DioError || (error?.type != DioErrorType.CANCEL)) {
                item.fail(error);
              }
            });
          }
        },
      ).catchError(debug);
  }

  Future<void> uploadFile(TransferItem item, AppState state) async {
    final filePath = item.filePath;
    CancelToken cancelToken = CancelToken();
    item.start(cancelToken, () => {});
    try {
      await _save();

      // get target dir
      Entry targetDir = item.targetDir;

      // hash
      final hash = await hashViaIsolate(filePath);

      // upload async
      await uploadAsync(state, targetDir, filePath, hash, cancelToken,
          (int a, int b) => item.update(a));

      item.finish();

      await _save();
    } catch (error) {
      debug(error);
      // DioErrorType.CANCEL is not error
      if (error is! DioError || (error?.type != DioErrorType.CANCEL)) {
        item.fail(error);
      }
    }
  }

  /// creat a new upload task
  newUploadFile(String filePath, Entry targetDir, AppState state) {
    File(filePath)
      ..stat().then(
        (stat) {
          debug('new Upload File $stat');
          if (stat.type != FileSystemEntityType.notFound) {
            String name = filePath.split('/').last;
            TransferItem item = TransferItem(
              entry: Entry(name: name, size: stat.size),
              transType: TransType.upload,
              filePath: filePath,
              targetDir: targetDir,
            );
            transferList.add(item);
            uploadFile(item, state).catchError((error) {
              debug(error);
              // DioErrorType.CANCEL is not error
              if (error is! DioError || (error?.type != DioErrorType.CANCEL)) {
                item.fail(error);
              }
            });
          }
        },
      ).catchError(debug);
  }
}
