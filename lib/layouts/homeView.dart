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
//                  child: CircularProgressIndicator(),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      Card(
                        elevation: 5.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Column(
                          children: <Widget>[
                            Container(
                              height: 60.0,
                              width: double.infinity,
                              color: const Color(0xFF00355D),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 25.0,
                                  left: 20.0,
                                  right: 20.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text("12345",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: const Color(0xFFFFD51F),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20.0
                                      ),
                                    ),
                                    Container(
                                      color: const Color(0xFFFFD51F),
                                      width: double.infinity,
                                      height: 1.5,
                                    )
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ExpansionTile(
                                  onExpansionChanged: (changed) {
                                    debugPrint(changed.toString());
                                  },
                                  children: <Widget>[

                                    new Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16.0,
                                          right: 56.0
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 20.0,
                                          right: 40.0,
                                        ),
                                        child: LinearProgressIndicator(
                                          backgroundColor: Color(0xFF0081C5), //ThemeData.backgroundColor
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00355D)), //ThemeData.accentColor
                                        ),
                                      ),
                                    ),
                                  ],
                                  title: GestureDetector(
                                    onLongPress: () {
                                      debugPrint("longpressed");
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8.0,
                                          left: 20.0,
                                          right: 40.0
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Container(
                                            width: 50.0,
                                            child: Text("100",
//                                      textAlign: TextAlign.start,
                                              style: TextStyle(
                                                  color: const Color(0xFF00355D),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20.0
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text("22ND ST STN/MARPOLE LOOP",
//                                      textAlign: TextAlign.start,
                                                  style: TextStyle(
                                                      color: const Color(0xFF00355D),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 20.0
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16.0 + 20.0,
                                    right: 56.0 + 40.0,
                                  ),
                                  child: Container(
                                    color: const Color(0xFF00355D),
                                    width: double.infinity,
                                    height: 1.5,
                                  ),
                                )
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ExpansionTile(
                                  children: <Widget>[
                                    new Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16.0,
                                          right: 56.0
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 20.0,
                                          right: 40.0,
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Container(
                                              width: 50.0,
                                            ),
                                            Text("4:00 AM, 4:30 AM",
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                  color: const Color(0xFF00355D),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15.0
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  title: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8.0,
                                        left: 20.0,
                                        right: 40.0
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Container(
                                          width: 50.0,
                                          child: Text("100",
//                                      textAlign: TextAlign.start,
                                            style: TextStyle(
                                                color: const Color(0xFF00355D),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20.0
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text("22ND ST STN/MARPOLE LOOP",
//                                      textAlign: TextAlign.start,
                                                style: TextStyle(
                                                    color: const Color(0xFF00355D),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20.0
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16.0 + 20.0,
                                    right: 56.0 + 40.0,
                                  ),
                                  child: Container(
                                    color: const Color(0xFF00355D),
                                    width: double.infinity,
                                    height: 1.5,
                                  ),
                                )
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ExpansionTile(
                                  children: <Widget>[
                                    new Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16.0,
                                        right: 56.0
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 20.0,
                                          right: 40.0,
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Container(
                                              width: 50.0,
                                            ),
                                            Text("4:00 AM, 4:30 AM",
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                  color: const Color(0xFF00355D),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15.0
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  title: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8.0,
                                        left: 20.0,
                                        right: 40.0
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Container(
                                          width: 50.0,
                                          child: Text("100",
//                                      textAlign: TextAlign.start,
                                            style: TextStyle(
                                                color: const Color(0xFF00355D),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20.0
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text("22ND ST STN/MARPOLE LOOP",
//                                      textAlign: TextAlign.start,
                                                style: TextStyle(
                                                    color: const Color(0xFF00355D),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20.0
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16.0 + 20.0,
                                    right: 56.0 + 40.0,
                                  ),
                                  child: Container(
                                    color: const Color(0xFF00355D),
                                    width: double.infinity,
                                    height: 1.5,
                                  ),
                                )
                              ],
                            ),
                            Container(
                              margin: EdgeInsets.only(
                                top: 8.0
                              ),
                              height: 50.0,
                              width: double.infinity,
                              color: const Color(0xFF87746A),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  new Padding(
                                    padding: const EdgeInsets.only(left: 20.0),
                                    child: Text("Distance: 3m",
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20.0
                                      ),
                                    ),
                                  ),

                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      Card(
                        elevation: 5.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Column(
                          children: <Widget>[
                            Container(
                              height: 60.0,
                              width: double.infinity,
                              color: const Color(0xFF00355D),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 25.0,
                                  left: 20.0,
                                  right: 20.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text("12345",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          color: const Color(0xFFFFD51F),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20.0
                                      ),
                                    ),
                                    Container(
                                      color: const Color(0xFFFFD51F),
                                      width: double.infinity,
                                      height: 1.5,
                                    )
                                  ],

                                ),
                              ),
                            ),
                            Container(
                              height: 200.0,
                              width: double.infinity,
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ),
                      Card(
                        elevation: 5.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Column(
                          children: <Widget>[
                            Container(
                              height: 60.0,
                              width: double.infinity,
                              color: const Color(0xFF00355D),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 25.0,
                                  left: 20.0,
                                  right: 20.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text("12345",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          color: const Color(0xFFFFD51F),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20.0
                                      ),
                                    ),
                                    Container(
                                      color: const Color(0xFFFFD51F),
                                      width: double.infinity,
                                      height: 1.5,
                                    )
                                  ],

                                ),
                              ),
                            ),
                            Container(
                              height: 200.0,
                              width: double.infinity,
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )

                )
            ),
          ],
        ),
      );
  }
}