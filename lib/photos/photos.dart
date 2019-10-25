import 'dart:async';
import 'dart:typed_data';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './backup.dart';
import './photoList.dart';
import '../redux/redux.dart';
import '../common/cache.dart';
import '../common/utils.dart';
import '../common/eventBus.dart';
import '../icons/winas_icons.dart';

const mediaTypes =
    'HEIC.JPEG.PNG.JPG.GIF.BMP.RAW.RM.RMVB.WMV.AVI.MP4.3GP.MKV.MOV.FLV.MPEG';
const videoTypes = 'RM.RMVB.WMV.AVI.MP4.3GP.MKV.MOV.FLV.MPEG';
const imageTypes = 'HEIC.JPEG.PNG.JPG.GIF.BMP';

class Photos extends StatefulWidget {
  Photos({Key key, this.backupWorker, this.toggleBackup}) : super(key: key);
  final BackupWorker backupWorker;
  final Function toggleBackup;
  @override
  _PhotosState createState() => _PhotosState();
}

class _PhotosState extends State<Photos> {
  static bool loading = true;

  /// Album
  static List<Album> albumList = [];

  /// current users's userUUID
  static String userUUID;

  /// cached album cover
  static Map<String, Uint8List> cachedThumbs = {};

  /// BackupEvent Listener
  StreamSubscription<BackupEvent> backupEventListener;

  int needRefresh = 0;

  /// req data error
  bool error = false;

  ScrollController myScrollController = ScrollController();

  Future getCover(Album album, AppState state) async {
    // get from cached list
    final preThumbData = cachedThumbs['${album.name + album.places}'];

    if (preThumbData != null) {
      album.setCover(Image.memory(
        preThumbData,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ));
    }

    // fix bug of call this after logout
    if (state?.apis?.req == null) return;

    // get first item
    final res = await state.apis.req('search', {
      'places': album.places,
      'types': album.types,
      'order': 'newest',
      'count': 1,
    });
    if (res.data is! List || res.data.length == 0) {
      return;
    }

    Entry entry = Entry.fromMap(res.data.first);
    final cm = await CacheManager.getInstance();
    final Uint8List thumbData = await cm.getThumbData(entry, state);

    // cache thumbData
    cachedThumbs['${album.name + album.places}'] = thumbData;

    if (this.mounted && thumbData != null) {
      album.setCover(Image.memory(
        thumbData,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ));
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

  Future<void> refresh(Store<AppState> store, bool isManual) async {
    /// should mounted
    if (this.mounted != true) {
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
          Album(i18n('Photos'), places, imageTypes, photosCount, drives);
      final allVideosAlbum =
          Album(i18n('Videos'), places, videoTypes, videosCount, drives);

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
        getCover(album, store.state).catchError(debug);
      }

      // cache data
      userUUID = store.state.localUser.uuid;
      loading = false;
      error = false;
      if (this.mounted) {
        setState(() {});
      }
    } catch (e) {
      debug(e);
      loading = false;
      error = true;
      if (this.mounted) {
        setState(() {});
      }
    }
  }

  /// refresh per second to show backup progress
  Future<void> autoRefresh(Store<AppState> store,
      {bool isFirst = false}) async {
    await Future.delayed(
        isFirst ? Duration(milliseconds: 100) : Duration(seconds: 1));

    if (needRefresh > 3 && !loading) {
      needRefresh = 0;
      await refresh(store, false);
    }
    if (this.mounted) {
      if (!loading && !error) {
        setState(() {});
      }
      autoRefresh(store);
    }
  }

  Future<void> initWorks(Store<AppState> store) async {
    // add backupEventListener (asynchronous)
    backupEventListener = eventBus.on<BackupEvent>().listen((event) {
      if (this.mounted) {
        setState(() {
          needRefresh += 1;
        });
      }
    });

    // refresh photoList
    refresh(store, false).catchError(debug);

    // refresh UI to show bakcup progress
    autoRefresh(store, isFirst: true).catchError(debug);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    backupEventListener?.cancel();
    myScrollController?.dispose();
    albumList.forEach((a) => a.clean());
    super.dispose();
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
                  child: Container(
                    constraints: BoxConstraints.expand(),
                    child: album.cover,
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
                    i18nPlural('Album Content Count', album.count),
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

  String backupStatus(StationConfig config, BackupWorker worker) {
    String text = i18n('Backup Photos');
    if (config?.autoBackup == true) {
      if (worker.isFinished) {
        text = i18n('Backup Finished');
      } else if (worker.isPaused) {
        text = i18n('Backup Paused in Mobile Data Traffic');
      } else if (worker.isFailed) {
        text = i18n('Backup Failed');
      } else if (worker.isDiffing) {
        text = i18n('Backup Preparing');
      } else if (worker.isRunning) {
        text = i18n('Backup Working');
      }
    }
    return text;
  }

  List<Widget> renderSlivers(Store<AppState> store) {
    final worker = widget.backupWorker;
    final stationConfig =
        store.state.config.getStationConfigs(store.state.apis.deviceSN);
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
                        backupStatus(stationConfig, worker),
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
                      stationConfig?.autoBackup == true
                          ? ''
                          : i18n('Backup Disabled'),
                      style: TextStyle(color: Colors.white),
                    ),
                    Switch(
                        activeColor: Colors.white,
                        value: stationConfig?.autoBackup == true,
                        onChanged: (bool value) =>
                            widget.toggleBackup(context, store, value)),
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
                  i18n('All'),
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
                  i18n('From'),
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
      onInit: (store) => initWorks(store).catchError(debug),
      onDispose: (store) => {},
      converter: (store) => store,
      builder: (context, store) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0.0,
            brightness: Brightness.light,
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black38),
            title: Text(i18n('Album'), style: TextStyle(color: Colors.black87)),
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
                              i18n('Failed to Load Page'),
                              style: TextStyle(color: Colors.black38),
                            ),
                            FlatButton(
                              padding: EdgeInsets.all(0),
                              child: Text(
                                i18n('Reload'),
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
