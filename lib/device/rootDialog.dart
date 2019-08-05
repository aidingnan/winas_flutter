import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';

class RootDialog extends StatefulWidget {
  RootDialog({Key key}) : super(key: key);

  @override
  _RootDialogState createState() => _RootDialogState();
}

class _RootDialogState extends State<RootDialog> {
  Model model = Model();
  bool loading = false;

  void close({bool success}) {
    if (model.close) return;
    model.close = true;
    Navigator.pop(this.context, success);
  }

  void onPressed(AppState state) async {
    setState(() {
      loading = true;
    });

    try {
      await state.cloud.req('root', {'deviceSN': state.apis.deviceSN});
    } catch (error) {
      debug(error);
      setState(() {
        loading = false;
      });
      close(success: false);
      return;
    }
    close(success: true);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return WillPopScope(
          onWillPop: () => Future.value(model.shouldClose),
          child: AlertDialog(
            title: Text(i18n('Root Device Title')),
            content: Text(i18n('Root Device Text')),
            actions: <Widget>[
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(i18n('Cancel')),
                onPressed: () => close(),
              ),
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(loading ? i18n('Rooting') : i18n('Confirm')),
                onPressed: loading ? null : () => onPressed(state),
              )
            ],
          ),
        );
      },
    );
  }
}
