import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './info.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../login/stationLogin.dart';

enum Status { loading, reboot, failed, success }

class UpgradeDialog extends StatefulWidget {
  UpgradeDialog({Key key, this.info}) : super(key: key);
  final UpgradeInfo info;
  @override
  _UpgradeDialogState createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends State<UpgradeDialog> {
  Status status = Status.loading;

  Future<void> upgradeFire(BuildContext ctx, AppState state) async {
    final deviceSN = state.apis.deviceSN;
    final info = widget.info;
    try {
      final result = await state.cloud.req('upgradeCheckout', {
        'tag': info.tag,
        'deviceSN': deviceSN,
        'uuid': info.uuid,
      });
      debug('result', result);
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
          debug('isOnline: $isOnline');
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
    } catch (e) {
      debug(e);
      showSnackBar(ctx, 'Update Failed');
      if (this.mounted) {
        setState(() {
          status = Status.failed;
        });
      }
    }
  }

  void backtoStationList(BuildContext ctx) {
    Navigator.pushNamedAndRemoveUntil(
        ctx, '/deviceList', (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    String text = i18n('Updating Firmware');
    Widget icon = CircularProgressIndicator();
    bool showButton = false;
    switch (status) {
      case Status.loading:
        break;
      case Status.reboot:
        text = i18n('Device Rebooting');
        icon = CircularProgressIndicator();
        break;
      case Status.success:
        text = i18n('Update Firmware Success');
        icon = Icon(Icons.check, color: Colors.teal, size: 72);
        showButton = true;
        break;
      case Status.failed:
        text = i18n('Update Firmware Failed');
        icon = Icon(Icons.close, color: Colors.redAccent, size: 72);
        showButton = true;
        break;
      default:
        break;
    }
    return StoreConnector<AppState, AppState>(
      onInit: (store) => upgradeFire(context, store.state).catchError(debug),
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return SimpleDialog(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          children: <Widget>[
            Container(height: 16),
            Center(
              child: icon,
            ),
            Container(height: 16),
            Center(
              child: Text(text),
            ),
            Container(height: 16),
            showButton
                ? Row(
                    children: <Widget>[
                      Expanded(child: Container(), flex: 1),
                      Container(
                        padding: EdgeInsets.only(right: 8),
                        child: FlatButton(
                          onPressed: () => backtoStationList(context),
                          child: Text(
                            i18n('OK'),
                            style: TextStyle(color: Colors.teal),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(),
          ],
        );
      },
    );
  }
}
