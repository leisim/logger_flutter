import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:logger_flutter/logger_flutter.dart';

void main() {
  runApp(MyApp());
  log();
}

var logger = Logger(
  printer: PrettyPrinter(),
  output: LogConsole.wrap(innerOutput: ConsoleOutput()),
  filter: ProductionFilter(),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

void log() {
  logger.d("Log message with 2 methods");

  loggerNoStack.i("Info message");

  loggerNoStack.w("Just a warning!");

  logger.e("Error! Something bad happened", "Test Error");

  loggerNoStack.v({"key": 5, "value": "something"});

  Future.delayed(Duration(seconds: 5), log);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: App());
  }
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MaterialButton(
          color: Colors.green,
          child: Text("Open the logs"),
          onPressed: () {
            LogConsole.openLogConsole(context);
          },
        ),
      ),
    );
  }
}
