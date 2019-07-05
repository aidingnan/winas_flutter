import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';

class LoginFailed extends StatelessWidget {
  LoginFailed({Key key, this.code}) : super(key: key);
  final Model model = Model();
  final String code;
  @override
  Widget build(BuildContext context) {
    String title;
    String content;
    bool formatAble = true;
    switch (code) {
      case 'EVOLUMENOTFOUND':
        title = i18n('Login Failed Title');
        content = i18n('Login Failed With EVOLUMENOTFOUND');
        formatAble = false;
        break;
      case 'EVOLUMEFILE':
        title = i18n('Login Failed Title');
        content = i18n('Login Failed With EVOLUMEFILE');
        break;
      case 'EVOLUMEFORMAT':
        title = i18n('Login Failed Title');
        content = i18n('Login Failed With EVOLUMEFORMAT');
        break;
      case 'EVOLUMEMISS':
        title = i18n('Login Failed Title');
        content = i18n('Login Failed With EVOLUMEMISS');
        break;
      default:
    }
    return WillPopScope(
      onWillPop: () => Future.value(model.shouldClose),
      child: StoreConnector<AppState, AppState>(
        onInit: (store) => {},
        onDispose: (store) => {},
        converter: (store) => store.state,
        builder: (context, state) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: formatAble
                ? <Widget>[
                    FlatButton(
                      textColor: Theme.of(context).primaryColor,
                      child: Text(i18n('Back')),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    FlatButton(
                      textColor: Theme.of(context).primaryColor,
                      child: Text(i18n('Format Disk')),
                      onPressed: () {},
                    ),
                  ]
                : <Widget>[
                    FlatButton(
                      textColor: Theme.of(context).primaryColor,
                      child: Text(i18n('Confirm')),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    )
                  ],
          );
        },
      ),
    );
  }
}
