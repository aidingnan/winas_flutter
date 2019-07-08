import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/request.dart';

enum Status { warnings, confirm, formating, success, failed }

class LoginDeviceFailed extends StatefulWidget {
  LoginDeviceFailed(
      {Key key, this.code, this.blks, this.deviceSN, this.request})
      : super(key: key);
  final String code;
  final List<Block> blks;
  final Request request;
  final String deviceSN;
  @override
  _LoginDeviceFailedState createState() => _LoginDeviceFailedState();
}

class _LoginDeviceFailedState extends State<LoginDeviceFailed> {
  Status status = Status.warnings;

  getContent() {
    String title = '';
    String content = '';
    bool formatAble = true;
    switch (widget.code) {
      // no disk
      case 'EVOLUMENOTFOUND':
        title = i18n('Login Failed Title');
        content = i18n('Login Failed With EVOLUMENOTFOUND');
        formatAble = false;
        break;
      // failed to read config files
      case 'EVOLUMEFILE':
        title = i18n('Login Failed Title');
        content = i18n('Login Failed With EVOLUMEFILE');
        break;
      // disk format is not correct
      case 'EVOLUMEFORMAT':
        title = i18n('Login Failed Title');
        content = i18n('Login Failed With EVOLUMEFORMAT');
        break;
      // volume is missing
      case 'EVOLUMEMISS':
        title = i18n('Login Failed Title');
        content = i18n('Login Failed With EVOLUMEMISS');
        break;
      default:
        break;
    }
    return ({'title': title, 'content': content, 'formatAble': formatAble});
  }

  get backButton => FlatButton(
        textColor: Theme.of(context).primaryColor,
        child: Text(i18n('Back')),
        onPressed: () {
          Navigator.pop(context);
        },
      );
  get okButton => FlatButton(
        textColor: Theme.of(context).primaryColor,
        child: Text(i18n('OK')),
        onPressed: () {
          Navigator.pop(context);
        },
      );

  get formatButton => FlatButton(
        textColor: Theme.of(context).primaryColor,
        child: Text(i18n('Format Disk')),
        onPressed: () {
          setState(() {
            status = Status.confirm;
          });
        },
      );

  get confirmButton => FlatButton(
        textColor: Theme.of(context).primaryColor,
        child: Text(i18n('Confirm')),
        onPressed: () async {
          try {
            setState(() {
              status = Status.formating;
            });
            final target = widget.blks[0].name;
            await widget.request.req(
                'formatDisk', {'target': target, 'deviceSN': widget.deviceSN});
            await Future.delayed(Duration(seconds: 2));
            if (mounted) {
              setState(() {
                status = Status.success;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                status = Status.failed;
              });
            }
          }
        },
      );

  @override
  Widget build(BuildContext context) {
    String title = '';
    String content = '';
    bool formatAble = true;
    List<Widget> actions = [];
    Widget icon;
    if (status == Status.warnings) {
      /// init warnings
      final data = getContent();
      title = data['title'];
      content = data['content'];
      formatAble = data['formatAble'];
      if (formatAble) {
        actions.add(backButton);
        actions.add(formatButton);
      } else {
        actions.add(okButton);
      }
    } else if (status == Status.confirm) {
      /// Confirm to Format Disk
      title = i18n('Confirm to Format Disk Title');
      content = i18n('Confirm to Format Disk Text');
      actions.add(backButton);
      actions.add(confirmButton);
    } else if (status == Status.formating) {
      /// Formating
      icon = CircularProgressIndicator();
      content = i18n('Formating Disk Text');
    } else if (status == Status.success) {
      /// Format success
      icon = Icon(
        Icons.check,
        color: Colors.teal,
        size: 64,
      );
      content = i18n('Format Disk Success Text');
      actions.add(okButton);
    } else if (status == Status.failed) {
      /// Format failed
      icon = Icon(
        Icons.close,
        color: Colors.redAccent,
        size: 64,
      );
      content = i18n('Format Disk Failed Text');
      actions.add(okButton);
    }
    return WillPopScope(
      onWillPop: () => Future.value(false),
      child: StoreConnector<AppState, AppState>(
        onInit: (store) => {},
        onDispose: (store) => {},
        converter: (store) => store.state,
        builder: (context, state) {
          return AlertDialog(
            title: title == '' ? null : Text(title),
            content: icon != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(32),
                        child: Center(child: icon),
                      ),
                      Text(content)
                    ],
                  )
                : Text(content),
            actions: actions,
          );
        },
      ),
    );
  }
}
