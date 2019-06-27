import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';

class TokenExpired extends StatelessWidget {
  TokenExpired({Key key}) : super(key: key);
  final Model model = Model();
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => Future.value(model.shouldClose),
      child: StoreConnector<AppState, AppState>(
        onInit: (store) => {},
        onDispose: (store) => {},
        converter: (store) => store.state,
        builder: (context, state) {
          return AlertDialog(
            title: Text(i18n('Token Expired Title')),
            content: Text(i18n('Token Expired Text')),
            actions: <Widget>[
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(i18n('Confirm')),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                },
              )
            ],
          );
        },
      ),
    );
  }
}
