import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'dart:io' show Platform;
import 'package:connectivity/connectivity.dart';

import './eventBus.dart';
import '../common/appConfig.dart';

class Apis {
  bool isIOS = !Platform.isAndroid;
  bool isCloud;
  String get cloudAddress => AppConfig.cloudAddress;
  String token;
  String cookie;
  String lanToken;
  String lanIp;
  String lanAdrress;
  String userUUID;
  String deviceSN;
  StreamSubscription<ConnectivityResult> sub;
  Dio dio = Dio();

  // handle error globally
  bool tokenExpired = false;
  bool stationOnline = true;

  Apis(this.token, this.lanIp, this.lanToken, this.userUUID, this.isCloud,
      this.deviceSN, this.cookie) {
    this.lanAdrress = 'http://${this.lanIp}:3000';
  }

  Apis.fromMap(Map m) {
    this.token = m['token'];
    this.lanIp = m['lanIp'];
    this.lanToken = m['lanToken'];
    this.userUUID = m['userUUID'];
    // reload from disk, isCloud = null, need to re-test;
    this.isCloud = null;
    this.deviceSN = m['deviceSN'];
    this.cookie = m['cookie'];
    this.lanAdrress = 'http://${this.lanIp}:3000';
  }
  @override
  String toString() {
    Map<String, dynamic> m = {
      'token': token,
      'lanIp': lanIp,
      'lanToken': lanToken,
      'userUUID': userUUID,
      'deviceSN': deviceSN,
      'cookie': cookie,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();

  void updateLanIp(String newIP) {
    this.lanIp = newIP;
    this.lanAdrress = 'http://${this.lanIp}:3000';
  }

  /// handle data.data response
  void interceptDio() {
    InterceptorsWrapper interceptorsWrapper = InterceptorsWrapper(
      onResponse: (Response response) {
        // only handle ResponseType.json
        if (response.request.responseType != ResponseType.json) return response;
        bool isCloud = false;
        try {
          if (response.data is Map && response.data['data'] != null) {
            isCloud = true;
          }
        } catch (e) {
          print('interceptDio get data.data failed: $e');
          print(response.data);
          isCloud = false;
        }

        if (isCloud) return response.data['data'];
        return response.data;
      },
      onError: (DioError error) {
        if (error is DioError) {
          if (error?.response?.statusCode == 401) {
            // tokenExpired
            this.tokenExpired = true;
            eventBus.fire(TokenExpiredEvent('401 in station apis'));
          } else if (error?.response?.data is Map &&
              error.response.data['message'] == 'Station is not online') {
            // station not online
            this.stationOnline = false;
            eventBus.fire(StationNotOnlineEvent('Station is not online'));
          }
        }
        return error;
      },
    );
    if (dio.interceptors.length == 0) {
      dio.interceptors.add(interceptorsWrapper);
    } else {
      dio.interceptors[0] = interceptorsWrapper;
    }
  }

  /// get with token
  tget(String ep, Map<String, dynamic> args) {
    assert(token != null);
    if (isCloud ?? true) return command('GET', ep, args);
    dio.options.headers['authorization'] = 'JWT $lanToken';
    return dio.get('$lanAdrress/$ep', queryParameters: args);
  }

  /// post with token
  tpost(String ep, dynamic args,
      {CancelToken cancelToken, Function onProgress}) {
    assert(token != null);
    if (isCloud ?? true)
      return command('POST', ep, args,
          cancelToken: cancelToken, onProgress: onProgress);
    dio.options.headers['authorization'] = 'JWT $lanToken';
    return dio.post('$lanAdrress/$ep',
        data: args, cancelToken: cancelToken, onSendProgress: onProgress);
  }

  /// post with token
  tpatch(String ep, dynamic args) {
    assert(token != null);
    if (isCloud ?? true) return command('PATCH', ep, args);
    dio.options.headers['authorization'] = 'JWT $lanToken';
    return dio.patch('$lanAdrress/$ep', data: args);
  }

  /// delete with token
  tdel(String ep, dynamic args, {CancelToken cancelToken}) {
    assert(token != null);
    if (isCloud ?? true)
      return command('DELETE', ep, args, cancelToken: cancelToken);
    dio.options.headers['authorization'] = 'JWT $lanToken';
    return dio.delete('$lanAdrress/$ep',
        queryParameters: args, cancelToken: cancelToken);
  }

  /// request via cloud
  command(String verb, String ep, dynamic data, // qs, body or formdata
      {CancelToken cancelToken,
      Function onProgress}) {
    assert(token != null);
    assert(cookie != null);
    bool isFormData = data is FormData;
    bool isGet = verb == 'GET';
    dio.options.headers['authorization'] = token;
    dio.options.headers['cookie'] = cookie;

    final url = '$cloudAddress/station/$deviceSN/json';
    final url2 = '$cloudAddress/station/$deviceSN/pipe';

    // handle formdata
    if (isFormData) {
      final qs = {
        'verb': verb,
        'urlPath': '/$ep',
      };
      final qsData = Uri.encodeQueryComponent(jsonEncode(qs));
      final newUrl = '$url2?data=$qsData';
      return dio.post(newUrl,
          data: data, cancelToken: cancelToken, onSendProgress: onProgress);
    }

    // normal pipe-json
    return dio.post(url,
        data: {
          'verb': verb,
          'urlPath': '/$ep',
          'body': isGet ? null : data,
          'params': isGet ? data : null,
        },
        cancelToken: cancelToken,
        onSendProgress: onProgress);
  }

  ///  handle formdata
  writeDir(String ep, FormData formData,
      {CancelToken cancelToken, Function onProgress}) {
    return (isCloud ?? true)
        ? command('POST', ep, formData,
            cancelToken: cancelToken, onProgress: onProgress)
        : tpost(ep, formData, cancelToken: cancelToken, onProgress: onProgress);
  }

  Future<bool> isMobile() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile) {
      return true;
    } else if (connectivityResult == ConnectivityResult.wifi) {
      return false;
    }
    return false;
  }

  // monitor network change and refresh token
  monitorStart() {
    sub = Connectivity().onConnectivityChanged.listen((ConnectivityResult res) {
      print('Network Changed to $res');
      if (res == ConnectivityResult.wifi) {
        this.testLAN().catchError(print);
      } else if (res == ConnectivityResult.mobile) {
        this.isCloud = true;
      }
    });
  }

  monitorCancel() {
    try {
      sub?.cancel();
    } catch (e) {
      print('monitorCancel failed');
      print(e);
    }
  }

  Future<bool> testLAN() async {
    bool isLAN = false;
    try {
      final res = await dio
          .get('http://${this.lanIp}:3001/winasd/info')
          .timeout(Duration(seconds: 1));
      isLAN = res.data['device']['sn'] == this.deviceSN;
    } catch (error) {
      // print('testLAN error: $error');
      isLAN = false;
    }
    this.isCloud = !isLAN;
    // print('this.lanIp: $lanIp, isCloud: $isCloud');
    return isLAN;
  }

  Future req(String name, Map<String, dynamic> args) {
    Future r;
    interceptDio();
    switch (name) {
      case 'listNavDir':
        r = tget(
          'drives/${args['driveUUID']}/dirs/${args['dirUUID']}',
          {'metadata': 'true'},
        );
        break;

      // handle drives
      case 'drives':
        r = tget('drives', null);
        break;

      case 'drive':
        r = tget('drives/${args['uuid']}', null);
        break;

      case 'createDrive':
        r = tpost('drives', args);
        break;

      case 'updateDrive':
        r = tpatch('drives/${args['uuid']}', args['props']);
        break;

      case 'deleteDrive':
        r = tdel('drives/${args['uuid']}', null);
        break;

      case 'updateBackupAttr':
        r = writeDir(
          'drives/${args['driveUUID']}/dirs/${args['dirUUID']}/entries',
          FormData.fromMap({
            args['bname']: jsonEncode(args['props']),
          }),
        );
        break;

      case 'space':
        r = tget('boot/space', null);
        break;
      case 'stats':
        r = tget('fruitmix/stats', null);
        break;
      case 'dirStat':
        r = tget(
            'drives/${args['driveUUID']}/dirs/${args['dirUUID']}/stats', null);
        break;

      case 'mkdir':
        r = writeDir(
          'drives/${args['driveUUID']}/dirs/${args['dirUUID']}/entries',
          FormData.fromMap({
            args['dirname']: jsonEncode({'op': 'mkdir'}),
          }),
        );
        break;

      case 'randomSrc':
        r = tget('media/${args['hash']}', {'alt': 'random'});
        break;

      case 'rename':
        r = writeDir(
          'drives/${args['driveUUID']}/dirs/${args['dirUUID']}/entries',
          FormData.fromMap({
            '${args['oldName']}|${args['newName']}':
                jsonEncode({'op': 'rename'}),
          }),
        );
        break;

      case 'deleteDirOrFile':
        r = writeDir(
          'drives/${args['driveUUID']}/dirs/${args['dirUUID']}/entries',
          args['formdata'],
        );
        break;

      // xcopy
      case 'xcopy':
        r = tpost('tasks', args);
        break;

      case 'task':
        r = tget('tasks/${args['uuid']}', null);
        break;

      case 'tasks':
        r = tget('tasks', null);
        break;

      case 'delTask':
        r = tdel('tasks/${args['uuid']}', null);
        break;

      case 'search':
        r = tget('files', args);
        break;

      // bind device
      case 'winasInfo':
        r = isCloud
            ? command('GET', 'winasd/info', null)
            : dio.get('http://${this.lanIp}:3001/winasd/info');
        break;

      case 'reqLocalAuth':
        r = dio.patch('http://${this.lanIp}:3001/winasd/localAuth');
        break;

      case 'localAuth':
        r = dio.post('http://${this.lanIp}:3001/winasd/localAuth',
            data: {'color': args['color']});
        break;
    }
    return r;
  }

  void thumbTrigger(String hash, {int height = 200, int width = 200}) {
    final ep = 'media/$hash';
    final qs = {
      'alt': 'thumbnail',
      'autoOrient': 'true',
      'modifier': 'caret',
      'width': width,
      'height': height,
    };
    tget(ep, qs)
        .timeout(Duration(seconds: 2))
        .then((_) => {})
        .catchError((_) => {});
  }

  Future download(String ep, Map<String, dynamic> qs, String downloadPath,
      {Function onProgress, CancelToken cancelToken}) async {
    // download via cloud pipe
    if (isCloud ?? true) {
      final url = '$cloudAddress/station/$deviceSN/pipe';
      final qsData = {
        'data': jsonEncode({
          'verb': 'GET',
          'urlPath': '/$ep',
          'params': qs,
        })
      };
      dio.options.headers['authorization'] = token;
      dio.options.headers['cookie'] = cookie;
      await dio.download(
        url,
        downloadPath,
        queryParameters: qsData,
        cancelToken: cancelToken,
        onReceiveProgress: (a, b) =>
            onProgress != null ? onProgress(a, b) : null,
      );
    } else {
      // download via lan
      dio.options.headers['authorization'] = 'JWT $lanToken';
      await dio.download(
        '$lanAdrress/$ep',
        downloadPath,
        queryParameters: qs,
        cancelToken: cancelToken,
        onReceiveProgress: (a, b) =>
            onProgress != null ? onProgress(a, b) : null,
      );
    }
  }

  Future uploadAsync(Map<String, dynamic> args,
      {Function onProgress, CancelToken cancelToken}) async {
    final formdata = FormData()
      ..files.add(MapEntry(args['fileName'], args['file']));
    return writeDir(
        'drives/${args['driveUUID']}/dirs/${args['dirUUID']}/entries', formdata,
        cancelToken: cancelToken, onProgress: onProgress);
  }

  upload(Map<String, dynamic> args, callback,
      {Function onProgress, CancelToken cancelToken}) {
    uploadAsync(args, cancelToken: cancelToken, onProgress: onProgress)
        .then((value) => callback(null, value))
        .catchError((error) => callback(error, null));
  }

  updateToken(String newToken, String newCookie) {
    this.token = newToken;
    this.cookie = newCookie;
  }
}
