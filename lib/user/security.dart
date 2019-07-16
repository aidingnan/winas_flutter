import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import './resetPwd.dart';
import './resetPhone.dart';
import '../redux/redux.dart';
import '../common/utils.dart';

class Security extends StatefulWidget {
  Security({Key key}) : super(key: key);
  @override
  _SecurityState createState() => _SecurityState();
}

class _SecurityState extends State<Security> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Account>(
        onInit: (store) => {},
        onDispose: (store) => {},
        converter: (store) => store.state.account,
        builder: (context, account) {
          if (!(account is Account)) return Container();
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
                    i18n('Account And Security'),
                    style: TextStyle(color: Colors.black87, fontSize: 21),
                  ),
                ),
                Container(height: 16),
                actionButton(
                  i18n('Phone Number'),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) {
                        return ResetPhone();
                      }),
                    );
                  },
                  Row(
                    children: <Widget>[
                      Text(
                        account.username,
                        style: TextStyle(color: Colors.black38),
                      ),
                      Container(width: 8),
                      Icon(Icons.chevron_right, color: Colors.black38),
                    ],
                  ),
                ),
                actionButton(
                  i18n('Password'),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return ResetPwd();
                        },
                      ),
                    );
                  },
                  Row(
                    children: <Widget>[
                      Text(
                        i18n('Goto Modify Password'),
                        style: TextStyle(color: Colors.black38),
                      ),
                      Container(width: 8),
                      Icon(Icons.chevron_right, color: Colors.black38),
                    ],
                  ),
                ),
                StoreConnector<AppState, VoidCallback>(
                  converter: (store) => () {
                    // cancel network monitor
                    store.state.apis.monitorCancel();

                    // remove account, apis, device, reset config
                    store.dispatch(LoginAction(null));
                    store.dispatch(UpdateApisAction(null));
                    store.dispatch(DeviceLoginAction(null));
                    store.dispatch(UpdateConfigAction(Config()));
                  },
                  builder: (context, logout) {
                    return actionButton(
                      i18n('Logout Account'),
                      () {
                        logout();
                        // pop all page
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (Route<dynamic> route) => false);
                      },
                      Container(),
                    );
                  },
                ),
              ],
            ),
          );
        });
  }
}
