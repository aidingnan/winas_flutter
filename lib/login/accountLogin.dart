import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import './stationLogin.dart';
import './forgetPassword.dart';

import '../redux/redux.dart';
import '../common/utils.dart';
import '../common/request.dart';

class Login extends StatefulWidget {
  Login({Key key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String _status = 'account';

  // Focus action
  FocusNode myFocusNode;

  final request = Request();

  @override
  void initState() {
    super.initState();

    myFocusNode = FocusNode();
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed
    myFocusNode.dispose();

    super.dispose();
  }

  String _phoneNumber = '';

  String _password = '';

  bool _showPassword = false;

  String _error;

  _currentTextField() {
    if (_status == 'account') {
      return TextField(
        key: Key('account'),
        onChanged: (text) {
          setState(() => _error = null);
          _phoneNumber = text;
        },
        // controller: TextEditingController(text: _phoneNumber),
        autofocus: true,
        decoration: InputDecoration(
            labelText: i18n('Phone Number'),
            labelStyle: TextStyle(
              fontSize: 21,
              color: Colors.white,
              height: 0.8,
            ),
            prefixIcon: Icon(Icons.person, color: Colors.white),
            errorText: _error),
        style: TextStyle(fontSize: 24, color: Colors.white),
        maxLength: 11,
        keyboardType: TextInputType.number,
      );
    }
    return TextField(
      key: Key('password'),
      onChanged: (text) {
        setState(() => _error = null);
        _password = text;
      },
      // controller: TextEditingController(text: _password),
      focusNode: myFocusNode,
      decoration: InputDecoration(
          labelText: i18n('Password'),
          labelStyle: TextStyle(
            fontSize: 21,
            color: Colors.white,
            height: 0.8,
          ),
          prefixIcon: Icon(Icons.lock, color: Colors.white),
          suffixIcon: GestureDetector(
            onTap: () => setState(() {
              _showPassword = !_showPassword;
            }),
            child: Icon(
              _showPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
          ),
          errorText: _error),
      style: TextStyle(fontSize: 24, color: Colors.white),
      obscureText: !_showPassword,
    );
  }

  void _nextStep(BuildContext context, store) async {
    if (_status == 'account') {
      // check length
      if (_phoneNumber.length != 11 || !_phoneNumber.startsWith('1')) {
        setState(() {
          _error = i18n('Invalid Phone Number');
        });
        return;
      }

      // userExist

      final loadingInstance = showLoading(context);
      bool userExist = false;
      try {
        final res = await request.req('checkUser', {'phone': _phoneNumber});
        userExist = res.data['userExist'];
      } catch (error) {
        debug(error);

        loadingInstance.close();
        showSnackBar(context, i18n('Check Phone Number Failed'));
        return;
      }
      loadingInstance.close();

      if (!userExist) {
        showSnackBar(context, i18n('User not Exist'));
      } else {
        // next page
        setState(() {
          _status = 'password';
        });
        final future = Future.delayed(const Duration(milliseconds: 100),
            () => FocusScope.of(context).requestFocus(myFocusNode));
        future.then((res) => print('100ms later'));
      }
    } else {
      // login
      if (_password.length == 0) {
        setState(() {
          _error = i18n('Please Enter Password');
        });
        return;
      }

      String clientId = await getClientId();
      final args = {
        'clientId': clientId,
        'username': _phoneNumber,
        'password': _password
      };

      // dismiss keyboard
      FocusScope.of(context).requestFocus(FocusNode());

      final loadingInstance = showLoading(context);
      var res;
      try {
        res = await request.req('token', args);
      } catch (error) {
        debug(error?.response?.data);
        if (error is DioError && error.response.data['code'] == 60008) {
          loadingInstance.close();
          setState(() {
            _error = i18n('Password Error');
          });
          return;
        }
        loadingInstance.close();
        showSnackBar(context, i18n('Login Failed'));
        return;
      }

      // update Account
      Account account = Account.fromMap(res.data);
      store.dispatch(LoginAction(account));

      // cloud apis
      store.dispatch(UpdateCloudAction(request));

      // device login
      await deviceLogin(context, request, account, store);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      appBar: AppBar(
        elevation: 0.0, // no shadow
        actions: <Widget>[
          FlatButton(
              child: Text(i18n('Forget Password')),
              textColor: Colors.white,
              onPressed: () {
                // Navigator to Login
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) {
                    return ForgetPassword();
                  }),
                );
              }),
        ],
      ),
      floatingActionButton: Builder(
        builder: (ctx) {
          return StoreConnector<AppState, VoidCallback>(
            converter: (store) => () => _nextStep(ctx, store),
            builder: (context, callback) => FloatingActionButton(
              onPressed: callback,
              tooltip: i18n('Next Step'),
              backgroundColor: Colors.white70,
              elevation: 0.0,
              child: Icon(
                Icons.chevron_right,
                color: Colors.teal,
                size: 48,
              ),
            ),
          );
        },
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          primaryColor: Colors.white,
          accentColor: Colors.white,
          hintColor: Colors.white,
          brightness: Brightness.dark,
        ),
        child: Container(
          color: Colors.teal,
          constraints: BoxConstraints.expand(),
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(16),
              color: Colors.teal,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    child: Text(
                      i18n('Login'),
                      textAlign: TextAlign.left,
                      style: TextStyle(fontSize: 28.0, color: Colors.white),
                    ),
                    width: double.infinity,
                  ),
                  Container(height: 48.0),
                  _currentTextField(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
