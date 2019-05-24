import 'package:flutter/material.dart';

class BleHelp extends StatelessWidget {
  Widget row(String text, {isTitle = false}) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Text(
        text,
        style: TextStyle(fontSize: isTitle ? 20 : 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        backgroundColor: Colors.white10,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.black38),
        title: Text('帮助', style: TextStyle(color: Colors.black87)),
      ),
      body: ListView(
        children: <Widget>[
          row('扫描不到设备？', isTitle: true),
          row('1. 请确认口袋网盘设备已插入USB供电，设备启动至指示灯显示蓝色闪烁状态。'),
          row('2. 确保手机蓝牙功能正常并已打开，蓝牙工作异常时，也可尝试在手机设置中重启蓝牙功能。'),
          row('3. 对于安卓手机，App使用蓝牙控制需要手机的定位权限，请确保口袋网盘应用的定位权限未被关闭。'),
          row('4. 尽量使手机靠近口袋网盘设备。'),
        ],
      ),
    );
  }
}
