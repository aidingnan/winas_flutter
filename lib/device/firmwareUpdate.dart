import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './info.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../icons/winas_icons.dart';
import '../login/stationLogin.dart';
import '../common/appBarSlivers.dart';

class Firmware extends StatefulWidget {
  Firmware({Key key}) : super(key: key);
  @override
  _FirmwareState createState() => _FirmwareState();
}

class _FirmwareState extends State<Firmware> {
  UpgradeInfo info;
  bool failed = false;
  bool loading = true;
  bool latest = false;
  ScrollController myScrollController = ScrollController();

  /// left padding of appbar
  double paddingLeft = 16;

  /// scrollController's listener to get offset
  void listener() {
    setState(() {
      paddingLeft = (myScrollController.offset * 1.25).clamp(16.0, 72.0);
    });
  }

  Future<void> getUpgradeInfo(AppState state) async {
    try {
      final res = await state.cloud.req(
        'upgradeInfo',
        {'deviceSN': state.apis.deviceSN},
      );
      if (res?.data is List && res.data.length > 0) {
        List<UpgradeInfo> list =
            List.from(res.data.map((m) => UpgradeInfo.fromMap(m)));

        info = list.firstWhere((l) => l.downloaded == true, orElse: () => null);
        if (info?.downloaded != true) {
          latest = true;
        }
      } else {
        latest = true;
      }
    } catch (e) {
      debug(e);
      failed = true;
    }

    loading = false;
    if (this.mounted) {
      setState(() {});
    }
  }

  Future<void> pollingInfo(AppState state, int timeout) async {}

  Future<void> upgradeFire(BuildContext ctx, AppState state) async {
    final model = Model();
    final deviceSN = state.apis.deviceSN;

    showNormalDialog(
      context: context,
      text: i18n('Updating Firmware'),
      model: model,
    );
    try {
      final result = await state.cloud.req('upgrade', {
        'version': info.tag,
        'deviceSN': deviceSN,
      });
      debug('result', result);
      int now = DateTime.now().millisecondsSinceEpoch;
      // wait upgrade state to 'Finished'
      bool finished = false;
      while (finished != true) {
        final current = DateTime.now().millisecondsSinceEpoch;

        if (current - now > 180000) {
          throw 'Timeout of 180 seconds for upgrade to state Finished';
        }

        await Future.delayed(Duration(seconds: 2));

        try {
          final res = await state.cloud.req('info', {
            'deviceSN': deviceSN,
          });

          debug(res.data['upgrade']['state']);
          if (res.data['upgrade']['state'] == 'Finished') {
            finished = true;
          }
        } catch (e) {
          debug(e);
          if (e is DioError) {
            debug(e.response.data);
          }
        }
      }

      debug('rebooting');
      // reboot
      await state.cloud.req('reboot', {
        'deviceSN': deviceSN,
      });

      // wait reboot
      now = DateTime.now().millisecondsSinceEpoch;
      bool isOnline = false;

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
          debug('isOnline', isOnline);
        } catch (e) {
          debug(e);
        }

        await Future.delayed(Duration(seconds: 2));

        model.close = true;
        Navigator.pushNamedAndRemoveUntil(
            ctx, '/deviceList', (Route<dynamic> route) => false);
      }
    } catch (e) {
      debug(e);
    }

    model.close = true;
    Navigator.pop(ctx);
  }

  @override
  void initState() {
    myScrollController.addListener(listener);
    super.initState();
  }

  @override
  void dispose() {
    myScrollController.removeListener(listener);
    super.dispose();
  }

  Widget renderText(String text) {
    return SliverToBoxAdapter(
      child: Container(
        height: 64,
        child: Center(
          child: Text(text),
        ),
      ),
    );
  }

  List<Widget> actions(AppState state) {
    return [
      IconButton(
        icon: Icon(Icons.refresh),
        onPressed: () {
          setState(() {
            loading = true;
          });
          getUpgradeInfo(state);
        },
      )
    ];
  }

  List<Widget> getSlivers(AppState state) {
    final String titleName = i18n('Firmware Update');
    // title
    List<Widget> slivers =
        appBarSlivers(paddingLeft, titleName, action: actions(state));
    if (loading) {
      // loading
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            height: 144,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
      slivers.add(renderText(i18n('Getting Firmware Info')));
    } else if (latest) {
      // latest
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            height: 144,
            child: Center(
                child: Icon(
              Icons.check,
              color: Colors.green,
              size: 72,
            )),
          ),
        ),
      );
      slivers.add(renderText(i18n('Firmware Already Latest')));
    } else if (failed) {
      // failed
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            height: 144,
            child: Center(
                child: Icon(
              Icons.close,
              color: Colors.redAccent,
              size: 72,
            )),
          ),
        ),
      );

      slivers.add(renderText(i18n('Get Firmware Info Error')));
    } else {
      // actions
      slivers.addAll([
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Icon(Winas.logo, color: Colors.grey[50], size: 84),
                ),
                Container(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Winas ${info.tag}',
                      style: TextStyle(fontSize: 18),
                    ),
                    Container(height: 4),
                    Text('Aidingnan Inc.'),
                    Container(height: 4),
                    Text(info.createdAt.substring(0, 10)),
                  ],
                )
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            children: <Widget>[
              Container(
                width: MediaQuery.of(context).size.width,
                padding: EdgeInsets.all(16),
                child: Text(info.desc),
              )
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            children: <Widget>[
              Builder(builder: (BuildContext ctx) {
                // TODO: firmware update
                return FlatButton(
                  onPressed: () => upgradeFire(ctx, state),
                  child: Text(
                    i18n('Update Firmware Now'),
                    style: TextStyle(color: Colors.teal),
                  ),
                );
              }),
            ],
          ),
        ),
      ]);
    }
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => getUpgradeInfo(store.state),
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return Scaffold(
          body: CustomScrollView(
            controller: myScrollController,
            slivers: getSlivers(state),
          ),
        );
      },
    );
  }
}
