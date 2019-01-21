import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';
import './login/login.dart';
import './nav/bottom_navigation.dart';
import './redux/redux.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  final store = Store<AppState>(
    appReducer,
    initialState: AppState.initial(),
  );

  @override
  Widget build(BuildContext context) {
    return StoreProvider(
      store: store,
      child: MaterialApp(
        title: 'Winas App',
        theme: ThemeData(
          primaryColor: Colors.teal,
          accentColor: Colors.redAccent,
          iconTheme: IconThemeData(color: Colors.black54),
        ),
        routes: <String, WidgetBuilder>{
          '/login': (BuildContext context) => new LoginPage(),
          '/station': (BuildContext context) => new BottomNavigation(),
        },
        home: LoginPage(),
      ),
    );
  }
}
