import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uplink_flutter/database.dart';

import 'package:uplink_flutter/models/stop.dart';
import 'package:uplink_flutter/layouts/stopView.dart';
import 'package:uplink_flutter/layouts/onboardingView.dart';

class MainView extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return new MaterialApp(
      title: "Uplink",
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text("Uplink")
        ),
        body: new HomeView(),
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  @override
  HomeViewState createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  List<BusStop> stops = List();
  bool _hasLoaded;
  TranslinkDbAdapter dbAdapter;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _hasLoaded = false;
    getApplicationDocumentsDirectory().then((Directory directory) {
      dbAdapter = TranslinkDbAdapter(p.join(directory.path,"stops.db"));
    });
    _getPrefs();
  }


  void _getPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int dbVersion = prefs.getInt('dbVersion') ?? null;

    if(dbVersion == null){
      // No data, start onboarding
      Navigator.push(
        context,
        new MaterialPageRoute(builder: (context) => OnboardingLogoPage()),
      );
    }
  }

  void onError(dynamic d) {
    setState(() {
      _hasLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(10.0),
        child: Column(
          children: <Widget>[
            TextField(
              keyboardType: TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              onChanged: (String query) async {
                if(query.length > 2) {
                  debugPrint("Searching for $query");
                  List<BusStop> stops = await dbAdapter.findStopById(query);
                  for(BusStop stop in stops){
                    stop.printInfo();
                  }
                }
              },
            ),
            Expanded(
                child: _hasLoaded ? ListView.builder(
                  padding: EdgeInsets.all(10.0),
                  itemCount: stops.length,
                  itemBuilder: (BuildContext context, int index) {
                    return new BusStopListItemView(stops[index]);
                  },
                ) : Center(
                  child: CircularProgressIndicator(),
                )
            ),
          ],
        ),
      );
  }
}