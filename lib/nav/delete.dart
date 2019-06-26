import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import './xcopyTasks.dart';

class DeleteDialog extends StatefulWidget {
  DeleteDialog({Key key, this.xCopyTasks, this.task}) : super(key: key);
  final XCopyTasks xCopyTasks;
  final Task task;
  @override
  _DeleteDialogState createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<DeleteDialog> {
  Model model = Model();
  bool loading = false;

  void close({bool success}) {
    if (model.close) return;
    model.close = true;
    Navigator.pop(this.context, success);
  }

  void onPressed(state) async {
    setState(() {
      loading = true;
    });

    try {
      if (widget.task != null) {
        await widget.xCopyTasks.cancelTask(widget.task);
      } else {
        await widget.xCopyTasks.cancelAllTaskAsync();
      }
    } catch (error) {
      print(error);
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
            title: Text(
              widget.task != null
                  ? i18n('Cancel Xcopy Task')
                  : i18n('Cancel All Xcopy Tasks'),
            ),
            content: Text(
              widget.task != null
                  ? i18n('Confirm to Cancel Selected Xcopy Tasks')
                  : i18n('Confirm to Cancel All Xcopy Tasks'),
            ),
            actions: <Widget>[
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(i18n('Back')),
                onPressed: () => close(),
              ),
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(loading ? i18n('Processing') : i18n('Confirm')),
                onPressed: loading ? null : () => onPressed(state),
              )
            ],
          ),
        );
      },
    );
  }
}
