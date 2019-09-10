import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import './delete.dart';
import './rename.dart';
import './fileRow.dart';
import './xcopyDialog.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/renderIcon.dart';
import '../icons/winas_icons.dart';

class _FileType {
  String name;
  Widget icon;
  String types;
  _FileType(this.name, this.icon, this.types);
}

/// Get corresponding icon via given file name
final iconFromName = (String name) => renderIcon(name, null, size: 16);

/// [title, icon, types]
List<_FileType> get fileTypes => List.from([
      [
        'PDFs',
        iconFromName('a.pdf'),
        'PDF',
      ],
      [
        'Word',
        iconFromName('a.docx'),
        'DOCX.DOC.PAGES',
      ],
      [
        'Excel',
        iconFromName('a.xlsx'),
        'XLSX.XLS.NUMBERS',
      ],
      [
        'PPT',
        iconFromName('a.ppt'),
        'PPTX.PPT.KEY',
      ],
      [
        i18n('Photos'),
        iconFromName('a.bmp'),
        'JPEG.PNG.GIF.BMP.TIFF.HEIC',
      ],
      [
        i18n('Videos'),
        iconFromName('a.mkv'),
        'RM.RMVB.WMV.AVI.MPEG.MP4.3GP.MOV.FLV.MKV',
      ],
      [
        i18n('Audios'),
        iconFromName('a.mp3'),
        'RA.WMA.MP3.OGG.MKA.WAV.APE.FLAC',
      ],
    ].map((x) => _FileType(x[0], x[1], x[2])));

class Search extends StatefulWidget {
  Search({Key key, this.node, this.actions, this.download}) : super(key: key);
  final Node node;
  final actions;
  final download;
  @override
  _SearchState createState() => _SearchState(node, download);
}

class _SearchState extends State<Search> {
  _FileType _fileType;
  final Node node;
  Function actions;
  final download;
  String _searchText;
  bool loading = false;
  List<Entry> _entries;
  ScrollController myScrollController = ScrollController();
  Select select;
  _SearchState(this.node, this.download);

  _onSearch(AppState state) async {
    FocusScope.of(this.context).requestFocus(FocusNode());
    debug('onSearch $_fileType $_searchText');
    if (_fileType == null && _searchText == null) return;
    setState(() {
      loading = true;
    });
    List<String> driveUUIDs = List.from(state.drives.map((d) => d.uuid));
    String places = driveUUIDs.join('.');

    var args = {
      'places': places,
      'order': 'find',
      'fileOnly': 'true',
    };

    if (_searchText != null) {
      args.addAll({
        'name': _searchText,
      });
    }

    if (_fileType != null) {
      args.addAll({
        'types': _fileType.types,
        'order': 'newest',
      });
    }

    try {
      var res = await state.apis.req('search', args);
      assert(res != null && res.data is List);
      debug('search results\' length: ${res.data.length}');
      final list = res.data;

      // filter archived files and deleted files
      if (list is List) {
        _entries = List.from(
          list.map((d) => Entry.fromSearch(d, state.drives)).where(
              (entry) => entry.archived != true && entry.deleted != true),
        );
      } else
        throw 'result is not List';
    } catch (error) {
      debug(error);
    } finally {
      if (this.mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // init Select
    select = Select(() => this.setState(() {}));
    actions = (state) => [
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
              ).then((success) => _onSearch(state));
            },
          },
          {
            'icon': Icons.content_copy,
            'title': i18n('Copy to'),
            'types': node.location == 'backup' ? [] : ['file', 'directory'],
            'action': (BuildContext ctx, Entry entry) async {
              Navigator.pop(ctx);
              newXCopyView(
                  this.context, ctx, [entry], 'copy', () => _onSearch(state));
            }
          },
          {
            'icon': Icons.forward,
            'title': i18n('Move to'),
            'types': node.location == 'backup' ? [] : ['file', 'directory'],
            'action': (BuildContext ctx, Entry entry) async {
              Navigator.pop(ctx);
              newXCopyView(
                  this.context, ctx, [entry], 'move', () => _onSearch(state));
            }
          },
          {
            'icon': Icons.file_download,
            'title': i18n('Download to Local'),
            'types': ['file'],
            'action': (BuildContext ctx, Entry entry) {
              Navigator.pop(ctx);
              download(ctx, entry, state, share: true);
            },
          },
          {
            'icon': Icons.open_in_new,
            'title': i18n('Share to Other App'),
            'types': ['file'],
            'action': (BuildContext ctx, Entry entry) {
              Navigator.pop(ctx);
              download(ctx, entry, state, share: true);
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
                await _onSearch(state);
                showSnackBar(ctx, i18n('Delete Success'));
              } else {
                showSnackBar(ctx, i18n('Delete Failed'));
              }
            },
          },
        ];
  }

  @override
  void dispose() {
    _entries = null;
    select = null;
    myScrollController?.dispose();
    super.dispose();
  }

  /// Normal AppBar
  AppBar searchAppBar(AppState state) {
    return AppBar(
      elevation: 2.0, // no shadow
      backgroundColor: Colors.white,
      brightness: Brightness.light,
      iconTheme: IconThemeData(color: Colors.black38),
      title: TextField(
        // autofocus: true,
        onChanged: (text) {
          _searchText = text;
          if (text == '') {
            setState(() {
              _entries = null;
            });
          }
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: i18n('Search'),
        ),
        style: TextStyle(color: Colors.black87),
        textInputAction: TextInputAction.search,
        onEditingComplete: () => _onSearch(state),
      ),
    );
  }

  /// AppBar when selected
  AppBar selectAppBar(AppState state) {
    return AppBar(
      title: Text(
        i18nPlural('Selected N Items', select.selectedEntry.length),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.normal,
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
            onPressed: select.selectedEntry.any((e) => e.location == 'backup')
                ? null
                : () => newXCopyView(
                        this.context, ctx, select.selectedEntry, 'copy', () {
                      select.clearSelect();
                      _onSearch(state);
                    }),
          );
        }),
        // move selected entry
        Builder(builder: (ctx) {
          return IconButton(
            icon: Icon(Icons.forward),
            onPressed: select.selectedEntry.any((e) => e.location == 'backup')
                ? null
                : () => newXCopyView(
                        this.context, ctx, select.selectedEntry, 'move', () {
                      select.clearSelect();
                      _onSearch(state);
                    }),
          );
        }),
        // delete selected entry
        Builder(builder: (ctx) {
          return IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
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
              await _onSearch(state);
            },
          );
        }),
      ],
    );
  }

  /// No search, init UI
  Widget renderInitUI(AppState state) {
    return Column(
      children: [
        Container(
          height: 56,
          child: Row(
            children: <Widget>[
              Container(width: 16),
              Text(i18n('File Types')),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: ListView(
            children: fileTypes
                .map((fileType) => InkWell(
                      onTap: () {
                        _fileType = fileType;
                        _onSearch(state);
                      },
                      child: Container(
                        height: 56,
                        child: Row(
                          children: <Widget>[
                            Container(width: 16),
                            fileType.icon,
                            Container(width: 32),
                            Text(fileType.name),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// No search result
  Widget renderNoResult() {
    return Column(
      children: <Widget>[
        Expanded(flex: 1, child: Container()),
        Container(
          padding: EdgeInsets.all(16),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(Winas.logo, color: Colors.grey[50], size: 84),
          ),
        ),
        Text(i18n('No Search Results')),
        Expanded(
          flex: 2,
          child: Container(),
        ),
      ],
    );
  }

  /// show search result
  Widget renderList(AppState state) {
    if (_entries.length == 0) return renderNoResult();
    return Container(
      color: Colors.grey[200],
      child: DraggableScrollbar.semicircle(
        controller: myScrollController,
        child: CustomScrollView(
          controller: myScrollController,
          physics: AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            // images, show GridView
            _fileType?.name != fileTypes[4].name
                ? SliverFixedExtentList(
                    itemExtent: 64,
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext ctx, int index) {
                        final entry = _entries[index];
                        return FileRow(
                          entry: entry,
                          type: 'file',
                          actions: actions(state),
                          onPress: () => download(ctx, entry, state),
                          isGrid: false,
                          select: select,
                          isLast: index == _entries.length - 1,
                        );
                      },
                      childCount: _entries.length,
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8.0,
                      crossAxisSpacing: 8.0,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext ctx, int index) {
                        final entry = _entries[index];
                        return FileRow(
                          entry: entry,
                          type: 'file',
                          actions: actions(state),
                          onPress: () => download(ctx, entry, state),
                          isGrid: true,
                          select: select,
                          isLast: index == _entries.length - 1,
                        );
                      },
                      childCount: _entries.length,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (ctx, state) {
        return Scaffold(
          appBar:
              select.selectMode() ? selectAppBar(state) : searchAppBar(state),
          body: Container(
            child: loading
                // loading
                ? Center(child: CircularProgressIndicator())
                : _entries == null
                    // no search
                    ? renderInitUI(state)
                    // search result
                    : _fileType == null
                        // no specific types
                        ? renderList(state)
                        // with specific types
                        : Column(
                            children: <Widget>[
                              Container(
                                height: 56,
                                padding: EdgeInsets.only(left: 16),
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: Row(
                                  children: <Widget>[
                                    Chip(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: EdgeInsets.all(12),
                                      backgroundColor: Colors.white,
                                      elevation: 2.0,
                                      label: Text(_fileType.name),
                                      avatar: _fileType.icon,
                                      deleteIcon: Icon(
                                        Icons.cancel,
                                        color: Colors.black38,
                                        size: 18,
                                      ),
                                      onDeleted: () {
                                        if (select.selectMode()) {
                                          select.clearSelect();
                                        }
                                        setState(() {
                                          _fileType = null;
                                          _entries = null;
                                        });
                                      },
                                    )
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: renderList(state),
                              ),
                            ],
                          ),
          ),
        );
      },
    );
  }
}
