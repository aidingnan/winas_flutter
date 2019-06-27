import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';

enum Status {
  auth,
  authFailed,
  reseting,
  resetFailed,
  success,
}

class ResetDevice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
        onInit: (store) => {},
        onDispose: (store) => {},
        converter: (store) => store.state,
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              elevation: 0.0, // no shadow
              backgroundColor: Colors.white10,
              brightness: Brightness.light,
              iconTheme: IconThemeData(color: Colors.black38),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    i18n('Reset Device'),
                    style: TextStyle(color: Colors.black87, fontSize: 21),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    i18n('Reset Device Text 1'),
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    i18n('Reset Device Text 2'),
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Text(
                    i18n('Reset Device Text 3'),
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                Builder(builder: (ctx) {
                  return Container(
                    height: 88,
                    padding: EdgeInsets.all(16),
                    width: double.infinity,
                    child: RaisedButton(
                      color: Colors.redAccent,
                      elevation: 1.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(48),
                      ),
                      onPressed: () async {
                        final loadingInstance = showLoading(ctx);
                        final isLAN = await state.apis.testLAN();
                        if (isLAN) {
                          try {
                            final res =
                                await state.apis.req('reqLocalAuth', null);
                            final colors = res.data['colors'];
                            if (colors is! List) throw 'get color code error';
                          } catch (e) {
                            print(e);
                            loadingInstance.close();
                            showSnackBar(ctx, i18n('Request Color Code Error'));
                            return;
                          }
                          loadingInstance.close();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => _ResetDevice()),
                          );
                        } else {
                          loadingInstance.close();
                          showSnackBar(ctx, i18n('Not LAN Network Error'));
                        }
                      },
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Container()),
                          Text(
                            i18n('Reset Device'),
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          Expanded(child: Container()),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        });
  }
}

class _ResetDevice extends StatefulWidget {
  _ResetDevice({Key key}) : super(key: key);

  @override
  _ResetDeviceState createState() => _ResetDeviceState();
}

class _ResetDeviceState extends State<_ResetDevice> {
  List<String> selected;

  Status status = Status.auth;

  String get redLight => i18n('Red Light');
  String get greenLight => i18n('Green Light');
  String get blueLight => i18n('Blue Light');
  String get alwaysOn => i18n('Always On');
  String get breath => i18n('Breath');

  /// color codes
  List<List<String>> get colorCodes => [
        [redLight, alwaysOn, '#ff0000', 'alwaysOn'],
        [redLight, breath, '#ff0000', 'breath'],
        [greenLight, alwaysOn, '#00ff00', 'alwaysOn'],
        [greenLight, breath, '#00ff00', 'breath'],
        [blueLight, alwaysOn, '#0000ff', 'alwaysOn'],
        [blueLight, breath, '#0000ff', 'breath'],
      ];

  /// '#ff0000' => Color(0xFF0000)
  Color _getColor(String color) {
    final value = int.parse('FF${color.substring(1)}', radix: 16);
    return Color(value);
  }

  /// check color code
  Future<String> checkCode(AppState state, List<String> code) async {
    final args = {
      'color': [code[2], code[3]]
    };
    final res = await state.apis.req('localAuth', args);
    String token = res.data['token'];
    return token;
  }

  /// start to bind device
  Future<void> restDevice(
      BuildContext ctx, AppState state, String token) async {
    setState(() {
      status = Status.reseting;
    });

    try {
      final res = await state.cloud.req('encrypted', null);
      final encrypted = res.data['encrypted'] as String;
      final resetRes =
          await state.cloud.unbindDevice(state.apis.lanIp, encrypted, token);
      print('resetRes: $resetRes');
      setState(() {
        status = Status.success;
      });
    } catch (e) {
      print('resetRes error $e');
      setState(() {
        status = Status.resetFailed;
      });
      return;
    }
  }

  void nextStep(BuildContext ctx, AppState state) async {
    if (status == Status.auth) {
      print('code is $selected');

      final loadingInstance = showLoading(ctx);
      try {
        String token = await checkCode(state, selected);
        loadingInstance.close();
        restDevice(ctx, state, token).catchError(print);
      } catch (e) {
        print(e);
        loadingInstance.close();
        setState(() {
          status = Status.authFailed;
        });
      }
    }
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
                      TextSpan(
                        children: [
                          TextSpan(
                            text: code[0],
                            style: TextStyle(color: _getColor(code[2])),
                          ),
                          TextSpan(text: ' '),
                          TextSpan(text: code[1]),
                        ],
                      ),
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

  Widget renderFailed(BuildContext ctx) {
    return Column(
      children: <Widget>[
        Container(height: 64),
        Icon(Icons.error_outline, color: Colors.redAccent, size: 96),
        Container(
          padding: EdgeInsets.all(64),
          child: Center(
            child: Text(i18n('Color Code Auth Failed')),
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
              Navigator.pushNamedAndRemoveUntil(
                  context, '/deviceList', (Route<dynamic> route) => false);
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

  Widget renderUnbind(BuildContext ctx) {
    String text = '';
    String buttonLabel;
    Widget icon = CircularProgressIndicator();
    switch (status) {
      case Status.reseting:
        text = i18n('Reseting Device');
        break;

      case Status.success:
        text = i18n('Reset Device Success');
        buttonLabel = i18n('Back');
        icon = Icon(Icons.check, color: Colors.teal, size: 96);
        break;

      case Status.resetFailed:
        text = i18n('Reset Device Failed');
        buttonLabel = i18n('Back');
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
            i18n('Reset Device'),
            style: TextStyle(color: Colors.black87, fontSize: 28),
          ),
        ),
        Container(
          height: 108,
          child: Center(child: icon),
        ),
        Container(
          height: 64,
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
                    if (status == Status.success) {
                      Navigator.pushNamedAndRemoveUntil(
                          ctx, '/deviceList', (Route<dynamic> route) => false);
                    } else {
                      Navigator.pop(ctx);
                    }
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

      case Status.authFailed:
        return renderFailed(ctx);

      default:
        return renderUnbind(ctx);
    }
  }

  @override
  Widget build(BuildContext context) {
    // whether has fab button or not
    bool hasFab = status == Status.auth;
    // whether has back button or not
    bool hasBack = status == Status.auth;
    // whether fab enable or not
    bool enabled = (status == Status.auth && selected != null);
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        backgroundColor: Colors.grey[50],
        automaticallyImplyLeading: hasBack,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.black38),
        actions: <Widget>[],
      ),
      body: Builder(builder: (ctx) => renderBody(ctx)),
      floatingActionButton: !hasFab
          ? null
          : Builder(
              builder: (ctx) {
                return StoreConnector<AppState, AppState>(
                    onInit: (store) => {},
                    onDispose: (store) => {},
                    converter: (store) => store.state,
                    builder: (context, state) {
                      return FloatingActionButton(
                        onPressed: !enabled ? null : () => nextStep(ctx, state),
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
