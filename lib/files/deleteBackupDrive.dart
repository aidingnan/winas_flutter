import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../redux/redux.dart';
import '../common/utils.dart';

class DeleteDriveDialog extends StatefulWidget {
  DeleteDriveDialog({Key key, this.drive}) : super(key: key);
  final Drive drive;
  @override
  _DeleteDialogState createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<DeleteDriveDialog> {
  _DeleteDialogState();
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
      // Map<String, dynamic> formdata = Map();

      // await state.apis.req('deleteDirOrFile', {
      //   'formdata': FormData.fromMap(formdata),
      //   'dirUUID': 'list[0].pdir',
      //   'driveUUID': 'list[0].pdrv',
      // });
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
            title: Text(i18n('Delete Backup Drive Title')),
            content: Text(i18n('Confirm to Delete Backup Drive')),
            actions: <Widget>[
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(i18n('Cancel')),
                onPressed: () => close(),
              ),
              FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(loading ? i18n('Deleting') : i18n('Confirm')),
                onPressed: loading ? null : () => onPressed(state),
              )
            ],
          ),
        );
      },
    );
  }
}
