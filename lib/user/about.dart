import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import './license.dart';
import '../common/utils.dart';
import '../icons/winas_icons.dart';

class About extends StatefulWidget {
  About({Key key}) : super(key: key);
  @override
  _AboutState createState() => _AboutState();
}

class _AboutState extends State<About> {
  String version = '';

  @override
  void initState() {
    super.initState();
    getAppVersion().then((value) {
      setState(() {
        version = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        backgroundColor: Colors.white10,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.black38),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(16),
            child: Text(
              i18n('App Version', {'version': version}),
              style: TextStyle(color: Colors.black87, fontSize: 21),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Container(
              width: 72,
              height: 72,
              // padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(Winas.logo, color: Colors.grey[50], size: 84),
            ),
          ),
          Container(height: 16),
          Container(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              i18n('App Description'),
              style: TextStyle(color: Colors.black54),
            ),
          ),
          Material(
            child: InkWell(
              onTap: () async {
                bool isIOS = !Platform.isAndroid;
                String url = isIOS
                    ? 'itms-apps://itunes.apple.com/cn/app/wisnuc/id1132191394?mt=8'
                    : 'https://www.aidingnan.com/download';
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  print('Could not launch $url');
                }
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(width: 1.0, color: Colors.grey[300]),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(i18n('Client Update')),
                      Expanded(child: Container()),
                      Text(
                        i18n('Check Latest'),
                        style: TextStyle(color: Colors.black54),
                      ),
                      Icon(Icons.chevron_right, color: Colors.black38)
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(height: 16),
          FlatButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (context) {
                      return Scaffold(
                        appBar: AppBar(
                          title: Text(i18n('User Agreement')),
                          elevation: 1.0,
                        ),
                        body: ListView(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.fromLTRB(8, 32, 8, 8),
                              child: Text(
                                i18n('User Agreement Title'),
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                license,
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ));
            },
            child: Text(
              i18n('User Agreement'),
              style: TextStyle(color: Colors.teal),
            ),
          )
        ],
      ),
    );
  }
}
