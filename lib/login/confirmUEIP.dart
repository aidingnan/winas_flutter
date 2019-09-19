import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/appConfig.dart';

/// Confirm User Experience Improvement Program
class ConfirmUEIP extends StatefulWidget {
  ConfirmUEIP({Key key}) : super(key: key);
  @override
  _ConfirmUEIPState createState() => _ConfirmUEIPState();
}

class _ConfirmUEIPState extends State<ConfirmUEIP> {
  _ConfirmUEIPState();

  void onFire(Store<AppState> store, bool result) {
    store.dispatch(
      UpdateConfigAction(
        Config.combine(
          store.state.config,
          Config(umeng: result),
        ),
      ),
    );
    AppConfig.umeng = result;
    Navigator.pop(this.context, result);
  }

  @override
  Widget build(BuildContext context) {
    final title = i18n('User Experience Improvement Program Title');
    final text = i18n('User Experience Improvement Program Text');

    return StoreConnector<AppState, Store<AppState>>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store,
      builder: (context, store) {
        return WillPopScope(
          onWillPop: () => Future.value(false),
          child: AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(text),
                Container(height: 16),
              ],
            ),
            actions: <Widget>[
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(i18n('Do not join')),
                onPressed: () => onFire(store, false),
              ),
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(i18n('Join')),
                onPressed: () => onFire(store, true),
              )
            ],
          ),
        );
      },
    );
  }
}
