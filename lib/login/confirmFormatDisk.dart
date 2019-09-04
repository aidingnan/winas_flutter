import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';

class ConfirmDialog extends StatefulWidget {
  ConfirmDialog({Key key}) : super(key: key);
  @override
  _ConfirmDialogState createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  _ConfirmDialogState();

  void onCancel() {
    Navigator.pop(this.context, false);
  }

  void onConfirm() {
    Navigator.pop(this.context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title = i18n('Format SSD Disk Title');
    final text = i18n('Format SSD Disk Text');

    return StoreConnector<AppState, AppState>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
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
                child: Text(i18n('Cancel')),
                onPressed: onCancel,
              ),
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(i18n('Confirm')),
                onPressed: onConfirm,
              )
            ],
          ),
        );
      },
    );
  }
}
