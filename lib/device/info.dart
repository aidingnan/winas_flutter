import 'dart:convert';

import '../common/utils.dart';

class Info {
  String bleAddr;
  String ssid;
  String sn;
  String usn;
  String bleName;
  String model;
  String address;
  String macAddress;
  String version;
  bool rooted;

  Info.fromMap(Map m) {
    final device = m['device'];
    final net = m['net'];

    final ble = m['ble'];
    final unknown = i18n('Unknown Status in Info');
    if (ble != null && ble['state'] == "Started") {
      bleAddr = ble['address'];
    } else {
      bleAddr = unknown;
    }
    this.sn = device['sn'];
    this.usn = device['usn'];
    this.bleName = 'pan-${this.usn?.substring(0, 4) ?? 'XXXX'}';
    this.model = device['model'];
    this.rooted = device['rooted'] == true;

    if (net != null && net['state'] == 70 && net['detail'] != null) {
      final interface = net['addresses'][0];
      this.address = interface['address'];
      final detail = net['detail'];
      this.macAddress = detail['HwAddress'];
      this.ssid = detail['Ssid'];
    } else {
      this.address = unknown;
      this.macAddress = unknown;
      this.ssid = unknown;
    }

    this.version = m['upgrade']['current'];
  }
}

class UpgradeInfo {
  String tag;
  String hash;
  String url;
  String desc;
  bool preRelease;
  int gradient;
  String createdAt;
  String type;
  String uuid;
  UpgradeInfo.fromMap(Map m) {
    this.tag = m['tag'];
    this.hash = m['hash'];
    this.url = m['url'];
    this.desc = m['desc'];
    this.preRelease = m['preRelease'] == 1;
    this.gradient = m['gradient'];
    this.createdAt = m['createdAt'];
    this.type = m['type'];
  }

  addUUID(String id) {
    this.uuid = id;
  }

  @override
  String toString() {
    Map<String, dynamic> m = {'tag': tag};
    return jsonEncode(m);
  }

  String toJson() => toString();
}
