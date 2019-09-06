import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart' hide Action;
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
  formatError,
  connecting,
  connectFailed,
  binding,
  bindFailed,
  logging,
  loginFailed,
  bleFailed,
  bindTimeout,
}

class ConfigDevice extends StatefulWidget {
  ConfigDevice(
      {Key key,
      this.device,
      this.request,
      this.action,
      this.needFormat,
      this.onClose})
      : super(key: key);
  final Action action;
  final Request request;
  final BluetoothDevice device;
  final bool needFormat;
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

  /// loadingInstance for connect wifi
  LoadingInstance loadingInstance;

  Status status = Status.auth;
  List<List<String>> colorCodes;
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
    colorCodes = getColorCodes();
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
    debug(authCommand);
    final res = await getLocalAuth(device, authCommand);
    debug('checkCode res: $res');
    String token = res['data']['token'];
    debug(token);
    return token;
  }

  /// store current device's ip
  String currentIP;

  BleRes bleRes;

  bool wifiError = false;
  Timer wifiTimer;

  /// onData res {seq: 123, success: WIFI, data: {address: 10.10.9.201, prefix: 24}}
  ///
  /// onData res {seq: 123, success: CHANNEL}
  ///
  /// onData res {seq: 123, success: NTP}
  ///
  /// onData res {seq: 123, success: BOUND, data: {sn: test_0123068cc0e5a15fee, addr: 10.10.9.201}}
  void onData(value, Store<AppState> store) {
    if (!this.mounted || wifiError) return;
    // clear timeout of connectWifi
    wifiTimer?.cancel();
    var res;
    var error;
    String success;
    String code;
    try {
      res = jsonDecode(String.fromCharCodes(value));
      debug('onData res $res');
      success = res['success'];
      error = res['error'];
      if (error != null) {
        code = error['code'];
      }
      if (code == null && success == null) {
        throw 'Neither success or error with code';
      }
    } catch (e) {
      this.loadingInstance.close();
      setState(() {
        status = Status.bleFailed;
      });
      return;
    }
    if (code != null) {
      bleRes?.cancel();
      switch (code) {
        case 'EWIFI':
          this.loadingInstance.close();
          setState(() {
            errorText = i18n('Set WiFi Error');
          });
          break;
        case 'ECHANNEL':
          setState(() {
            status = Status.connectFailed;
          });
          break;
        case 'ENTP':
          setState(() {
            status = Status.connectFailed;
          });
          break;
        case 'EBOUND':
          setState(() {
            status = Status.bindFailed;
          });
          break;
        default:
          // Other Unknown Error
          this.onError('Other Unknown Error Code in setting wifi');
          break;
      }
    } else if (success != null) {
      switch (success) {
        case 'WIFI':
          this.loadingInstance.close();
          setState(() {
            status = Status.connecting;
          });
          setTimeout();
          break;
        case 'CHANNEL':
          setState(() {
            status = Status.connecting;
          });
          setTimeout();
          break;
        case 'NTP':
          setState(() {
            status = Status.binding;
          });
          setTimeout();
          break;
        case 'BOUND':
          String sn = res['data']['sn'];
          setState(() {
            status = Status.logging;
          });
          loginViaCloud(store, sn).catchError(debug);
          break;
        default:
          break;
      }
    }
  }

  void onError(error) {
    debug(error);
    wifiError = true;
    wifiTimer?.cancel();
    bleRes?.cancel();
    this.loadingInstance.close();
    if (status == Status.wifi) {
      setState(() {
        errorText = i18n('Set WiFi Error');
      });
    } else if (error == 'Connect Timeout') {
      setState(() {
        status = Status.bindTimeout;
      });
    } else {
      setState(() {
        status = Status.bleFailed;
      });
    }
  }

  void setTimeout() {
    wifiTimer = Timer(
      Duration(seconds: 60),
      () {
        this.onError('Connect Timeout');
      },
    );
  }

  /// login Via Cloud, without lcoal ip
  Future loginViaCloud(Store<AppState> store, String sn) async {
    try {
      debug('loginViaCloud start');
      final request = widget.request;

      bool started = false;
      final now = DateTime.now().millisecondsSinceEpoch;

      while (started != true) {
        final current = DateTime.now().millisecondsSinceEpoch;
        if (current - now > 30000)
          throw 'Timeout of 30 seconds for winas starting';
        await Future.delayed(Duration(seconds: 2));

        // request info via cloud
        try {
          final res = await request.req(
            'info',
            {'deviceSN': sn},
            Options(connectTimeout: 5000),
          );
          debug('get info in loginViaCloud...');

          final winas = res.data['winas'];
          final channel = res.data['channel'];

          if (winas != null && channel != null) {
            if (winas['state'] == "Started" &&
                channel['state'] == 'Connected' &&
                winas['users'] is List) {
              started = true;
            } else if (winas['state'] == "Failed") {
              throw 'Winas Failed';
            }
          }
        } catch (e) {
          debug(e);
          continue;
        }
      }
      debug('winas started');
      final result = await reqStationList(request);
      final stationList = result['stationList'] as List;
      final currentDevice = stationList.firstWhere(
          (s) => s.sn == sn && s.sn != null,
          orElse: () => null) as Station;
      final account = store.state.account;
      debug('stationLogin ....');
      await stationLogin(context, request, currentDevice, account, store);
    } catch (e) {
      debug(e);
      setState(() {
        status = Status.loginFailed;
      });
      return;
    }

    // pop all page and nav to station page
    Navigator.pushNamedAndRemoveUntil(
        context, '/station', (Route<dynamic> route) => false);
  }

  /// set Wifi And Bind
  Future<void> setWifiAndBind(String wifiPwd, Store<AppState> store) async {
    assert(token != null);
    assert(ssid != null);
    wifiError = false;
    final res = await widget.request.req('encrypted', null);
    final encrypted = res.data['encrypted'] as String;
    final device = widget.device;
    final wifiCommand =
        '{"action":"addAndActiveAndBound", "seq":123, "token":"$token", "body":{"ssid":"$ssid", "pwd":"$wifiPwd", "encrypted":"$encrypted"}}';
    bleRes = BleRes(
      (data) {
        this.onData(data, store);
      },
      this.onError,
    );
    setTimeout();
    await connectWifiAndBind(device, wifiCommand, bleRes)
        .timeout(Duration(seconds: 20));
    debug('setWifiAndBind fired');
  }

  /// only set Wifi
  Future<String> setWifi(String wifiPwd) async {
    assert(token != null);
    assert(ssid != null);
    final device = widget.device;
    final wifiCommand =
        '{"action":"addAndActive", "seq": 123, "token": "$token", "body":{"ssid":"$ssid", "pwd":"$wifiPwd"}}';
    final wifiRes =
        await connectWifi(device, wifiCommand).timeout(Duration(seconds: 20));
    debug('wifiRes: $wifiRes');
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
        bool timeIsOK;
        try {
          res = await request.winasdInfo(ip);
          timeIsOK = await request.timeDate(ip);
        } catch (e) {
          debug(e);
          continue;
        }

        final channel = res['channel'];
        if (channel != null && channel['state'] == 'Connected' && timeIsOK) {
          started = true;
          infoRes = res;
        }
      }

      deviceSN = infoRes['device']['sn'] as String;
      if (deviceSN == null) throw 'Failed to get deviceSN from winasd';
    } catch (e) {
      debug(e);
      setState(() {
        status = Status.connectFailed;
      });
      return;
    }

    debug('connect');
    debug(widget.action);
    // switch by Action, bind device or login device directly
    if (widget.action == Action.bind) {
      bindDevice(ip, token, store).catchError(debug);
    } else if (widget.action == Action.wifi) {
      loginDevice(ip, token, store).catchError(debug);
    }
  }

  /// start to bind device
  Future<void> bindDevice(String ip, String token, store) async {
    debug('bindDevice start');
    final request = widget.request;

    setState(() {
      status = Status.binding;
    });

    try {
      final res = await request.req('encrypted', null);
      final encrypted = res.data['encrypted'] as String;
      final bindRes = await request.deviceBind(ip, encrypted);
      debug('bindRes $bindRes');
    } catch (e) {
      debug('bind device error $e');
      setState(() {
        status = Status.bindFailed;
      });
      return;
    }
    loginDevice(ip, token, store).catchError(debug);
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
      debug('loginFailed');
      debug(e);
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
      debug('code is $selected');
      // reset token

      final loading = showLoading(ctx);
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
          debug(e);
          ssid = null;
        }

        loading.close();
        if (widget.action == Action.bind && widget.needFormat) {
          LoadingInstance newLoading;
          try {
            newLoading = showLoading(
              ctx,
              fakeProgress: 10.0,
              text: i18n('Formating Disk Text'),
            );
            await Future.delayed(Duration(seconds: 2));
            newLoading.close();
          } catch (e) {
            debug('Formating Disk failed');
            debug(e);
            newLoading.close();
            setState(() {
              status = Status.formatError;
            });
            return;
          }
        }

        setState(() {
          status = Status.wifi;
        });
      } catch (e) {
        debug(e);

        loading.close();
        setState(() {
          status = Status.authFailed;
        });
      }
    } else if (status == Status.wifi) {
      if (widget.action == Action.bind) {
        // set Wi-Fi and bind Device in one step
        this.loadingInstance = showLoading(
          ctx,
          fakeProgress: 10.0,
          text: i18n('Connecting To WiFi'),
        );
        try {
          await setWifiAndBind(pwd, store);
        } catch (e) {
          debug(e);
          this.loadingInstance.close();
          setState(() {
            errorText = i18n('Set WiFi Error');
          });
        }
      } else if (pwd is String && pwd.length > 0) {
        // previous progress: set Wi-Fi and connectDevice and login device
        final loading = showLoading(
          ctx,
          fakeProgress: 10.0,
          text: i18n('Connecting To WiFi'),
        );
        try {
          debug('pwd: $pwd');
          final ip = await setWifi(pwd);

          // check ip
          if (ip is! String) {
            throw 'set wifi Failed';
          }

          // connect to device via ip
          setState(() {
            status = Status.connecting;
          });
          connectDevice(ip, token, store).catchError(debug);
          loading.close();
        } catch (e) {
          debug(e);
          loading.close();
          setState(() {
            errorText = i18n('Set WiFi Error');
          });
        }
      }
    }
  }

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
          i18n('Color Code Auth Title'),
          style: TextStyle(color: Colors.black87, fontSize: 28),
        ),
      ),
      Container(
        padding: EdgeInsets.all(16),
        child: Text(
          i18n('Color Code Auth Text'),
          style: TextStyle(color: Colors.black54),
        ),
      ),
    ];
    debug('selected: $selected');
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
                  debug('on tap $code');
                  setState(() {
                    selected = value;
                  });
                },
                value: code,
                title: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: code[0],
                      style: TextStyle(color: _getColor(code[4])),
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
            i18n('Configure WiFi Title'),
            style: TextStyle(color: Colors.black87, fontSize: 28),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            i18n('Configure WiFi Text'),
            style: TextStyle(color: Colors.black54),
          ),
        ),
        ssid == null
            ? Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  i18n('Phone Not Connect to WiFi Text 1'),
                  style: TextStyle(color: Colors.black87, fontSize: 21),
                ),
              )
            : Container(
                padding: EdgeInsets.all(16),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: i18n('WiFi Password Input Text Part 1'),
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextSpan(
                      text: ssid,
                      style: TextStyle(fontSize: 18),
                    ),
                    TextSpan(
                      text: i18n('WiFi Password Input Text Part 2'),
                      style: TextStyle(color: Colors.black54),
                    ),
                  ]),
                ),
              ),
        ssid == null
            ? Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  i18n('Phone Not Connect to WiFi Text 2'),
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

  Widget renderFailed(BuildContext ctx, String text) {
    return Column(
      children: <Widget>[
        Container(height: 64),
        Icon(Icons.error_outline, color: Colors.redAccent, size: 96),
        Container(
          padding: EdgeInsets.all(64),
          child: Center(
            child: Text(text),
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
                  i18n('Back'),
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

  Widget successLine(String text) {
    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 32),
      child: Row(
        children: <Widget>[
          Expanded(flex: 2, child: Container()),
          Expanded(
            flex: 4,
            child: Center(
              child: Text(text, style: TextStyle(fontSize: 18)),
            ),
          ),
          Expanded(
            flex: 1,
            child: Icon(Icons.check, color: Colors.teal),
          ),
          Expanded(flex: 1, child: Container()),
        ],
      ),
    );
  }

  Widget iconLine(Widget icon) {
    return Container(
      height: 108,
      child: Center(child: icon),
    );
  }

  Widget renderBind(BuildContext ctx) {
    String text = '';
    String buttonLabel;
    Widget icon = CircularProgressIndicator();
    List<Widget> list = [
      Container(
        padding: EdgeInsets.all(16),
        child: Text(
          widget.action == Action.bind
              ? i18n('Bind Device Title')
              : i18n('Configuring Device WiFi'),
          style: TextStyle(color: Colors.black87, fontSize: 28),
        ),
      ),
    ];

    switch (status) {
      case Status.connecting:
        list.add(iconLine(icon));
        text = i18n('Connecting to Device via Ip');
        break;

      case Status.connectFailed:
        icon = Icon(Icons.error_outline, color: Colors.redAccent, size: 96);
        list.add(iconLine(icon));
        text = i18n('Connect to Device via Ip Failed', {'ip': currentIP});
        buttonLabel = i18n('Back');
        break;

      case Status.binding:
        list.add(iconLine(icon));
        list.add(successLine(i18n('Connect Device Success')));
        text = i18n('Binding Device');
        break;

      case Status.bindFailed:
        icon = Icon(Icons.error_outline, color: Colors.redAccent, size: 96);
        list.add(iconLine(icon));
        text = i18n('Bind Device Failed');
        buttonLabel = i18n('Back');
        break;

      case Status.logging:
        list.add(iconLine(icon));
        list.add(successLine(i18n('Connect Device Success')));
        if (widget.action == Action.bind) {
          list.add(successLine(i18n('Bind Device Success')));
        }
        text = i18n('Logging Device');
        break;

      case Status.loginFailed:
        icon = Icon(Icons.error_outline, color: Colors.redAccent, size: 96);
        list.add(iconLine(icon));
        text = i18n('Device Login Failed');
        buttonLabel = i18n('Back');

        break;

      default:
        text = '';
        buttonLabel = null;
    }
    // current running
    list.add(Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 18),
        ),
      ),
    ));
    // button
    list.add(
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
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/deviceList', (Route<dynamic> route) => false);
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
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list,
    );
  }

  Widget renderBody(BuildContext ctx) {
    switch (status) {
      case Status.auth:
        return renderAuth();

      case Status.wifi:
        return renderWifi();

      case Status.authFailed:
        return renderFailed(ctx, i18n('Color Code Auth Failed'));

      case Status.authTimeout:
        return renderFailed(ctx, i18n('Color Code Auth Timeout'));

      case Status.bleFailed:
        return renderFailed(ctx, i18n('BLE Error'));

      case Status.formatError:
        return renderFailed(ctx, i18n('Format Disk Failed Text'));

      case Status.bindTimeout:
        return renderFailed(ctx, i18n('Bind Timeout Error'));

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
                          debug(e);
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
                        tooltip: i18n('Next Step'),
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
