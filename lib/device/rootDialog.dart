import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../login/stationLogin.dart';

enum Status { init, loading, reboot, failed, success }

class RootDialog extends StatefulWidget {
  RootDialog({Key key, this.rooted}) : super(key: key);
  final bool rooted;
  @override
  _RootDialogState createState() => _RootDialogState();
}

class _RootDialogState extends State<RootDialog> {
  Model model = Model();
  Status status = Status.init;

  void close({bool success}) {
    if (model.close) return;
    model.close = true;
    Navigator.pop(this.context, success);
  }

  void onPressed(AppState state) async {
    if (this.mounted) {
      setState(() {
        status = Status.loading;
      });
    }

    try {
      final deviceSN = state.apis.deviceSN;
      final op = widget.rooted ? 'unroot' : 'root';

      await state.cloud.req(op, {'deviceSN': deviceSN});

      int now = DateTime.now().millisecondsSinceEpoch;

      bool isOnline = false;
      await Future.delayed(Duration(seconds: 4));

      if (this.mounted) {
        setState(() {
          status = Status.reboot;
        });
      }

      while (isOnline != true) {
        final current = DateTime.now().millisecondsSinceEpoch;

        if (current - now > 180000) {
          throw 'Timeout of 180 seconds for upgrade to state Finished';
        }

        await Future.delayed(Duration(seconds: 2));

        try {
          final res = await reqStationList(state.cloud);

          List<Station> list = res['stationList'];
          isOnline = list
                  .firstWhere((s) => s.sn == deviceSN, orElse: () => null)
                  ?.isOnline ==
              true;
          print('isOnline: $isOnline');
        } catch (e) {
          debug(e);
        }
      }

      await Future.delayed(Duration(seconds: 2));

      if (this.mounted) {
        setState(() {
          status = Status.success;
        });
      }
    } catch (error) {
      debug(error);
      if (this.mounted) {
        setState(() {
          status = Status.failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String text = '';
    Widget icon = CircularProgressIndicator();

    switch (status) {
      case Status.init:
        text = widget.rooted
            ? i18n('Unroot Device Text')
            : i18n('Root Device Text');
        break;
      case Status.loading:
        text =
            widget.rooted ? i18n('Unrooting Device') : i18n('Rooting Device');
        icon = CircularProgressIndicator();
        break;
      case Status.reboot:
        text = i18n('Device Rebooting');
        icon = CircularProgressIndicator();
        break;
      case Status.success:
        text = widget.rooted
            ? i18n('Device Unroot Success')
            : i18n('Device Root Success');
        icon = Icon(Icons.check, color: Colors.teal, size: 72);
        break;
      case Status.failed:
        text = widget.rooted
            ? i18n('Device Unroot Failed')
            : i18n('Device Root Failed');
        icon = Icon(Icons.close, color: Colors.redAccent, size: 72);
        break;
      default:
        break;
    }

    return StoreConnector<AppState, AppState>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return WillPopScope(
          onWillPop: () => Future.value(model.shouldClose),
          child: AlertDialog(
            title:
                status == Status.init ? Text(i18n('Root Device Title')) : null,
            content: status == Status.init
                ? Text(text)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        height: 96,
                        child: Center(
                          child: icon,
                        ),
                      ),
                      Text(text),
                    ],
                  ),
            actions: status == Status.init
                ? <Widget>[
                    FlatButton(
                      textColor: Theme.of(context).primaryColor,
                      child: Text(i18n('Cancel')),
                      onPressed: () => close(),
                    ),
                    FlatButton(
                      textColor: Theme.of(context).primaryColor,
                      child: Text(i18n('Confirm')),
                      onPressed: () => onPressed(state),
                    )
                  ]
                : status == Status.reboot || status == Status.loading
                    ? <Widget>[Container(height: 24)]
                    : <Widget>[
                        FlatButton(
                          textColor: Theme.of(context).primaryColor,
                          child: Text(i18n('OK')),
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(context,
                                '/deviceList', (Route<dynamic> route) => false);
                          },
                        )
                      ],
          ),
        );
      },
    );
  }
}
