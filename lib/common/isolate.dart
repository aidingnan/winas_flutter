import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

import '../redux/redux.dart';
import '../common/stationApis.dart';

/// handle cancel an isolate (via Isolate.kill())
class CancelIsolate {
  Isolate target;
  bool canceled = false;

  cancel() {
    if (canceled) return;

    if (target != null) {
      try {
        print('kill isolate target');
        target.kill();
      } catch (e) {
        print('kill isolate error:\n $e');
      }
    }
    canceled = true;
  }

  setTarget(Isolate work) {
    target = work;
  }
}

/// A sink used to get a digest value out of `Hash.startChunkedConversion`.
class DigestSink extends Sink<Digest> {
  /// The value added to the sink, if any.
  Digest get value {
    assert(_value != null);
    return _value;
  }

  Digest _value;

  /// Adds [value] to the sink.
  ///
  /// Unlike most sinks, this may only be called once.
  @override
  void add(Digest value) {
    assert(_value == null);
    _value = value;
  }

  @override
  void close() {
    assert(_value != null);
  }
}

/// Pure isolate function to hash file
void isolateHash(SendPort sendPort) {
  final port = ReceivePort();
  // send current sendPort to caller
  sendPort.send(port.sendPort);

  // listen message from caller
  port.listen((message) {
    final filePath = message[0] as String;
    final answerSend = message[1] as SendPort;
    File file = File(filePath);
    final stream = file.openRead();
    final ds = DigestSink();

    final s = sha256.startChunkedConversion(ds);
    stream.listen(
      (List<int> chunk) {
        s.add(chunk);
      },
      onDone: () {
        s.close();
        final digest = ds.value;
        answerSend.send(digest.toString());
        port.close();
      },
      onError: (error) {
        print(error);
        answerSend.send(null);
        port.close();
      },
      cancelOnError: true,
    );
  });
}

/// upload single photo to target dir in Isolate
void isolateUpload(SendPort sendPort) {
  final port = ReceivePort();

  // send current sendPort to caller
  sendPort.send(port.sendPort);

  // listen message from caller
  port.listen((message) {
    final entryJson = message[0] as String;
    final filePath = message[1] as String;
    final sha256Value = message[2] as String;
    final mtime = message[3] as int;
    final apisJson = message[4] as String;
    final isCloud = message[5] as bool;
    final answerSend = message[6] as SendPort;
    final progressSend = message[7] as SendPort;
    final fileName = message[8] as String;

    final dir = Entry.fromMap(jsonDecode(entryJson));

    final file = File(filePath);
    final apis = Apis.fromMap(jsonDecode(apisJson));

    // set network status
    apis.isCloud = isCloud;

    final FileStat stat = file.statSync();

    final formDataOptions = {
      'op': 'newfile',
      'size': stat.size,
      'sha256': sha256Value,
      'bctime': mtime,
      'bmtime': mtime,
      'policy': ['rename', 'rename'],
    };

    final args = {
      'driveUUID': dir.pdrv,
      'dirUUID': dir.uuid,
      'fileName': fileName,
      'file': UploadFileInfo(file, jsonEncode(formDataOptions)),
    };

    print('$fileName: ${stat.size}');

    apis.upload(
      args,
      (error, value) {
        if (error != null) {
          answerSend.send(error.toString());
        } else {
          answerSend.send(null);
        }
      },
      onProgress: (int count, int total) {
        progressSend.send([count, total]);
      },
    );

    port.close();
  });
}

/// hash file in Isolate
Future<String> hashViaIsolate(String filePath,
    {CancelIsolate cancelIsolate}) async {
  final response = ReceivePort();
  final work = await Isolate.spawn(isolateHash, response.sendPort);

  if (cancelIsolate != null) {
    cancelIsolate.setTarget(work);
  }
  // sendPort from isolateHash
  final sendPort = await response.first as SendPort;
  final answer = ReceivePort();

  // send filePath and sendPort(to get answer) to isolateHash
  sendPort.send([filePath, answer.sendPort]);
  final res = await answer.first as String;
  return res;
}

/// upload file in Isolate
Future<void> uploadViaIsolate(Apis apis, Entry targetDir, String filePath,
    String hash, int mtime, String fileName,
    {CancelIsolate cancelIsolate, Function updateSpeed}) async {
  final response = ReceivePort();

  final work = await Isolate.spawn(isolateUpload, response.sendPort);

  if (cancelIsolate != null) {
    cancelIsolate.setTarget(work);
  }

  // sendPort from isolateHash
  final sendPort = await response.first as SendPort;
  final answer = ReceivePort();
  final progressRes = ReceivePort();

  // send filePath and sendPort(to get answer) to isolateHash
  // Object in params need to convert to String
  // final entryJson = message[0] as String;
  // final filePath = message[1] as String;
  // final hash = message[2] as String;
  // final mtime = message[3] as int;
  // final apisJson = message[4] as String;
  // final isCloud = message[5] as bool;
  // final answerSend = message[6] as SendPort;
  // final progressSend = message[7] as SendPort;
  // final fileName = message[8] as String;

  sendPort.send([
    targetDir.toString(),
    filePath,
    hash,
    mtime,
    apis.toString(),
    apis.isCloud,
    answer.sendPort,
    progressRes.sendPort,
    fileName,
  ]);
  List<int> uploadedList = [];
  List<int> timeList = [];

  progressRes.listen((res) {
    // print('progressRes.listen res ${res[0]}, ${res[1]}');
    int uploaded = res[0];
    int now = DateTime.now().millisecondsSinceEpoch;
    uploadedList.insert(0, uploaded);
    timeList.insert(0, now);
    final deltaSize = uploadedList.first - uploadedList.last;

    // add 40 to avoid show a mistake large speed
    final deltaTime = timeList.first - timeList.last + 40;
    final speed = deltaSize / deltaTime * 1000;
    updateSpeed(speed);
    if (deltaTime > 4 * 1000 || uploadedList.length > 256) {
      uploadedList.removeLast();
      timeList.removeLast();
    }
  });

  final error = await answer.first;

  progressRes.close();
  uploadedList.length = 0;
  timeList.length = 0;

  if (error != null) throw error;
}
