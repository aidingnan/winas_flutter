import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import './pwdCode.dart';
import '../redux/redux.dart';
import '../common/utils.dart';

final pColor = Colors.teal;

class ResetPwd extends StatefulWidget {
  ResetPwd({Key key}) : super(key: key);
  @override
  _ResetPwdState createState() => _ResetPwdState();
}

class _ResetPwdState extends State<ResetPwd> {
  bool loading = false;

  _sendMsgCode(BuildContext ctx, AppState state) async {
    setState(() {
      loading = true;
    });
    final request = state.cloud;
    final phone = state.account.username;
    try {
      await request.req('smsCode', {
        'type': 'password',
        'phone': phone,
      });
    } catch (error) {
      print(error);
      if (this.mounted) {
        if ([60702, 60003].contains(error.response.data['code'])) {
          showSnackBar(ctx, i18n('Request Verification Code Too Frquent'));
        } else {
          showSnackBar(ctx, i18n('Request Verification Code Failed'));
        }
        setState(() {
          loading = false;
        });
      }
      return;
    }

    setState(() {
      loading = false;
    });
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (context) {
        return SmsCode(phone: phone, request: request);
      }),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        backgroundColor: Colors.white10,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.black38),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(16),
              child: Text(
                i18n('Change Password'),
                style: TextStyle(fontSize: 21),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                i18n('Change Password Text'),
                style: TextStyle(color: Colors.black54),
              ),
            ),
            StoreConnector<AppState, AppState>(
                onInit: (store) => {},
                onDispose: (store) => {},
                converter: (store) => store.state,
                builder: (ctx, state) {
                  return Container(
                    height: 88,
                    padding: EdgeInsets.all(16),
                    width: double.infinity,
                    child: RaisedButton(
                      color: pColor,
                      elevation: 1.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(48),
                      ),
                      onPressed: () => _sendMsgCode(ctx, state),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Container()),
                          Text(
                            i18n(
                              'Send Verification Code to Phone',
                              {'phoneNumber': state.account.username},
                            ),
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          Expanded(child: Container()),
                          Container(width: 24),
                        ],
                      ),
                    ),
                  );
                }),
            Container(height: 32),
            Center(
              child: loading ? CircularProgressIndicator() : Container(),
            ),
          ],
        ),
      ),
    );
  }
}
