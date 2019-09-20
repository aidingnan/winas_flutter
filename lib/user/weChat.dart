import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluwx/fluwx.dart' as fluwx;
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../icons/winas_icons.dart';

final pColor = Colors.teal;

class WeChat extends StatefulWidget {
  WeChat({Key key}) : super(key: key);
  @override
  _WeChatState createState() => _WeChatState();
}

class _WeChatState extends State<WeChat> {
  String code;
  bool _loading = true;
  var wechatInfo;
  bool isWeChatInstalled = false;

  StreamSubscription<fluwx.WeChatAuthResponse> _wxlogin;

  _initFluwx() async {
    await fluwx.register(
      appId: "wx0aa672b8371cde8e",
      doOnAndroid: true,
      doOnIOS: true,
      enableMTA: false,
    );
    isWeChatInstalled = await fluwx.isWeChatInstalled();
    if (this.mounted) {
      setState(() {});
    }
  }

  _refresh(AppState state) async {
    final res = await state.cloud.req('wechat', null);
    wechatInfo = res.data;
    if (this.mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  _bindWeChat(BuildContext ctx, AppState state) async {
    // remove previous listener
    _wxlogin?.cancel();

    if (isWeChatInstalled != true) {
      showSnackBar(ctx, i18n('WeChat not Installed'));
      return;
    }

    String clientId = await getClientId();

    await fluwx.sendAuth(
      openId: "wx0aa672b8371cde8e",
      scope: "snsapi_userinfo",
      state: "winas_login",
    );

    _wxlogin = fluwx.responseFromAuth.listen((data) {
      code = data?.code;
      if (code != null) {
        final args = {
          'clientId': clientId,
          'code': code,
        };

        state.cloud.req('wechatLogin', args).then((res) {
          if (res.data['wechat'] != null && res.data['user'] == false) {
            // bind to wechat
            state.cloud.req('bindWechat', {
              'wechatToken': res.data['wechat'],
            }).then((data) {
              showSnackBar(ctx, i18n('Bind WeChat Success'));
              if (this.mounted) {
                this.setState(() {
                  _loading = true;
                });
              }
              _refresh(state);
            });
          } else if (res.data['user'] == true && res.data['token'] != null) {
            // wechat has bind to other account
            showSnackBar(ctx, i18n('WeChat Bind to Another Account'));
          } else {
            debug(res);
            throw res;
          }
        }).catchError((err) {
          debug(err);
          if (err is DioError) {
            debug(err.response.statusMessage);
          }
          showSnackBar(ctx, i18n('Bind WeChat Failed'));
        });
      } else {
        debug(data);
        showSnackBar(ctx, i18n('Bind WeChat Failed'));
      }
    });
  }

  _unbindWeChat(BuildContext ctx, AppState state) async {
    // remove previous listener
    _wxlogin?.cancel();

    final loadingInstance = showLoading(context);
    try {
      await state.cloud.req('unbindWechat', {
        'unionid': wechatInfo[0]['unionid'],
      });
      await _refresh(state);
      loadingInstance.close();
      showSnackBar(ctx, i18n('Unbind WeChat Success'));
    } catch (error) {
      debug(error);
      if (error is DioError) {
        debug(error.response);
      }
      if (this.mounted) {
        setState(() {
          _loading = false;
        });
      }

      loadingInstance.close();
      showSnackBar(ctx, i18n('Unbind WeChat Failed'));
    }
  }

  @override
  void initState() {
    super.initState();
    _initFluwx().catchError(print);
  }

  @override
  void dispose() {
    // remove listener
    _wxlogin?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasWeChat = wechatInfo is List && wechatInfo.length > 0;
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        backgroundColor: Colors.white10,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.black38),
      ),
      body: StoreConnector<AppState, AppState>(
        onInit: (store) => _refresh(store.state),
        onDispose: (store) => {},
        converter: (store) => store.state,
        builder: (ctx, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  i18n('Bind WeChat Title'),
                  style: TextStyle(color: Colors.black87, fontSize: 21),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Text(
                  i18n('Bind WeChat Text'),
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  _loading
                      ? ''
                      : hasWeChat
                          ? i18n(
                              'WeChat Already Bound',
                              {'wechat': wechatInfo[0]['nickname']},
                            )
                          : i18n('No WeChat Bound'),
                  style: TextStyle(fontSize: 16),
                ),
              ),
              _loading
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : Container(
                      height: 88,
                      padding: EdgeInsets.all(16),
                      width: double.infinity,
                      child: RaisedButton(
                        color: pColor,
                        elevation: 1.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(48),
                        ),
                        onPressed: () => hasWeChat
                            ? _unbindWeChat(ctx, state)
                            : _bindWeChat(ctx, state),
                        child: Row(
                          children: <Widget>[
                            Icon(Winas.wechat, color: Colors.white),
                            Expanded(child: Container()),
                            Text(
                              hasWeChat
                                  ? i18n('Unbind WeChat')
                                  : i18n('Bind WeChat Now'),
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            Expanded(child: Container()),
                            Container(width: 24),
                          ],
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}
