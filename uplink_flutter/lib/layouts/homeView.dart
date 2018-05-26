import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:uplink_flutter/models/stop.dart';
import 'package:uplink_flutter/layouts/stopView.dart';

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
  bool hasLoaded = true;

//  final PublishSubject subject = PublishSubject<String>();

  @override
  void dispose() {
//    subject.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
//    subject.stream.debounce(Duration(milliseconds: 400)).listen(searchMovies);
    _getPrefs();
  }

  void _getPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String lastCheck = prefs.getString('lastCheck') ?? null;

    if(lastCheck == null){
      Scaffold.of(context).showSnackBar(SnackBar(
        content: new Text('no lastCheck'),
        duration: Duration(seconds:20),
      ));
    }
  }

  void onError(dynamic d) {
    setState(() {
      hasLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(10.0),
        child: Column(
          children: <Widget>[
            TextField(
//            onChanged: (String string) => (subject.add(string)),
              keyboardType: TextInputType.url,
            ),
            CircularProgressIndicator(),
            Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(10.0),
                  itemCount: stops.length,
                  itemBuilder: (BuildContext context, int index) {
                    return new BusStopListItemView(stops[index]);
                  },
                ))
          ],
        ),
      );
  }
}