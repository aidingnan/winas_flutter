import 'dart:io';
import 'dart:async';
import 'package:redux/redux.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_redux/flutter_redux.dart';
import 'package:outline_material_icons/outline_material_icons.dart';

import '../user/user.dart';
import '../files/file.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../files/fileRow.dart';
import '../photos/backup.dart';
import '../common/intent.dart';
import '../photos/photos.dart';
import '../common/eventBus.dart';
import '../transfer/manager.dart';
import '../files/backupView.dart';
import '../device/myStation.dart';
import '../transfer/transfer.dart';
import '../files/tokenExpired.dart';
import '../files/deviceNotOnline.dart';

class NavigationIconView {
  NavigationIconView({
    Widget icon,
    Widget activeIcon,
    Function view,
    String title,
    String nav,
    Color color,
  })  : view = view,
        item = BottomNavigationBarItem(
          icon: icon,
          activeIcon: activeIcon,
          title: Text(title),
          backgroundColor: color,
        );

  final Function view;
  final BottomNavigationBarItem item;
}

List<FileNavView> get fileNavViews => [
      FileNavView(
        icon: Icon(Icons.people, color: Colors.white),
        title: i18n('Public Drive'),
        nav: 'public',
        color: Colors.orange,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return Files(
                node: Node(
                  name: i18n('Public Drive'),
                  tag: 'built-in',
                  location: 'built-in',
                ),
              );
            },
          ),
        ),
      ),
      FileNavView(
        icon: Icon(Icons.refresh, color: Colors.white),
        title: i18n('Backup Drive'),
        nav: 'backup',
        color: Colors.blue,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BackupView(),
          ),
        ),
      ),
      FileNavView(
        icon: Icon(Icons.swap_vert, color: Colors.white),
        title: i18n('Transfer'),
        nav: 'transfer',
        color: Colors.purple,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Transfer(),
          ),
        ),
      ),
    ];

class BottomNavigation extends StatefulWidget {
  @override
  _BottomNavigationState createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  BottomNavigationBarType _type = BottomNavigationBarType.fixed;
  BackupWorker backupWorker;
  StreamSubscription<String> intentListener;
  StreamSubscription<TokenExpiredEvent> tokenExpiredListener;
  StreamSubscription<StationNotOnlineEvent> stationNotOnlineListener;

  /// Timer to refresh token
  Timer refreshTimer;

  /// only refresh token at first just once (in `../files/file.dart`)
  Justonce justonce = Justonce();

  Future<void> refreshAndSaveToken(Store<AppState> store) async {
    String clientId = await getClientId();
    final res =
        await store.state.cloud.req('refreshToken', {'clientId': clientId});
    if (res?.data != null && res.data['token'] != null) {
      store.state.apis
          .updateToken(store.state.cloud.token, store.state.cloud.cookie);

      /// update apis in backup apis
      if (backupWorker?.apis != null) {
        backupWorker.apis
            .updateToken(store.state.cloud.token, store.state.cloud.cookie);
      }
      // cloud apis
      store.dispatch(UpdateCloudAction(store.state.cloud));

      // stations apis
      store.dispatch(UpdateApisAction(store.state.apis));

      debug('refreshAndSaveToken success');
    }
  }

  void toggleBackup(BuildContext ctx, Store<AppState> store, bool value) async {
    final loadingInstance = showLoading(context);
    try {
      final data = await getMachineId();
      final deviceName = data['deviceName'];
      final machineId = data['machineId'];
      debug('deviceName $deviceName, machineId $machineId');
      final res = await store.state.apis.req('drives', null);
      // get current drives data
      List<Drive> drives = List.from(
        res.data.map((drive) => Drive.fromMap(drive)),
      );

      Drive backupDrive = drives.firstWhere(
        (d) =>
            d?.client?.id == machineId ||
            (d?.client?.idList is List && d.client.idList.contains(machineId)),
        orElse: () => null,
      );

      // not find backupDrive
      // 1. create new
      // 2. choose one oldDrive with same name

      if (backupDrive == null && value == true) {
        // check exist drive with same label
        Drive sameLabelDrive = drives.firstWhere(
          (d) => d.label == deviceName,
          orElse: () => null,
        );

        if (sameLabelDrive != null) {
          final success = await showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (BuildContext context) => WillPopScope(
              onWillPop: () => Future.value(false),
              child: AlertDialog(
                content: Text(
                  i18n(
                    'Preivous Backup Detected',
                    {'deviceName': deviceName},
                  ),
                ),
                actions: <Widget>[
                  FlatButton(
                    textColor: Theme.of(context).primaryColor,
                    child: Text(i18n('Use New Backup')),
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                  ),
                  FlatButton(
                    textColor: Theme.of(context).primaryColor,
                    child: Text(
                      i18n(
                        'Use Previous Backup',
                        {'deviceName': deviceName},
                      ),
                    ),
                    onPressed: () async {
                      AppState state = store.state;

                      try {
                        final res = await state.apis.req(
                          'drive',
                          {'uuid': sameLabelDrive.uuid},
                        );
                        final client = res.data['client'];
                        List idList = client['idList'] ?? [client['id']];
                        idList.add(machineId);
                        final props = {
                          'op': 'backup',
                          'client': {
                            'status': 'Idle',
                            'lastBackupTime': client['lastBackupTime'],
                            'id': client['id'],
                            'idList': idList,
                            'disabled': false,
                            'type': client['type'],
                          }
                        };

                        await state.apis.req('updateDrive', {
                          'uuid': sameLabelDrive.uuid,
                          'props': props,
                        });
                      } catch (e) {
                        debug(e);
                        Navigator.pop(context, false);
                        return;
                      }
                      Navigator.pop(context, true);
                    },
                  )
                ],
              ),
            ),
          );
          if (success == false) {
            throw 'update backup drive id list failed';
          }
        }
      }
    } catch (e) {
      debug(e);
      loadingInstance.close();
      showSnackBar(context, i18n('Toggle Backup Failed'));
      return;
    }

    loadingInstance.close();

    store.dispatch(UpdateConfigAction(
      Config.combine(
        store.state.config,
        Config(autoBackup: value),
      ),
    ));

    if (value == true) {
      backupWorker.start();
    } else {
      backupWorker.abort();
    }
  }

  /// init works onStart:
  /// 1. autoBackup
  /// 2. add intent Listener
  /// 3. refresh token
  void initWorks(Store<AppState> store) {
    final state = store.state;
    backupWorker = BackupWorker(state.apis, state.config.cellularBackup);

    // start autoBackup
    if (state.config.autoBackup == true) {
      backupWorker.start();
    }
    // add listener of new intent
    intentListener = Intent.listenToOnNewIntent().listen((filePath) {
      debug('newIntent: $filePath');
      if (filePath != null) {
        final cm = TransferManager.getInstance();
        cm.newUploadSharedFile(filePath, state);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Transfer(),
          ),
        );
      }
    });

    // refresh token every 2 hour
    refreshTimer = Timer.periodic(Duration(hours: 2), (Timer timer) {
      if (this.mounted) {
        refreshAndSaveToken(store).catchError(debug);
      } else {
        timer.cancel();
      }
    });

    justonce.callback = refreshAndSaveToken;
  }

  @override
  void initState() {
    super.initState();

    /// cache context for i18n
    cacheContext(this.context);

    // add tokenExpiredListener (asynchronous)
    tokenExpiredListener = eventBus.on<TokenExpiredEvent>().listen((event) {
      debug('TokenExpiredEvent ${event.text}');
      showDialog(
        context: context,
        builder: (_) => TokenExpired(),
      );
      // only listen once, cancel listener
      tokenExpiredListener.cancel();
      tokenExpiredListener = null;
    });

    // add tokenExpiredListener (asynchronous)
    stationNotOnlineListener =
        eventBus.on<StationNotOnlineEvent>().listen((event) {
      debug('StationNotOnlineEvent ${event.text}');
      showDialog(
        context: context,
        builder: (_) => DeviceNotOnline(),
      );
      // only listen once, cancel listener
      stationNotOnlineListener.cancel();
      stationNotOnlineListener = null;
    });

    cacheContext(context);
  }

  @override
  void dispose() {
    super.dispose();
    backupWorker?.abort();
    refreshTimer?.cancel();
    intentListener?.cancel();
    tokenExpiredListener?.cancel();
    stationNotOnlineListener?.cancel();
  }

  BottomNavigationBar get _botNavBar => BottomNavigationBar(
        items: _navigationViews
            .map<BottomNavigationBarItem>(
                (NavigationIconView navigationView) => navigationView.item)
            .toList(),
        currentIndex: _currentIndex,
        type: _type,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
      );

  List<NavigationIconView> get _navigationViews => <NavigationIconView>[
        NavigationIconView(
          icon: Icon(Icons.folder_open),
          activeIcon: Icon(Icons.folder),
          title: i18n('My Drive'),
          nav: 'files',
          view: () => Files(
            node: Node(tag: 'home', location: 'home'),
            fileNavViews: fileNavViews,
            justonce: justonce,
          ),
          color: Colors.teal,
        ),
        NavigationIconView(
          activeIcon: Icon(Icons.photo_library),
          icon: Icon(OMIcons.photoLibrary),
          title: i18n('Album'),
          nav: 'photos',
          view: () =>
              Photos(backupWorker: backupWorker, toggleBackup: toggleBackup),
          color: Colors.indigo,
        ),
        NavigationIconView(
          activeIcon: Icon(Icons.router),
          icon: Icon(OMIcons.router),
          title: i18n('Device'),
          nav: 'device',
          view: () => MyStation(),
          color: Colors.deepPurple,
        ),
        NavigationIconView(
          activeIcon: Icon(Icons.person),
          icon: Icon(Icons.person_outline),
          title: i18n('Me'),
          nav: 'user',
          view: () => AccountInfo(
              backupWorker: backupWorker, toggleBackup: toggleBackup),
          color: Colors.deepOrange,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    // set SystemUiStyle to dark
    if (Platform.isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    }

    return StoreConnector<AppState, AppState>(
      onInit: (store) => initWorks(store),
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (ctx, state) {
        // Future.delayed(Duration.zero, () => checkTokenState(ctx, state));
        return Scaffold(
          body: Center(child: _navigationViews[_currentIndex].view()),
          bottomNavigationBar: _botNavBar,
        );
      },
    );
  }
}
