import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/request.dart';

final pColor = Colors.teal;

/// handle smscode and replace phone number
class SmsCode extends StatefulWidget {
  SmsCode({Key key, this.phone}) : super(key: key);
  final String phone;
  @override
  _SmsCodeState createState() => _SmsCodeState();
}

class _SmsCodeState extends State<SmsCode> {
  String _status = 'code';
  bool showPwd = true;

  // Focus action
  FocusNode focusNode1;
  FocusNode focusNode2;

  Request request = Request();
  String _code = '';

  String _phoneNumber = '';

  String _error;

  String _ticket;
  String _newTicket;

  @override
  void initState() {
    super.initState();

    focusNode1 = FocusNode();
    focusNode2 = FocusNode();

    _startCount();
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed
    focusNode1.dispose();
    focusNode2.dispose();

    _count = -1;

    super.dispose();
  }

  LoadingInstance _loadingInstance;

  /// show loading
  _loading(BuildContext ctx) {
    _loadingInstance = showLoading(ctx);
  }

  /// close loading
  _loadingOff() {
    _loadingInstance.close();
  }

  /// close loading, setState and focus node
  _nextPage(BuildContext context, String status, FocusNode node) {
    _loadingOff();
    setState(() {
      _status = status;
    });

    var future = Future.delayed(Duration(milliseconds: 100),
        () => FocusScope.of(context).requestFocus(node));
    future.then((res) => print('100ms later'));
  }

  /// handle SmsError: close loading, setState
  _handleSmsError(BuildContext context, DioError error) {
    _loadingOff();
    debug(error.response.data);
    if ([60702, 60003].contains(error.response.data['code'])) {
      showSnackBar(context, i18n('Request Verification Code Too Frquent'));
    } else {
      showSnackBar(context, i18n('Request Verification Code Failed'));
    }
    setState(() {});
  }

  /// nextStep for reset password
  _nextStep(BuildContext context, AppState state) async {
    if (_status == 'code') {
      // check code
      if (_code.length != 4) {
        setState(() {
          _error = i18n('Verification Code Input Text');
        });
        return;
      }

      // request smsTicket via code
      _ticket = null;
      _loading(context);
      try {
        final res = await request.req('smsTicket', {
          'code': _code,
          'phone': widget.phone,
          'type': 'replace',
        });

        _ticket = res.data;
      } catch (error) {
        _loadingOff();
        setState(() {
          _error = i18n('Verification Code Error');
        });
        return;
      }

      // show next page
      _nextPage(context, 'newPhone', focusNode1);
    } else if (_status == 'newPhone') {
      // check phoneNumber
      if (_phoneNumber.length != 11 || !_phoneNumber.startsWith('1')) {
        setState(() {
          _error = i18n('Invalid Phone Number');
        });
        return;
      }

      // request smsCode
      _loading(context);

      bool userExist = true;
      try {
        final res = await request.req('checkUser', {'phone': _phoneNumber});
        userExist = res.data['userExist'];
      } catch (error) {
        _loadingOff();
        showSnackBar(context, i18n('Check Phone Number Failed'));
        setState(() {});
        return;
      }

      if (userExist) {
        _loadingOff();
        showSnackBar(context, i18n('Phone Bind to Another Accout'));
        setState(() {});
        return;
      }

      try {
        await request.req('smsCode', {
          'type': 'register',
          'phone': _phoneNumber,
        });
      } catch (error) {
        _handleSmsError(context, error);
        return;
      }
      _startCount();

      // reset code
      // show next page
      _code = '';
      _nextPage(context, 'newCode', focusNode2);
    } else if (_status == 'newCode') {
      // check code
      if (_code.length != 4) {
        setState(() {
          _error = i18n('Verification Code Length Not Match Error');
        });
        return;
      }

      // request smsTicket via code
      _newTicket = null;
      _loading(context);
      try {
        final res = await request.req('smsTicket', {
          'code': _code,
          'phone': _phoneNumber,
          'type': 'register',
        });

        _newTicket = res.data;
      } catch (error) {
        debug(error);
        _loadingOff();
        setState(() {
          _error = i18n('Verification Code Error');
        });
        return;
      }

      try {
        // need cloud token
        await state.cloud.req('replacePhone', {
          'oldTicket': _ticket,
          'newTicket': _newTicket,
          'type': 'replace',
        });
      } catch (err) {
        debug(err);
        _loadingOff();
        showSnackBar(context, i18n('Change Phone Number Failed'));
        return;
      }

      // show next page
      _loadingOff();
      setState(() {
        _status = 'success';
      });
    } else {
      // return to login: remove all router, and push '/login'
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (Route<dynamic> route) => false);
    }
  }

  List<Widget> renderPage() {
    switch (_status) {
      case 'code':
        return <Widget>[
          Text(
            i18n('Verification Code Input Text'),
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 28.0),
          ),
          Container(height: 16.0),
          Text(
            i18n(
              'Verification Code Has Sent Text',
              {'phoneNumber': widget.phone},
            ),
            style: TextStyle(color: Colors.black54),
          ),
          Container(height: 32.0),
          TextField(
            key: Key('code'),
            onChanged: (text) {
              setState(() => _error = null);
              _code = text;
            },
            // controller: TextEditingController(text: _phoneNumber),
            autofocus: true,
            decoration: InputDecoration(
                labelText: i18n('Verification Code Input Text'),
                prefixIcon: Icon(Icons.verified_user),
                errorText: _error),
            style: TextStyle(fontSize: 24, color: Colors.black87),
            maxLength: 4,
            keyboardType: TextInputType.number,
          ),
        ];

      case 'newPhone':
        return <Widget>[
          Text(
            i18n('New Phone Number'),
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 28.0),
          ),
          Container(height: 16.0),
          Text(
            i18n('New Phone Number Text'),
            style: TextStyle(color: Colors.black54),
          ),
          Container(height: 32.0),
          TextField(
            key: Key('phoneNumber'),
            onChanged: (text) {
              setState(() => _error = null);
              _phoneNumber = text;
            },
            focusNode: focusNode1,
            decoration: InputDecoration(
                labelText: i18n('Phone Number'),
                prefixIcon: Icon(Icons.person),
                errorText: _error),
            style: TextStyle(fontSize: 24, color: Colors.black87),
            maxLength: 11,
            keyboardType: TextInputType.number,
          ),
        ];

      case 'newCode':
        return <Widget>[
          Text(
            i18n('Verification Code Input Text'),
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 28.0),
          ),
          Container(height: 16.0),
          Text(
            i18n(
              'Verification Code Has Sent Text',
              {'phoneNumber': _phoneNumber},
            ),
            style: TextStyle(color: Colors.black54),
          ),
          Container(height: 32.0),
          TextField(
            key: Key('newCode'),
            onChanged: (text) {
              setState(() => _error = null);
              _code = text;
            },
            focusNode: focusNode2,
            decoration: InputDecoration(
                labelText: i18n('Verification Code Input Text'),
                prefixIcon: Icon(Icons.verified_user),
                errorText: _error),
            style: TextStyle(fontSize: 24, color: Colors.black87),
            maxLength: 4,
            keyboardType: TextInputType.number,
          ),
        ];

      case 'success':
        return <Widget>[
          Text(
            i18n('Change Phone Number Success'),
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 28.0),
          ),
          Container(height: 16.0),
          Text(
            i18n('Change Phone Number Success Text'),
            style: TextStyle(color: Colors.black54),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Icon(Icons.check, color: pColor, size: 48),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(),
          ),
        ];

      default:
        return <Widget>[];
    }
  }

  int _count = -1;

  _countDown() async {
    if (_count > 0 && this.mounted) {
      await Future.delayed(Duration(seconds: 1));
      if (this.mounted) {
        setState(() {
          _count -= 1;
        });
        await _countDown();
      }
    }
  }

  /// start count down of 60 seconds
  _startCount() {
    _count = 60;
    _countDown().catchError(print);
  }

  /// resendSmg
  _resendSmg(BuildContext ctx) async {
    _loading(ctx);
    try {
      await request.req('smsCode', {
        'type': 'password',
        'phone': widget.phone,
      });
    } catch (error) {
      _handleSmsError(ctx, error);
      return;
    }
    _startCount();
    _loadingOff();
    showSnackBar(ctx, i18n('Send Verification Code Success'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0, // no shadow
        backgroundColor: Colors.white,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.black38),
        automaticallyImplyLeading: _status == 'success' ? false : true,
        actions: _status == 'code'
            ? <Widget>[
                Builder(builder: (BuildContext ctx) {
                  return FlatButton(
                    child: _count > 0
                        ? Text(i18nPlural('Resend Later', _count))
                        : Text(i18n('Resend')),
                    textColor: Colors.black38,
                    onPressed: _count > 0 ? null : () => _resendSmg(ctx),
                  );
                }),
              ]
            : <Widget>[],
      ),
      floatingActionButton: Builder(
        builder: (ctx) {
          return StoreConnector<AppState, VoidCallback>(
            converter: (store) => () => _nextStep(ctx, store.state),
            builder: (context, callback) => FloatingActionButton(
              onPressed: callback,
              tooltip: i18n('Next Step'),
              backgroundColor: pColor,
              elevation: 0.0,
              child: Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 48,
              ),
            ),
          );
        },
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          primaryColor: pColor,
          // accentColor: pColor,
          // hintColor: pColor,
          brightness: Brightness.light,
        ),
        child: Container(
          constraints: BoxConstraints.expand(),
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: renderPage()),
        ),
      ),
    );
  }
}
