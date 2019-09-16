import 'dart:convert';
import 'dart:typed_data';
import 'package:redux/redux.dart';
import 'package:photo_manager/photo_manager.dart';

import '../common/utils.dart';
import '../common/request.dart';
import '../common/stationApis.dart';

/// User account data
class Account {
  String token;
  String nickName;
  String username;
  String avatarUrl;
  String id;
  String mail;
  Account(
      {this.token,
      this.nickName,
      this.username,
      this.avatarUrl,
      this.id,
      this.mail});
  Account.fromMap(Map m) {
    this.token = m['token'];
    this.nickName = m['nickName'] ?? m['username'];
    this.username = m['username'];
    this.avatarUrl = m['avatarUrl'];
    this.id = m['id'];
    this.mail = m['mail'];
  }

  void updateNickName(String name) {
    this.nickName = name;
  }

  void updateAvatar(String url) {
    this.avatarUrl = url;
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'token': token,
      'nickName': nickName,
      'username': username,
      'avatarUrl': avatarUrl,
      'id': id,
      'mail': mail,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

/// response of station list
class Station {
  String sn;
  String type;
  int online;
  bool isOnline;
  String onlineTime;
  String offlineTime;
  String lanIp;
  String name;
  String time;
  bool isOwner;

  Station.fromMap(Map m, {bool isOwner: true}) {
    this.sn = m['sn'];
    this.type = m['type'];
    this.online = m['online'];
    this.isOnline = m['online'] == 1;
    this.onlineTime = m['onlineTime'];
    this.offlineTime = m['offlineTime'];
    this.lanIp = m['LANIP'];
    this.name = m['name'];
    this.time = m['time'];
    this.isOwner = isOwner;
  }
  @override
  String toString() {
    Map<String, dynamic> m = {
      'sn': sn,
      'name': name,
      'lanIp': lanIp,
      'isOnline': isOnline,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

/// current logged device
class Device {
  String deviceSN;
  String deviceName;
  String lanIp;
  String lanToken;
  Device({this.deviceSN, this.deviceName, this.lanIp, this.lanToken});
  Device.fromMap(Map m) {
    this.deviceSN = m['deviceSN'];
    this.deviceName = m['deviceName'];
    this.lanIp = m['lanIp'];
    this.lanToken = m['lanToken'];
  }
  @override
  String toString() {
    Map<String, dynamic> m = {
      'deviceSN': deviceSN,
      'deviceName': deviceName,
      'lanIp': lanIp,
      'lanToken': lanToken,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

class User {
  String uuid;
  String username;
  bool isFirstUser;
  String status;
  String phoneNumber;
  String winasUserId;
  String avatarUrl;

  User.fromMap(Map m) {
    this.uuid = m['uuid'];
    this.username = m['username'];
    this.isFirstUser = m['isFirstUser'];
    this.status = m['status'];
    this.phoneNumber = m['phoneNumber'];
    this.winasUserId = m['winasUserId'];
    this.avatarUrl = m['avatarUrl'];
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'uuid': uuid,
      'username': username,
      'isFirstUser': isFirstUser,
      'status': status,
      'phoneNumber': phoneNumber,
      'winasUserId': winasUserId,
      'avatarUrl': avatarUrl,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

class DriveClient {
  String id;

  /// list of machineIds which are combined to this single backup drive
  List idList;

  bool disabled;
  int lastBackupTime;

  /// Idle, Working, Failed
  String status;

  /// Win-PC, Linux-PC, Mac-PC, Mobile-iOS, Mobile-Android
  String type;

  DriveClient({this.type});

  DriveClient.fromMap(Map m) {
    this.id = m['id'];
    this.idList = m['idList'] ?? [];
    this.status = m['status'];
    this.disabled = m['disabled'];
    this.lastBackupTime = m['lastBackupTime'];
    this.type = m['type'];
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'id': id,
      'idList': idList,
      'status': status,
      'disabled': disabled,
      'lastBackupTime': lastBackupTime,
      'type': type,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

class Drive {
  String uuid;
  String type;
  bool privacy;
  String owner;
  String tag;
  String label;
  bool isDeleted;
  bool smb;
  int ctime;
  int mtime;
  int dirCount = 0;
  int fileCount = 0;
  String fileTotalSize = '';
  DriveClient client;
  Drive({this.uuid, this.tag, this.type, this.label, this.client});
  Drive.fromMap(Map m) {
    this.uuid = m['uuid'];
    this.type = m['type'];
    this.privacy = m['privacy'];
    this.owner = m['owner'];
    this.tag = m['tag'];
    this.label = m['label'];
    this.isDeleted = m['isDeleted'];
    this.smb = m['smb'];
    this.ctime = m['ctime'];
    this.mtime = m['mtime'];
    this.client = (m['client'] == 'null' || m['client'] == null)
        ? null
        : DriveClient.fromMap(
            m['client'] is String ? jsonDecode(m['client']) : m['client']);
  }

  void updateStats(Map s) {
    this.dirCount = s['dirCount'];
    this.fileCount = s['fileCount'];
    this.fileTotalSize = prettySize(s['fileTotalSize']);
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'uuid': uuid,
      'type': type,
      'client': client.toString(),
      'label': label,
      'tag': tag,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

class Metadata {
  String type;
  String datetime;
  String hdate;
  String fullDate;
  String make;
  String model;
  // video's duration
  String duration;
  int height;
  int width;
  int rot;

  Metadata.fromMap(Map m) {
    this.type = m['type'];
    this.datetime = m['dateo'] ?? m['datec'] ?? m['date'];
    this.height = m['h'];
    this.width = m['w'];
    this.rot = m['rot'];
    this.make = m['make'];
    this.model = m['model'];
    try {
      // only allow format: "2017:06:17 17:31:18" or "2017:10:07 17:55:33-07:00"
      // hdate: 2017-06-17
      // fullDate: 2017-06-17 17:31
      final list = this.datetime?.substring(0, 19)?.split(':');
      if (this.datetime != null &&
          !this.datetime.startsWith('0') &&
          list.length == 5) {
        this.hdate = this.datetime.split(' ')[0].replaceAll(':', '-');
        this.fullDate =
            this.hdate + ' ' + list[2].split(' ').last + ':' + list[3];
      }
    } catch (err) {
      this.hdate = null;
      print('get hdate failed');
      print(err);
    }
    try {
      final dur = m['dur'];
      if (dur is! num) return;
      int hours = 0;
      int minutes = 0;
      int seconds = 0;

      hours = (dur / 3600).floor();
      minutes = ((dur - hours * 3600) / 60).floor();
      seconds = ((dur - hours * 3600 - minutes * 60)).ceil();

      String hoursString = hours >= 10 ? hours.toString() : '0$hours';
      String minutesString = minutes >= 10 ? minutes.toString() : '0$minutes';
      String secondsString = seconds >= 10 ? seconds.toString() : '0$seconds';
      this.duration = '$minutesString:$secondsString';
      if (hoursString != '00') {
        this.duration = '$hoursString:${this.duration}';
      }
    } catch (err) {
      print('get duration failed');
      print(err);
      this.duration = null;
    }
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'type': type,
      'datetime': datetime,
      'hdate': hdate,
      'fullDate': fullDate,
      'height': height,
      'width': width,
      'rot': rot,
      'make': make,
      'model': model,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

class Entry {
  int size;
  int ctime;
  int bctime;
  int mtime;
  String name;
  String uuid;
  String type;
  String hash;
  String hsize;
  String hmtime;
  String pdir;
  String pdrv;
  String location;
  bool archived = false;
  bool deleted = false;
  // large file's part in backup
  String fingerprint;

  /// photo token date
  String hdate;
  List namepath;
  Metadata metadata;
  bool selected = false;
  Entry(
      {this.name,
      this.uuid,
      this.hash,
      this.type,
      this.pdir,
      this.pdrv,
      this.size,
      this.location});

  Entry.fromMap(Map m) {
    this.size = m['size'] ?? 0;
    this.ctime = m['ctime'] ?? 0;
    this.mtime = m['mtime'] ?? 0;
    this.name = m['bname'] ?? m['name'];
    this.uuid = m['uuid'];
    this.type = m['type'];
    this.hash = m['hash'];
    this.hsize = prettySize(this.size);
    this.hmtime = prettyDate(this.mtime);
    this.location = m['location'];
    this.pdir = m['pdir'];
    this.pdrv = m['pdrv'];
    this.archived = m['archived'] ?? false;
    this.deleted = m['deleted'] ?? false;
    this.fingerprint = m['fingerprint'];
    this.metadata = (m['metadata'] == 'null' || m['metadata'] == null)
        ? null
        : Metadata.fromMap(m['metadata'] is String
            ? jsonDecode(m['metadata'])
            : m['metadata']);
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'size': size,
      'ctime': ctime,
      'mtime': mtime,
      'bctime': bctime,
      'name': name,
      'uuid': uuid,
      'type': type,
      'hash': hash,
      'pdir': pdir,
      'pdrv': pdrv,
      'location': location,
      'namepath': namepath,
      'metadata': metadata,
      'archived': archived,
      'deleted': deleted,
      'fingerprint': fingerprint,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();

  Entry.fromSearch(Map m, List<Drive> d) {
    this.size = m['size'] ?? 0;
    this.ctime = m['ctime'] ?? 0;
    this.mtime = m['mtime'] ?? 0;
    this.bctime = m['bctime'];
    this.name = m['bname'] ?? m['name'];
    this.uuid = m['uuid'];
    this.type = 'file';
    this.hash = m['hash'];
    this.hsize = prettySize(this.size);
    this.hmtime = prettyDate(this.mtime);
    this.metadata =
        m['metadata'] == null ? null : Metadata.fromMap(m['metadata']);
    this.pdir = m['pdir'];
    this.namepath = m['namepath'];
    Drive drive = d[m['place']];
    this.pdrv = drive.uuid;
    this.location = drive.tag ?? drive.type;
    this.archived = m['archived'] ?? false;
    this.deleted = m['deleted'] ?? false;
    this.fingerprint = m['fingerprint'];
    this.hdate = this.metadata?.hdate ??
        prettyDate(this.bctime ?? this.mtime, showDay: true);
  }

  Entry.mixNode(Map m, Node n) {
    this.size = m['size'] ?? 0;
    this.ctime = m['ctime'] ?? 0;
    this.mtime = m['mtime'] ?? 0;
    this.name = m['bname'] ?? m['name'];
    this.uuid = m['uuid'];
    this.type = m['type'];
    this.hash = m['hash'];
    this.hsize = prettySize(this.size);
    this.hmtime = prettyDate(this.mtime);
    this.archived = m['archived'] ?? false;
    this.deleted = m['deleted'] ?? false;
    this.fingerprint = m['fingerprint'];
    this.metadata =
        m['metadata'] == null ? null : Metadata.fromMap(m['metadata']);
    this.pdir = n.dirUUID;
    this.pdrv = n.driveUUID;
    this.location = n.location;
  }

  void select() {
    this.selected = true;
  }

  void unSelect() {
    this.selected = false;
  }

  void toggleSelect() {
    this.selected = !this.selected;
  }
}

class DirPath {
  String uuid;
  String name;
  int mtime;
  DirPath(this.uuid, this.name, this.mtime);
  DirPath.fromMap(Map m) {
    this.mtime = m['mtime'];
    this.name = m['name'];
    this.uuid = m['uuid'];
  }
}

class Node {
  String name;
  String driveUUID;
  String dirUUID;

  /// root, dir, built-in, home,
  String tag;

  /// backup, home, built-in, xcopy
  String location;

  Node({this.name, this.driveUUID, this.dirUUID, this.tag, this.location});
}

/// list of photos and videos from NAS
class Album {
  List<Entry> items;
  String name;
  String places;
  String types;
  int count = 0;
  List<Drive> drives;

  // thumbData
  Uint8List cover;
  Album(this.name, this.places, this.types, this.count, this.drives);

  void setCover(Uint8List thumbData) {
    this.cover = thumbData;
  }
}

/// list of photos and videos from phone
class LocalAlbum {
  List<AssetEntity> items = [];
  String name;

  // thumbData
  Uint8List cover;
  LocalAlbum(this.items, this.name);
  get length => items.length;

  void setCover(thumbData) {
    this.cover = thumbData;
  }
}

/// storage blocks
class Block {
  String name;
  int size;
  String model;
  String serial;
  bool isUSB;
  Block.fromMap(Map m) {
    this.name = m['name'];
    this.size = m['size'];
    this.model = m['model'];
    this.serial = m['serial'];
    this.isUSB = m['isUSB'] == true;
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'name': name,
      'size': size,
      'model': model,
      'serial': serial,
      'isUSB': isUSB,
    };
    return jsonEncode(m);
  }
}

/// update Selection, and refresh(setState)
class Select {
  Function update;
  Select(this.update);
  bool forceSelect = false;
  List<Entry> selectedEntry = [];

  void toggleSelect(Entry entry) {
    if (entry.selected) {
      entry.unSelect();
      selectedEntry.remove(entry);
    } else {
      entry.select();
      selectedEntry.add(entry);
    }
    this.update();
  }

  void clearSelect() {
    for (Entry entry in selectedEntry) {
      entry.unSelect();
    }
    selectedEntry.clear();
    forceSelect = false;
    this.update();
  }

  void selectAll(List<Entry> entries) {
    for (Entry entry in entries) {
      entry.select();
      selectedEntry.add(entry);
    }
    this.update();
  }

  void enterSelect() {
    forceSelect = true;
    this.update();
  }

  bool selectMode() => selectedEntry.length != 0 || forceSelect;
}

/// Types of sortBy:
enum SortTypes { nameUp, nameDown, sizeUp, sizeDown, mtimeUp, mtimeDown }

class EntrySort {
  SortTypes type = SortTypes.nameUp;
  Function update;
  EntrySort(this.update);

  void changeType(SortTypes newType) {
    this.type = newType;
    this.update();
  }

  int sort(Entry a, Entry b) {
    if (a.type != b.type) {
      return a.type.compareTo(b.type);
    }

    switch (type) {
      case SortTypes.nameUp:
        return a.name.compareTo(b.name);

      case SortTypes.nameDown:
        return b.name.compareTo(a.name);

      case SortTypes.mtimeUp:
        return a.mtime.compareTo(b.mtime);

      case SortTypes.mtimeDown:
        return b.mtime.compareTo(a.mtime);

      case SortTypes.sizeUp:
        return a.size.compareTo(b.size);

      case SortTypes.sizeDown:
        return b.size.compareTo(a.size);

      default:
        return 0;
    }
  }

  String getName(SortTypes value) {
    switch (value) {
      case SortTypes.sizeDown:
      case SortTypes.sizeUp:
        return 'Size';

      case SortTypes.mtimeDown:
      case SortTypes.mtimeUp:
        return 'Last Modified';

      case SortTypes.nameDown:
      case SortTypes.nameUp:
        return 'Name';

      default:
        return '';
    }
  }
}

class StationConfig {
  /// station
  String deviceSN;
  bool autoBackup = false;
  bool cellularBackup = false;
  bool cellularTransfer = true;

  StationConfig({
    this.deviceSN,
    this.autoBackup,
    this.cellularBackup,
    this.cellularTransfer,
  });

  StationConfig.combine(StationConfig oldConfig, StationConfig newConfig) {
    this.deviceSN = newConfig.deviceSN ?? oldConfig.deviceSN;
    this.autoBackup = newConfig.autoBackup ?? oldConfig.autoBackup;
    this.cellularBackup = newConfig.cellularBackup ?? oldConfig.cellularBackup;
    this.cellularTransfer =
        newConfig.cellularTransfer ?? oldConfig.cellularTransfer;
  }

  StationConfig.fromMap(Map m) {
    this.deviceSN = m['deviceSN'];
    this.autoBackup = m['autoBackup'] == true;
    this.cellularBackup = m['cellularBackup'] == true;
    this.cellularTransfer = m['cellularTransfer'] == true;
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'deviceSN': deviceSN,
      'autoBackup': autoBackup,
      'cellularBackup': cellularBackup,
      'cellularTransfer': cellularTransfer,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

class Config {
  /// `auto` `en` `zh`
  String language = 'auto';
  bool gridView = false;
  bool showArchive = false;
  bool showTaskFab = false;

  /// Map of <device, StationConfig>
  List<StationConfig> stationConfigs = [];

  Config({
    this.gridView,
    this.showTaskFab,
    this.showArchive,
    this.language,
    this.stationConfigs,
  });

  factory Config.initial() => Config(
        gridView: false,
        showTaskFab: false,
        showArchive: false,
        language: 'auto',
        stationConfigs: [],
      );

  Config.combine(Config oldConfig, Config newConfig) {
    this.gridView = newConfig.gridView ?? oldConfig.gridView;
    this.showArchive = newConfig.showArchive ?? oldConfig.showArchive;
    this.showTaskFab = newConfig.showTaskFab ?? oldConfig.showTaskFab;
    this.language = newConfig.language ?? oldConfig.language ?? 'auto';
    this.stationConfigs =
        newConfig.stationConfigs ?? oldConfig.stationConfigs ?? [];
  }

  Config.fromMap(Map m) {
    this.showTaskFab = false;
    this.gridView = m['gridView'] == true;
    this.showArchive = m['showArchive'] == true;
    this.language = m['language'] ?? 'auto';
    this.stationConfigs = m['stationConfigs'] == null
        ? []
        : List.from(
            jsonDecode(m['stationConfigs'])
                .map((s) => StationConfig.fromMap(s))
                .where((s) => s.deviceSN != null),
          );
  }

  StationConfig getStationConfigs(String deviceSN) {
    return stationConfigs.firstWhere((s) => s.deviceSN == deviceSN,
        orElse: () => null);
  }

  void setStationConfig(String deviceSN, StationConfig stationConfig) {
    final index = stationConfigs.indexWhere((s) => s.deviceSN == deviceSN);
    if (index > -1) {
      final oldStationConfig = stationConfigs[index];
      stationConfigs[index] =
          StationConfig.combine(oldStationConfig, stationConfig);
    } else {
      stationConfigs.add(stationConfig);
    }
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'gridView': gridView,
      'showArchive': showArchive,
      'showTaskFab': showTaskFab,
      'language': language,
      'stationConfigs': stationConfigs.toString(),
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}

// actions
class LoginAction {
  final Account data;
  LoginAction(this.data);
}

class DeviceLoginAction {
  final Device data;
  DeviceLoginAction(this.data);
}

class UpdateUserAction {
  final User data;
  UpdateUserAction(this.data);
}

class UpdateDrivesAction {
  final List<Drive> data;
  UpdateDrivesAction(this.data);
}

class UpdateApisAction {
  final Apis data;
  UpdateApisAction(this.data);
}

class UpdateCloudAction {
  final Request data;
  UpdateCloudAction(this.data);
}

class UpdateConfigAction {
  final Config data;
  UpdateConfigAction(this.data);
}

final deviceLoginReducer = combineReducers<Device>([
  TypedReducer<Device, DeviceLoginAction>((data, action) => action.data),
]);

final accountLoginReducer = combineReducers<Account>([
  TypedReducer<Account, LoginAction>((data, action) => action.data),
]);

final updateUserReducer = combineReducers<User>([
  TypedReducer<User, UpdateUserAction>((data, action) => action.data),
]);

final updateDriveReducer = combineReducers<List<Drive>>([
  TypedReducer<List<Drive>, UpdateDrivesAction>((data, action) => action.data),
]);

final updateApisReducer = combineReducers<Apis>([
  TypedReducer<Apis, UpdateApisAction>((data, action) => action.data),
]);

final updateCloudReducer = combineReducers<Request>([
  TypedReducer<Request, UpdateCloudAction>((data, action) => action.data),
]);

// combine config
final updateConfigReducer = combineReducers<Config>([
  TypedReducer<Config, UpdateConfigAction>(
    (oldConfig, action) => Config.combine(oldConfig, action.data),
  ),
]);

AppState appReducer(AppState state, action) {
  return AppState(
    account: accountLoginReducer(state.account, action),
    device: deviceLoginReducer(state.device, action),
    localUser: updateUserReducer(state.localUser, action),
    drives: updateDriveReducer(state.drives, action),
    apis: updateApisReducer(state.apis, action),
    config: updateConfigReducer(state.config, action),
    cloud: updateCloudReducer(state.cloud, action),
  );
}

class AppState {
  final Account account;
  final Device device;
  final User localUser;
  final List<Drive> drives;
  final Apis apis;
  final Config config;
  final Request cloud;
  AppState({
    this.account,
    this.device,
    this.localUser,
    this.drives,
    this.apis,
    this.config,
    this.cloud,
  });

  factory AppState.initial() => AppState(
        account: null,
        device: null,
        localUser: null,
        drives: [],
        apis: null,
        config: Config.initial(),
      );

  static AppState fromJson(dynamic json) {
    var m = jsonDecode(json);
    return AppState(
      account: m['account'] == null
          ? null
          : Account.fromMap(jsonDecode(m['account'])),
      device:
          m['device'] == null ? null : Device.fromMap(jsonDecode(m['device'])),
      localUser: m['localUser'] == null
          ? null
          : User.fromMap(jsonDecode(m['localUser'])),
      drives: List.from(
        m['drives'].map((d) => Drive.fromMap(jsonDecode(d))),
      ),
      apis: m['apis'] == null ? null : Apis.fromMap(jsonDecode(m['apis'])),
      config:
          m['config'] == null ? null : Config.fromMap(jsonDecode(m['config'])),
      cloud:
          m['cloud'] == null ? null : Request.fromMap(jsonDecode(m['cloud'])),
    );
  }

  @override
  String toString() {
    Map<String, dynamic> m = {
      'account': account,
      'device': device,
      'localUser': localUser,
      'drives': drives,
      'apis': apis,
      'config': config,
      'cloud': cloud,
    };
    return jsonEncode(m);
  }

  String toJson() => toString();
}
