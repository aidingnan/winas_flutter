import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';

class RenameDialog extends StatefulWidget {
  RenameDialog({Key key, this.entry}) : super(key: key);

  final Entry entry;
  @override
  _RenameDialogState createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  String _fileName;
  String _error;
  TextEditingController textController;
  bool loading = false;

  _onPressed(context, state) async {
    if (!isEnabled()) return;
    setState(() {
      loading = true;
    });
    final entry = widget.entry;
    try {
      await state.apis.req('rename', {
        'oldName': entry.name,
        'newName': _fileName,
        'dirUUID': entry.pdir,
        'driveUUID': entry.pdrv,
      });
    } catch (error) {
      _error = i18n('Rename Failed');
      if (error is DioError && error?.response?.data is Map) {
        final res = error.response.data;
        if (res['code'] == 'EEXIST') {
          _error = res['xcode'] == 'EISFILE'
              ? i18n('File Conflict')
              : i18n('Directory Conflict');
        } else if (res['message'] == 'invalid name') {
          _error = i18n('Invalid Name');
        }
      } else {
        print(error);
      }

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
        widget.entry.name != _fileName;
  }

  @override
  void initState() {
    textController = TextEditingController(text: widget.entry.name);
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
