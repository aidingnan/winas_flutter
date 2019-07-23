import 'package:flutter/material.dart' hide Action;
import 'package:flutter_redux/flutter_redux.dart';

import './info.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../login/ble.dart';
import '../login/scanBleDevice.dart';

class Network extends StatefulWidget {
  Network({Key key}) : super(key: key);
  @override
  _NetworkState createState() => _NetworkState();
}

class _NetworkState extends State<Network> {
  Info info;
  bool loading = true;
  bool failed = false;

  Widget _ellipsisText(String text) {
    return ellipsisText(text, style: TextStyle(color: Colors.black38));
  }

  refresh(AppState state) async {
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

  void startScanBLEDevice(AppState state, Action action) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return ScanBleDevice(request: state.cloud, action: action);
        },
      ),
    );
  }

  void showBottom(BuildContext ctx, AppState state) {
    showModalBottomSheet(
      context: ctx,
      builder: (BuildContext c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Material(
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(c);
                    startScanBLEDevice(state, Action.wifi);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    child: Text(
                      i18n('Configuring Device WiFi'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => refresh(store.state),
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0.0, // no shadow
            backgroundColor: Colors.white10,
            brightness: Brightness.light,
            iconTheme: IconThemeData(color: Colors.black38),
            actions: <Widget>[
              Builder(builder: (ctx) {
                return IconButton(
                  icon: Icon(Icons.more_horiz),
                  onPressed: () => showBottom(ctx, state),
                );
              })
            ],
          ),
          body: loading
              ? Container(
                  height: 256,
                  child: Center(child: CircularProgressIndicator()),
                )
              : (info == null || failed)
                  ? Container(
                      height: 256,
                      child: Center(
                        child: Text(i18n('Failed to Load Page')),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            i18n('Network Detail'),
                            style:
                                TextStyle(color: Colors.black87, fontSize: 21),
                          ),
                        ),
                        Container(height: 16),
                        actionButton(
                          i18n('WiFi Id'),
                          () => {},
                          _ellipsisText(info.ssid),
                        ),
                        actionButton(
                          i18n('LAN Ip Address'),
                          () => {},
                          _ellipsisText(state.apis.lanIp),
                        ),
                        actionButton(
                          i18n('MAC Address'),
                          () => {},
                          _ellipsisText(info.macAddress),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
