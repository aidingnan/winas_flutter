import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/cache.dart';
import './cupertino_progress_bar.dart';

const videoTypes = 'RM.RMVB.WMV.AVI.MP4.3GP.MKV.MOV.FLV.MPEG';

class GridVideo extends StatefulWidget {
  const GridVideo({
    Key key,
    this.video,
    this.thumbData,
    this.updateOpacity,
    this.toggleTitle,
    this.showTitle,
  }) : super(key: key);
  final Uint8List thumbData;
  final Entry video;
  final Function updateOpacity;
  final Function toggleTitle;
  final bool showTitle;

  @override
  _GridVideoState createState() => _GridVideoState();
}

class _GridVideoState extends State<GridVideo>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Offset> _flingAnimation;
  Offset _offset = Offset.zero;
  ImageInfo info;

  /// VideoPlayerController.value()
  ///
  /// ```
  /// VideoPlayerValue(
  ///   duration: 0:02:30.300000,
  ///   size: Size(480.0, 220.0),
  ///   position: 0:00:14.416000,
  ///   buffered: [],
  ///   isPlaying: false,
  ///   isLooping: false,
  ///   isBuffering: falsevolume: 1.0,
  ///   errorDescription: null
  /// )
  /// ```
  VideoPlayerController vpc;
  ChewieController chewieController;
  Widget playerWidget;
  bool showDetails = false;
  double detailTop = double.negativeInfinity;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addListener(_handleFlingAnimation);
    thumbData = widget.thumbData;
  }

  @override
  void dispose() {
    _controller?.dispose();
    vpc?.pause();
    vpc?.dispose();
    chewieController?.pause();
    chewieController?.dispose();
    super.dispose();
  }

  Size getTrueSize() {
    final clientW = context.size.width;
    final clientH = context.size.height;
    if (info is ImageInfo) {
      final w = info.image.width;
      final h = info.image.height;
      if (w / h > clientW / clientH) {
        return Size(clientW, h / w * clientW);
      }
      return Size(w / h * clientH, clientH);
    } else {
      return Size(clientW, clientH);
    }
  }

  /// top of detail widget
  double getDetailTop() {
    // hidden detail widget
    if (!showDetails && detailTop != double.negativeInfinity) {
      return double.infinity;
    }
    // move detail widget up
    if (_offset.dy >= detailTop) {
      // speed of detail widget appear
      final speed = 480;
      return 240 + speed * (1 - _offset.dy / detailTop);
    } else {
      // move detail widget over maxtop
      return 480 - (_offset.dy / detailTop) * 240;
    }
  }

  void _handleFlingAnimation() {
    setState(() {
      _offset = _flingAnimation.value;
    });
  }

  double opacity = 1;

  updateOpacity() {
    widget.updateOpacity(opacity);
  }

  Offset prevPosition;

  bool isPlaying = false;
  bool playFired = false;

  Future<void> playVideo() async {
    await chewieController.play();
    setState(() {
      isPlaying = true;
      playFired = true;
    });
  }

  Future<void> pauseVideo() async {
    await chewieController.pause();
    setState(() {
      isPlaying = false;
    });
  }

  void _skipBack() {
    final beginning = Duration(seconds: 0).inMilliseconds;
    final skip = (_latestValue.position - Duration(seconds: 15)).inMilliseconds;
    vpc.seekTo(Duration(milliseconds: math.max(skip, beginning)));
  }

  void _skipForward() {
    final end = _latestValue.duration.inMilliseconds;
    final skip = (_latestValue.position + Duration(seconds: 15)).inMilliseconds;
    vpc.seekTo(Duration(milliseconds: math.min(skip, end)));
  }

  /// on Detail Vertical Drag Start
  void onDetailVerticalDragStart(DragStartDetails detail) {
    opacity = 1;

    // toggle title
    canceled = true;

    // update opacity
    updateOpacity();
    setState(() {
      prevPosition = detail.globalPosition;
      _controller.stop();
    });
  }

  /// on Detail Vertical Drag Update
  void onDetailVerticalDragUpdate(DragUpdateDetails details) {
    Offset delta = details.globalPosition - prevPosition;

    // quick fix bug of Twofingers drag which not recognized as scale
    if (delta.distance > 32) delta = Offset(0, 0);
    prevPosition = details.globalPosition;
    // print('onDetailVerticalDragUpdate $details $delta');
    setState(() {
      // Ensure that image location under the focal point stays in the same place despite scaling.
      _offset = _offset + Offset(0, delta.dy);
    });
  }

  /// on Detail Vertical Drag End
  void onDetailVerticalDragEnd(DragEndDetails details) {
    /// dy > 0: drag down
    /// dy < 0: drag up
    final dy = details.velocity.pixelsPerSecond.dy;

    final double magnitude = details.velocity.pixelsPerSecond.distance;

    // drag image up, show image detail
    if (_offset.dy < 0.0 && dy < 0) {
      final Size size = getTrueSize();
      final bottomHeight = (context.size.height - size.height) / 2;
      final deltaH = (context.size.height - 240.0 - bottomHeight) * -1;
      _flingAnimation = _controller
          .drive(Tween<Offset>(begin: _offset, end: Offset(0, deltaH)));

      // show title
      widget.toggleTitle(show: true);
      setState(() {
        detailTop = deltaH;
        showDetails = true;
      });
    } else {
      // return to center
      _flingAnimation =
          _controller.drive(Tween<Offset>(begin: _offset, end: Offset(0, 0)));

      setState(() {
        detailTop = double.negativeInfinity;
        showDetails = false;
      });
    }
    opacity = 1.0;
    updateOpacity();

    _controller
      ..value = 0.0
      ..fling(velocity: magnitude / 1000.0);
  }

  Future<ImageInfo> _getImage(imageProvider) {
    final Completer completer = Completer<ImageInfo>();
    final ImageStream stream =
        imageProvider.resolve(const ImageConfiguration());
    final listener = (ImageInfo info, bool synchronousCall) {
      if (!completer.isCompleted) {
        completer.complete(info);
      }
    };
    stream.addListener(listener);
    completer.future.then((_) {
      stream.removeListener(listener);
    });
    return completer.future;
  }

  VideoPlayerValue _latestValue;
  void _updateState() {
    setState(() {
      _latestValue = vpc.value;
    });
  }

  Uint8List imageData;
  Uint8List thumbData;

  _getPhoto(AppState state) async {
    final cm = await CacheManager.getInstance();

    // download thumb
    if (thumbData == null) {
      thumbData = await cm.getThumbData(widget.video, state);
    }

    info = await _getImage(MemoryImage(thumbData));

    if (this.mounted) {
      print('thumbData updated');
      setState(() {});
    } else {
      return;
    }
    // is video
    final ext = widget.video.metadata.type;

    final apis = state.apis;
    // preview video
    if (apis.isCloud) return;

    final key = await cm.getRandomKey(widget.video, state);
    if (key == null) return;

    final String url =
        'http://${apis.lanIp}:3000/media/$key.${ext.toLowerCase()}';

    print('${widget.video.name}, url: $url, $mounted');

    // keep singleton
    if (vpc != null) return;

    vpc = VideoPlayerController.network(url);
    vpc.addListener(_updateState);
    double aspectRatio;
    final meta = widget.video.metadata;
    if (meta.width != null && meta.height != null && meta.width != 0) {
      aspectRatio = meta.width / meta.height;
      if ([90, 270].contains(meta.rot)) {
        aspectRatio = 1 / aspectRatio;
      }
    }

    print('aspectRatio $aspectRatio, $meta');
    chewieController = ChewieController(
      videoPlayerController: vpc,
      aspectRatio: aspectRatio,
      autoInitialize: true,
      autoPlay: false,
      looping: false,
      showControls: false,
    );

    playerWidget = Chewie(
      controller: chewieController,
    );

    if (this.mounted) {
      setState(() {});
    }
  }

  int lastTapTime = 0;

  /// milliseconds of double tap's delay
  final timeDelay = 300;

  /// whether background Color is red
  bool showBlack = false;

  /// handle double tap
  bool canceled = false;
  void handleTapUp(TapUpDetails event) {
    final tapTime = DateTime.now().millisecondsSinceEpoch;
    if (tapTime - lastTapTime < timeDelay) {
      canceled = true;
      widget.toggleTitle(show: false);
      Offset offsetEnd;

      offsetEnd = Offset(context.size.width / -2, context.size.height / -2);

      _flingAnimation =
          _controller.drive(Tween<Offset>(begin: _offset, end: offsetEnd));

      _controller
        ..value = 0.0
        ..fling(velocity: 1.0);
    } else {
      canceled = false;
      Future.delayed(Duration(milliseconds: timeDelay))
          .then((v) => canceled ? null : widget.toggleTitle());
    }
    lastTapTime = tapTime;
  }

  Widget detailRow(Widget icon, String mainText, String subText) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          icon,
          Container(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(child: Text(mainText)),
              Container(height: 8),
              Container(
                child: Text(subText, style: TextStyle(color: Colors.black38)),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget renderDetail() {
    final video = widget.video;
    final metadata = video.metadata;

    // fullDate
    final date = metadata.fullDate ?? prettyDate(video.bctime ?? video.mtime);
    final List<int> list = List.from(date
        .replaceAll(' ', '-')
        .replaceAll(':', '-')
        .split('-')
        .map((s) => int.parse(s)));

    // week day
    final weekday =
        getWeekday(DateTime(list[0], list[1], list[2], list[3], list[4]));

    // image pixel
    final pixel = getPixel(metadata.width * metadata.height);
    // image resolution
    final resolution = '${metadata.width} x ${metadata.height}';

    // image size
    final size = prettySize(video.size);

    final rowList = [
      Container(
        margin: EdgeInsets.all(16),
        child: Text('详情', style: TextStyle(fontSize: 18)),
      ),
      detailRow(Icon(Icons.insert_drive_file), video.name, size),
      detailRow(Icon(Icons.calendar_today), date, weekday),
      detailRow(Icon(Icons.image), pixel, resolution),
    ];
    if (metadata.model != null && metadata.make != null) {
      rowList.add(detailRow(Icon(Icons.camera), metadata.model, metadata.make));
    }

    return GestureDetector(
      onVerticalDragStart: onDetailVerticalDragStart,
      onVerticalDragUpdate: onDetailVerticalDragUpdate,
      onVerticalDragEnd: onDetailVerticalDragEnd,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowList,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppState>(
      onInit: (store) => _getPhoto(store.state),
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (context, state) {
        return Container(
          color: widget.showTitle
              ? Color.fromARGB((opacity * 255).round(), 255, 255, 255)
              : Color.fromARGB((opacity * 255).round(), 0, 0, 0),
          child: Stack(
            children: <Widget>[
              // thumbnail
              Positioned.fill(
                child: thumbData == null
                    ? Center(child: CircularProgressIndicator())
                    : playerWidget != null
                        ? Container()
                        : Image.memory(
                            thumbData,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
              ),

              // video
              Positioned.fill(
                child: playerWidget == null
                    ? Center(child: CircularProgressIndicator())
                    : GestureDetector(
                        onTapUp: handleTapUp,
                        child: Container(
                          color: Colors.transparent,
                          height: double.infinity,
                          width: double.infinity,
                          child: playerWidget,
                        ),
                      ),
              ),

              // large play button in center
              Positioned.fill(
                child: Center(
                  child: !isPlaying && widget.showTitle
                      ? Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.black54,
                              size: 32,
                            ),
                            onPressed: () =>
                                isPlaying ? pauseVideo() : playVideo(),
                          ),
                        )
                      : Container(),
                ),
              ),

              // controller
              Positioned(
                left: 8,
                right: 8,
                bottom: 16,
                // final orientation = MediaQuery.of(context).orientation;
                // final barHeight = orientation == Orientation.portrait ? 30.0 : 47.0;
                // final buttonPadding = orientation == Orientation.portrait ? 16.0 : 24.0;
                height: 40,
                child: playFired && widget.showTitle
                    ? ClipRRect(
                        borderRadius: BorderRadius.all(
                          Radius.circular(28),
                        ),
                        child: Container(
                          color: Color.fromRGBO(41, 41, 41, 0.7),
                          child: Row(
                            children: <Widget>[
                              // skipback
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.skewY(0.0)
                                  ..rotateX(math.pi)
                                  ..rotateZ(math.pi),
                                child: IconButton(
                                  padding: EdgeInsets.all(0),
                                  icon: Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  onPressed: _skipBack,
                                ),
                              ),

                              // play/pause
                              GestureDetector(
                                onTap: () =>
                                    isPlaying ? pauseVideo() : playVideo(),
                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),

                              // skipforward
                              IconButton(
                                padding: EdgeInsets.all(0),
                                icon: Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                onPressed: _skipForward,
                              ),

                              // play position
                              Text(
                                formatDuration(_latestValue.position),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                ),
                              ),
                              Container(width: 12),

                              // progress bar
                              Expanded(
                                flex: 1,
                                child: CupertinoVideoProgressBar(
                                  vpc,
                                  onDragStart: () {
                                    print('onDragStart');
                                  },
                                  onDragEnd: () {
                                    print('onDragEnd');
                                  },
                                ),
                              ),
                              Container(width: 12),

                              // remaining time
                              Text(
                                formatDuration(
                                  _latestValue.duration ??
                                      Duration.zero - _latestValue.position ??
                                      Duration.zero,
                                ),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                ),
                              ),
                              Container(width: 12),
                            ],
                          ),
                        ),
                      )
                    : Container(),
              )
            ],
          ),
        );
      },
    );
  }
}
