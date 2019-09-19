import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:fluwx/fluwx.dart' as fluwx;
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_redux/flutter_redux.dart';

import './registry.dart';
import './confirmUEIP.dart';
import './stationLogin.dart';
import './accountLogin.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/request.dart';
import '../common/appConfig.dart';
import '../icons/winas_icons.dart';

final pColor = Colors.teal;

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isWeChatInstalled = false;
  var request = Request();
  String code;
  var tokenRes;

  bool toggleTest = false;

  @override
  void initState() {
    super.initState();

    /// cache context for i18n
    cacheContext(this.context);

    _initFluwx().catchError(print);
    // set SystemUiStyle to dark
    if (Platform.isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    }

    /// test cloud connectivity
    request.req('testCloud', null).catchError(debug);

    /// Confirm User Experience Improvement Program
    _confirmUEIP().catchError(print);
  }

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

  Future<void> _confirmUEIP() async {
    await Future.delayed(Duration.zero);
    if (AppConfig.umeng == null) {
      showDialog(
        context: context,
        // Confirm User Experience Improvement Program
        builder: (BuildContext context) => ConfirmUEIP(),
      );
    }
  }

  accoutLogin(BuildContext context, store) async {
    showLoading(context);

    // update Account
    Account account = Account.fromMap(tokenRes);
    store.dispatch(LoginAction(account));

    // device login
    await deviceLogin(context, request, account, store);
  }

  wechatAuth(BuildContext ctx, Function callback) async {
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

    _wxlogin = fluwx.responseFromAuth.listen((fluwx.WeChatAuthResponse data) {
      code = data?.code;
      if (code != null) {
        final args = {
          'clientId': clientId,
          'code': code,
        };
        tokenRes = null;
        request.req('wechatLogin', args).then((res) {
          if (res.data['wechat'] != null && res.data['user'] == false) {
            // nav to registry
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Registry(wechat: res.data['wechat']),
              ),
            );
          } else if (res.data['user'] == true && res.data['token'] != null) {
            // wechat bound
            tokenRes = res.data;
            callback(ctx);
          } else {
            debug(res);
            throw Error();
          }
        }).catchError((err) {
          debug(err);
          showSnackBar(ctx, i18n('WeChat Login Failed'));
        });
      } else {
        debug(data?.errCode);
        showSnackBar(ctx, i18n('WeChat Login Failed'));
      }
    });
  }

  @override
  void dispose() {
    // remove listener
    _wxlogin?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      appBar: AppBar(
        elevation: 0.0, // no shadow
        leading: GestureDetector(
          onDoubleTap: () {
            setState(() {
              toggleTest = true;
            });
          },
          onLongPress: () async {
            if (toggleTest != true) return;
            await AppConfig.toggleDev();
            setState(() {
              toggleTest = false;
            });
          },
          child: Stack(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                color: Colors.teal,
              ),
              if (AppConfig.isDev)
                Banner(
                  location: BannerLocation.topStart,
                  message: 'Test',
                ),
            ],
          ),
        ),
        actions: <Widget>[
          FlatButton(
            child: Text(i18n('Login')),
            textColor: Colors.white,
            onPressed: () {
              // Navigator to Login
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Login()),
              );
            },
          ),
        ],
      ),
      body: StoreConnector<AppState, Function>(
        converter: (store) => (BuildContext ctx) => accoutLogin(ctx, store),
        builder: (ctx, callback) {
          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height - 108,
              color: Colors.teal,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // title
                  Container(
                    margin: EdgeInsets.only(bottom: 48),
                    child: Text(
                      i18n('Welcoming Text'),
                      style: TextStyle(fontSize: 28.0, color: Colors.white),
                      textAlign: TextAlign.left,
                    ),
                    width: double.infinity,
                  ),

                  // wechat login
                  if (isWeChatInstalled == true)
                    Container(
                      margin: EdgeInsets.only(bottom: 32),
                      height: 56,
                      width: double.infinity,
                      child: RaisedButton(
                        color: Colors.white,
                        elevation: 1.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(48),
                        ),
                        onPressed: () => wechatAuth(ctx, callback),
                        child: Row(
                          children: <Widget>[
                            Icon(Winas.wechat, color: pColor),
                            Expanded(child: Container()),
                            Text(
                              i18n('Login via WeChat'),
                              style: TextStyle(color: pColor, fontSize: 16),
                            ),
                            Expanded(child: Container()),
                            Container(width: 24),
                          ],
                        ),
                      ),
                    ),

                  // create account
                  Container(
                    margin: EdgeInsets.only(bottom: 32),
                    height: 56,
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: RaisedButton(
                        color: pColor,
                        elevation: 1.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Registry(),
                            ),
                          );
                        },
                        child: Text(
                          i18n('Create Account'),
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ),

                  // license
                  GestureDetector(
                    onTap: () async {
                      String url = 'https://www.aidingnan.com/support';
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        debug('Could not launch $url');
                      }
                    },
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: i18n('Licence Hint Part 1'),
                          style: TextStyle(fontSize: 12.0, color: Colors.white),
                        ),
                        TextSpan(
                          text: i18n('Licence Hint Part 2'),
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontSize: 12.0,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]),
                    ),
                  ),

                  Container(height: 64.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
