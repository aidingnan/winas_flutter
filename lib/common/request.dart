import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';

import './eventBus.dart';
import '../common/appConfig.dart';

class Request {
  bool isIOS = !Platform.isAndroid;

  String get cloudAddress => AppConfig.cloudAddress;

  String token;
  String refreshToken;
  String cookie;
  Dio dio = Dio();
  bool tokenExpired = false;

  Request({this.token, this.refreshToken});

  Request.fromMap(Map m) {
    this.token = m['token'];
    this.cookie = m['cookie'];
    this.refreshToken = m['refreshToken'];
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'token': token,
      'cookie': cookie,
      'refreshToken': refreshToken,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();

  // handle data.data response
  void interceptDio() {
    InterceptorsWrapper interceptorsWrapper = InterceptorsWrapper(
      onResponse: (Response response) {
        if (response.data == null) return null;
        var res = response.data['data'];
        // save cloud token not lanToken
        if (res is Map && res['token'] != null && res['id'] != null) {
          token = res['token'];
          refreshToken = res['refreshToken'];
          cookie = response.headers['set-cookie']?.first;
        }
        if (res != null) return res;
        return response.data;
      },
      onError: (DioError error) {
        if (error is DioError) {
          if (error?.response?.statusCode == 401) {
            // tokenExpired
            this.tokenExpired = true;
            eventBus.fire(TokenExpiredEvent('401 in could request'));
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

  aget(String ep, args) {
    dio.options.headers['cookie'] = cookie;
    return args == null
        ? dio.get('$cloudAddress/$ep')
        : dio.get('$cloudAddress/$ep', queryParameters: args);
  }

  apost(String ep, args) {
    dio.options.headers['cookie'] = cookie;
    return args == null
        ? dio.post('$cloudAddress/$ep')
        : dio.post('$cloudAddress/$ep', data: args);
  }

  apatch(String ep, args) {
    dio.options.headers['cookie'] = cookie;
    return args == null
        ? dio.patch('$cloudAddress/$ep')
        : dio.patch('$cloudAddress/$ep', data: args);
  }

  /// get with token
  tget(String ep, args) {
    assert(token != null);
    dio.options.headers['Authorization'] = token;
    dio.options.headers['cookie'] = cookie;
    return dio.get('$cloudAddress/$ep', queryParameters: args);
  }

  /// post with token
  tpost(String ep, args) {
    assert(token != null);
    dio.options.headers['Authorization'] = token;
    dio.options.headers['Content-Type'] = 'application/json';
    dio.options.headers['cookie'] = cookie;
    return dio.post('$cloudAddress/$ep', data: args);
  }

  /// patch with token
  tpatch(String ep, args) {
    assert(token != null);
    dio.options.headers['Authorization'] = token;
    dio.options.headers['cookie'] = cookie;
    return dio.patch('$cloudAddress/$ep', data: args);
  }

  /// patch with token
  tdel(String ep, args) {
    assert(token != null);
    dio.options.headers['Authorization'] = token;
    dio.options.headers['cookie'] = cookie;
    return dio.delete('$cloudAddress/$ep', queryParameters: args);
  }

  /// command via pipe
  command(deviceSN, data, [Options options]) {
    assert(token != null);
    assert(cookie != null);
    dio.options.headers['Authorization'] = token;
    dio.options.headers['Content-Type'] = 'application/json';
    dio.options.headers['cookie'] = cookie;
    return dio.post(
      '$cloudAddress/station/$deviceSN/json',
      data: data,
      options: options,
    );
  }

  /// test lanIp
  Future<bool> testLAN(String ip, String deviceSN) async {
    bool isLAN = false;
    try {
      final res = await dio.get(
        'http://$ip:3001/winasd/info',
        options: Options(connectTimeout: 1000),
      );
      isLAN = res.data['device']['sn'] == deviceSN;
    } catch (error) {
      print('testLAN error');
      print(error);
      isLAN = false;
    }
    return isLAN;
  }

  /// get winasd/info
  Future winasdInfo(String ip) async {
    final res = await dio.get(
      'http://$ip:3001/winasd/info',
      options: Options(connectTimeout: 10000),
    );
    return res.data;
  }

  /// get winasd/time
  Future<bool> timeDate(String ip) async {
    final res = await dio.get(
      'http://$ip:3001/winasd/timedate',
      options: Options(connectTimeout: 10000),
    );
    // print('timeDate res $res');
    return res.data['System clock synchronized'] == 'yes';
  }

  /// device Bind
  Future deviceBind(String ip, String encrypted) async {
    final res = await dio.post(
      'http://$ip:3001/winasd/bind',
      data: {'encrypted': encrypted},
      options: Options(connectTimeout: 10000),
    );
    print('deviceBind res $res');
    return res.data;
  }

  /// unbind device
  Future unbindDevice(
      String ip, String encrypted, String authToken, bool cleanVolume) async {
    // return Future.value('fake success');
    final res = await dio.post(
      'http://$ip:3001/winasd/unbind',
      data: {
        'encrypted': encrypted,
        'authToken': authToken,
        'clean': cleanVolume,
      },
      options: Options(connectTimeout: 10000),
    );
    print('unbindDevice res $res');
    return res.data;
  }

  Future req(String name, Map<String, dynamic> args, [Options options]) {
    Future r;
    interceptDio();
    switch (name) {
      case 'registry':
        r = apost('user', {
          'type': isIOS ? 'iOS' : 'Android',
          'phone': args['phone'],
          "ticket": args['ticket'],
          'clientId': args['clientId'],
          "password": args['password'],
        });
        break;

      case 'smsTicket':
        r = apost('user/smsCode/ticket', {
          'type': args['type'],
          'code': args['code'],
          'phone': args['phone'],
        });
        break;

      case 'checkUser':
        r = aget('user/phone/check', {"phone": args['phone']});
        break;

      case 'setLastSN':
        r = tpost('user/deviceInfo', {'sn': args['sn']});
        break;

      case 'token':
        r = aget('user/password/token', {
          'clientId': args['clientId'],
          'type': isIOS ? 'iOS' : 'Android',
          'username': args['username'],
          'password': args['password']
        });
        break;

      case 'refreshToken':
        r = apost('user/refreshToken', {
          'clientId': args['clientId'],
          'type': isIOS ? 'iOS' : 'Android',
          'refreshToken': refreshToken,
        });
        break;

      // get user encrypted info, used in bind or unbind device
      case 'encrypted':
        r = tpost('user/encrypted', null);
        break;

      case 'wechat':
        r = tget('wechat', null);
        break;

      case 'unbindWechat':
        r = tdel('user/wechat', {
          'unionid': args['unionid'],
        });
        break;

      case 'wechatLogin':
        r = aget('wechat/token', {
          'loginType': 'mobile',
          'code': args['code'],
          'type': isIOS ? 'iOS' : 'Android',
          'clientId': args['clientId'],
        });
        break;

      case 'bindWechat':
        r = tpatch('wechat/user', {
          'wechat': args['wechatToken'],
        });
        break;

      case 'smsCode':
        r = apost('user/smsCode', {
          'type': args['type'], // register, password, login, replace
          'phone': args['phone'],
        });
        break;

      case 'smsToken':
        r = aget('user/smsCode/token', {
          'type': isIOS ? 'iOS' : 'Android',
          'phone': args['phone'],
          'code': args['code'],
          'clientId': args['clientId'],
        });
        break;

      case 'resetPwd':
        r = apatch('user/password', {
          'password': args['password'],
          'phoneTicket': args['phoneTicket'],
        });
        break;

      case 'replacePhone':
        r = tpatch('user/phone', {
          'oldTicket': args['oldTicket'],
          'newTicket': args['newTicket'],
        });
        break;

      case 'newNickName':
        r = tpatch('user/nickname', {
          'nickName': args['nickName'],
        });
        break;

      case 'stations':
        r = tget('station', null);
        break;

      // upgrade
      case 'upgradeList':
        r = aget('station/upgrade', null);
        break;

      case 'upgradeDownload':
        r = tpost(
          'station/${args['deviceSN']}/publish',
          {
            'message': 'download',
            'content': {},
            'tag': args['tag'],
          },
        );
        break;

      case 'upgradeCheckout':
        r = tpost(
          'station/${args['deviceSN']}/publish',
          {
            'message': 'checkout',
            'content': {
              'uuid': args['uuid'],
            },
            'tag': args['tag'],
          },
        );
        break;

      case 'upgradeInfo':
        r = command(
            args['deviceSN'], {'verb': 'GET', 'urlPath': '/winasd/upgrade'});
        break;

      case 'upgrade':
        r = command(args['deviceSN'], {
          'verb': 'POST',
          'urlPath': '/winasd/upgrade',
          'body': {
            'version': args['version'],
          },
        });
        break;

      case 'info':
        r = command(
          args['deviceSN'],
          {'verb': 'GET', 'urlPath': '/winasd/info'},
          options,
        );
        break;

      case 'reboot':
        r = command(
          args['deviceSN'],
          {
            'verb': 'PATCH',
            'urlPath': '/winasd',
            'body': {
              'op': 'reboot',
            },
          },
        );
        break;

      case 'root':
        r = command(
          args['deviceSN'],
          {
            'verb': 'PATCH',
            'urlPath': '/winasd',
            'body': {
              'op': 'root',
            },
          },
        );
        break;

      case 'unroot':
        r = command(
          args['deviceSN'],
          {
            'verb': 'PATCH',
            'urlPath': '/winasd',
            'body': {
              'op': 'unroot',
            },
          },
        );
        break;

      // login
      case 'localBoot':
        r = command(
            args['deviceSN'], {'verb': 'GET', 'urlPath': '/boot'}, options);
        break;
      case 'localDrives':
        r = command(args['deviceSN'], {'verb': 'GET', 'urlPath': '/drives'});
        break;
      case 'localToken':
        r = command(args['deviceSN'], {'verb': 'GET', 'urlPath': '/token'});
        break;
      case 'localUsers':
        r = command(
            args['deviceSN'], {'verb': 'GET', 'urlPath': '/users'}, options);
        break;
      case 'renameStation':
        r = command(args['deviceSN'], {
          'verb': 'POST',
          'urlPath': '/winasd/device',
          'body': {
            'name': args['name'],
          },
        });
        break;
      case 'formatDisk':
        r = command(args['deviceSN'], {
          'verb': 'POST',
          'urlPath': '/boot',
          'body': {
            'target': args['target'],
          },
        });
        break;
    }
    return r;
  }

  Future setAvatar(List<int> imageData, {CancelToken cancelToken}) async {
    assert(token != null);
    interceptDio();
    return dio.put(
      '$cloudAddress/user/avatar',
      data: Stream.fromIterable(imageData.map((e) => [e])),
      options: Options(
        headers: {
          HttpHeaders.contentTypeHeader: 'application/octet-stream',
          HttpHeaders.authorizationHeader: token,
          HttpHeaders.contentLengthHeader: imageData.length,
        },
      ),
      cancelToken: cancelToken,
    );
  }
}
