import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './info.dart';
import './rootDialog.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/appBarSlivers.dart';

Widget _ellipsisText(String text) {
  return ellipsisText(text, style: TextStyle(color: Colors.black38));
}

class DeviceInfo extends StatefulWidget {
  DeviceInfo({Key key}) : super(key: key);
  @override
  _DeviceInfoState createState() => _DeviceInfoState();
}

class _DeviceInfoState extends State<DeviceInfo> {
  Info info;
  bool loading = true;
  bool failed = false;
  ScrollController myScrollController = ScrollController();

  /// left padding of appbar
  double paddingLeft = 16;

  /// cheats to open root dialog
  int count = 0;

  Future<void> onCheat(BuildContext ctx) async {
    count += 1;
    if (count > 7) {
      debug('onCheat: click 7 times');
      count = 0;
      bool success = await showDialog(
        context: context,
        builder: (BuildContext context) => RootDialog(),
      );
      debug('root result $success');
      if (success == true) {
        showSnackBar(ctx, i18n('Device Root Success'));
      } else if (success == false) {
        showSnackBar(ctx, i18n('Device Root Failed'));
      }
    }
  }

  /// scrollController's listener to get offset
  void listener() {
    setState(() {
      paddingLeft = (myScrollController.offset * 1.25).clamp(16.0, 72.0);
    });
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

  void refresh(AppState state) async {
    try {
      final res = await state.apis.req('winasInfo', null);
      info = Info.fromMap(res.data);
      if (this.mounted) {
        setState(() {
          loading = false;
          failed = false;
        });
      }
    } catch (error) {
      debug(error);
      if (this.mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Widget renderModel() {
    return SliverToBoxAdapter(
      child: Builder(builder: (ctx) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onCheat(ctx),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(width: 1.0, color: Colors.grey[200]),
                ),
              ),
              child: Container(
                height: 64,
                padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  children: <Widget>[
                    Text(
                      i18n('Device Model'),
                      style: TextStyle(fontSize: 16),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(),
                    ),
                    _ellipsisText(info.model),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  List<Widget> getSlivers() {
    final String titleName = i18n('Device Info');
    // title
    List<Widget> slivers = appBarSlivers(paddingLeft, titleName);
    if (loading) {
      // loading
      slivers.add(SliverToBoxAdapter(child: Container(height: 16)));
    } else if (info == null || failed) {
      // failed
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            height: 256,
            child: Center(
              child: Text(i18n('Failed to Load Page')),
            ),
          ),
        ),
      );
    } else {
      // actions
      slivers.addAll([
        renderModel(),
        // sliverActionButton(
        //   i18n('Device Model'),
        //   () => {},
        //   _ellipsisText(info.model),
        // ),
        sliverActionButton(
          i18n('Device Serial Number'),
          () => {},
          _ellipsisText(info.usn),
        ),
        sliverActionButton(
          i18n('Bluetooth Address'),
          () => {},
          _ellipsisText(info.bleAddr),
        ),
      ]);
    }
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => refresh(store.state),
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
