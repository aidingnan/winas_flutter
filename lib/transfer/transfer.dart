import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './manager.dart';
import './removable.dart';
import '../files/file.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/renderIcon.dart';

class Transfer extends StatefulWidget {
  Transfer({Key key}) : super(key: key);

  @override
  _TransferState createState() => _TransferState();
}

class _TransferState extends State<Transfer> {
  bool loading = false;
  List<TransferItem> list = [];
  ScrollController myScrollController = ScrollController();
  _TransferState();

  @override
  void initState() {
    super.initState();
  }

  /// refresh per second
  _autoRefresh({bool isFirst = false}) async {
    list = TransferManager.getList();

    // only order by startTime
    list.sort((a, b) => b.startTime - a.startTime);

    await Future.delayed(
        isFirst ? Duration(milliseconds: 100) : Duration(seconds: 1));
    if (this.mounted) {
      setState(() {});
      _autoRefresh();
    }
  }

  /// Resume task
  ///
  /// clean current, start a new task
  void resumeTask(List<TransferItem> items, int index, AppState state) {
    final item = items[index];
    item.clean();
    items.removeAt(index);
    final cm = TransferManager.getInstance();
    if (item.transType == TransType.download) {
      cm.newDownload(item.entry, state);
    } else if (item.transType == TransType.shared) {
      cm.newUploadSharedFile(item.filePath, state);
    } else if (item.transType == TransType.upload) {
      cm.newUploadFile(item.filePath, item.targetDir, state);
    }
  }

  Widget renderStatus(List<TransferItem> items, int index, AppState state) {
    final item = items[index];
    switch (item.status) {
      case 'finished':
        return Center(child: Icon(Icons.check_circle_outline));
      case 'working':
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                value: 1,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[50]),
              ),
            ),
            Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                value: item.finishedSize / item.entry.size,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
          ],
        );
      case 'paused':
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                value: 1,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[200]),
              ),
            ),
            Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                value: item.finishedSize / item.entry.size,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
            Positioned.fill(child: Center(child: Icon(Icons.pause))),
          ],
        );
      case 'failed':
        return Center(
          child: IconButton(
            icon: Icon(Icons.error, color: Colors.redAccent),
            onPressed: () async {
              await showDialog(
                context: this.context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text(i18n('Transfer Task Failed')),
                  content: Text('${item.error}'),
                  actions: <Widget>[
                    FlatButton(
                        textColor: Theme.of(context).primaryColor,
                        child: Text(i18n('Cancel')),
                        onPressed: () {
                          Navigator.pop(context);
                        }),
                    FlatButton(
                        textColor: Theme.of(context).primaryColor,
                        child: Text(i18n('Retry Transfer Task')),
                        onPressed: () {
                          Navigator.pop(context);
                          resumeTask(items, index, state);
                        })
                  ],
                ),
              );
            },
          ),
        );
    }
    return Container();
  }

  Widget renderRow(
      BuildContext ctx, List<TransferItem> items, int index, AppState state) {
    TransferItem item = items[index];
    Entry entry = item.entry;
    bool isLast = index == items.length - 1;
    return Removable(
      key: Key(item.uuid),
      onDismissed: () {
        setState(() {
          item.clean();
          items.removeAt(index);
          showSnackBar(ctx, i18n('Delete Success'));
        });
      },
      child: Material(
        child: InkWell(
          onTap: () async {
            if (item.status == 'finished') {
              // open file
              if (item.transType == TransType.download) {
                await OpenFile.open(item.filePath);
              } else {
                Entry entry = item.targetDir;
                Navigator.push(
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
                );
              }
            } else if (item.status == 'working') {
              // pause task
              item.pause();
            } else if (item.status == 'paused') {
              // resume task
              resumeTask(items, index, state);
            } else if (item.status == 'failed') {
              // resume task
              resumeTask(items, index, state);
            }
          },
          child: Row(
            children: <Widget>[
              Container(
                child: renderIcon(entry.name, entry.metadata, size: 24.0),
                padding: EdgeInsets.all(16),
              ),
              Container(width: 16),
              Expanded(
                flex: 1,
                child: Container(
                  decoration: isLast
                      ? null
                      : BoxDecoration(
                          border: Border(
                            bottom:
                                BorderSide(width: 1.0, color: Colors.grey[300]),
                          ),
                        ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(flex: 1, child: Container()),
                            Row(
                              children: <Widget>[
                                Text(
                                  entry.name,
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.fade,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                            Container(height: 8),
                            Row(
                              children: <Widget>[
                                Icon(
                                  item.transType == TransType.download
                                      ? Icons.file_download
                                      : Icons.file_upload,
                                  size: 18,
                                ),
                                Container(height: 4),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    item.status == 'finished'
                                        ? prettySize(item.entry.size)
                                        : '${prettySize(item.finishedSize)} / ${prettySize(item.entry.size)}',
                                    style: TextStyle(fontSize: 10),
                                    overflow: TextOverflow.fade,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            Expanded(flex: 1, child: Container()),
                          ],
                        ),
                      ),
                      Expanded(flex: 1, child: Container()),
                      Text(
                        item.status == 'working'
                            ? item.speed
                            : item.status == 'paused'
                                ? i18n('Transfer Task Paused')
                                : '',
                        style: TextStyle(fontSize: 12),
                      ),
                      Container(
                        padding: EdgeInsets.all(16),
                        width: 72,
                        height: 72,
                        child: renderStatus(items, index, state),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => _autoRefresh(isFirst: true),
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (ctx, state) {
        return Scaffold(
          appBar: AppBar(
            elevation: 2.0, // no shadow
            backgroundColor: Colors.white,
            brightness: Brightness.light,
            iconTheme: IconThemeData(color: Colors.black38),
            title: Text(
              i18n('Transfer Tasks'),
              style: TextStyle(color: Colors.black87),
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.more_horiz),
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    builder: (BuildContext c) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // start all
                            Material(
                              child: InkWell(
                                onTap: () async {
                                  Navigator.pop(c);
                                  List<Entry> resumeList = [];
                                  for (int i = list.length - 1; i >= 0; i--) {
                                    TransferItem item = list[i];
                                    if (item.status == 'paused') {
                                      item.clean();
                                      list.removeAt(i);
                                      resumeList.add(item.entry);
                                    }
                                  }
                                  final cm = TransferManager.getInstance();
                                  for (Entry entry in resumeList) {
                                    cm.newDownload(entry, state);
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(i18n('Start All Transfer Tasks')),
                                ),
                              ),
                            ),
                            // pause all
                            Material(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(c);
                                  for (TransferItem item in list) {
                                    if (item.status == 'working') item.pause();
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(i18n('Pause All Transfer Tasks')),
                                ),
                              ),
                            ),
                            // clear all
                            Material(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(c);
                                  for (TransferItem item in list) {
                                    item.clean();
                                  }
                                  list.clear();
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    i18n('Delete All Transfer Tasks'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              )
            ],
          ),
          body: Container(
            child: loading
                ? Center(child: CircularProgressIndicator())
                : list.length == 0
                    ? Column(
                        children: <Widget>[
                          Expanded(flex: 1, child: Container()),
                          Icon(
                            Icons.web_asset,
                            color: Colors.grey[300],
                            size: 84,
                          ),
                          Container(height: 16),
                          Text(i18n('No Transfer Tasks')),
                          Expanded(
                            flex: 2,
                            child: Container(),
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: CustomScrollView(
                          controller: myScrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          slivers: <Widget>[
                            SliverFixedExtentList(
                              itemExtent: 72,
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext ctx, int index) =>
                                    renderRow(ctx, list, index, state),
                                childCount: list.length,
                              ),
                            )
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }
}
