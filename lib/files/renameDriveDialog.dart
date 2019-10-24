import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';

class RenameDriveDialog extends StatefulWidget {
  RenameDriveDialog({Key key, this.drive}) : super(key: key);

  final Drive drive;
  @override
  _RenameDialogState createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDriveDialog> {
  String _fileName;
  String _error;
  TextEditingController textController;
  bool loading = false;

  _onPressed(context, state) async {
    if (!isEnabled()) return;
    setState(() {
      loading = true;
    });
    // final drive = widget.drive;
    try {
      // await state.apis.req('rename', {
      //   'oldName': entry.name,
      //   'newName': _fileName,
      //   'dirUUID': entry.pdir,
      //   'driveUUID': entry.pdrv,
      // });
    } catch (error) {
      _error = i18n('Rename Failed');

      debug(error);

      setState(() {
        loading = false;
      });
      return;
    }

    Navigator.pop(context, true);
  }

  bool isEnabled() {
    return loading == false &&
        _error == null &&
        _fileName is String &&
        _fileName.length > 0 &&
        widget.drive.label != _fileName;
  }

  @override
  void initState() {
    textController = TextEditingController(text: widget.drive.label);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return AlertDialog(
          title: Text(i18n('Rename')),
          content: TextField(
            autofocus: true,
            onChanged: (text) {
              setState(() => _error = null);
              _fileName = text;
            },
            controller: textController,
            decoration: InputDecoration(errorText: _error),
            style: TextStyle(fontSize: 24, color: Colors.black87),
          ),
          actions: <Widget>[
            FlatButton(
                textColor: Theme.of(context).primaryColor,
                child: Text(i18n('Cancel')),
                onPressed: () {
                  Navigator.pop(context);
                }),
            FlatButton(
              textColor: Theme.of(context).primaryColor,
              child: Text(i18n('Confirm')),
              onPressed: isEnabled() ? () => _onPressed(context, state) : null,
            )
          ],
        );
      },
    );
  }
}
