import 'package:flutter/material.dart';

import '../common/utils.dart';

class BleHelp extends StatelessWidget {
  Widget row(String text, {isTitle = false}) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Text(
        text,
        style: TextStyle(fontSize: isTitle ? 20 : 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        backgroundColor: Colors.white10,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.black38),
        title: Text(
          i18n('Help of BLE'),
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: ListView(
        children: <Widget>[
          row(i18n('BLE No Results Title'), isTitle: true),
          row(i18n('BLE No Results Reason 1')),
          row(i18n('BLE No Results Reason 2')),
          row(i18n('BLE No Results Reason 3')),
          row(i18n('BLE No Results Reason 4')),
        ],
      ),
    );
  }
}
