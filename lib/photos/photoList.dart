import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';

import './photoItem.dart';
import './pageViewer.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../files/delete.dart';
import '../icons/winas_icons.dart';

class PhotoList extends StatefulWidget {
  final Album album;
  PhotoList({Key key, this.album}) : super(key: key);
  @override
  _PhotoListState createState() => _PhotoListState();
}

class _PhotoListState extends State<PhotoList> {
  ScrollController myScrollController = ScrollController();
  Select select;

  /// crossAxisCount in Gird
  int lineCount = 4;

  /// mainAxisSpacing and crossAxisSpacing in Grid
  final double spacing = 4.0;

  ///  height of header
  final double headerHeight = 32;

  bool loading = true;
  List photoMapDates;
  List mapHeight;
  double cellSize;

  /// calc photoMapDates and mapHeight from given album
  Future<void> getList(Album album, BuildContext ctx, AppState state,
      {bool isManual = false}) async {
    List<Entry> items;
    if (album.items == null || isManual) {
      // request album's item list
      final res = await state.apis.req('search', {
        'places': album.places,
        'types': album.types,
        'order': 'newest',
      });
      items = List.from(
        res.data
            .map((m) => Entry.fromSearch(m, album.drives))
            .where((e) => !e.archived && e.fingerprint == null && !e.deleted),
      );
      // sort allMedia
      items.sort((a, b) {
        int order = b.hdate.compareTo(a.hdate);
        return order == 0 ? b.mtime.compareTo(a.mtime) : order;
      });

      // update and cache album.items
      album.items = items;
    } else {
      items = album.items;
    }

    final width = MediaQuery.of(ctx).size.width;

    cellSize = width - spacing * lineCount + spacing;

    if (items.length == 0) {
      photoMapDates = [];
      mapHeight = [];
      loading = false;
      // delay to next render circle
      await Future.delayed(Duration.zero);
      if (this.mounted) {
        setState(() {});
      }

      return;
    }

    /// String headers '2019-03-06' or List of Entry, init with first item
    photoMapDates = [
      items[0].hdate,
      [items[0]],
    ];
    items.forEach((entry) {
      final last = photoMapDates.last;
      if (last[0].hdate == entry.hdate) {
        last.add(entry);
      } else if (last[0].hdate != entry.hdate) {
        photoMapDates.add(entry.hdate);
        photoMapDates.add([entry]);
      }
    });

    // remove the duplicated item
    photoMapDates[1].removeAt(0);

    mapHeight = [];
    double acc = 0;

    photoMapDates.forEach((line) {
      if (line is String) {
        acc += headerHeight;
        mapHeight.add([acc, line]);
      } else if (line is List) {
        final int count = (line.length / lineCount).ceil();
        // (count -1) * spacings + cellSize * count
        acc += (count - 1) * spacing + cellSize / lineCount * count;
        mapHeight.last[0] = acc;
      }
    });

    loading = false;

    // delay to next render circle
    await Future.delayed(Duration.zero);
    if (this.mounted) {
      setState(() {});
    }
  }

  void updateList() {
    setState(() {});
  }

  void showPhoto(BuildContext ctx, Entry entry, Uint8List thumbData) {
    Navigator.push(
      ctx,
      TransparentPageRoute(
        builder: (BuildContext context) {
          return PageViewer(
            photo: entry,
            list: widget.album.items,
            thumbData: thumbData,
            updateList: updateList,
          );
        },
      ),
    );
  }

  /// getDate via Offset
  ///
  /// mapHeight is List of [offset, hdate]
  Widget getDate(double offset, List mapHeight) {
    final List current =
        mapHeight.firstWhere((e) => e[0] >= offset, orElse: () => [0, '']);
    return Text(current[1]);
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
      elevation: 1.0,
      iconTheme: IconThemeData(color: Colors.white),
      actions: <Widget>[
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

                    if (success == true) {
                      showSnackBar(ctx, i18n('Delete Success'));
                      for (Entry entry in select.selectedEntry) {
                        widget.album.items.remove(entry);
                      }
                    } else if (success == false) {
                      showSnackBar(ctx, i18n('Delete Failed'));
                    }
                    select.clearSelect();

                    await getList(widget.album, context, state);
                  },
          );
        }),
      ],
    );
  }

  AppBar listAppBar(AppState state) {
    return AppBar(
      title: Text(
        widget.album.name,
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.normal,
        ),
      ),
      backgroundColor: Colors.white,
      brightness: Brightness.light,
      elevation: 2.0,
      iconTheme: IconThemeData(color: Colors.black38),
      actions: <Widget>[
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
                            select.selectAll(widget.album.items);
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
      ],
    );
  }

  @override
  void initState() {
    select = Select(() => this.setState(() {}));
    super.initState();
  }

  @override
  void dispose() {
    photoMapDates = null;
    mapHeight = null;
    myScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) =>
          getList(widget.album, context, store.state).catchError(debug),
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (ctx, state) {
        return Scaffold(
          key: Key(widget.album.count.toString()),
          appBar: select.selectMode() ? selectAppBar(state) : listAppBar(state),
          body: Container(
            color: Colors.grey[100],
            child: RefreshIndicator(
              onRefresh: () async {
                if (loading || select.selectMode()) return;
                await getList(widget.album, ctx, state, isManual: true);
              },
              child: loading == true
                  ? Center(child: CircularProgressIndicator())
                  : widget.album.count == 0
                      // no content
                      ? Column(
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
                                child: Icon(Winas.logo,
                                    color: Colors.grey[100], size: 84),
                              ),
                            ),
                            Text(
                              i18n('No Content in Album'),
                              style: TextStyle(color: Colors.black38),
                            ),
                            Expanded(flex: 2, child: Container()),
                          ],
                        )
                      // photo list
                      : DraggableScrollbar.semicircle(
                          controller: myScrollController,
                          labelTextBuilder: (double offset) =>
                              getDate(offset, mapHeight),
                          labelConstraints:
                              BoxConstraints.expand(width: 88, height: 36),
                          child: CustomScrollView(
                            key: Key(photoMapDates.length.toString()),
                            controller: myScrollController,
                            physics: AlwaysScrollableScrollPhysics(),
                            slivers: List.from(
                              photoMapDates.map(
                                (line) {
                                  if (line is String) {
                                    return SliverFixedExtentList(
                                      itemExtent: headerHeight,
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => Container(
                                          padding: EdgeInsets.all(8),
                                          child: Text(line),
                                        ),
                                        childCount: 1,
                                      ),
                                    );
                                  }
                                  return SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: lineCount,
                                      mainAxisSpacing: spacing,
                                      crossAxisSpacing: spacing,
                                      childAspectRatio: 1.0,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (BuildContext context, int index) {
                                        return PhotoItem(
                                          key: Key(line[index].uuid +
                                              line[index].selected.toString()),
                                          item: line[index],
                                          showPhoto: showPhoto,
                                          cellSize: cellSize,
                                          select: select,
                                        );
                                      },
                                      childCount: line.length,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        );
      },
    );
  }
}
