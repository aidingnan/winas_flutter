import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:share_extend/share_extend.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './gridPhoto.dart';
import './gridVideo.dart';
import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/cache.dart';
import '../files/delete.dart';
import '../transfer/manager.dart';

const videoTypes = 'RM.RMVB.WMV.AVI.MP4.3GP.MKV.MOV.FLV.MPEG';

class PageViewer extends StatefulWidget {
  const PageViewer(
      {Key key, this.photo, this.thumbData, this.list, this.updateList})
      : super(key: key);
  final Uint8List thumbData;
  final List list;
  final Entry photo;
  final Function updateList;
  @override
  _PageViewerState createState() => _PageViewerState();
}

class _PageViewerState extends State<PageViewer> {
  /// current photo, default: widget.photo
  Entry currentItem;
  ScrollController myScrollController = ScrollController();
  PageController pageController;

  @override
  void initState() {
    currentItem = widget.photo;
    pageController =
        PageController(initialPage: widget.list.indexOf(currentItem));
    super.initState();
  }

  double opacity = 1.0;
  updateOpacity(double value) {
    setState(() {
      opacity = value.clamp(0.0, 1.0);
    });
  }

  bool showTitle = true;
  void toggleTitle({bool show}) {
    if (show != null) {
      showTitle = show;
    } else {
      showTitle = !showTitle;
    }

    // show/hidden status bar
    if (showTitle) {
      SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    } else {
      SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    }

    setState(() {});
  }

  void _share(BuildContext ctx, Entry entry, AppState state) async {
    final dialog = DownloadingDialog(ctx, entry.size);
    dialog.openDialog();

    final cm = await CacheManager.getInstance();
    String entryPath = await cm.getPhotoPath(entry, state,
        onProgress: dialog.onProgress, cancelToken: dialog.cancelToken);

    dialog.close();
    if (dialog.canceled) {
      showSnackBar(ctx, '下载已取消');
    } else if (entryPath == null) {
      showSnackBar(ctx, '下载失败');
    } else {
      try {
        ShareExtend.share(entryPath, "file");
      } catch (error) {
        print(error);
        showSnackBar(ctx, '分享失败');
      }
    }
  }

  void _download(BuildContext ctx, Entry entry, AppState state) async {
    final cm = TransferManager.getInstance();
    cm.newDownload(entry, state);
    showSnackBar(ctx, '该文件已加入下载任务');
  }

  void _delete(BuildContext ctx, Entry entry, AppState state) async {
    bool success = await showDialog(
      context: this.context,
      builder: (BuildContext context) => DeleteDialog(
            entries: [entry],
            isMedia: true,
          ),
    );

    if (success == true) {
      showSnackBar(ctx, '删除成功');
      final isFirstPage = pageController.offset == 0.0;

      // is not FirstPage: return to previousPage
      if (!isFirstPage) {
        pageController.previousPage(
            duration: Duration(milliseconds: 300), curve: Curves.ease);
      }

      setState(() {
        widget.list.remove(entry);
      });
      widget.updateList();

      // is FirstPage: return to list
      if (isFirstPage) {
        Navigator.pop(ctx);
      }
    } else if (success == false) {
      showSnackBar(ctx, '删除失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView.builder(
              controller: pageController,
              itemBuilder: (context, position) {
                final Entry item = widget.list[position];
                final ext = item?.metadata?.type?.toUpperCase();
                final isVideo = videoTypes.split('.').contains(ext);
                final view = isVideo
                    ? GridVideo(
                        updateOpacity: updateOpacity,
                        video: item,
                        thumbData:
                            item == widget.photo ? widget.thumbData : null,
                        toggleTitle: toggleTitle,
                        showTitle: showTitle,
                      )
                    : GridPhoto(
                        updateOpacity: updateOpacity,
                        photo: item,
                        thumbData:
                            item == widget.photo ? widget.thumbData : null,
                        toggleTitle: toggleTitle,
                        showTitle: showTitle,
                      );
                return Container(child: view);
              },
              itemCount: widget.list.length,
              onPageChanged: (int index) {
                print('current index $index');
                if (mounted) {
                  setState(() {
                    currentItem = widget.list[index];
                  });
                }
              },
            ),
          ),
          // title
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height - 80,
            child: showTitle
                ? Material(
                    color: Color.fromARGB(240, 255, 255, 255),
                    elevation: 2.0,
                    child: SafeArea(
                      child: StoreConnector<AppState, AppState>(
                        converter: (store) => store.state,
                        builder: (context, state) {
                          return Container(
                            color: Colors.transparent,
                            padding: EdgeInsets.only(top: 4, bottom: 4),
                            child: Row(
                              children: <Widget>[
                                Container(width: 4),
                                IconButton(
                                  icon: Icon(Icons.close),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                ),
                                Container(width: 16),
                                Expanded(flex: 1, child: Container()),
                                IconButton(
                                  icon: Icon(Icons.share),
                                  onPressed: () =>
                                      _share(context, currentItem, state),
                                ),
                                IconButton(
                                  icon: Icon(Icons.file_download),
                                  onPressed: () =>
                                      _download(context, currentItem, state),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () =>
                                      _delete(context, currentItem, state),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : Container(),
          ),
        ],
      ),
    );
  }
}
