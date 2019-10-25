import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/cache.dart';
import '../common/placeHolderImage.dart';

const double _kMinFlingVelocity = 800.0;

class GridPhoto extends StatefulWidget {
  const GridPhoto({
    Key key,
    this.photo,
    this.thumbData,
    this.updateOpacity,
    this.toggleTitle,
    this.showTitle,
  }) : super(key: key);
  final Uint8List thumbData;
  final Entry photo;
  final Function updateOpacity;
  final Function toggleTitle;
  final bool showTitle;

  @override
  _GridPhotoState createState() => _GridPhotoState();
}

class _GridPhotoState extends State<GridPhoto>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Offset> _flingAnimation;
  Animation<double> _scaleAnimation;
  Offset _offset = Offset.zero;
  ImageInfo info;
  double _scale = 1.0;
  Offset _normalizedOffset;
  double _previousScale;
  Widget playerWidget;
  bool showDetails = false;
  double detailTop = double.negativeInfinity;
  Uint8List imageData;
  Uint8List thumbData;
  Image _imageThumb;
  Image _imageRaw;
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
    // prevent memory leak
    info = null;
    playerWidget = null;

    /// manual clean iamge cache
    imageData = null;
    thumbData = null;

    if (_imageThumb != null) {
      _imageThumb.image.evict().catchError(print);
      _imageThumb = null;
    }
    if (_imageRaw != null) {
      _imageRaw.image.evict().catchError(print);
      _imageRaw = null;
    }

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

  // keep value in maximum and minimum offset value
  Offset _clampOffset(Offset offset) {
    final Size size = getTrueSize();

    double maxDx =
        context.size.width - (context.size.width + size.width) / 2 * _scale;

    double minDx = (size.width - context.size.width) / 2 * _scale;

    // keep min < max
    if (maxDx < minDx) {
      final tmp = maxDx;
      maxDx = minDx;
      minDx = tmp;
    }

    // max dy = H - (H + h) / 2 * scale
    double maxDy =
        context.size.height - (context.size.height + size.height) / 2 * _scale;
    // min dy
    double minDy = (size.height - context.size.height) / 2 * _scale;

    if (maxDy < minDy) {
      final tmp = maxDy;
      maxDy = minDy;
      minDy = tmp;
    }

    final res =
        Offset(offset.dx.clamp(minDx, maxDx), offset.dy.clamp(minDy, maxDy));
    return res;
  }

  void _handleFlingAnimation() {
    setState(() {
      _offset = _flingAnimation.value;
      _scale = _scaleAnimation.value;
    });
  }

  double opacity = 1;

  updateOpacity() {
    widget.updateOpacity(opacity);
  }

  Offset prevPosition;

  /// ⤡⤢ Scale Start
  void _handleOnScaleStart(ScaleStartDetails details) {
    opacity = 1;
    prevPosition = details.focalPoint;

    // toggle title
    canceled = true;
    // widget.toggleTitle(show: false);

    // update opacity
    updateOpacity();
    setState(() {
      _previousScale = _scale;
      _normalizedOffset = (details.focalPoint - _offset) / _scale;
      // The fling animation stops if an input gesture starts.
      _controller.stop();
    });
  }

  /// ⤡⤢ Scale Update
  void _handleOnScaleUpdate(ScaleUpdateDetails details) {
    if (_scale == 1.0 && details.scale == 1.0) {
      /// rate of downScale to close viewer
      final rate = 255;

      Offset delta = details.focalPoint - prevPosition;
      prevPosition = details.focalPoint;
      if (delta.dy < 0 && _offset.dy == 0) {
        setState(() {
          showDetails = true;
        });
      }

      _offset += delta;

      // prevent move vertically when drag up
      if (_offset.dy < 0 && showDetails) {
        _offset = Offset(0.0, _offset.dy);
      }

      opacity = (1 - _offset.dy / rate).clamp(0.0, 1.0);

      updateOpacity();
      setState(() {});
    } else {
      setState(() {
        _scale = (_previousScale * details.scale).clamp(1.0, 8.0);
        // Ensure that image location under the focal point stays in the same place despite scaling.
        _offset = _clampOffset(details.focalPoint - _normalizedOffset * _scale);
        showDetails = false;
      });
    }
  }

  /// ⤡⤢ Scale End
  void _handleOnScaleEnd(ScaleEndDetails details) {
    /// dy > 0: drag down
    /// dy < 0: drag up
    final dy = details.velocity.pixelsPerSecond.dy;

    // drag image down, discard image view
    if (opacity <= 0.8 && dy > 0) {
      Navigator.pop(context);
      return;
    }

    _scaleAnimation =
        _controller.drive(Tween<double>(begin: _scale, end: _scale));
    final double magnitude = details.velocity.pixelsPerSecond.distance;

    // drag image up, show image detail
    if (_offset.dy < 0.0 && _scale == 1.0 && dy < 0) {
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
    } else if (_scale == 1.0) {
      // return to center
      _flingAnimation =
          _controller.drive(Tween<Offset>(begin: _offset, end: Offset(0, 0)));

      setState(() {
        detailTop = double.negativeInfinity;
        showDetails = false;
      });
    } else {
      // fling after move
      if (magnitude < _kMinFlingVelocity) return;
      final Offset direction = details.velocity.pixelsPerSecond / magnitude;
      final double distance = (Offset.zero & context.size).shortestSide;
      _flingAnimation = _controller.drive(Tween<Offset>(
          begin: _offset, end: _clampOffset(_offset + direction * distance)));
    }
    opacity = 1.0;
    updateOpacity();

    _controller
      ..value = 0.0
      ..fling(velocity: magnitude / 1000.0);
  }

  /// ←→ Horizontal Drag Start
  void _handleHDragStart(DragStartDetails detail) {
    opacity = 1;

    // toggle title
    canceled = true;
    widget.toggleTitle(show: false);

    // update opacity
    updateOpacity();
    setState(() {
      _previousScale = _scale;
      prevPosition = detail.globalPosition;
      _controller.stop();
    });
  }

  /// ←→ Horizontal Drag Update
  void _handleHDragUpdate(DragUpdateDetails details) {
    Offset delta = details.globalPosition - prevPosition;

    // quick fix bug of Twofingers drag which not recognized as scale
    if (delta.distance > 32) delta = Offset(0, 0);
    prevPosition = details.globalPosition;

    setState(() {
      // Ensure that image location under the focal point stays in the same place despite scaling.
      _offset = _clampOffset(_offset + delta);
    });
  }

  /// ←→ on Horizontal Drag End
  void _handleHDragEnd(DragEndDetails detail) {
    if (opacity <= 0.8) {
      Navigator.pop(context);
      return;
    }
    _scaleAnimation =
        _controller.drive(Tween<double>(begin: _scale, end: _scale));
    final double magnitude = detail.velocity.pixelsPerSecond.distance;

    if (_scale == 1.0) {
      // return to center
      _flingAnimation =
          _controller.drive(Tween<Offset>(begin: _offset, end: Offset(0, 0)));
    } else {
      // fling after move
      if (magnitude < _kMinFlingVelocity) return;
      final Offset direction = detail.velocity.pixelsPerSecond / magnitude;
      final double distance = (Offset.zero & context.size).shortestSide;
      _flingAnimation = _controller.drive(Tween<Offset>(
          begin: _offset, end: _clampOffset(_offset + direction * distance)));
    }
    opacity = 1.0;
    updateOpacity();

    _controller
      ..value = 0.0
      ..fling(velocity: magnitude / 1000.0);
  }

  /// ↑↓ Detail Vertical Drag Start
  void _onDetailVerticalDragStart(DragStartDetails detail) {
    opacity = 1;

    // toggle title
    canceled = true;

    // update opacity
    updateOpacity();
    setState(() {
      _previousScale = _scale;
      prevPosition = detail.globalPosition;
      _controller.stop();
    });
  }

  /// ↑↓ Detail Vertical Drag Update
  void _onDetailVerticalDragUpdate(DragUpdateDetails details) {
    Offset delta = details.globalPosition - prevPosition;

    // quick fix bug of Twofingers drag which not recognized as scale
    if (delta.distance > 32) delta = Offset(0, 0);
    prevPosition = details.globalPosition;
    setState(() {
      // Ensure that image location under the focal point stays in the same place despite scaling.
      _offset = _offset + Offset(0, delta.dy);
    });
  }

  /// ↑↓ Detail Vertical Drag End
  void _onDetailVerticalDragEnd(DragEndDetails details) {
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

  int lastTapTime = 0;

  /// milliseconds of double tap's delay
  final timeDelay = 300;

  /// scale rate when double tap
  final scaleRate = 2.0;

  /// whether background Color is red
  bool showBlack = false;

  /// handle double tap
  bool canceled = false;
  void _handleTapUp(TapUpDetails event) {
    final tapTime = DateTime.now().millisecondsSinceEpoch;
    if (tapTime - lastTapTime < timeDelay) {
      canceled = true;
      widget.toggleTitle(show: false);
      double scaleEnd;
      Offset offsetEnd;
      if (_scale == 1.0) {
        scaleEnd = scaleRate;
        offsetEnd = Offset(context.size.width / -2, context.size.height / -2);
      } else {
        scaleEnd = 1.0;
        offsetEnd = Offset(0, 0);
      }

      _flingAnimation =
          _controller.drive(Tween<Offset>(begin: _offset, end: offsetEnd));

      _scaleAnimation =
          _controller.drive(Tween<double>(begin: _scale, end: scaleEnd));

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

  /// get image info via MemoryImage
  Future<ImageInfo> _getImage(Uint8List imageData) {
    // no image data
    if (imageData == null) return Future.value(null);

    // use MemoryImage to load image
    final imageProvider = MemoryImage(imageData);
    final Completer completer = Completer<ImageInfo>();
    final ImageStream stream =
        imageProvider.resolve(const ImageConfiguration());
    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(info);
        }
      },
    );

    stream.addListener(listener);
    completer.future.then((_) {
      stream.removeListener(listener);
      imageProvider.evict().catchError(print);
    });
    return completer.future;
  }

  Future<void> _getThumb(AppState state, CacheManager cm) async {
    // download thumb
    if (thumbData == null) {
      thumbData = await cm.getThumbData(widget.photo, state);
    }
    if (!this.mounted) {
      thumbData = null;
      return;
    }
    if (imageData == null || info == null) {
      info = await _getImage(thumbData);
    }
    if (thumbData != null && this.mounted) {
      setState(() {});
    } else {
      info = null;
      thumbData = null;
    }
  }

  Future<void> _getRawImage(AppState state, CacheManager cm) async {
    // download raw photo
    if (widget.photo?.metadata?.type == 'HEIC') {
      imageData = await cm.getHEICPhoto(widget.photo, state);
    } else {
      imageData = await cm.getPhoto(widget.photo, state);
    }

    // imageData = await cm.getLargePhoto(widget.photo, state);
    if (!this.mounted) {
      imageData = null;
      return;
    }
    info = await _getImage(imageData);
    if (imageData != null && this.mounted) {
      setState(() {});
    } else {
      info = null;
      imageData = null;
    }
  }

  _getPhoto(AppState state) async {
    final cm = await CacheManager.getInstance();
    await Future.wait([_getRawImage(state, cm), _getThumb(state, cm)]);
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
    final photo = widget.photo;
    final metadata = photo.metadata;

    // fullDate
    final date = metadata.fullDate ?? prettyDate(photo.bctime ?? photo.mtime);
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
    final size = prettySize(photo.size);

    final rowList = [
      Container(
        margin: EdgeInsets.all(16),
        child: Text(i18n('Detail'), style: TextStyle(fontSize: 18)),
      ),
      detailRow(Icon(Icons.insert_drive_file), photo.name, size),
      detailRow(Icon(Icons.calendar_today), date, weekday),
      detailRow(Icon(Icons.image), pixel, resolution),
    ];
    if (metadata.model != null && metadata.make != null) {
      rowList.add(detailRow(Icon(Icons.camera), metadata.model, metadata.make));
    }

    return GestureDetector(
      onVerticalDragStart: _onDetailVerticalDragStart,
      onVerticalDragUpdate: _onDetailVerticalDragUpdate,
      onVerticalDragEnd: _onDetailVerticalDragEnd,
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
        _imageThumb = Image.memory(
          thumbData ?? placeHolderImage,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
        _imageRaw = Image.memory(
          imageData ?? thumbData ?? placeHolderImage,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
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
                        : GestureDetector(
                            onScaleStart: _handleOnScaleStart,
                            onScaleUpdate: _handleOnScaleUpdate,
                            onScaleEnd: _handleOnScaleEnd,
                            onTapUp: _handleTapUp,
                            child: ClipRect(
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..translate(_offset.dx, _offset.dy)
                                  ..scale(_scale),
                                child: _imageThumb,
                              ),
                            ),
                          ),
              ),

              // photo
              Positioned.fill(
                child: thumbData == null && imageData == null
                    ? Center(child: CircularProgressIndicator())
                    : playerWidget != null
                        ? GestureDetector(
                            onTapUp: _handleTapUp,
                            child: playerWidget,
                          )
                        : GestureDetector(
                            onScaleStart: _handleOnScaleStart,
                            onScaleUpdate: _handleOnScaleUpdate,
                            onScaleEnd: _handleOnScaleEnd,
                            onHorizontalDragUpdate:
                                _scale == 1.0 ? null : _handleHDragUpdate,
                            onHorizontalDragStart:
                                _scale == 1.0 ? null : _handleHDragStart,
                            onHorizontalDragEnd:
                                _scale == 1.0 ? null : _handleHDragEnd,
                            onTapUp: _handleTapUp,
                            child: ClipRect(
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..translate(_offset.dx, _offset.dy)
                                  ..scale(_scale),
                                child: _imageRaw,
                              ),
                            ),
                          ),
              ),

              // details
              Positioned(
                left: 0,
                right: 0,
                top: getDetailTop(),
                height: showDetails ? 480 : 0,
                child:
                    showDetails && _scale == 1 ? renderDetail() : Container(),
              ),

              // CircularProgressIndicator
              imageData == null && playerWidget == null
                  ? Center(child: CircularProgressIndicator())
                  : Container(),
            ],
          ),
        );
      },
    );
  }
}
