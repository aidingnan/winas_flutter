import 'dart:ui' as ui;
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../photos/backup.dart';
// import '../common/appConfig.dart';

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
        final stationConfig =
            store.state.config.getStationConfigs(store.state.apis.deviceSN);

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
                                onTap: () {
                                  Navigator.pop(c);
                                  store.dispatch(
                                    UpdateConfigAction(
                                      store.state.config
                                        ..setStationConfig(
                                          store.state.apis.deviceSN,
                                          StationConfig(
                                            deviceSN: store.state.apis.deviceSN,
                                            cellularBackup: true,
                                            autoBackup: true,
                                          ),
                                        ),
                                    ),
                                  );
                                  // update backupWorker setting
                                  widget.backupWorker.updateConfig(
                                    shouldBackupViaCellular: true,
                                    autoBackup: true,
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(i18n('Both Wi-Fi and Cellular')),
                                ),
                              ),
                            ),
                            Material(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(c);
                                  store.dispatch(
                                    UpdateConfigAction(
                                      store.state.config
                                        ..setStationConfig(
                                          store.state.apis.deviceSN,
                                          StationConfig(
                                            deviceSN: store.state.apis.deviceSN,
                                            cellularBackup: false,
                                            autoBackup: true,
                                          ),
                                        ),
                                    ),
                                  );
                                  // update backupWorker setting
                                  widget.backupWorker.updateConfig(
                                    shouldBackupViaCellular: false,
                                    autoBackup: true,
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(i18n('Only Wi-Fi')),
                                ),
                              ),
                            ),
                            Material(
                              child: InkWell(
                                onTap: () async {
                                  Navigator.pop(c);
                                  store.dispatch(
                                    UpdateConfigAction(
                                      store.state.config
                                        ..setStationConfig(
                                          store.state.apis.deviceSN,
                                          StationConfig(
                                            deviceSN: store.state.apis.deviceSN,
                                            cellularBackup: false,
                                            autoBackup: false,
                                          ),
                                        ),
                                    ),
                                  );
                                  await widget.toggleBackup(
                                    context,
                                    store,
                                    false,
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(i18n('Close')),
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
                  stationConfig?.autoBackup == true &&
                          stationConfig?.cellularBackup == true
                      ? i18n('Both Wi-Fi and Cellular')
                      : stationConfig?.autoBackup == true
                          ? i18n('Only Wi-Fi')
                          : i18n('Close'),
                ),
              ),
              actionButton(
                i18n('Transfer Files'),
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
                                onTap: () {
                                  Navigator.pop(c);
                                  store.dispatch(
                                    UpdateConfigAction(
                                      store.state.config
                                        ..setStationConfig(
                                          store.state.apis.deviceSN,
                                          StationConfig(
                                            deviceSN: store.state.apis.deviceSN,
                                            cellularTransfer: true,
                                          ),
                                        ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(i18n('Both Wi-Fi and Cellular')),
                                ),
                              ),
                            ),
                            Material(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(c);
                                  store.dispatch(
                                    UpdateConfigAction(
                                      store.state.config
                                        ..setStationConfig(
                                          store.state.apis.deviceSN,
                                          StationConfig(
                                            deviceSN: store.state.apis.deviceSN,
                                            cellularTransfer: false,
                                          ),
                                        ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(i18n('Only Wi-Fi')),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                Text(stationConfig?.cellularTransfer == true
                    ? i18n('Both Wi-Fi and Cellular')
                    : i18n('Only Wi-Fi')),
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
              // actionButton(
              //   i18n('User Experience Improvement Program'),
              //   () {
              //     showModalBottomSheet(
              //       context: context,
              //       builder: (BuildContext c) {
              //         return SafeArea(
              //           child: Column(
              //             crossAxisAlignment: CrossAxisAlignment.start,
              //             mainAxisSize: MainAxisSize.min,
              //             children: <Widget>[
              //               Material(
              //                 child: InkWell(
              //                   onTap: () {
              //                     Navigator.pop(c);
              //                     store.dispatch(
              //                       UpdateConfigAction(
              //                         Config.combine(
              //                           store.state.config,
              //                           Config(umeng: true),
              //                         ),
              //                       ),
              //                     );
              //                     AppConfig.umeng = true;
              //                   },
              //                   child: Container(
              //                     width: double.infinity,
              //                     padding: EdgeInsets.all(16),
              //                     child: Text(i18n('Join')),
              //                   ),
              //                 ),
              //               ),
              //               Material(
              //                 child: InkWell(
              //                   onTap: () {
              //                     Navigator.pop(c);
              //                     store.dispatch(
              //                       UpdateConfigAction(
              //                         Config.combine(
              //                           store.state.config,
              //                           Config(umeng: false),
              //                         ),
              //                       ),
              //                     );
              //                     AppConfig.umeng = false;
              //                   },
              //                   child: Container(
              //                     width: double.infinity,
              //                     padding: EdgeInsets.all(16),
              //                     child: Text(i18n('Do not join')),
              //                   ),
              //                 ),
              //               ),
              //             ],
              //           ),
              //         );
              //       },
              //     );
              //   },
              //   Text(AppConfig.umeng == false
              //       ? i18n('Do not join')
              //       : i18n('Join')),
              // ),
            ],
          ),
        );
      },
    );
  }
}
