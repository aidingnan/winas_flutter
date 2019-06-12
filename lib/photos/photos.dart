import 'dart:typed_data';
import 'package:pocket_drive/common/utils.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './backup.dart';
import './photoList.dart';
import '../redux/redux.dart';
import '../common/cache.dart';
import '../icons/winas_icons.dart';

// TODO: HEIC in mediaTypes
// const mediaTypes =
//   'HEIC.JPEG.PNG.JPG.GIF.BMP.RAW.RM.RMVB.WMV.AVI.MP4.3GP.MKV.MOV.FLV.MPEG';

const mediaTypes =
    'JPEG.PNG.JPG.GIF.BMP.RAW.RM.RMVB.WMV.AVI.MP4.3GP.MKV.MOV.FLV.MPEG';
const videoTypes = 'RM.RMVB.WMV.AVI.MP4.3GP.MKV.MOV.FLV.MPEG';
const imageTypes = 'JPEG.PNG.JPG.GIF.BMP';

class Photos extends StatefulWidget {
  Photos({Key key, this.backupWorker}) : super(key: key);
  final BackupWorker backupWorker;
  @override
  _PhotosState createState() => _PhotosState();
}

class _PhotosState extends State<Photos> {
  static bool loading = true;

  /// Album
  static List<Album> albumList = [];

  /// current users's userUUID
  static String userUUID;

  /// req data error
  bool error = false;

  ScrollController myScrollController = ScrollController();

  Future getCover(Album album, AppState state) async {
    // get first item
    final res = await state.apis.req('search', {
      'places': album.places,
      'types': album.types,
      'order': 'newest',
      'count': 1,
    });

    Entry entry = Entry.fromMap(res.data.first);
    final cm = await CacheManager.getInstance();
    final Uint8List thumbData = await cm.getThumbData(entry, state);

    if (this.mounted && thumbData != null) {
      album.setCover(thumbData);
      setState(() {});
    }
  }

  /// request and update drive list
  Future<List<Drive>> updateDrives(Store<AppState> store) async {
    AppState state = store.state;
    // get current drives data
    final res = await state.apis.req('drives', null);
    List<Drive> allDrives = List.from(
      res.data.map((drive) => Drive.fromMap(drive)),
    );

    store.dispatch(
      UpdateDrivesAction(allDrives),
    );
    return allDrives;
  }

  Future refresh(Store<AppState> store, bool isManual) async {
    // use store.state to keep the state as latest
    if (!isManual &&
        store.state.localUser.uuid == userUUID &&
        albumList.length > 0) {
      return;
    }

    /// reload after error
    if (isManual && error) {
      setState(() {
        error = false;
        loading = true;
      });
    }

    try {
      AppState state = store.state;
      if (isManual) {
        await state.apis.testLAN();
      }

      final List<Drive> drives = await updateDrives(store);

      List<String> driveUUIDs = List.from(drives.map((d) => d.uuid));
      String places = driveUUIDs.join('.');

      // all photos and videos
      final imageRes = await state.apis.req('search', {
        'places': places,
        'types': imageTypes,
        'order': 'newest',
        'countOnly': 'true',
        'groupBy': 'place'
      });

      final videoRes = await state.apis.req('search', {
        'places': places,
        'types': videoTypes,
        'order': 'newest',
        'countOnly': 'true',
        'groupBy': 'place'
      });

      int photosCount = 0;
      for (Map m in imageRes.data) {
        photosCount += m['count'];
      }
      int videosCount = 0;
      for (Map m in videoRes.data) {
        videosCount += m['count'];
      }

      final allRes = [];
      allRes.addAll(imageRes.data);
      allRes.addAll(videoRes.data);
      Map<String, int> groupByPlaces = {};

      for (Map m in allRes) {
        String key = m['key'];
        groupByPlaces[key] = groupByPlaces[key] == null
            ? m['count']
            : (groupByPlaces[key] + m['count']);
      }

      final allPhotosAlbum =
          Album('照片', places, imageTypes, photosCount, drives);
      final allVideosAlbum =
          Album('视频', places, videoTypes, videosCount, drives);

      albumList = [allPhotosAlbum, allVideosAlbum];

      final List<Drive> backupDrives =
          List.from(store.state.drives.where((d) => d.type == 'backup'));
      for (String key in groupByPlaces.keys) {
        final drive = backupDrives.firstWhere((Drive d) => d.uuid == key,
            orElse: () => null);
        if (drive != null) {
          albumList.add(
              Album(drive.label, key, mediaTypes, groupByPlaces[key], [drive]));
        }
      }

      // request album's cover
      for (var album in albumList) {
        getCover(album, store.state).catchError(print);
      }
      // cache data
      userUUID = store.state.localUser.uuid;
      loading = false;
      error = false;
      if (this.mounted) {
        setState(() {});
      }
    } catch (e) {
      print(e);
      loading = false;
      error = true;
      if (this.mounted) {
        setState(() {});
      }
    }
  }

  /// refresh per second to show backup progress
  Future autoRefresh({bool isFirst = false}) async {
    await Future.delayed(
        isFirst ? Duration(milliseconds: 100) : Duration(seconds: 1));
    if (this.mounted) {
      if (!loading && !error) {
        setState(() {});
      }
      autoRefresh();
    }
  }

  @override
  void initState() {
    super.initState();
    autoRefresh(isFirst: true).catchError(print);
  }

  Widget renderAlbum(Album album) {
    return Container(
      child: Material(
        child: InkWell(
          onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return PhotoList(album: album);
                  },
                ),
              ),
          child: Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 1,
                  child: album.cover != null
                      ? Container(
                          constraints: BoxConstraints.expand(),
                          child: Image.memory(
                            album.cover,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                        ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(0, 4, 0, 4),
                  width: double.infinity,
                  child: Text(
                    album.name,
                    style: TextStyle(fontSize: 15),
                    overflow: TextOverflow.fade,
                    maxLines: 1,
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 4),
                  width: double.infinity,
                  child: Text(
                    '${album.count} 项内容',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String backupStatus(Config config, BackupWorker worker) {
    String text = '照片备份功能';
    if (config.autoBackup == true) {
      if (worker.isFinished) {
        text = '备份已经完成';
      } else if (worker.isPaused) {
        text = '备份已暂停';
      } else if (worker.isFailed) {
        text = '备份未完成';
      } else if (worker.isDiffing) {
        text = '正在准备备份';
      } else if (worker.isRunning) {
        text = '备份中';
      }
    }
    return text;
  }

  void _onSwitchChange(
      BuildContext ctx, Store<AppState> store, bool value) async {
    final loadingInstance = showLoading(context);
    try {
      final data = await getMachineId();
      final deviceName = data['deviceName'];
      final machineId = data['machineId'];
      print('deviceName $deviceName, machineId $machineId');
      final res = await store.state.apis.req('drives', null);
      // get current drives data
      List<Drive> drives = List.from(
        res.data.map((drive) => Drive.fromMap(drive)),
      );

      Drive backupDrive = drives.firstWhere(
        (d) =>
            d?.client?.id == machineId ||
            (d?.client?.idList is List && d.client.idList.contains(machineId)),
        orElse: () => null,
      );

      // not find backupDrive
      // 1. create new
      // 2. choose one oldDrive with same name

      if (backupDrive == null && value == true) {
        // check exist drive with same label
        Drive sameLabelDrive = drives.firstWhere(
          (d) => d.label == deviceName,
          orElse: () => null,
        );

        if (sameLabelDrive != null) {
          final success = await showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (BuildContext context) => WillPopScope(
                  onWillPop: () => Future.value(false),
                  child: AlertDialog(
                    title: Text('选择备份设备'),
                    content: Text('检测到当前设备 $deviceName 已存在备份，是否合并备份？'),
                    actions: <Widget>[
                      FlatButton(
                        textColor: Theme.of(context).primaryColor,
                        child: Text('不，新建一个备份'),
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                      ),
                      FlatButton(
                        textColor: Theme.of(context).primaryColor,
                        child: Text('合并'),
                        onPressed: () async {
                          AppState state = store.state;

                          try {
                            final res = await state.apis.req(
                              'drive',
                              {'uuid': sameLabelDrive.uuid},
                            );
                            final client = res.data['client'];
                            List idList = client['idList'] ?? [client['id']];
                            idList.add(machineId);
                            final props = {
                              'op': 'backup',
                              'client': {
                                'status': 'Idle',
                                'lastBackupTime': client['lastBackupTime'],
                                'id': client['id'],
                                'idList': idList,
                                'disabled': false,
                                'type': client['type'],
                              }
                            };

                            await state.apis.req('updateDrive', {
                              'uuid': sameLabelDrive.uuid,
                              'props': props,
                            });
                          } catch (e) {
                            print(e);
                            Navigator.pop(context, false);
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                      )
                    ],
                  ),
                ),
          );
          if (success == false) {
            throw 'update backup drive id list failed';
          }
        }
      }
    } catch (e) {
      print(e);
      loadingInstance.close();
      showSnackBar(context, '操作失败');
      return;
    }

    loadingInstance.close();

    store.dispatch(UpdateConfigAction(
      Config.combine(
        store.state.config,
        Config(autoBackup: value),
      ),
    ));

    if (value == true) {
      widget.backupWorker.start();
    } else {
      widget.backupWorker.abort();
    }
  }

  List<Widget> renderSlivers(Store<AppState> store) {
    final worker = widget.backupWorker;
    return <Widget>[
      // backup switch
      SliverToBoxAdapter(
        child: loading || error || albumList.length == 0
            ? Container()
            : Container(
                padding: EdgeInsets.only(left: 16, right: 8),
                color: Colors.blue,
                child: Row(
                  children: <Widget>[
                    Center(
                      child: Text(
                        backupStatus(store.state.config, worker),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Container(width: 16),
                    Expanded(
                      child: Container(
                        child: Text(
                          worker.isRunning ? worker.progress : '',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      flex: 1,
                    ),
                    Text(
                      store.state.config.autoBackup == true ? '' : '已关闭',
                      style: TextStyle(color: Colors.white),
                    ),
                    Switch(
                      activeColor: Colors.white,
                      value: store.state.config.autoBackup == true,
                      onChanged: (bool value) =>
                          _onSwitchChange(context, store, value),
                    ),
                  ],
                ),
              ),
      ),
      // backup loading
      SliverToBoxAdapter(
        child: worker.isRunning
            ? Container(
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.blue[700]),
                  backgroundColor: Colors.blue,
                ),
              )
            : Container(),
      ),

      // backup title
      SliverToBoxAdapter(
        child: albumList.length < 3
            ? Container()
            : Container(
                padding: EdgeInsets.only(top: 16, left: 16, right: 8),
                // padding: EdgeInsets.all(16),
                child: Text(
                  '全部',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
      ),

      // all photos
      SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16.0,
            crossAxisSpacing: 16.0,
            childAspectRatio: 0.8,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final album = albumList[index];
              return renderAlbum(album);
            },
            childCount: albumList.length > 2 ? 2 : albumList.length,
          ),
        ),
      ),

      // backup title
      SliverToBoxAdapter(
        child: albumList.length < 3
            ? Container()
            : Container(
                padding: EdgeInsets.only(top: 8, left: 16, right: 8),
                // padding: EdgeInsets.all(16),
                child: Text(
                  '来自',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
      ),

      // backup drives
      SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16.0,
            crossAxisSpacing: 16.0,
            childAspectRatio: 0.8,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final album = albumList[index + 2];
              return renderAlbum(album);
            },
            childCount: albumList.length > 2 ? albumList.length - 2 : 0,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Store<AppState>>(
      onInit: (store) => refresh(store, false).catchError(print),
      onDispose: (store) => {},
      converter: (store) => store,
      builder: (context, store) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0.0,
            brightness: Brightness.light,
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black38),
            title: Text('相簿', style: TextStyle(color: Colors.black87)),
            centerTitle: false,
          ),
          body: SafeArea(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : error
                    ? Center(
                        child: Column(
                          children: <Widget>[
                            Expanded(flex: 4, child: Container()),
                            Container(
                              padding: EdgeInsets.all(16),
                              child: Container(
                                width: 72,
                                height: 72,
                                // padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(36),
                                ),
                                child: Icon(
                                  Winas.logo,
                                  color: Colors.grey[50],
                                  size: 84,
                                ),
                              ),
                            ),
                            Text(
                              '加载页面失败，请检查网络设置',
                              style: TextStyle(color: Colors.black38),
                            ),
                            FlatButton(
                              padding: EdgeInsets.all(0),
                              child: Text(
                                '重新加载',
                                style: TextStyle(color: Colors.teal),
                              ),
                              onPressed: () => refresh(store, true),
                            ),
                            Expanded(flex: 6, child: Container()),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => refresh(store, true),
                        child: Container(
                          child: CustomScrollView(
                            controller: myScrollController,
                            physics: AlwaysScrollableScrollPhysics(),
                            slivers: renderSlivers(store),
                          ),
                        ),
                      ),
          ),
        );
      },
    );
  }
}
