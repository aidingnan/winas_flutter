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

  /// value of checkBox
  bool check = false;

  void onCancel() {
    Navigator.pop(this.context, null);
  }

  void onConfirm() {
    Navigator.pop(this.context, check == true);
  }

  @override
  Widget build(BuildContext context) {
    // final title = 'Confirm To RestDevice Title';
    // final text = 'Confirm To RestDevice Text';
    // final checkBoxText = 'Confirm To RestDevice checkBoxText';
    final title = '重置口袋网盘';
    final text = '该操作将解绑用户、恢复口袋网盘的出厂设置。确定要继续吗？';
    final checkBoxText = '同时擦除SSD硬盘内的数据';
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
                Transform.translate(
                  offset: Offset(-10, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Checkbox(
                        value: check,
                        onChanged: (value) {
                          setState(() {
                            check = value;
                          });
                        },
                      ),
                      Text(checkBoxText),
                    ],
                  ),
                )
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
