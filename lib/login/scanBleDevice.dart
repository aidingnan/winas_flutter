import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/cupertino.dart' hide Action;
import 'package:flutter_blue/flutter_blue.dart';

import './ble.dart';
import './helps.dart';
import './configDevice.dart';
import './confirmFormatDisk.dart';

import '../common/utils.dart';
import '../common/request.dart';

class ScanBleDevice extends StatefulWidget {
  ScanBleDevice({Key key, this.request, this.action, this.target})
      : super(key: key);
  final Request request;
  final Action action;

  ///  target ble device's advertising name
  final List<String> target;
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
      if (widget.target != null && !widget.target.contains(deviceName)) return;
      final id = scanResult.device.id;
      int index = results.indexWhere((res) => res.device.id == id);

      // only add once
      if (index > -1) return;
      results.add(scanResult);

      print('get device >>>>>>>>>>>');
      print(id);
      print(scanResult.device.name);
      print(scanResult.advertisementData.manufacturerData);

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
    final colors = res['data']['colors'];
    return colors;
  }

  /// connect to selected BLE device
  void connect(ScanResult scanResult, Function callback) {
    final device = scanResult.device;
    FlutterBlue flutterBlue = FlutterBlue.instance;
    // cancel previous BLE device connection
    deviceConnection?.cancel();
    print('connecting ${scanResult.device.name} ...');
    bool done = false;
    deviceConnection = flutterBlue
        .connect(device, timeout: Duration(seconds: 60), autoConnect: false)
        .listen((s) {
      print(s);
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
      value = -1;
    }

    String status = '';
    if (widget.action == Action.bind) {
      status = value != 2
          ? i18n('Device To Be Bound')
          : i18n('Device Already Bound');
    } else {
      status = value != 1
          ? i18n('WiFi Configurable')
          : i18n('Device Need To Be Bound');
    }
    if (!([0, 1, 2].contains(value))) {
      status = i18n('Unknown Status in BLE');
    }

    bool enabled = (widget.action == Action.wifi && value != 1) ||
        (widget.action == Action.bind && value != 2);

    /// disk value
    /// 0x02	未插入ssd	sda size为0（udev设备节点?）	拒绝ble之外所有服务	需用户插入或检查插入ssd
    /// 0x03	文件系统非btrfs	使用btrfs命令	拒绝ble之外所有服务	需用户执行格式化操作
    /// 0x04	btrfs文件系统无法挂载，btrfs文件系统无法读写	使用mount/umount，在mount后做文件读写测试	拒绝ble之外所有服务	文件系统损坏，建议用户在PC上维修，或者尝试格式化
    /// 0x80	一切正常	通过所有检查	直接使用
    int diskValue = -1;
    bool needFormat = false;

    try {
      diskValue = manufacturerData[65535][1];
    } catch (e) {
      diskValue = -1;
    }

    switch (diskValue) {
      case 2:
        status = i18n('No SSD Found');
        enabled = false;
        break;

      case 3:
      case 4:
        needFormat = true;
        break;

      case 128:
        needFormat = false;
        break;
      // -1 or other value
      default:
    }

    return {
      'status': status,
      'enabled': enabled,
      'needFormat': needFormat,
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
                              final String status = res['status'];
                              final bool enabled = res['enabled'];
                              final bool needFormat = res['needFormat'];

                              String localName = scanResult.device.name;

                              return Material(
                                child: InkWell(
                                  onTap: () async {
                                    if (!enabled) return;

                                    // need user to confirm to format disk
                                    if (needFormat == true) {
                                      final bool confirmFormat =
                                          await showDialog(
                                        context: ctx,
                                        builder: (_) => ConfirmDialog(),
                                      );

                                      if (confirmFormat != true) {
                                        return;
                                      }
                                    }

                                    BluetoothDevice device;

                                    final loadingInstance = showLoading(
                                      ctx,
                                      fakeProgress: 5.0,
                                      text: i18n('Connecting to BLE'),
                                    );

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
                                          needFormat: needFormat == true,
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
