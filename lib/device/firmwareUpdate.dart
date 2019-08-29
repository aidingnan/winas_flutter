import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './info.dart';
import './upgradeDialog.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../icons/winas_icons.dart';
import '../common/appBarSlivers.dart';

/// 1.2.3 > 1.0.4 => true
bool versionCompare(String a, String b) {
  List<int> listA = List.from(a.split('.').map((i) => int.parse(i)));
  List<int> listB = List.from(b.split('.').map((i) => int.parse(i)));
  if (listA[0] > listB[0]) {
    return true;
  } else if (listA[0] < listB[0]) {
    return false;
  }

  if (listA[1] > listB[1]) {
    return true;
  } else if (listA[1] < listB[1]) {
    return false;
  }

  if (listA[2] > listB[2]) {
    return true;
  }
  return false;
}

class Firmware extends StatefulWidget {
  Firmware({Key key}) : super(key: key);
  @override
  _FirmwareState createState() => _FirmwareState();
}

class _FirmwareState extends State<Firmware> {
  UpgradeInfo info;
  bool failed = false;
  bool loading = true;
  bool downloading = false;
  bool downloaded = false;
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
      final res = await state.cloud.req('upgradeList', null);

      final local = await state.cloud.req(
        'upgradeInfo',
        {'deviceSN': state.apis.deviceSN},
      );

      // debug('local $local');

      final currentVersion = local.data['current']['version'];
      // debug('currentVersion $currentVersion');
      if (res?.data is List && res.data.length > 0) {
        List<UpgradeInfo> list =
            List.from(res.data.map((m) => UpgradeInfo.fromMap(m)));

        // sort by version
        list.sort((UpgradeInfo a, UpgradeInfo b) {
          if (versionCompare(b.tag, a.tag) == true) {
            return 1;
          }
          return -1;
        });

        // find newer version
        info = list.firstWhere(
            (l) => versionCompare(l.tag, currentVersion) == true,
            orElse: () => null);

        // TODO: Fake update
        // info = list.last;

        if (info != null) {
          debug('find newer version, tag: ${info.tag}');
          List roots = List.from(local.data['roots']);
          final downloadedVersion = roots
              .firstWhere((r) => r['version'] == info.tag, orElse: () => null);
          String uuid =
              downloadedVersion != null ? downloadedVersion['uuid'] : null;
          if (uuid != null) {
            info.addUUID(uuid);
            downloaded = true;
          } else {
            // TODO: new version not download
            downloaded = false;
            debug('new version not download');
            try {
              final winasdInfo = await state.cloud.req(
                'info',
                {'deviceSN': state.apis.deviceSN},
              );
              final downloadData = winasdInfo.data['upgrade']['download'];
              downloading =
                  downloadData != null && downloadData['state'] != 'Failed';
            } catch (e) {
              debug(e);
            }
            // latest = true;
          }
        } else {
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

  Future<void> downloadUpgrade(BuildContext ctx, AppState state) async {
    try {
      final deviceSN = state.apis.deviceSN;
      final result = await state.cloud.req('upgradeDownload', {
        'tag': info.tag,
        'deviceSN': deviceSN,
      });

      debug('result', result);
      showSnackBar(ctx, i18n('Download Started Text', {'tag': info.tag}));
      setState(() {
        downloading = true;
      });
    } catch (e) {
      debug(e);
    }
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
        if (!downloaded)
          SliverToBoxAdapter(
            child: Row(
              children: <Widget>[
                Builder(builder: (BuildContext ctx) {
                  if (!downloading) {
                    return FlatButton(
                      onPressed: () => downloadUpgrade(ctx, state),
                      child: Text(
                        i18n('Download'),
                        style: TextStyle(color: Colors.teal),
                      ),
                    );
                  }
                  return Container(
                    margin: EdgeInsets.all(16),
                    child: Text(
                      i18n('Downloading'),
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }),
              ],
            ),
          )
        else
          SliverToBoxAdapter(
            child: Row(
              children: <Widget>[
                Builder(builder: (BuildContext ctx) {
                  return FlatButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) => WillPopScope(
                          onWillPop: () => Future.value(false),
                          child: UpgradeDialog(info: info),
                        ),
                      ).catchError(debug);
                    },
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
