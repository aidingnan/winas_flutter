import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './info.dart';
import '../common/utils.dart';
import '../redux/redux.dart';
import '../icons/winas_icons.dart';
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
  bool lastest = true;
  bool notLAN = false;
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
    final isLAN = await state.apis.testLAN();
    if (isLAN) {
      print('isLAN $isLAN');
      try {
        final res = await state.apis.upgradeInfo();
        if (res?.data is List && res.data.length > 0) {
          print(res.data);
          info = UpgradeInfo.fromMap(res.data[0]);
        } else {
          lastest = true;
        }
      } catch (e) {
        failed = true;
      }
    } else {
      notLAN = true;
    }
    loading = false;
    if (this.mounted) {
      setState(() {});
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
        height: 256,
        child: Center(
          child: Text(text),
        ),
      ),
    );
  }

  List<Widget> getSlivers() {
    final String titleName = i18n('Firmware Update');
    // title
    List<Widget> slivers = appBarSlivers(paddingLeft, titleName);
    if (loading) {
      // loading
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            height: 160,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            height: 120,
            child: Center(
              child: Text(i18n('Getting Firmware Info')),
            ),
          ),
        ),
      );
    } else if (!lastest) {
      // lastest
      slivers.add(renderText(i18n('Firmware Already Latest')));
    } else if (failed) {
      // failed
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
                    Text(info.tag.substring(0, 9)),
                    Container(height: 4),
                    Text(info.desc),
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
                child: Text(
                  'Winas 1.1.2: Bugs fixed.',
                ),
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
                  onPressed: () async {
                    final model = Model();
                    showNormalDialog(
                      context: context,
                      text: i18n('Updating Firmware'),
                      model: model,
                    );
                    await Future.delayed(Duration(seconds: 3));
                    model.close = true;
                    // Navigator.pushNamedAndRemoveUntil(
                    //     ctx, '/deviceList', (Route<dynamic> route) => false);
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
            slivers: getSlivers(),
          ),
        );
      },
    );
  }
}
