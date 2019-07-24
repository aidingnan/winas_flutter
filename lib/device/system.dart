import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './info.dart';
import './resetDevice.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import './firmwareUpdate.dart';
import '../common/appBarSlivers.dart';

class System extends StatefulWidget {
  System({Key key}) : super(key: key);
  @override
  _SystemState createState() => _SystemState();
}

class _SystemState extends State<System> {
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
      debug(error);
      if (this.mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  List<Widget> getSlivers() {
    final String titleName = i18n('System Manage');
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
          i18n('Firmware Update'),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return Firmware();
              }),
            );
          },
          null,
        ),
        sliverActionButton(
          i18n('Reset Device'),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return ResetDevice();
              }),
            );
          },
          null,
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
