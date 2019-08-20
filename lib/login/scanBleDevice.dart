import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/cupertino.dart' hide Action;
import 'package:flutter_blue/flutter_blue.dart';

import './ble.dart';
import './bleHelp.dart';
import './configDevice.dart';

import '../common/utils.dart';
import '../login/bleHelp.dart';
import '../common/request.dart';

class ScanBleDevice extends StatefulWidget {
  ScanBleDevice({Key key, this.request, this.action, this.target})
      : super(key: key);
  final Request request;
  final Action action;

  ///  target ble device's advertising name
  final String target;
  @override
  _ScanBleDeviceState createState() => _ScanBleDeviceState();
}

class _ScanBleDeviceState extends State<ScanBleDevice> {
  StreamSubscription<ScanResult> scanSubscription;
  StreamSubscription<BluetoothDeviceState> deviceConnection;
  ScrollController myScrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    startBLESearch();
  }

  @override
  void dispose() {
    super.dispose();
    scanSubscription?.cancel();

    /// Disconnect from device
    deviceConnection?.cancel();
  }

  List<ScanResult> results = [];

  String error;

  Future<void> startBLESearch() async {
    FlutterBlue flutterBlue = FlutterBlue.instance;
    error = null;
    scanSubscription?.cancel();

    try {
      bool isAvailable = await flutterBlue.isAvailable;
      if (!isAvailable) throw 'bluetooth is not available';

      bool isOn = await flutterBlue.isOn;
      if (!isOn) throw 'bluetooth is not on';
    } catch (e) {
      debug(e);
      error = i18n('Bluetooth Not Available Error');
      if (mounted) {
        setState(() {});
      }
      return;
    }

    scanSubscription = flutterBlue.scan().listen((ScanResult scanResult) {
      final deviceName = scanResult.device.name;
      // filter device
      if (!deviceName.toLowerCase().startsWith('pan')) return;

      // only show target if specified
      if (widget.target != null && deviceName != widget.target) return;
      final id = scanResult.device.id;
      int index = results.indexWhere((res) => res.device.id == id);

      // only add once
      if (index > -1) return;
      results.add(scanResult);

      // debug('get device >>>>>>>>>>>');
      // debug('AdvertisementData ${scanResult.advertisementData.localName}');
      // debug(id);
      // debug(scanResult.device.name);

      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
      debug(e);
      if (e is PlatformException && e.code == 'no_permissions') {
        error = i18n('Bluetooth No Permission Error');
      } else {
        error = i18n('Bluetooth Scan Failed Text');
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  /// send a auth request, make device flash light (show color code)
  Future reqAuth(BluetoothDevice device) async {
    final reqCommand = '{"action":"req","seq":1}';
    final res = await getLocalAuth(device, reqCommand);
    debug('reqAuth: $res');
    final colors = res['data']['colors'];
    return colors;
  }

  /// connect to selected BLE device
  void connect(ScanResult scanResult, Function callback) {
    final device = scanResult.device;
    FlutterBlue flutterBlue = FlutterBlue.instance;
    // cancel previous BLE device connection
    deviceConnection?.cancel();
    debug('connecting ${scanResult.device.name} ...');
    bool done = false;
    deviceConnection = flutterBlue
        .connect(device, timeout: Duration(seconds: 60), autoConnect: false)
        .listen((s) {
      debug(s);
      if (done) return;
      if (s == BluetoothDeviceState.connected) {
        done = true;
        callback(null, device);
      } else {
        done = true;
        callback('Disconnected', null);
      }
    });
  }

  /// async function of `connect`
  Future<BluetoothDevice> connectAsync(ScanResult scanResult) async {
    Completer<BluetoothDevice> c = Completer();
    connect(scanResult, (error, BluetoothDevice value) {
      if (error != null) {
        c.completeError(error);
      } else {
        c.complete(value);
      }
    });
    return c.future;
  }

  parseResult(ScanResult scanResult) {
    final manufacturerData = scanResult.advertisementData.manufacturerData;
    int value = -1;
    try {
      value = manufacturerData[65535][0];
    } catch (e) {
      debug('parseResult $e');
      value = -1;
    }

    String status = '';
    switch (value) {
      case 1:
        status = widget.action == Action.bind
            ? i18n('Device To Be Bound')
            : i18n('Device Need To Be Bound');
        break;

      case 2:
        status = widget.action == Action.bind
            ? i18n('Device Already Bound')
            : i18n('WiFi Configurable');
        break;

      default:
        status = i18n('Unknown Status in BLE');
    }
    bool enabled = (widget.action == Action.wifi && value == 2) ||
        (widget.action == Action.bind && value == 1);
    return {
      'status': status,
      'enabled': enabled,
    };
  }

  @override
  Widget build(BuildContext context) {
    bool noResult = results.length == 0;
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        brightness: Brightness.light,
        backgroundColor: Colors.grey[50],
        iconTheme: IconThemeData(color: Colors.black38),
        title: Text(
          i18n('Scan BLE Device Title'),
          style: TextStyle(color: Colors.black87),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                results.clear();
              });
              startBLESearch();
            },
          )
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: error == null
                  ? CustomScrollView(
                      controller: myScrollController,
                      physics: AlwaysScrollableScrollPhysics(),
                      slivers: <Widget>[
                        // List
                        SliverFixedExtentList(
                          itemExtent: noResult ? 256 : 72,
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext ctx, int index) {
                              // no result, show loading
                              if (noResult) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              ScanResult scanResult = results[index];
                              final res = parseResult(scanResult);
                              final status = res['status'];
                              final enabled = res['enabled'];

                              String localName = scanResult.device.name;

                              return Material(
                                child: InkWell(
                                  onTap: () async {
                                    if (!enabled) return;

                                    BluetoothDevice device;

                                    final loadingInstance =
                                        showLoading(ctx, fakeProgress: 5.0);

                                    try {
                                      device = await connectAsync(scanResult);
                                    } catch (e) {
                                      debug(e);

                                      loadingInstance.close();
                                      showSnackBar(
                                        ctx,
                                        i18n('Connect BLE Error'),
                                      );
                                      return;
                                    }

                                    try {
                                      await reqAuth(device);
                                    } catch (e) {
                                      debug(e);

                                      loadingInstance.close();
                                      showSnackBar(
                                        ctx,
                                        i18n('Request Color Code Error'),
                                      );
                                      return;
                                    }

                                    loadingInstance.close();
                                    Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (context) => ConfigDevice(
                                          device: device,
                                          request: widget.request,
                                          action: widget.action,
                                          onClose: () =>
                                              deviceConnection?.cancel(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Opacity(
                                    opacity: enabled ? 1 : 0.5,
                                    child: Container(
                                      margin: EdgeInsets.all(16),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            flex: 10,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: <Widget>[
                                                Text(i18n('Product Name')),
                                                Text(
                                                  i18n(
                                                    'Product Number in BLE',
                                                    {'deviceNumber': localName},
                                                  ),
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Container(),
                                          ),
                                          Text(
                                            status,
                                            style: TextStyle(
                                                color: Colors.black54),
                                          ),
                                          Icon(Icons.chevron_right),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: noResult ? 1 : results.length,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: <Widget>[
                        Expanded(child: Container(), flex: 1),
                        Icon(
                          Icons.error,
                          color: Colors.pinkAccent,
                          size: 72,
                        ),
                        Container(
                          padding: EdgeInsets.all(16),
                          child: Text(error),
                        ),
                        FlatButton(
                          padding: EdgeInsets.all(0),
                          child: Text(
                            i18n('BLE Rescan'),
                            style: TextStyle(color: Colors.teal),
                          ),
                          onPressed: () {
                            setState(() {
                              results.clear();
                              error = null;
                            });
                            startBLESearch();
                          },
                        ),
                        Expanded(child: Container(), flex: 2),
                      ],
                    ),
            ),
            Container(
              height: 64,
              child: FlatButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => BleHelp(),
                    fullscreenDialog: true,
                  ),
                ),
                child: Text(
                  i18n('BLE No Results Text'),
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
