import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';

class NewFolder extends StatefulWidget {
  NewFolder({Key key, this.node}) : super(key: key);
  final Node node;
  @override
  _NewFolderState createState() => _NewFolderState(node);
}

class _NewFolderState extends State<NewFolder> {
  _NewFolderState(this.node);
  String _fileName;
  String _error;
  bool loading = false;
  final Node node;

  _onPressed(context, state) async {
    if (!isEnabled()) return;

    setState(() {
      loading = true;
    });

    try {
      await state.apis.req('mkdir', {
        'dirname': _fileName,
        'dirUUID': node.dirUUID,
        'driveUUID': node.driveUUID,
      });
    } catch (error) {
      _error = i18n('Create New Folder Failed');
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
        debug(error);
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
        _fileName.length > 0;
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return AlertDialog(
          title: Text(i18n('New Folder')),
          content: TextField(
            autofocus: true,
            onChanged: (text) {
              setState(() => _error = null);
              _fileName = text;
            },
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
