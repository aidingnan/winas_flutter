import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './file.dart';
import './deleteBackupDrive.dart';
import './renameDriveDialog.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../icons/winas_icons.dart';

class BackupView extends StatefulWidget {
  BackupView({Key key}) : super(key: key);

  @override
  _BackupViewState createState() => _BackupViewState();
}

class _BackupViewState extends State<BackupView> {
  ScrollController myScrollController = ScrollController();
  List<Drive> drives = [];

  bool loading = true;

  String error;

  /// manage mode
  bool alt = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    myScrollController?.dispose();
    drives = [];
    super.dispose();
  }

  void renameDrive(Drive drive, Store<AppState> store) {
    print('renameDrive, $drive');
    showDialog(
      context: this.context,
      builder: (BuildContext context) => RenameDriveDialog(
        drive: drive,
      ),
    ).then((success) => refresh(store));
  }

  Future<void> deleteDrive(Drive drive, Store<AppState> store) async {
    print('deleteDrive, $drive');
    bool success = await showDialog(
      context: this.context,
      builder: (BuildContext context) => DeleteDriveDialog(drive: drive),
    );

    if (success == true) {
      await refresh(store);
      showSnackBar(this.context, i18n('Delete Success'));
    } else if (success == false) {
      showSnackBar(this.context, i18n('Delete Failed'));
    }
  }

  Future updateDirSize(AppState state, Drive drive) async {
    var res = await state.apis
        .req('dirStat', {'driveUUID': drive.uuid, 'dirUUID': drive.uuid});
    drive.updateStats(res.data);
  }

  Future refresh(store) async {
    try {
      if (mounted && loading == false) {
        setState(() {
          loading = true;
        });
      }
      AppState state = store.state;
      // get current drives data
      final res = await state.apis.req('drives', null);
      List<Drive> allDrives = List.from(
        res.data.map((drive) => Drive.fromMap(drive)),
      );

      store.dispatch(
        UpdateDrivesAction(allDrives),
      );

      drives = List.from(
        allDrives.where((drive) => drive.type == 'backup'),
      );
      List<Future> reqs = [];
      for (Drive drive in drives) {
        reqs.add(updateDirSize(state, drive));
      }
      await Future.wait(reqs);
      if (mounted) {
        setState(() {
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      debug(e);
      if (mounted) {
        setState(() {
          error = 'refresh failed';
          loading = false;
        });
      }
    }
  }

  void showBottom(BuildContext ctx, Store<AppState> store) {
    showModalBottomSheet(
      context: this.context,
      builder: (BuildContext c) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Material(
                child: InkWell(
                  onTap: () {
                    Navigator.pop(c);
                    setState(() {
                      alt = true;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    child: Text(i18n('Manage Backup Drive')),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// list og backup drive
  Widget renderList(Store<AppState> store) {
    return CustomScrollView(
      controller: myScrollController,
      physics: AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverFixedExtentList(
          itemExtent: 48.0,
          delegate: SliverChildBuilderDelegate(
              (context, index) => Column(
                    children: <Widget>[
                      Container(height: 8, color: Colors.grey[100]),
                      Container(
                        padding: EdgeInsets.only(left: 18, right: 18),
                        height: 40,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              i18n('Backup Device'),
                              style: TextStyle(color: Colors.black54),
                            ),
                            if (!alt)
                              Text(
                                i18n('Backup Size'),
                                style: TextStyle(color: Colors.black54),
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
              childCount: 1),
        ),
        SliverFixedExtentList(
          itemExtent: 64.0,
          delegate: SliverChildBuilderDelegate((context, index) {
            Drive drive = drives[index];

            Color backgroundColor = Color(0xFF039be5);
            IconData icon = Icons.laptop;

            switch (drive?.client?.type) {
              case 'Win-PC':
                backgroundColor = Color(0xFF039be5);
                icon = Icons.laptop;
                break;
              case 'Mac-PC':
                backgroundColor = Color(0xFF000000);
                icon = Icons.laptop;
                break;
              case 'Mobile-Android':
                backgroundColor = Color(0xFF43a047);
                icon = Icons.phone_iphone;
                break;
              case 'Mobile-iOS':
                backgroundColor = Color(0xFF000000);
                icon = Icons.phone_iphone;
                break;
              case 'Linux-PC':
                backgroundColor = Color(0xFF039be5);
                icon = Icons.laptop;
                break;
              default:
                break;
            }

            return Material(
              child: InkWell(
                onTap: alt
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return Files(
                                node: Node(
                                  name: drive.label,
                                  driveUUID: drive.uuid,
                                  dirUUID: drive.uuid,
                                  tag: 'dir',
                                  location: 'backup',
                                ),
                              );
                            },
                          ),
                        ),
                child: Container(
                  constraints: BoxConstraints.expand(),
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          // color: Colors.cyan[800],
                          color: backgroundColor,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: Icon(icon, color: Colors.white),
                      ),
                      Container(width: 16),
                      Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 216),
                        child: Text(
                          drive.label,
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          maxLines: 1,
                        ),
                      ),

                      // edit backup drive name
                      if (alt)
                        IconButton(
                          iconSize: 18.0,
                          padding: EdgeInsets.all(6),
                          icon: Icon(Icons.edit),
                          onPressed: () => renameDrive(drive, store),
                        ),

                      Expanded(flex: 1, child: Container()),

                      // bakcup size
                      if (!alt)
                        Text(
                          drive.fileTotalSize == '0 B'
                              ? i18n('No Backup Size')
                              : drive.fileTotalSize,
                          style: TextStyle(color: Colors.black54),
                        ),

                      // delete backup drive
                      if (alt)
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => deleteDrive(drive, store),
                        )
                      else
                        Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            );
          }, childCount: drives.length),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Store<AppState>>(
      onInit: (store) => refresh(store),
      onDispose: (store) => {},
      converter: (store) => store,
      builder: (context, store) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0.0, // no shadow
            brightness: Brightness.light,
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black38),
            title: Text(
              alt ? i18n('Manage Backup Drive') : i18n('Backup Drive'),
              style: TextStyle(color: Colors.black87),
            ),
            leading: alt
                ? IconButton(
                    icon: Icon(Icons.close, color: Colors.black38),
                    onPressed: () => setState(() {
                      alt = false;
                    }),
                  )
                : null,
            // actions: alt
            //     ? null
            //     : <Widget>[
            //         Builder(builder: (ctx) {
            //           return IconButton(
            //             icon: Icon(Icons.more_horiz),
            //             onPressed: () => showBottom(ctx, store),
            //           );
            //         })
            //       ],
          ),
          body: loading
              ? Center(child: CircularProgressIndicator())
              : error != null
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
                            onPressed: () => refresh(store),
                          ),
                          Expanded(flex: 6, child: Container()),
                        ],
                      ),
                    )
                  : drives.length == 0
                      ? Column(
                          children: <Widget>[
                            Expanded(flex: 1, child: Container()),
                            Icon(
                              Icons.content_copy,
                              color: Colors.grey[300],
                              size: 84,
                            ),
                            Container(height: 16),
                            Text(i18n('No Backup Drive')),
                            Expanded(
                              flex: 2,
                              child: Container(),
                            ),
                          ],
                        )
                      : renderList(store),
        );
      },
    );
  }
}
