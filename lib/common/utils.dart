import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:device_info/device_info.dart';
import 'package:package_info/package_info.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_umplus/flutter_umplus.dart';

import './iPhoneCodeMap.dart';

/// showSnackBar, require BuildContext to find Scaffold
void showSnackBar(BuildContext ctx, String message) {
  final snackBar = SnackBar(
    content: Text(message),
    duration: Duration(seconds: 3),
  );

  // Find the Scaffold in the Widget tree and use it to show a SnackBar!
  Scaffold.of(ctx, nullOk: true)?.showSnackBar(snackBar);
  // Scaffold.of(ctx).showSnackBar(snackBar);
}

class FakeProgress extends StatefulWidget {
  FakeProgress({Key key, this.targetTime, this.text}) : super(key: key);

  /// target time that progress should finished (seconds)
  final double targetTime;

  // text to show doing
  final String text;
  @override
  _FakeProgressState createState() => _FakeProgressState();
}

class _FakeProgressState extends State<FakeProgress> {
  double progress = 0;
  Timer timer;

  void refreshProgress() {
    setState(() {
      progress += (1 - progress) / widget.targetTime / 10;
    });
  }

  @override
  void initState() {
    // widget.targetTime
    super.initState();

    timer = Timer.periodic(Duration(milliseconds: 100), (Timer t) {
      if (mounted) {
        refreshProgress();
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final text = widget.text ?? i18n('Progressing');
    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4.0,
      child: Container(
        width: 240,
        height: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(16),
              child: Text(text, style: TextStyle(fontSize: 18)),
            ),
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Expanded(
                      flex: 1,
                      child: LinearProgressIndicator(
                        value: progress,
                        valueColor: AlwaysStoppedAnimation(Colors.teal),
                        backgroundColor: Colors.grey[200],
                      )),
                  // Container(width: 16),
                  // Text('${(progress * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingInstance {
  PageRoute route;
  BuildContext context;
  bool isLoading = true;

  LoadingInstance(this.context, this.route);

  void close() {
    if (isLoading == true) {
      Navigator.removeRoute(context, route);
      isLoading = false;
    }
  }
}

/// Show modal loading
///
/// use `loadingInstance.close()` to finish loading
LoadingInstance showLoading(BuildContext context,
    {double fakeProgress, String text}) {
  final router = TransparentPageRoute(
    builder: (_) => WillPopScope(
      onWillPop: () => Future.value(false),
      child: Container(
        constraints: BoxConstraints.expand(),
        child: Center(
          child: fakeProgress != null
              ? FakeProgress(targetTime: fakeProgress, text: text)
              : CircularProgressIndicator(),
        ),
      ),
    ),
  );
  final loadingInstance = LoadingInstance(context, router);
  Navigator.push(context, router);
  return loadingInstance;
}

class Model {
  Model();
  bool close = false;
  bool get shouldClose => close;
}

/// fire just once
/// ```
/// if (justonce?.fired == false) {
///   // dosomething
///   // ...
///   justonce.fire();
/// }
/// ```
class Justonce {
  bool fired = false;
  Function callback;
  Future<void> fire(props) async {
    this.fired = true;
    if (callback is Function) {
      await callback(props);
    }
  }
}

class Progress extends StatefulWidget {
  Progress({Key key, this.ctrl, this.onCancel}) : super(key: key);
  final StreamController<double> ctrl;
  final Function onCancel;
  @override
  _ProgressState createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  double progress = 0;

  @override
  void initState() {
    widget.ctrl.stream.listen((value) {
      progress = value.clamp(0, 1);
      setState(() {});
    });
    super.initState();
  }

  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(16),
          child: Text(i18n('Caching File'), style: TextStyle(fontSize: 18)),
        ),
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                  flex: 1,
                  child: LinearProgressIndicator(
                    value: progress,
                    valueColor: AlwaysStoppedAnimation(Colors.teal),
                    backgroundColor: Colors.grey[200],
                  )),
              Container(width: 16),
              Text('${(progress * 100).toStringAsFixed(1)}%'),
            ],
          ),
        ),
        Container(
          child: Row(
            children: <Widget>[
              Expanded(flex: 1, child: Container()),
              FlatButton(
                child: Text(
                  i18n('Cancel'),
                  style: TextStyle(color: Colors.redAccent),
                ),
                onPressed: widget.onCancel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Downloading dialog with progress
class DownloadingDialog {
  double progress = 0;
  final BuildContext ctx;
  bool canceled = false;
  bool closed = false;
  final int total;
  DownloadingDialog(this.ctx, this.total);
  CancelToken cancelToken = CancelToken();

  Model model = Model();

  final StreamController<double> ctrl = StreamController();

  openDialog<T>() {
    showDialog<T>(
      context: ctx,
      builder: (BuildContext context) => WillPopScope(
        onWillPop: () => Future.value(model.shouldClose),
        child: SimpleDialog(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          children: <Widget>[
            Progress(
              ctrl: ctrl,
              onCancel: cancel,
            ),
          ],
        ),
      ),
    ).then<void>((T value) {});
  }

  void cancel() {
    canceled = true;
    cancelToken.cancel();
    close();
  }

  void close() {
    if (closed) return;
    closed = true;
    model.close = true;
    ctrl.close();
    Navigator.pop(ctx);
  }

  void onProgress(int a, int b) {
    if (closed) return;
    progress = a / total;
    ctrl.sink.add(progress);
  }
}

/// Provide pretty printed file sizes
String prettySize(num size) {
  if (size == null || size < 0 || size == double.infinity) return '';
  if (size < 800) return '${size.toInt()} B';
  if (size < 1024 * 800) return '${(size / 1024).toStringAsFixed(2)} KB';
  if (size < 1024 * 1024 * 800)
    return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
  return '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String twoDigits(int n) {
  if (n >= 10) return "$n";
  return "0$n";
}

/// Provide pretty printed date time, result:
///
/// date == false: 2019-03-06 17:46
///
/// date == true: 2019-03-06
String prettyDate(int time, {bool showDay: false, bool showMonth: false}) {
  if (time == null) return '';
  var t = DateTime.fromMillisecondsSinceEpoch(time);
  var year = t.year;
  var month = twoDigits(t.month);
  var day = twoDigits(t.day);
  var hour = twoDigits(t.hour);
  var minute = twoDigits(t.minute);
  if (showMonth) return '$year-$month';
  if (showDay) return '$year-$month-$day';
  return '$year-$month-$day $hour:$minute';
}

/// get DateTime.now().millisecondsSinceEpoch
int getNow() => DateTime.now().millisecondsSinceEpoch;

const weekDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// get weekday: 7 => i18n('Sunday')
String getWeekday(DateTime dt) => i18n(weekDays[dt.weekday - 1]);

/// get Pixel: 10000 => 0.01 MP
String getPixel(int p) {
  if (p == null || p < 0) return '';
  if (p < 10000) return i18nPlural('Pixels', p);
  if (p < 10000 * 10000)
    return i18n(
      '001 Million Pixels',
      {
        'count': (p / 10000).toStringAsFixed(2),
        'million': (p / 1000000).toStringAsFixed(2),
      },
    );

  return i18n(
    '100 Million Pixels',
    {
      'count': (p / 100000000).toStringAsFixed(2),
      'million': (p / 1000000).toStringAsFixed(2),
    },
  );
}

/// Ellipsis Text
Widget ellipsisText(String text, {TextStyle style}) {
  return Expanded(
    child: Text(
      text ?? '',
      textAlign: TextAlign.end,
      overflow: TextOverflow.fade,
      softWrap: false,
      maxLines: 1,
      style: style,
    ),
    flex: 10,
  );
}

/// Full width action button with inkwell
Widget actionButton(String title, Function action, Widget rightItem) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: action,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 1.0, color: Colors.grey[200]),
          ),
        ),
        child: Container(
          height: 64,
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: <Widget>[
              Text(
                title,
                style: TextStyle(fontSize: 16),
              ),
              Expanded(
                flex: 1,
                child: Container(),
              ),
              rightItem ?? Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
}

/// actionButton as Sliver
Widget sliverActionButton(String title, Function action, Widget rightItem) {
  return SliverToBoxAdapter(child: actionButton(title, action, rightItem));
}

Future getMachineId() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String deviceName;
  String machineId;
  String model;
  if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    deviceName = iPhoneModel(iosInfo.utsname.machine);
    machineId = iosInfo.identifierForVendor;
    model = deviceName + ', Version ' + iosInfo.systemVersion;
  } else {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    deviceName = androidInfo.model;
    machineId = androidInfo.androidId;
    model = deviceName + ', Version ' + androidInfo.version.release;
  }
  return {
    'deviceName': deviceName,
    'machineId': machineId,
    'model': model,
  };
}

Future<String> getClientId() async {
  String clientId;
  try {
    final idRes = await getMachineId();
    clientId = idRes['machineId'];
  } catch (e) {
    clientId = 'default_mobile_clientId';
  }
  return clientId;
}

/// App version
Future<String> getAppVersion() async {
  String version = '';
  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    version = packageInfo.version;
  } catch (e) {
    print('getAppVersion failed');
    print(e);
    version = '';
  }
  return version;
}

/// Transparent PageRoute
class TransparentPageRoute extends PageRoute<void> {
  TransparentPageRoute({
    @required this.builder,
    RouteSettings settings,
  })  : assert(builder != null),
        super(settings: settings, fullscreenDialog: true);

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  Color get barrierColor => null;

  @override
  String get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration(milliseconds: 350);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final result = builder(context);
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(animation),
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: result,
      ),
    );
  }
}

/// handle error, convert dynamic error to String
///
String converError(dynamic error) {
  if (error is DioError) {
    if (error.message is String) if (error.message
        .contains('Connection refused')) {
      return i18n('Connection Refused Error');
    }
    if (error.message.contains('Connection closed')) {
      return i18n('Connection Closed Error');
    }

    return error.toString();
  }
  return error.toString();
}

/// copied from 'package:chewie/src/utils.dart'
String formatDuration(Duration position) {
  final ms = position.inMilliseconds;

  int seconds = ms ~/ 1000;
  final int hours = seconds ~/ 3600;
  seconds = seconds % 3600;
  var minutes = seconds ~/ 60;
  seconds = seconds % 60;

  final hoursString = hours >= 10 ? '$hours' : hours == 0 ? '00' : '0$hours';

  final minutesString =
      minutes >= 10 ? '$minutes' : minutes == 0 ? '00' : '0$minutes';

  final secondsString =
      seconds >= 10 ? '$seconds' : seconds == 0 ? '00' : '0$seconds';

  final formattedTime =
      '${hoursString == '00' ? '' : hoursString + ':'}$minutesString:$secondsString';

  return formattedTime;
}

/// i18n
/// cached BuildContext

BuildContext cachedBuildContext;

/// cacheContext in `login/login.dart`, `login/stationList.dart` and `nav/bottom_navigation.dart`
void cacheContext(BuildContext ctx) {
  cachedBuildContext = ctx;
  // print('currentLocale ${FlutterI18n.currentLocale(ctx)}  in $ctx');
}

Locale getCurrentLocale() => FlutterI18n.currentLocale(cachedBuildContext);

String i18n(String key, [Map<String, String> params]) {
  String result = '';
  try {
    result = FlutterI18n.translate(cachedBuildContext, key, params);
  } catch (e) {
    print('i18n error: $key');
    print(e);
    result = '';
  }
  return result;
}

String i18nPlural(String key, int count) {
  String translationKey = '$key.i';
  String result = '';
  try {
    result = FlutterI18n.plural(cachedBuildContext, translationKey, count);
  } catch (e) {
    print('i18nPlural failed $key');
    print(e);
    result = '';
  }
  return result;
}

Future<void> i18nRefresh(Locale languageCode) async {
  await FlutterI18n.refresh(cachedBuildContext, languageCode);
}

Future<void> writeLog(String log, String fileName) async {
  Directory root = await getApplicationDocumentsDirectory();
  await Directory(root.path + '/tmp/').create(recursive: true);
  File logFile = File(root.path + '/tmp/' + fileName);
  await logFile.writeAsString(log, mode: FileMode.append);
}

Future<String> getLogs() async {
  Directory root = await getApplicationDocumentsDirectory();
  File logFile = File(root.path + '/tmp/log.txt');
  String logs = await logFile.readAsString();
  return logs;
}

void debug(dynamic text, [dynamic t2, dynamic t3]) {
  final String trace = StackTrace.current.toString().split('\n')[1];
  String log =
      (text ?? '').toString() + (t2 ?? '').toString() + (t3 ?? '').toString();
  DateTime time = DateTime.now();
  if (text is DioError && text?.response?.data != null) {
    log += '\ntext.response.data: ${text.response.data}';
  }
  final str = '#### $time ####\n$trace\n$log\n';
  print(str);
  writeLog(str, 'log.txt').catchError(print);
  FlutterUmplus.event('DEBUG_LOG', label: str);
}

String getTimeString(DateTime time) {
  final y = time.year;
  final m = time.month;
  final d = time.day;
  final h = time.hour;
  final mi = time.minute;
  final s = time.second;
  final ms = time.millisecond;
  return '$y$m${d}_$h$mi$s$ms';
}

/// [Color Text,Status Text, True Color,True Status, Color for Text]
List<List<String>> getColorCodes() => [
      [i18n('Red Light'), i18n('Always On'), '#ff0000', 'alwaysOn', '#ff0000'],
      [i18n('Red Light'), i18n('Breath'), '#ff0000', 'breath', '#ff0000'],
      [
        i18n('White Light'),
        i18n('Always On'),
        '#ffffff',
        'alwaysOn',
        '#9e9e9e'
      ],
      [i18n('White Light'), i18n('Breath'), '#ffffff', 'breath', '#9e9e9e'],
      [i18n('Green Light'), i18n('Breath'), '#00ff00', 'breath', '#00ff00'],
      [i18n('Blue Light'), i18n('Always On'), '#0000ff', 'alwaysOn', '#0000ff'],
    ];

String getUsnName(String sn) {
  try {
    // Convert to number List
    final List<int> list = [];
    for (int i = 0; i <= 10; i += 2) {
      list.add(int.parse(sn.substring(4 + i, 6 + i), radix: 16));
    }

    // Convert to 8-bit bytes List
    List<String> a = List.from(list.map((f) {
      String v = f.toRadixString(2);
      return v.padLeft(8, '0');
    }));

    // Convert to fullString
    int number = int.parse(a.join('').substring(0, 13), radix: 2);
    int h1 = (number ~/ 96) + 10;
    int h2 = number % 96 + 3;

    // get value
    String v1 = h1.toString().padLeft(2, '0');
    String v2 = h2.toString().padLeft(2, '0');
    return 'pan-$v1$v2';
  } catch (e) {
    debug('getUsnName error: $sn');
    return 'pan-xxxx';
  }
}
