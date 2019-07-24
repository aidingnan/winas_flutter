import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter/material.dart';

import './about.dart';
import './detail.dart';
import './security.dart';
import './settings.dart';
import '../redux/redux.dart';
import '../common/cache.dart';
import '../common/utils.dart';
import '../photos/backup.dart';

class AccountInfo extends StatefulWidget {
  AccountInfo({Key key, this.backupWorker, this.toggleBackup})
      : super(key: key);
  final BackupWorker backupWorker;
  final Function toggleBackup;
  @override
  _AccountInfoState createState() => new _AccountInfoState();
}

class _AccountInfoState extends State<AccountInfo> {
  int cacheSize;
  String version = '';
  Future getCacheSize() async {
    final cm = await CacheManager.getInstance();
    var size = await cm.getCacheSize();
    if (this.mounted) {
      setState(() {
        cacheSize = size;
      });
    }
  }

  Future clearCache(BuildContext ctx) async {
    final cm = await CacheManager.getInstance();
    await cm.clearCache();
    await getCacheSize();
    Navigator.pop(ctx);
  }

  @override
  void initState() {
    super.initState();
    // cache
    getCacheSize();

    // app version
    getAppVersion().then((value) {
      setState(() {
        version = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Account>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store.state.account,
      builder: (context, account) {
        if (account == null) return Container();
        return Scaffold(
          appBar: AppBar(
            elevation: 0.0, // no shadow
            backgroundColor: Colors.white10,
            brightness: Brightness.light,
          ),
          body: Container(
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      return Detail();
                    }),
                  ),
                  child: Container(
                    height: 72,
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 10,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.nickName,
                                style: TextStyle(fontSize: 28),
                                textAlign: TextAlign.start,
                                overflow: TextOverflow.fade,
                                maxLines: 1,
                              ),
                              Text(
                                i18n('Account Detail'),
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.start,
                                overflow: TextOverflow.fade,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(),
                          flex: 1,
                        ),
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: account.avatarUrl == null
                                ? null
                                : Border.all(color: Colors.grey[400]),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(
                              Radius.circular(28),
                            ),
                            child: account.avatarUrl == null
                                ? Center(
                                    child: Icon(
                                      Icons.account_circle,
                                      color: Colors.blueGrey,
                                      size: 56,
                                    ),
                                  )
                                : Image.network(
                                    account.avatarUrl,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 16),
                actionButton(
                  i18n('Account And Security'),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return Security();
                      },
                      settings: RouteSettings(name: 'security'),
                    ),
                  ),
                  null,
                ),
                actionButton(
                  i18n('Settings'),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Settings(
                        backupWorker: widget.backupWorker,
                        toggleBackup: widget.toggleBackup,
                      ),
                      settings: RouteSettings(name: 'settings'),
                    ),
                  ),
                  null,
                ),
                actionButton(
                  i18n('Clean Cache'),
                  () async {
                    await showDialog(
                      context: this.context,
                      builder: (BuildContext context) => AlertDialog(
                        title: Text(i18n('Clean Cache')),
                        content: Text(i18n('Clean Cache Text')),
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
                            onPressed: () => clearCache(context),
                          )
                        ],
                      ),
                    );
                  },
                  Text(cacheSize != null ? prettySize(cacheSize) : ''),
                ),
                actionButton(
                  i18n('About'),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      return About();
                    }),
                  ),
                  Row(
                    children: <Widget>[
                      Text(i18n('Client Version', {'version': version})),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                actionButton(
                  'Log',
                  () async {
                    String logs = await getLogs();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) {
                        return Scaffold(
                          body: ListView(
                            children: <Widget>[
                              Container(
                                padding: EdgeInsets.all(8),
                                child: Text(logs),
                              )
                            ],
                          ),
                        );
                      }),
                    );
                  },
                  null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
