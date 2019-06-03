import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../photos/backup.dart';
import '../common/utils.dart';

class Settings extends StatefulWidget {
  Settings({Key key, this.backupWorker}) : super(key: key);
  final BackupWorker backupWorker;
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Store>(
        onInit: (store) => {},
        onDispose: (store) => {},
        converter: (store) => store,
        builder: (context, store) {
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
                    '设置',
                    style: TextStyle(color: Colors.black87, fontSize: 21),
                  ),
                ),
                Container(height: 16),
                actionButton(
                  '自动备份照片',
                  () {},
                  Switch(
                    activeColor: Colors.teal,
                    value: store.state.config.autoBackup == true,
                    onChanged: (value) {
                      store.dispatch(UpdateConfigAction(
                        Config.combine(
                          store.state.config,
                          Config(autoBackup: value),
                        ),
                      ));
                      if (value == true) {
                        widget.backupWorker.start();
                      } else {
                        widget.backupWorker.abort();
                      }
                    },
                  ),
                ),
                actionButton(
                  '允许使用移动数据流量备份照片',
                  () {},
                  Switch(
                    activeColor: Colors.teal,
                    value: store.state.config.cellularBackup == true,
                    onChanged: (value) {
                      store.dispatch(UpdateConfigAction(
                        Config.combine(
                          store.state.config,
                          Config(cellularBackup: value),
                        ),
                      ));

                      // update backupWorker setting
                      widget.backupWorker.updateConfig(
                          shouldBackupViaCellular: value,
                          autoBackup: store.state.config.autoBackup);
                    },
                  ),
                ),
                actionButton(
                  '允许使用移动数据流量传输文件',
                  () {},
                  Switch(
                    activeColor: Colors.teal,
                    value: store.state.config.cellularTransfer == true,
                    onChanged: (value) {
                      store.dispatch(UpdateConfigAction(
                        Config.combine(
                          store.state.config,
                          Config(cellularTransfer: value),
                        ),
                      ));
                    },
                  ),
                ),
                actionButton(
                  '语言',
                  () => {},
                  Text('中文'),
                ),
              ],
            ),
          );
        });
  }
}
