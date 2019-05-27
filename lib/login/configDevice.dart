import 'dart:async';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './ble.dart';
import './stationLogin.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/request.dart';

enum Status {
  auth,
  wifi,
  authFailed,
  authTimeout,
  connecting,
  connectFailed,
  binding,
  bindFailed,
  logging,
  loginFailed
}

class ConfigDevice extends StatefulWidget {
  ConfigDevice({Key key, this.device, this.request, this.action, this.onClose})
      : super(key: key);
  final Action action;
  final Request request;
  final BluetoothDevice device;
  final Function onClose;

  @override
  _ConfigDeviceState createState() => _ConfigDeviceState();
}

class _ConfigDeviceState extends State<ConfigDevice> {
  List<String> selected;
  String token;

  /// sn of current device
  String deviceSN;

  /// The wifi ssid which current phone connected.
  String ssid;

  /// password for Wi-Fi
  String pwd = 'wisnuc123456';

  /// Error for set wifi Error;
  String errorText;

  Status status = Status.auth;

  // 60 seconds to timeout
  bool timeoutCheck = true;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 60), () {
      if (mounted && status == Status.auth && timeoutCheck) {
        setState(() {
          status = Status.authFailed;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.onClose();
    super.dispose();
  }

  /// check color code
  Future<String> checkCode(BluetoothDevice device, List<String> code) async {
    final authCommand =
        '{"action":"auth","seq":2,"body":{"color":["${code[2]}","${code[3]}"]}}';
    print(authCommand);
    final res = await getLocalAuth(device, authCommand);
    print('checkCode res: $res');
    String token = res['data']['token'];
    print(token);
    return token;
  }

  /// store current device's ip
  String currentIP;

  /// check color code
  Future<String> setWifi(String wifiPwd) async {
    assert(token != null);
    assert(ssid != null);
    final device = widget.device;
    final wifiCommand =
        '{"action":"addAndActive", "seq": 123, "token": "$token", "body":{"ssid":"$ssid", "pwd":"$wifiPwd"}}';
    final wifiRes = await withTimeout(connectWifi(device, wifiCommand), 20);
    print('wifiRes: $wifiRes');
    final ip = wifiRes['data']['address'];
    currentIP = ip;
    return ip;
  }

  /// try connect to device via ip
  Future<void> connectDevice(
      String ip, String token, Store<AppState> store) async {
    final request = widget.request;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      bool started = false;
      var infoRes;
      // polling for winas Started, channel Connected
      while (started != true) {
        final current = DateTime.now().millisecondsSinceEpoch;
        if (current - now > 30000)
          throw 'Timeout of 30 seconds for channel connected';
        await Future.delayed(Duration(seconds: 2));
        var res;
        try {
          res = await request.winasdInfo(ip);
        } catch (e) {
          print(e);
          continue;
        }

        final channel = res['channel'];
        if (channel != null && channel['state'] == 'Connected') {
          started = true;
          infoRes = res;
        }
      }

      deviceSN = infoRes['device']['sn'] as String;
      if (deviceSN == null) throw 'Failed to get deviceSN from winasd';
    } catch (e) {
      print(e);
      setState(() {
        status = Status.connectFailed;
      });
      return;
    }

    print('connect');
    print(widget.action);
    // switch by Action, bind device or login device directly
    if (widget.action == Action.bind) {
      bindDevice(ip, token, store).catchError(print);
    } else if (widget.action == Action.wifi) {
      loginDevice(ip, token, store).catchError(print);
    }
  }

  /// start to bind device
  Future<void> bindDevice(String ip, String token, store) async {
    print('bindDevice start');
    final request = widget.request;

    setState(() {
      status = Status.binding;
    });

    try {
      final res = await request.req('encrypted', null);
      final encrypted = res.data['encrypted'] as String;
      final bindRes = await request.deviceBind(ip, encrypted);
      print('bindRes $bindRes');
    } catch (e) {
      setState(() {
        status = Status.bindFailed;
      });
      return;
    }
    loginDevice(ip, token, store).catchError(print);
  }

  /// try login to device
  ///  http://ip:3001/winasd/info
  ///  ```json
  ///  {
  ///     "winas": {
  ///       "state": "Started",
  ///       "isBeta": true,
  ///       "users": [
  ///        {
  ///         "uuid": "8d23bb8a-d6fa-4abe-831e-6eb25ce5ff19",
  ///         "winasUserId": "6947667a-f8ff-498c-b0cb-ebc4d97715d7"
  ///         }
  ///      ]
  ///     },
  ///     "channel": {
  ///       "state": "Connected"
  ///     },
  ///     ...
  ///  }
  ///  ```
  Future<void> loginDevice(String ip, String token, store) async {
    final request = widget.request;
    setState(() {
      status = Status.logging;
    });

    try {
      bool started = false;
      final now = DateTime.now().millisecondsSinceEpoch;
      while (started != true) {
        final current = DateTime.now().millisecondsSinceEpoch;
        if (current - now > 30000)
          throw 'Timeout of 30 seconds for winas starting';
        await Future.delayed(Duration(seconds: 1));
        final res = await request.winasdInfo(ip);
        print(res);
        final winas = res['winas'];
        final channel = res['channel'];

        if (winas != null && channel != null) {
          if (winas['state'] == "Started" &&
              channel['state'] == 'Connected' &&
              winas['users'] is List) {
            started = true;
          } else if (winas['state'] == "Failed") {
            throw 'Winas Failed';
          }
        }
      }
      final result = await reqStationList(request);
      final stationList = result['stationList'] as List;
      final currentDevice = stationList.firstWhere(
          (s) => s.sn == deviceSN && s.sn != null,
          orElse: () => null) as Station;
      final account = store.state.account as Account;
      await stationLogin(context, request, currentDevice, account, store);
    } catch (e) {
      print('loginFailed');
      print(e);
      setState(() {
        status = Status.loginFailed;
      });
      return;
    }

    // pop all page
    Navigator.pushNamedAndRemoveUntil(
        context, '/station', (Route<dynamic> route) => false);
  }

  void nextStep(BuildContext ctx, Store<AppState> store) async {
    if (status == Status.auth) {
      print('code is $selected');
      // reset token

      showLoading(ctx);

      // fired, not time out
      timeoutCheck = false;
      try {
        // request token
        token = await checkCode(widget.device, selected);
        if (token == null) throw 'no token';

        // request current wifi ssid
        try {
          ssid = await getWifiSSID();
        } catch (e) {
          print(e);
          ssid = null;
        }

        Navigator.pop(ctx);
        setState(() {
          status = Status.wifi;
        });
      } catch (e) {
        print(e);
        Navigator.pop(ctx);
        setState(() {
          status = Status.authFailed;
        });
      }
    } else if (status == Status.wifi) {
      if (pwd is String && pwd.length > 0) {
        showLoading(ctx);
        try {
          print('pwd: $pwd');
          final ip = await setWifi(pwd);

          // check ip
          if (ip is! String) {
            throw 'set wifi Failed';
          }

          // connect to device via ip
          setState(() {
            status = Status.connecting;
          });
          connectDevice(ip, token, store).catchError(print);
          Navigator.pop(ctx);
        } catch (e) {
          print(e);
          Navigator.pop(ctx);
          setState(() {
            errorText = '设备连接网络失败，请确认密码是否正确';
          });
          // showSnackBar(ctx, '设备连接网络失败，请确认密码是否正确');
        }
      }
    }
  }

  /// color codes
  static const List<List<String>> colorCodes = [
    ['红色灯', '常亮', '#ff0000', 'alwaysOn'],
    ['红色灯', '闪烁', '#ff0000', 'breath'],
    ['绿色灯', '常亮', '#00ff00', 'alwaysOn'],
    ['绿色灯', '闪烁', '#00ff00', 'breath'],
    ['蓝色灯', '常亮', '#0000ff', 'alwaysOn'],
    ['蓝色灯', '闪烁', '#0000ff', 'breath'],
  ];

  /// '#ff0000' => Color(0xFF0000)
  Color _getColor(String color) {
    final value = int.parse('FF${color.substring(1)}', radix: 16);
    return Color(value);
  }

  Widget renderAuth() {
    List<Widget> widgets = [
      Container(
        padding: EdgeInsets.all(16),
        child: Text(
          '身份确认',
          style: TextStyle(color: Colors.black87, fontSize: 28),
        ),
      ),
      Container(
        padding: EdgeInsets.all(16),
        child: Text(
          '请您观察设备指示灯，并选择它的状态：',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    ];
    print('selected: $selected');
    List<Widget> options = List.from(
      colorCodes.map(
        (code) => Material(
              child: InkWell(
                child: Container(
                  height: 56,
                  width: double.infinity,
                  child: RadioListTile(
                    activeColor: Colors.teal,
                    groupValue: selected,
                    onChanged: (value) {
                      print('on tap $code');
                      setState(() {
                        selected = value;
                      });
                    },
                    value: code,
                    title: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: code[0],
                          style: TextStyle(color: _getColor(code[2])),
                        ),
                        TextSpan(text: ' '),
                        TextSpan(text: code[1]),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
    widgets.addAll(options);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget renderWifi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(16),
          child: Text(
            '配置Wi-Fi',
            style: TextStyle(color: Colors.black87, fontSize: 28),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            '配置设备的Wi-Fi，使手机与设备连至同一网络',
            style: TextStyle(color: Colors.black54),
          ),
        ),
        ssid == null
            ? Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  '当前手机未连接至Wi-Fi网络',
                  style: TextStyle(color: Colors.black87, fontSize: 21),
                ),
              )
            : Container(
                padding: EdgeInsets.all(16),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '设备将连接至 ',
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextSpan(
                      text: ssid,
                      style: TextStyle(fontSize: 18),
                    ),
                    TextSpan(
                      text: ' , 请输入该Wi-Fi的密码: ',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ]),
                ),
              ),
        ssid == null
            ? Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  '请连接后刷新重试',
                  style: TextStyle(color: Colors.black87, fontSize: 21),
                ),
              )
            : Container(
                padding: EdgeInsets.all(16),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock, color: Colors.teal),
                    errorText: errorText,
                  ),
                  onChanged: (text) {
                    setState(() {
                      pwd = text;
                      errorText = null;
                    });
                  },
                  style: TextStyle(fontSize: 24, color: Colors.black87),
                ),
              ),
      ],
    );
  }

  Widget renderFailed(BuildContext ctx) {
    return Column(
      children: <Widget>[
        Container(height: 64),
        Icon(Icons.error_outline, color: Colors.redAccent, size: 96),
        Container(
          padding: EdgeInsets.all(64),
          child: Center(
            child: Text('验证失败，请重启设备后再重试'),
          ),
        ),
        Container(
          height: 88,
          padding: EdgeInsets.all(16),
          width: double.infinity,
          child: RaisedButton(
            color: Colors.teal,
            elevation: 1.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(48),
            ),
            onPressed: () {
              // return to deviceList
              Navigator.pushNamedAndRemoveUntil(
                  context, '/deviceList', (Route<dynamic> route) => false);
            },
            child: Row(
              children: <Widget>[
                Expanded(child: Container()),
                Text(
                  '返回',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Expanded(child: Container()),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget renderTimeout(BuildContext ctx) {
    return Column(
      children: <Widget>[
        Container(height: 64),
        Icon(Icons.error_outline, color: Colors.redAccent, size: 96),
        Container(
          padding: EdgeInsets.all(64),
          child: Center(
            child: Text('验证超时，请返回后重新连接'),
          ),
        ),
        Container(
          height: 88,
          padding: EdgeInsets.all(16),
          width: double.infinity,
          child: RaisedButton(
            color: Colors.teal,
            elevation: 1.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(48),
            ),
            onPressed: () {
              // return to ble list
              Navigator.pop(ctx);
            },
            child: Row(
              children: <Widget>[
                Expanded(child: Container()),
                Text(
                  '返回',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Expanded(child: Container()),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget renderBind(BuildContext ctx) {
    String text = '';
    String buttonLabel;
    Widget icon = CircularProgressIndicator();
    switch (status) {
      case Status.connecting:
        text = '连接设备中...';
        break;

      case Status.connectFailed:
        text = '无法连接到您的口袋网盘设备，请确认设备与你的手机连接同一路由器或在同一内网网段中。\n当前设备IP： $currentIP';
        buttonLabel = '返回';
        icon = Icon(Icons.error_outline, color: Colors.redAccent, size: 96);
        break;

      case Status.binding:
        text = '绑定设备中...';
        break;

      case Status.bindFailed:
        text = '绑定失败';
        buttonLabel = '返回';
        icon = Icon(Icons.error_outline, color: Colors.redAccent, size: 96);
        break;

      case Status.logging:
        text = '登录设备中...';
        break;

      case Status.loginFailed:
        text = '登录失败';
        buttonLabel = '返回';
        icon = Icon(Icons.error_outline, color: Colors.redAccent, size: 96);
        break;

      default:
        text = '';
        buttonLabel = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(16),
          child: Text(
            widget.action == Action.bind ? '绑定设备' : '设置Wi-Fi',
            style: TextStyle(color: Colors.black87, fontSize: 28),
          ),
        ),
        Container(
          height: 108,
          child: Center(child: icon),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Center(
              child: Text(
            text,
            style: TextStyle(fontSize: 18),
          )),
        ),
        buttonLabel != null
            ? Container(
                height: 88,
                padding: EdgeInsets.all(16),
                width: double.infinity,
                child: RaisedButton(
                  color: Colors.teal,
                  elevation: 1.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(48),
                  ),
                  onPressed: () {
                    // pop all page
                    Navigator.pushNamedAndRemoveUntil(context, '/deviceList',
                        (Route<dynamic> route) => false);
                  },
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Container()),
                      Text(
                        buttonLabel,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Expanded(child: Container()),
                    ],
                  ),
                ),
              )
            : Container(),
      ],
    );
  }

  Widget renderBody(BuildContext ctx) {
    switch (status) {
      case Status.auth:
        return renderAuth();

      case Status.wifi:
        return renderWifi();

      case Status.authFailed:
        return renderFailed(ctx);

      case Status.authTimeout:
        return renderTimeout(ctx);

      default:
        return renderBind(ctx);
    }
  }

  @override
  Widget build(BuildContext context) {
    // whether has fab button or not
    bool hasFab = status == Status.auth || status == Status.wifi;
    // whether has back button or not
    bool hasBack = status == Status.auth || status == Status.wifi;
    // whether fab enable or not
    bool enabled = (status == Status.auth && selected != null) ||
        (status == Status.wifi && pwd is String && pwd.length > 0);
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        backgroundColor: Colors.grey[50],
        automaticallyImplyLeading: hasBack,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.black38),
        actions: status == Status.wifi
            ? <Widget>[
                Builder(
                  builder: (ctx) {
                    return IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: () async {
                        try {
                          ssid = await getWifiSSID();
                        } catch (e) {
                          ssid = null;
                          print(e);
                        } finally {
                          setState(() {});
                        }
                      },
                    );
                  },
                )
              ]
            : <Widget>[],
      ),
      body: Builder(builder: (ctx) => renderBody(ctx)),
      floatingActionButton: !hasFab
          ? null
          : Builder(
              builder: (ctx) {
                return StoreConnector<AppState, Store<AppState>>(
                    onInit: (store) => {},
                    onDispose: (store) => {},
                    converter: (store) => store,
                    builder: (context, store) {
                      return FloatingActionButton(
                        onPressed: !enabled ? null : () => nextStep(ctx, store),
                        tooltip: '下一步',
                        backgroundColor:
                            !enabled ? Colors.grey[200] : Colors.teal,
                        elevation: 0.0,
                        child: Icon(
                          Icons.chevron_right,
                          color: !enabled ? Colors.black26 : Colors.white,
                          size: 48,
                        ),
                      );
                    });
              },
            ),
    );
  }
}
