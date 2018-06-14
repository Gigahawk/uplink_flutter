import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uplink_flutter/layouts/downloadDialog.dart';

import 'package:uplink_flutter/transformers.dart';
import 'package:uplink_flutter/database.dart';
import 'package:uplink_flutter/csvRebuilder.dart';
import 'package:android_permissions_manager/android_permissions_manager.dart';

class NoPopWrapper extends StatelessWidget {
  final Widget child;
  final String message;
  final GlobalKey<ScaffoldState> childKey;

  NoPopWrapper({
    @required this.child,
    @required this.message,
    @required this.childKey
  });


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        childKey.currentState.showSnackBar(SnackBar(
          content: new Text(message),
          duration: Duration(seconds: 3),
        ));
        return false;
      },
      child: child,
    );
  }

}

class OnboardingLogoPage extends StatelessWidget {
  GlobalKey<ScaffoldState> logoKey = new GlobalKey<ScaffoldState>();

  Widget build(BuildContext context) {
    return NoPopWrapper(
      childKey: logoKey,
      message: "This setup is necessary for Uplink to work",
      child: Scaffold(
        key: logoKey,
          bottomNavigationBar: BottomAppBar(
              elevation: 0.0,
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  FlatButton(
                    child: Row(
                      children: <Widget>[Text("Next"), Icon(Icons.navigate_next)],
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => OnboardingSetupPage()),
                      );
                    },
                  ),
                ],
              )),
          body: Container(
              width: double.infinity, // Fill screen
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset("assets/images/logo.png",
                      width: 200.0, height: 200.0),
                  Text(
                    "Welcome to Uplink",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 34.0,
                    ),
                  ),
                  Text(
                    "Your offline Translink assistant",
                    style: TextStyle(
                      fontSize: 18.0,
                    ),
                  )
                ],
              ))),
    );
  }
}

class OnboardingSetupPage extends StatefulWidget {
  @override
  _OnboardingSetupState createState() => new _OnboardingSetupState();
}

class _OnboardingSetupState extends State<OnboardingSetupPage> {
  GlobalKey<ScaffoldState> setupKey = new GlobalKey<ScaffoldState>();

  int _current_step = 0;
  bool _should_continue = false;
  static const double _description_size = 12.0;
  static const double _description_margin = 15.0;
  bool _sms_granted = false;
  bool _gps_granted = false;
  bool _database_setup = false;

  String _dialogTitle = "Downloading data...";
  double _downloadValue = 0.0;
  static String _url = 'http://ns.translink.ca/gtfs/google_transit.zip';

  Future _startDownload() async {
    AlertDialog dialog = new AlertDialog(
      title: Text(_dialogTitle),
      content: LinearProgressIndicator(
        value: _downloadValue,
      ),
      actions: <Widget>[

      ],
    );

    int dbVersion = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return new DownloadDialog();
      }
    );

    assert(dbVersion != null);

    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('dbVersion', dbVersion);
  }

  void _createList() {
    List<Step> steps = [];
    steps.add(Step(
      title: Text("SMS Permissions"),
      isActive: true,
      state: _sms_granted ? StepState.complete : StepState.indexed,
      content: Column(
        children: <Widget>[
          Text("Uplink uses SMS to query bus info",
            style: TextStyle(
              fontSize: _description_size,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: _description_margin),
            child: RaisedButton(
              child: Text("Request Permission"),
              onPressed: _sms_granted ? null : () async {
                debugPrint("sms: requesting");
                List<PermissionResult> res = await AndroidPermissionsManager.requestPermissions(<PermissionType>[
                  PermissionType.SEND_SMS,
                  PermissionType.READ_SMS,
                ]);

                List<PermissionResult> results = await AndroidPermissionsManager.checkPermissions(<PermissionType>[
                  PermissionType.SEND_SMS,
                  PermissionType.READ_SMS,
                ]);
                debugPrint(results.toString());

                if(results[0] == PermissionResult.granted) {
                  debugPrint("sms granted");
                  setState(() {
                    _should_continue = true;
                    _sms_granted = true;
                    _createList();
                  });
                }
              }
            ),
          ),
        ],
      ),
    ));

    steps.add(Step(
      title: Text("GPS Permissions"),
      isActive: true,
      state: _gps_granted ? StepState.complete : StepState.indexed,
      content: Column(
        children: <Widget>[
          Text("Uplink uses GPS to find nearby stops",
            style: TextStyle(
              fontSize: _description_size,
            ),
          ),
          new Padding(
            padding: const EdgeInsets.only(top: _description_margin),
            child: RaisedButton(
              child: Text("Request Permission"),
                onPressed: _gps_granted ? null : () async {
                  PermissionResult result = await AndroidPermissionsManager.requestPermission(PermissionType.ACCESS_FINE_LOCATION);

                  if(result == PermissionResult.granted) {
                    print("gps granted");
                    setState(() {
                      _should_continue = true;
                      _gps_granted = true;
                      _createList();
                    });
                  }
                }
            ),
          ),
        ],
      ),
    ));

    steps.add(Step(
      title: Text("Database Setup"),
      isActive: true,
      state: _database_setup ? StepState.complete : StepState.indexed,
      content: Column(
        children: <Widget>[
          Text("Uplink needs to download data from Translink for offline usage (this may take a long time)",
            style: TextStyle(
              fontSize: _description_size,
            ),
          ),
          new Padding(
            padding: const EdgeInsets.only(top: _description_margin),
            child: RaisedButton(
              child: Text("Setup Database"),
              onPressed: _database_setup ? null : () async {
                await _startDownload();
                final prefs = await SharedPreferences.getInstance();
                if(prefs.getInt('dbVersion') != null){
                  setState(() {
                    _should_continue = true;
                    _database_setup = true;
                    _createList();
                  });
                }
              },
            ),
          ),
        ],
      ),
    ));

    _steps = steps;
  }

  List<Step> _steps;

  @override
  void initState() {
    _createList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NoPopWrapper(
      childKey: setupKey,
      message: "This setup is necessary for Uplink to work",
      child: Scaffold(
        key: setupKey,
          bottomNavigationBar: BottomAppBar(
            elevation: 0.0,
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FlatButton(
                  child: Row(
                    children: <Widget>[Text("Next"), Icon(Icons.navigate_next)],
                  ),
                  onPressed: _database_setup ? () {
                    Navigator.of(context).pop();
                  } : null,
                ),
              ],
            )
          ),
          body: Container(
            padding: EdgeInsets.all(20.0),
            width: double.infinity, // Fill screen
            child: Stepper(
              currentStep: _current_step,
              steps: _steps,
              onStepContinue: _should_continue ? (){
                setState(() {
                  _should_continue = false;
                  if(_current_step < _steps.length - 1)
                    _current_step++;
                  else
                    Navigator.of(context).pop();
                });
              } : null,
              onStepTapped: null,
              onStepCancel: null,
            ),
          ),
      ),
    );
  }
}

