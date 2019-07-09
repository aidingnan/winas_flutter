import 'dart:ui' as ui;
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../photos/backup.dart';

class Settings extends StatefulWidget {
  Settings({Key key, this.backupWorker, this.toggleBackup}) : super(key: key);
  final BackupWorker backupWorker;
  final Function toggleBackup;
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
    return StoreConnector<AppState, Store<AppState>>(
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
                  i18n('Settings'),
                  style: TextStyle(color: Colors.black87, fontSize: 21),
                ),
              ),
              Container(height: 16),
              actionButton(
                i18n('Backup Photos'),
                () {},
                Switch(
                  activeColor: Colors.teal,
                  value: store.state.config.autoBackup == true,
                  onChanged: (bool value) =>
                      widget.toggleBackup(context, store, value),
                ),
              ),
              actionButton(
                i18n('All Mobile Data to Backup Photos'),
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
                      autoBackup: store.state.config.autoBackup,
                    );
                  },
                ),
              ),
              actionButton(
                i18n('All Mobile Data to Transfer Files'),
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
                i18n('Language'),
                () {
                  showModalBottomSheet(
                    context: context,
                    builder: (BuildContext c) {
                      return SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Material(
                              child: InkWell(
                                onTap: () async {
                                  String code = ui.window.locale.languageCode;
                                  if (code == 'en') {
                                    await i18nRefresh(Locale('en'));
                                  } else {
                                    await i18nRefresh(Locale('zh'));
                                  }

                                  await i18nRefresh(getCurrentLocale());
                                  print('>>>>>>>>>>>>>>>>>>>>>>>> $code');
                                  store.dispatch(UpdateConfigAction(
                                    Config.combine(
                                      store.state.config,
                                      Config(language: 'auto'),
                                    ),
                                  ));
                                  Navigator.pop(c);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(i18n('System Default Language')),
                                ),
                              ),
                            ),
                            Material(
                              child: InkWell(
                                onTap: () async {
                                  await i18nRefresh(Locale('zh'));

                                  store.dispatch(UpdateConfigAction(
                                    Config.combine(
                                      store.state.config,
                                      Config(language: 'zh'),
                                    ),
                                  ));
                                  Navigator.pop(c);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text('中文'),
                                ),
                              ),
                            ),
                            Material(
                              child: InkWell(
                                onTap: () async {
                                  await i18nRefresh(Locale('en'));
                                  store.dispatch(UpdateConfigAction(
                                    Config.combine(
                                      store.state.config,
                                      Config(language: 'en'),
                                    ),
                                  ));
                                  Navigator.pop(c);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text('English'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                Text(
                  store.state.config.language == 'auto'
                      ? i18n('System Default Language')
                      : i18n('Current Language'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
