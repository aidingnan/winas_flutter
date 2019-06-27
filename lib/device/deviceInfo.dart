import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './info.dart';
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
      print(error);
      if (this.mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
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
        sliverActionButton(
          i18n('Device Model'),
          () => {},
          _ellipsisText('Bacchus'),
        ),
        sliverActionButton(
          i18n('Device Serial Number'),
          () => {},
          _ellipsisText(info.sn),
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
    return StoreConnector<AppState, Account>(
      onInit: (store) => refresh(store.state),
      onDispose: (store) => {},
      converter: (store) => store.state.account,
      builder: (context, account) {
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
