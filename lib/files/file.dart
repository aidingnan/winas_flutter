import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';

import 'package:redux/redux.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_extend/share_extend.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';

import './delete.dart';
import './rename.dart';
import './search.dart';
import './fileRow.dart';
import './newFolder.dart';
import './xcopyDialog.dart';

import '../redux/redux.dart';
import '../common/cache.dart';
import '../common/utils.dart';
import '../common/intent.dart';
import '../common/eventBus.dart';
import '../transfer/manager.dart';
import '../transfer/transfer.dart';
import '../icons/winas_icons.dart';
import '../nav/taskFab.dart';

class Files extends StatefulWidget {
  Files({Key key, this.node, this.fileNavViews, this.justonce})
      : super(key: key);
  final Justonce justonce;
  final Node node;
  final List<FileNavView> fileNavViews;
  @override
  _FilesState createState() => _FilesState(node);
}

class _FilesState extends State<Files> {
  _FilesState(this.node);

  final Node node;
  Node currentNode;
  bool loading = true;
  Error _error;
  List<Entry> entries = [];
  List<Entry> dirs = [];
  List<Entry> files = [];
  List<DirPath> paths = [];
  ScrollController myScrollController = ScrollController();
  StreamSubscription<RefreshEvent> refreshListener;
  Function actions;
  Select select;
  EntrySort entrySort;

  @override
  void initState() {
    super.initState();
    select = Select(() => this.setState(() {}));
    entrySort = EntrySort(() {
      setState(() {
        loading = true;
      });
      parseEntries(entries, paths);
    });

    actions = (AppState state) => [
          {
            'icon': Icons.edit,
            'title': i18n('Rename'),
            'types': node.location == 'backup' ? [] : ['file', 'directory'],
            'action': (BuildContext ctx, Entry entry) {
              Navigator.pop(ctx);
              showDialog(
                context: ctx,
                builder: (BuildContext context) => RenameDialog(
                  entry: entry,
                ),
              ).then((success) => refresh(state));
            },
          },
          {
            'icon': Icons.content_copy,
            'title': i18n('Copy to'),
            'types': node.location == 'backup' ? [] : ['file', 'directory'],
            'action': (BuildContext ctx, Entry entry) async {
              Navigator.pop(ctx);
              newXCopyView(
                  this.context, ctx, [entry], 'copy', () => refresh(state));
            }
          },
          {
            'icon': Icons.forward,
            'title': i18n('Move to'),
            'types': node.location == 'backup' ? [] : ['file', 'directory'],
            'action': (BuildContext ctx, Entry entry) async {
              Navigator.pop(ctx);
              newXCopyView(
                  this.context, ctx, [entry], 'move', () => refresh(state));
            }
          },
          {
            'icon': Icons.file_download,
            'title': i18n('Download to Local'),
            'types': ['file'],
            'action': (BuildContext ctx, Entry entry) async {
              Navigator.pop(ctx);

              bool shouldContinue = await checkMobile(ctx, state);
              if (shouldContinue != true) return;

              final cm = TransferManager.getInstance();
              cm.newDownload(entry, state);
              showSnackBar(ctx, i18n('File Add to Transfer List'));
            },
          },
          {
            'icon': Icons.share,
            'title': i18n('Share to Public Drive'),
            'types': node.location == 'home' ? ['file', 'directory'] : [],
            'action': (BuildContext ctx, Entry entry) async {
              Navigator.pop(ctx);

              final loadingInstance = showLoading(this.context);

              // get built-in public drive
              Drive publicDrive = state.drives.firstWhere(
                  (drive) => drive.tag == 'built-in',
                  orElse: () => null);

              String driveUUID = publicDrive?.uuid;

              var args = {
                'type': 'copy',
                'entries': [entry.name],
                'policies': {
                  'dir': ['rename', 'rename'],
                  'file': ['rename', 'rename']
                },
                'dst': {'drive': driveUUID, 'dir': driveUUID},
                'src': {
                  'drive': currentNode.driveUUID,
                  'dir': currentNode.dirUUID
                },
              };
              try {
                await state.apis.req('xcopy', args);
                loadingInstance.close();
                showSnackBar(ctx, i18n('Share to Public Drive Success'));
              } catch (error) {
                loadingInstance.close();
                showSnackBar(ctx, i18n('Share to Public Drive Failed'));
              }
            },
          },
          {
            'icon': Icons.open_in_new,
            'title': i18n('Share to Other App'),
            'types': ['file'],
            'action': (BuildContext ctx, Entry entry) {
              Navigator.pop(ctx);
              _download(ctx, entry, state, share: true);
            },
          },
          {
            'icon': Icons.delete,
            'title': i18n('Delete'),
            'types': ['file', 'directory'],
            'action': (BuildContext ctx, Entry entry) async {
              Navigator.pop(ctx);
              bool success = await showDialog(
                context: this.context,
                builder: (BuildContext context) =>
                    DeleteDialog(entries: [entry]),
              );

              if (success == true) {
                await refresh(state);
                showSnackBar(ctx, i18n('Delete Success'));
              } else if (success == false) {
                showSnackBar(ctx, i18n('Delete Failed'));
              }
            },
          },
        ];
  }

  @override
  void dispose() {
    refreshListener?.cancel();
    myScrollController?.dispose();
    refreshListener = null;
    myScrollController = null;
    currentNode = null;
    entries = [];
    dirs = [];
    files = [];
    paths = [];
    actions = null;
    select = null;
    entrySort = null;
    super.dispose();
  }

  Future<void> refresh(AppState state,
      {bool isRetry: false, bool needTestLAN: false}) async {
    String driveUUID;
    String dirUUID;
    if (isRetry == true) {
      setState(() {
        loading = true;
      });
    }
    if (node.tag == 'home') {
      Drive homeDrive = state.drives
          .firstWhere((drive) => drive.tag == 'home', orElse: () => null);

      driveUUID = homeDrive?.uuid;
      dirUUID = driveUUID;
      currentNode = Node(
        name: i18n('My Drive'),
        driveUUID: driveUUID,
        dirUUID: driveUUID,
        tag: 'home',
        location: 'home',
      );
    } else if (node.tag == 'dir') {
      driveUUID = node.driveUUID;
      dirUUID = node.dirUUID;
      currentNode = node;
    } else if (node.tag == 'built-in') {
      Drive homeDrive = state.drives
          .firstWhere((drive) => drive.tag == 'built-in', orElse: () => null);

      driveUUID = homeDrive?.uuid;
      dirUUID = driveUUID;
      currentNode = Node(
        name: i18n('Public Drive'),
        driveUUID: driveUUID,
        dirUUID: driveUUID,
        tag: 'built-in',
        location: 'built-in',
      );
    }
    // restart monitorStart
    if (state.apis.sub == null) {
      state.apis.monitorStart();
    }

    // test network
    if (state.apis.isCloud == null || isRetry || needTestLAN) {
      await state.apis.testLAN();
      debug('testLAN: ${state.apis.lanIp} isCloud: ${state.apis.isCloud}');
    }

    // request listNav
    var listNav;
    try {
      listNav = await state.apis
          .req('listNavDir', {'driveUUID': driveUUID, 'dirUUID': dirUUID});
      _error = null;
    } catch (error) {
      debug(error);
      loading = false;
      _error = error;
      if (this.mounted) {
        setState(() {});
      }
      return;
    }

    // assert(listNav.data is Map<String, List>);
    // mix currentNode's dirUUID, driveUUID
    List<Entry> rawEntries = List.from(listNav.data['entries']
        .map((entry) => Entry.mixNode(entry, currentNode)));
    List<DirPath> rawPath =
        List.from(listNav.data['path'].map((path) => DirPath.fromMap(path)));

    // remove deleted file/dir, or part-file in backup drive
    rawEntries = List.from(rawEntries
        .where((entry) => entry.deleted != true && entry.fingerprint == null));

    // hidden archived entries
    if (state.config.showArchive != true) {
      rawEntries =
          List.from(rawEntries.where((entry) => entry.archived != true));
    }

    parseEntries(rawEntries, rawPath);

    // handle intent
    // node: Node(tag: 'home')
    if (widget.node.tag == 'home') {
      String filePath = await Intent.initIntent;
      // debug('handle intent: $filePath');
      if (filePath != null) {
        final cm = TransferManager.getInstance();
        cm.newUploadSharedFile(filePath, state);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Transfer(),
          ),
        );
      }
    }
    return;
  }

  Future<void> firstRefresh(Store<AppState> store) async {
    try {
      if (widget?.justonce?.fired == false) {
        await widget.justonce.fire(store);
      }
      await refresh(store.state);

      /// add Listener to refresh event
      refreshListener = eventBus.on<RefreshEvent>().listen((event) {
        // debug('RefreshEvent ${event.dirUUID} ${currentNode?.dirUUID}');
        if (currentNode?.dirUUID == event.dirUUID && event.dirUUID != null) {
          refresh(store.state).catchError(print);
        }
      });
    } catch (e) {
      debug(e);
      loading = false;
      _error = e;
      if (this.mounted) {
        setState(() {});
      }
      return;
    }
  }

  /// sort entries, update dirs, files
  void parseEntries(List<Entry> rawEntries, List<DirPath> rawPath) {
    // sort by type
    rawEntries.sort((a, b) => entrySort.sort(a, b));

    // insert FileNavView
    List<Entry> newEntries = [];
    List<Entry> newDirs = [];
    List<Entry> newFiles = [];

    if (rawEntries.length == 0) {
      // debug('empty entries');
    } else if (rawEntries[0]?.type == 'directory') {
      int index = rawEntries.indexWhere((entry) => entry.type == 'file');
      if (index > -1) {
        newDirs = List.from(rawEntries.take(index));

        // filter entry.hash
        newFiles = List.from(rawEntries.skip(index));
      } else {
        newDirs = rawEntries;
      }
    } else if (rawEntries[0]?.type == 'file') {
      // filter entry.hash
      newFiles = List.from(rawEntries);
    } else {
      debug('other entries!!!!');
    }
    newEntries.addAll(newDirs);
    newEntries.addAll(newFiles);

    if (this.mounted) {
      // avoid calling setState after dispose()
      setState(() {
        entries = newEntries;
        dirs = newDirs;
        files = newFiles;
        paths = rawPath;
        loading = false;
        _error = null;
      });
    }
  }

  /// checkMobile, return shouldContinue or not
  Future<bool> checkMobile(BuildContext ctx, AppState state) async {
    if (state.config.cellularTransfer == false) {
      bool isMobile = await state.apis.isMobile();
      if (isMobile) {
        final shouldContinue = await showDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (BuildContext context) => WillPopScope(
            onWillPop: () => Future.value(false),
            child: AlertDialog(
              content: Text(i18n('Using Mobile Data Traffic Warning')),
              actions: <Widget>[
                FlatButton(
                  textColor: Theme.of(context).primaryColor,
                  child: Text(i18n('Cancel')),
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                ),
                StoreConnector<AppState, VoidCallback>(
                  converter: (store) => () => store.dispatch(
                        UpdateConfigAction(
                          Config.combine(
                            store.state.config,
                            Config(cellularTransfer: true),
                          ),
                        ),
                      ),
                  builder: (context, callback) {
                    return FlatButton(
                      textColor: Theme.of(context).primaryColor,
                      child: Text(i18n('Continue')),
                      onPressed: () {
                        callback();
                        Navigator.pop(context, true);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );

        return shouldContinue;
      }
    }
    return true;
  }

  // download and openFile via system or share to other app
  void _download(BuildContext ctx, Entry entry, AppState state,
      {bool share: false}) async {
    bool shouldContinue = await checkMobile(ctx, state);

    if (shouldContinue != true) return;

    final dialog = DownloadingDialog(ctx, entry.size);
    dialog.openDialog();

    final cm = await CacheManager.getInstance();
    String entryPath = await cm.getTmpFile(
        entry, state, dialog.onProgress, dialog.cancelToken);

    dialog.close();
    if (dialog.canceled) {
      showSnackBar(ctx, i18n('Download Canceled'));
    } else if (entryPath == null) {
      showSnackBar(ctx, i18n('Download Failed'));
    } else {
      try {
        if (share) {
          await ShareExtend.share(entryPath, "file");
        } else {
          await OpenFile.open(entryPath);
        }
      } catch (error) {
        debug(error);
        showSnackBar(ctx, i18n('No Available App to Open This File'));
      }
    }
  }

  void openSearch(context, state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Search(
            node: currentNode,
            actions: actions(state),
            download: _download,
          );
        },
      ),
    );
  }

  /// upload new file to current directroy
  void upload(String filePath, AppState state) {
    final cm = TransferManager.getInstance();
    Entry targetDir = Entry(
      uuid: currentNode.dirUUID,
      pdrv: currentNode.driveUUID,
      name: currentNode.name,
      location: currentNode.location,
    );
    cm.newUploadFile(filePath, targetDir, state);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Transfer(),
      ),
    );
  }

  /// select New Image/Video/File/Folder
  Future<void> showUploadSheet(context, state) async {
    showModalBottomSheet(
      context: this.context,
      builder: (BuildContext c) {
        return SafeArea(
          child: Container(
            height: 120,
            width: double.infinity,
            child: Row(
              children: <Widget>[
                navButton(
                  () async {
                    // close showModalBottomSheet
                    Navigator.pop(this.context);

                    File file;
                    try {
                      file = await FilePicker.getFile(type: FileType.IMAGE);
                      if (file == null) return;
                      if (Platform.isIOS) {
                        String dirPath = file.parent.path;
                        String fileName = file.path.split('/').last;
                        String extension = fileName.contains('.')
                            ? fileName.split('.').last
                            : '';
                        DateTime time = (await file.stat()).modified;
                        String newName = extension == ''
                            ? 'IMG_${getTimeString(time)}'
                            : 'IMG_${getTimeString(time)}.$extension';
                        file = await file.rename('$dirPath' + '/' + newName);
                      }
                    } catch (e) {
                      debug(e);
                      showSnackBar(
                        this.context,
                        i18n('Pick Image Failed Text'),
                      );
                    }

                    if (file != null) {
                      upload(file.path, state);
                    }
                  },
                  Icon(Icons.image, color: Colors.white),
                  Colors.blue,
                  i18n('Upload Photo'),
                ),
                navButton(
                  () async {
                    // close showModalBottomSheet
                    Navigator.pop(this.context);

                    File file;
                    try {
                      file = await FilePicker.getFile(type: FileType.VIDEO);
                      if (file == null) return;
                      if (Platform.isIOS) {
                        String dirPath = file.parent.path;
                        String fileName = file.path.split('/').last;
                        String extension = fileName.contains('.')
                            ? fileName.split('.').last
                            : '';
                        DateTime time = (await file.stat()).modified;
                        String newName = extension == ''
                            ? 'VID_${getTimeString(time)}'
                            : 'VID_${getTimeString(time)}.$extension';
                        file = await file.rename('$dirPath' + '/' + newName);
                      }
                    } catch (e) {
                      debug(e);
                      showSnackBar(
                        this.context,
                        i18n('Pick Video Failed Text'),
                      );
                      return;
                    }

                    upload(file.path, state);
                  },
                  Icon(Icons.videocam, color: Colors.white),
                  Colors.green,
                  i18n('Upload Video'),
                ),
                navButton(
                  () async {
                    // close showModalBottomSheet
                    Navigator.pop(this.context);
                    String filePath;
                    try {
                      filePath =
                          await FilePicker.getFilePath(type: FileType.ANY);
                      if (filePath == null) return;
                    } catch (e) {
                      debug(e);
                      showSnackBar(this.context, i18n('Pick File Failed Text'));
                      return;
                    }
                    upload(filePath, state);
                  },
                  Icon(Icons.insert_drive_file, color: Colors.white),
                  Colors.lightBlue,
                  i18n('Upload File'),
                ),
                navButton(
                  () async {
                    // close showModalBottomSheet
                    Navigator.pop(this.context);
                    bool success = await showDialog(
                      context: context,
                      builder: (BuildContext context) =>
                          NewFolder(node: currentNode),
                    );
                    if (success == true) {
                      refresh(state);
                    }
                  },
                  Icon(Icons.create_new_folder, color: Colors.white),
                  Colors.lightGreen,
                  i18n('New Folder'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> appBarAction(AppState state) {
    return [
      node.location == 'backup'
          // Button to toggle archive view in backup
          ? StoreConnector<AppState, VoidCallback>(
              converter: (store) {
                return () {
                  bool showArchive = !store.state.config.showArchive;
                  store.dispatch(UpdateConfigAction(
                    Config.combine(
                      store.state.config,
                      Config(showArchive: showArchive),
                    ),
                  ));
                  setState(() {
                    loading = true;
                  });
                  refresh(store.state);
                };
              },
              builder: (context, callback) {
                return IconButton(
                  icon: Icon(
                    state.config.showArchive
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  tooltip: state.config.showArchive
                      ? i18n('Hide Archived')
                      : i18n('Show Archived'),
                  onPressed: callback,
                );
              },
            )
          // Button to add new Image/Video/File/Folder
          : IconButton(
              icon: Icon(Icons.add_circle_outline),
              onPressed: () => showUploadSheet(context, state),
            ),
      // Button to toggle gridView
      StoreConnector<AppState, VoidCallback>(
        converter: (store) {
          return () => store.dispatch(UpdateConfigAction(
                Config.combine(
                  store.state.config,
                  Config(gridView: !store.state.config.gridView),
                ),
              ));
        },
        builder: (context, callback) {
          return IconButton(
            icon: Icon(
                state.config.gridView ? Icons.view_list : Icons.view_module),
            tooltip:
                state.config.gridView ? i18n('List View') : i18n('Grid View'),
            onPressed: callback,
          );
        },
      ),
      // Button to show more actions
      IconButton(
        icon: Icon(Icons.more_horiz),
        onPressed: () {
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
                          select.enterSelect();
                          Navigator.pop(c);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          child: Text(i18n('Select')),
                        ),
                      ),
                    ),
                    Material(
                      child: InkWell(
                        onTap: () {
                          select.selectAll(entries);
                          Navigator.pop(c);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          child: Text(i18n('Select All')),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ];
  }

  Widget _buildItem(
    BuildContext context,
    List<Entry> entries,
    int index,
    List actions,
    Function download,
    Select select,
    bool isGrid,
    bool isLast,
  ) {
    final entry = entries[index];
    switch (entry.type) {
      case 'dirTitle':
        return TitleRow(isFirst: true, type: 'directory');
      case 'fileTitle':
        return TitleRow(isFirst: index == 0, type: 'file');
      case 'file':
        return FileRow(
          key: Key(entry.name + entry.uuid + entry.selected.toString()),
          type: 'file',
          onPress: () => download(entry),
          entry: entry,
          actions: actions,
          isGrid: isGrid,
          select: select,
          isLast: isLast,
        );
      case 'directory':
        return FileRow(
          key: Key(entry.name + entry.uuid + entry.selected.toString()),
          type: 'directory',
          onPress: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                return Files(
                  node: Node(
                    name: entry.name,
                    driveUUID: entry.pdrv,
                    dirUUID: entry.uuid,
                    location: entry.location,
                    tag: 'dir',
                  ),
                );
              },
            ),
          ),
          entry: entry,
          actions: actions,
          isGrid: isGrid,
          select: select,
          isLast: isLast,
        );
    }
    return null;
  }

  Widget navButton(Function onTap, Widget icon, Color color, String title) {
    return Expanded(
      flex: 1,
      child: Container(
        width: double.infinity,
        height: 80,
        margin: EdgeInsets.all(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              children: <Widget>[
                Container(height: 8),
                Container(
                  height: 48,
                  width: 48,
                  child: icon,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.all(
                      const Radius.circular(24),
                    ),
                  ),
                ),
                Container(
                  height: 32,
                  child: Center(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar directoryViewAppBar(AppState state) {
    return AppBar(
      title: Text(
        node.name,
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.normal,
        ),
      ),
      brightness: Brightness.light,
      backgroundColor: Colors.white,
      elevation: 2.0,
      iconTheme: IconThemeData(color: Colors.black38),
      actions: appBarAction(state),
    );
  }

  AppBar homeViewAppBar(AppState state) {
    final List<Widget> actions = [
      Expanded(
        flex: 1,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => openSearch(this.context, state),
          child: Row(
            children: <Widget>[
              Container(width: 16),
              Icon(Icons.search),
              Container(width: 32),
              Text(
                i18n('Search'),
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      )
    ]..addAll(appBarAction(state));

    return AppBar(
      elevation: 2.0,
      brightness: Brightness.light,
      backgroundColor: Colors.white,
      titleSpacing: 0.0,
      iconTheme: IconThemeData(color: Colors.black38),
      title: Row(children: actions),
    );
  }

  AppBar selectAppBar(AppState state) {
    final length = select.selectedEntry.length;
    return AppBar(
      title: WillPopScope(
        onWillPop: () {
          if (select.selectMode()) {
            select.clearSelect();
            return Future.value(false);
          }
          return Future.value(true);
        },
        child: Text(
          i18nPlural('Selected N Items', length),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.close, color: Colors.white),
        onPressed: () => select.clearSelect(),
      ),
      brightness: Brightness.light,
      elevation: 2.0,
      iconTheme: IconThemeData(color: Colors.white),
      actions: <Widget>[
        // copy selected entry
        Builder(builder: (ctx) {
          return IconButton(
            icon: Icon(Icons.content_copy),
            onPressed: select.selectedEntry
                        .any((e) => e.location == 'backup') ||
                    length == 0
                ? null
                : () => newXCopyView(
                        this.context, ctx, select.selectedEntry, 'copy', () {
                      select.clearSelect();
                      refresh(state);
                    }),
          );
        }),
        // move selected entry
        Builder(builder: (ctx) {
          return IconButton(
            icon: Icon(Icons.forward),
            onPressed: select.selectedEntry
                        .any((e) => e.location == 'backup') ||
                    length == 0
                ? null
                : () => newXCopyView(
                        this.context, ctx, select.selectedEntry, 'move', () {
                      select.clearSelect();
                      refresh(state);
                    }),
          );
        }),
        // delete selected entry
        Builder(builder: (ctx) {
          return IconButton(
            icon: Icon(Icons.delete),
            onPressed: length == 0
                ? null
                : () async {
                    bool success = await showDialog(
                      context: this.context,
                      builder: (BuildContext context) =>
                          DeleteDialog(entries: select.selectedEntry),
                    );
                    select.clearSelect();

                    if (success == true) {
                      showSnackBar(ctx, i18n('Delete Success'));
                    } else if (success == false) {
                      showSnackBar(ctx, i18n('Delete Failed'));
                    }
                    await refresh(state);
                  },
          );
        }),
      ],
    );
  }

  Widget dirTitle() {
    return SliverFixedExtentList(
      itemExtent: 48,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return TitleRow(
            isFirst: true,
            type: 'directory',
            entrySort: entrySort,
          );
        },
        childCount: dirs.length > 0 ? 1 : 0,
      ),
    );
  }

  Widget fileTitle() {
    return SliverFixedExtentList(
      itemExtent: 48,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return TitleRow(
            isFirst: dirs.length == 0,
            type: 'file',
            entrySort: entrySort,
          );
        },
        childCount: files.length > 0 ? 1 : 0,
      ),
    );
  }

  Widget dirGrid(state) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
        childAspectRatio: 4.0,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return _buildItem(
            context,
            dirs,
            index,
            actions(state),
            (entry) => _download(context, entry, state),
            select,
            true,
            index == dirs.length - 1,
          );
        },
        childCount: dirs.length,
      ),
    );
  }

  Widget dirRow(state) {
    return SliverFixedExtentList(
      itemExtent: 64,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return _buildItem(
            context,
            dirs,
            index,
            actions(state),
            (entry) => _download(context, entry, state),
            select,
            false,
            index == dirs.length - 1,
          );
        },
        childCount: dirs.length,
      ),
    );
  }

  Widget fileGrid(state) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
        childAspectRatio: 1.0,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return _buildItem(
            context,
            files,
            index,
            actions(state),
            (entry) => _download(context, entry, state),
            select,
            true,
            index == files.length - 1,
          );
        },
        childCount: files.length,
      ),
    );
  }

  Widget fileRow(state) {
    return SliverFixedExtentList(
      itemExtent: 64,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return _buildItem(
            context,
            files,
            index,
            actions(state),
            (entry) => _download(context, entry, state),
            select,
            false,
            index == files.length - 1,
          );
        },
        childCount: files.length,
      ),
    );
  }

  Widget mainScrollView(AppState state, bool isHome) {
    return CustomScrollView(
      key: Key(entries.length.toString()),
      controller: myScrollController,
      physics: AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        // file nav view
        SliverFixedExtentList(
          itemExtent: 96.0,
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return Container(
                color: Colors.grey[200],
                height: 96,
                child: Row(
                  children: widget.fileNavViews
                      .map<Widget>((FileNavView fileNavView) =>
                          fileNavView.navButton(context))
                      .toList(),
                ),
              );
            },
            childCount: !isHome || select.selectMode() ? 0 : 1,
          ),
        ),

        // List is empty
        SliverFixedExtentList(
          itemExtent: MediaQuery.of(context).size.height - 320,
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return Column(
                children: <Widget>[
                  Expanded(flex: 3, child: Container()),
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child:
                          Icon(Winas.logo, color: Colors.grey[200], size: 84),
                    ),
                  ),
                  Text(
                    isHome
                        ? i18n('Empty Folder in Home')
                        : i18n('Empty Folder'),
                    style: TextStyle(color: Colors.black38),
                  ),
                  Expanded(flex: isHome ? 4 : 1, child: Container()),
                ],
              );
            },
            childCount: entries.length == 0 && !loading ? 1 : 0,
          ),
        ),

        // show dir title
        dirTitle(),

        // dir Grid or Row view
        state.config.gridView ? dirGrid(state) : dirRow(state),

        // file title
        fileTitle(),

        // file Grid or Row view
        state.config.gridView ? fileGrid(state) : fileRow(state),

        SliverFixedExtentList(
          itemExtent: 24,
          delegate: SliverChildBuilderDelegate(
            (context, index) => Container(),
            childCount: 1,
          ),
        ),
      ],
    );
  }

  /// main view of file list
  ///
  /// if isHome == true:
  ///
  /// 1. show homeViewAppBar
  /// 2. file nav view
  Widget mainView(bool isHome) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => firstRefresh(store).catchError(print),
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return Scaffold(
          appBar: select.selectMode()
              ? selectAppBar(state)
              : isHome ? homeViewAppBar(state) : directoryViewAppBar(state),
          body: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // File list
                Positioned.fill(
                  child: RefreshIndicator(
                    onRefresh: loading || select.selectMode()
                        ? () async {}
                        : () => refresh(state, needTestLAN: true),
                    child: _error != null
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
                                  onPressed: () =>
                                      refresh(state, isRetry: true),
                                ),
                                Expanded(flex: 6, child: Container()),
                              ],
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: entries.length > 100
                                ? DraggableScrollbar.semicircle(
                                    controller: myScrollController,
                                    child: mainScrollView(state, isHome),
                                  )
                                : mainScrollView(state, isHome),
                          ),
                  ),
                ),

                // CircularProgressIndicator
                loading
                    ? Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Container(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: node.tag == 'home'
              ? mainView(true)
              : (node.tag == 'dir' || node.tag == 'built-in')
                  ? mainView(false)
                  : Center(child: Text('Error !')),
        ),

        /// xcopy task fab
        TaskFab(hasBottom: node.tag == 'home'),
      ],
    );
  }
}
