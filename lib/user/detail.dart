import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:fluwx/fluwx.dart' as fluwx;

import './weChat.dart';
import './avatarView.dart';
import './newNickName.dart';
import '../redux/redux.dart';
import '../common/utils.dart';

class Detail extends StatefulWidget {
  Detail({Key key}) : super(key: key);
  @override
  _DetailState createState() => _DetailState();
}

class _DetailState extends State<Detail> {
  @override
  bool isWeChatInstalled = false;

  void initState() {
    super.initState();
    _initFluwx().catchError(debug);
  }

  Future<void> _initFluwx() async {
    await fluwx.register(
      appId: "wx0aa672b8371cde8e",
      doOnAndroid: true,
      doOnIOS: true,
      enableMTA: false,
    );
    isWeChatInstalled = await fluwx.isWeChatInstalled();
    if (this.mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Account>(
        onInit: (store) => {},
        onDispose: (store) => {},
        converter: (store) => store.state.account,
        builder: (context, account) {
          if (!(account is Account)) return Container();
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
                    i18n('Personal Info'),
                    style: TextStyle(color: Colors.black87, fontSize: 21),
                  ),
                ),
                Container(height: 16),
                actionButton(
                  i18n('Avatar'),
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) {
                          return AvatarView(avatarUrl: account.avatarUrl);
                        },
                      ),
                    );
                  },
                  Row(
                    children: <Widget>[
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: account.avatarUrl == null
                              ? null
                              : Border.all(color: Colors.grey[400]),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(
                            Radius.circular(24),
                          ),
                          child: account.avatarUrl == null
                              ? Center(
                                  child: Icon(
                                    Icons.account_circle,
                                    color: Colors.blueGrey,
                                    size: 48,
                                  ),
                                )
                              : Image.network(
                                  account.avatarUrl,
                                ),
                        ),
                      ),
                      Container(width: 8),
                      Icon(Icons.chevron_right, color: Colors.black38),
                    ],
                  ),
                ),
                actionButton(
                  i18n('Nickname'),
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) {
                          return NewNickName(nickName: account.nickName);
                        },
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  Expanded(
                    flex: 10,
                    child: Row(
                      children: <Widget>[
                        ellipsisText(account.nickName,
                            style: TextStyle(color: Colors.black38)),
                        Container(width: 8),
                        Icon(Icons.chevron_right, color: Colors.black38),
                      ],
                    ),
                  ),
                ),
                actionButton(
                  i18n('Account Name'),
                  () => {},
                  Text(
                    account.username,
                    style: TextStyle(color: Colors.black38),
                  ),
                ),
                if (isWeChatInstalled == true)
                  actionButton(
                    i18n('WeChat'),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) {
                          return WeChat();
                        }),
                      );
                    },
                    Row(
                      children: <Widget>[
                        Text(
                          i18n('Detail'),
                          style: TextStyle(color: Colors.black38),
                        ),
                        Container(width: 8),
                        Icon(Icons.chevron_right, color: Colors.black38),
                      ],
                    ),
                  ),
              ],
            ),
          );
        });
  }
}
