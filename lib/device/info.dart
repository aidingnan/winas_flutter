import '../common/utils.dart';

const UNKNOWN = '未知';

class Info {
  String bleAddr;
  String eccName;
  String ssid;
  String sn;
  String cert;
  String address;
  String macAddress;

  String fingerprint;
  String signer;
  String certNotBefore;
  String certNotAfter;
  Info.fromMap(Map m) {
    final device = m['device'];
    final net = m['net'];

    this.eccName = device['ecc'];
    final ble = m['ble'];
    if (ble != null && ble['state'] == "Started") {
      bleAddr = ble['address'];
    } else {
      bleAddr = UNKNOWN;
    }
    this.sn = device['sn'];
    this.cert = device['cert'];
    if (net != null && net['state'] == 70 && net['detail'] != null) {
      final interface = net['addresses'][0];
      this.address = interface['address'];
      final detail = net['detail'];
      this.macAddress = detail['HwAddress'];
      this.ssid = detail['Ssid'];
    } else {
      this.address = UNKNOWN;
      this.macAddress = UNKNOWN;
      this.ssid = UNKNOWN;
    }

    this.fingerprint = device['fingerprint'];
    this.signer = device['signer'];
    this.certNotBefore = prettyDate(device['notBefore']);
    this.certNotAfter = prettyDate(device['notAfter']);
  }
}
