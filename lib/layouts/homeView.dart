import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocation/geolocation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uplink_flutter/database.dart';
import 'package:uplink_flutter/location.dart';

import 'package:uplink_flutter/models/stop.dart';
import 'package:uplink_flutter/layouts/stopView.dart';
import 'package:uplink_flutter/layouts/onboardingView.dart';
import 'package:uplink_flutter/theme.dart';

class MainView extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return new MaterialApp(
      title: "Uplink",
      theme: translinkTheme,
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
  List<BusStop> _stops = List();
  bool _hasLoaded = false;
  TranslinkDbAdapter dbAdapter;
  LocationResult _currLocation;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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

  void _addStops(List<BusStop> stops, bool fromGPS){
    setState(() {
      // Take only stops we're interested in
      List<BusStop> combined_stops = _stops.where((BusStop stop) => stop.fromGPS == fromGPS).toList();
      if(combined_stops.length > 0) {
        combined_stops.addAll(stops);

        debugPrint("combined_stops is ${combined_stops.length} long");
        _stops.removeWhere((BusStop stop) => stop.fromGPS == fromGPS);

        for (BusStop stop in stops)
          combined_stops.remove(
              combined_stops.lastWhere((BusStop _stop) => stop.id == _stop.id));

        debugPrint("combined_stops is now ${combined_stops.length} long");


        if (combined_stops != null)
          _stops.addAll(combined_stops);
        _hasLoaded = _stops.length > 0;
      } else {
        if (stops != null)
          _stops.addAll(stops);
        _hasLoaded = _stops.length > 0;

      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final container = LocationContainer.of(context);
    _currLocation = container.location;
    if(_currLocation != null) {
      dbAdapter.findStopsByLocation(_currLocation.location).then((List<BusStop> stops) {
        _addStops(stops, true);
      });
    }
    return Container(
        padding: EdgeInsets.only(
          top: 10.0,
          left: 10.0,
          right: 10.0,
        ),
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  height: 50.0,
                ),
                Expanded(
                  child: _hasLoaded ? ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(top: 10.0),
                    itemCount: _stops.length,
                    itemBuilder: (BuildContext context, int index) {
                      return StopView(_stops[index]);
                    },
                  ) : Center(
                    child: CircularProgressIndicator(),
                  )
                )
              ],
            ),
            Card(
              elevation: 10.0,
              margin: EdgeInsets.only(
                top: 5.0,
                bottom: 0.0,
                left: 0.0,
                right: 0.0,
              ),
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 8.0,
                  left: 10.0,
                  right: 10.0,
                ),
                child: TextField(
                  keyboardType: TextInputType.numberWithOptions(
                    signed: false,
                    decimal: false,
                  ),
                  onChanged: (String query) async {
                    List<BusStop> stops;
                    if(query.length > 3) {
                      debugPrint("Searching for $query");
                      stops = await dbAdapter.findStopsById(query);
                    }
                    _addStops(stops, false);
                  },
                ),
              ),
            ),
          ],
        ),
      );
  }
}