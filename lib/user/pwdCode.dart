import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/request.dart';

final pColor = Colors.teal;

/// handle smscode and reset password
class SmsCode extends StatefulWidget {
  SmsCode({Key key, this.phone, this.request}) : super(key: key);
  final String phone;
  final Request request;
  @override
  _SmsCodeState createState() => _SmsCodeState();
}

class _SmsCodeState extends State<SmsCode> {
  String _status = 'code';
  bool showPwd = true;

  // Focus action
  FocusNode focusNode;

  String _code = '';

  String _password = '';

  String _error;

  String _ticket;

  @override
  void initState() {
    super.initState();

    focusNode = FocusNode();

    _startCount();
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed
    focusNode.dispose();

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

    Future.delayed(
      Duration(milliseconds: 100),
      () => FocusScope.of(context).requestFocus(node),
    ).catchError(debug);
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
  _nextStep(BuildContext context, store) async {
    final request = widget.request;
    if (_status == 'code') {
      // check code
      if (_code.length != 4) {
        setState(() {
          _error = i18n('Verification Code Length Not Match Error');
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
          'type': 'password',
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
      _nextPage(context, 'password', focusNode);
    } else if (_status == 'password') {
      // check password
      if (_password.length <= 7) {
        setState(() {
          _error = i18n('Password Too Short Error');
        });
        return;
      }

      // register with _code, _phoneNumber, _ticket
      _loading(context);
      try {
        await request.req('resetPwd', {
          'password': _password,
          'phoneTicket': _ticket,
        });
        final clientId = await getClientId();
        // refresh token
        await request.req('token', {
          'clientId': clientId,
          'username': widget.phone,
          'password': _password
        });
      } catch (error) {
        _loadingOff();
        setState(() {
          _error = i18n('Reset Password Failed');
        });
        return;
      }

      // show next page
      _loadingOff();
      setState(() {
        _status = 'success';
      });
    } else {
      // return to security
      Navigator.popUntil(context, ModalRoute.withName('security'));
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

      case 'password':
        return <Widget>[
          Text(
            i18n('New Password Text'),
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 28.0),
          ),
          Container(height: 16.0),
          Text(
            i18n('Password Requirements'),
            style: TextStyle(color: Colors.black54),
          ),
          Container(height: 32.0),
          TextField(
            key: Key('password'),
            onChanged: (text) {
              setState(() => _error = null);
              _password = text;
            },
            // controller: TextEditingController(text: _password),
            focusNode: focusNode,
            decoration: InputDecoration(
                labelText: i18n('Password'),
                prefixIcon: Icon(
                  Icons.lock,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    showPwd ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showPwd = !showPwd;
                    });
                  },
                ),
                errorText: _error),
            style: TextStyle(fontSize: 24, color: Colors.black87),
            obscureText: showPwd,
          ),
        ];

      case 'success':
        return <Widget>[
          Text(
            i18n('Reset Password Success'),
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 28.0),
          ),
          Container(height: 16.0),
          Text(
            i18n('Reset Password Success Text'),
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
      await widget.request.req('smsCode', {
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
            converter: (store) => () => _nextStep(ctx, store),
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
