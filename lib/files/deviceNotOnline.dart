import 'package:flutter/material.dart';

import '../common/utils.dart';

class DeviceNotOnline extends StatelessWidget {
  DeviceNotOnline({Key key}) : super(key: key);
  final Model model = Model();
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => Future.value(model.shouldClose),
      child: AlertDialog(
        title: Text(i18n('Device Not Online Title')),
        content: Text(i18n('Device Not Online Text')),
        actions: <Widget>[
          FlatButton(
            textColor: Theme.of(context).primaryColor,
            child: Text(i18n('Confirm')),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/deviceList', (Route<dynamic> route) => false);
            },
          )
        ],
      ),
    );
  }
}
