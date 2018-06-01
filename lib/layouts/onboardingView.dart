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

import 'package:uplink_flutter/transformers.dart';
import 'package:uplink_flutter/database.dart';
import 'package:uplink_flutter/csvRebuilder.dart';

class OnboardingView extends StatefulWidget {
  @override
  OnboardingState createState() => OnboardingState();
}


// Use GlobalKey to get state of child scaffold so that we can display a
// snackbar warning when the user tries to exit out of the onboarding screen
final GlobalKey<ScaffoldState> onboardLogoKey = new GlobalKey<ScaffoldState>();
final GlobalKey<ScaffoldState> onboardPermissionsKey = new GlobalKey<ScaffoldState>();
final GlobalKey<ScaffoldState> onboardDownloadKey = new GlobalKey<ScaffoldState>();

class OnboardingState extends State<OnboardingView> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          onboardLogoKey.currentState.showSnackBar(SnackBar(
            content: new Text('This setup is mandatory for Uplink to work'),
            duration: Duration(seconds: 3),
          ));
          return false;
        },
        child: Stack(
          children: <Widget>[
            OnboardingLogoPage(),
          ],
        ));
  }
}

class OnboardingLogoPage extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
      key: onboardLogoKey,
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OnboardingPermissionsPage()),
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
            )));
  }
}

class OnboardingPermissionsPage extends StatelessWidget {
  static const _methodChannel = const MethodChannel('runtimepermissions/SMS');

  Future<PermissionState> canGetPermission() async{
    debugPrint("Getting perms");
    try {
      final int result = await _methodChannel.invokeMethod('hasPermission');
      return Future.value(PermissionState.values.elementAt(result));
    } on PlatformException catch (e) {
      print('Exception' + e.toString());
    }
    return Future.value(PermissionState.DENIED);
  }

  Widget build(BuildContext context) {
    return Scaffold(
        key: onboardPermissionsKey,
        bottomNavigationBar: BottomAppBar(
            elevation: 0.0,
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FlatButton(
                  child: Row(
                    children: <Widget>[Text("Next"), Icon(Icons.navigate_next)],
                  ),
                  onPressed: () async {
                    PermissionState state = await canGetPermission();

                    if(state != PermissionState.GRANTED){
                      onboardPermissionsKey.currentState.showSnackBar(SnackBar(
                        content: Text("You must allow SMS sending for Uplink to work"),
                      ));
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OnboardingDownloadPage(),
                      )
                    );


                  },
                ),
              ],
            )),
        body: Container(
            padding: EdgeInsets.all(20.0),
            width: double.infinity, // Fill screen
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                  child: Text(
                    "Uplink uses SMS to get info without requiring an internet connection",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.0,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                  child: Text(
                    "To do so, we need to get permission to send SMS.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )));
  }
}


class OnboardingDownloadPage extends StatefulWidget {
  @override
  _OnboardingDownloadState createState() => new _OnboardingDownloadState();
}

class _OnboardingDownloadState extends State<OnboardingDownloadPage> {
  int _downloadStatus = 0;
  bool _isDownloading;
  static String _url = 'http://ns.translink.ca/gtfs/google_transit.zip';
  String _message;
  String _fileContents;



//  static var httpClient = new HttpClient();
//  Future<File> _downloadFile(String url, String filename) async {
//    var request = await httpClient.getUrl(Uri.parse(url));
//    var response = await request.close();
//    var bytes = await consolidateHttpClientResponseBytes(response);
//    File file = new File(filename);
//    await file.writeAsBytes(bytes);
//    return file;
//  }

  _downloadFile(String url, String filename) async {
    Dio dio = new Dio();
    onboardDownloadKey.currentState.showSnackBar(
        SnackBar(
          content: Text("Downloading"),
        ));
    try {
      await dio.download(url, filename,
        onProgress: (recieved, total) {
          setState(() {
            _downloadStatus = (recieved.toDouble()/total*100).toInt();
          });
        }
      );
    } catch (e) {
      onboardDownloadKey.currentState.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ));
    }
  }

  Stream<int> dataStream(List<int> data) {
    var list = new List<int>.from(data);
    bool running = false;

    StreamController<int> controller = new StreamController<int>(
      onListen: () { running = true; },
    );

    void run() async {
      int item;
      while(!running);
      while(list.length > 0) {
        item = list.removeAt(0);
//        debugPrint(item.toString());
        controller.add(item);
      }
      controller.close();
    }

//    void run() async {
//      while(!running);
//      for(int i = 0; i < 10; i++) {
//        debugPrint(i.toString());
//        controller.add(i);
//      }
//      controller.close();
//    }

    run();

    return controller.stream;
  }



  Future<http.Response> getZip() {
    return http.get(_url);
  }

  Future<bool> _fetchData() async {
    final tempDir = await getApplicationDocumentsDirectory();
    debugPrint(tempDir.path);
    final tempPath = '${tempDir.path}/google_transit.zip';

    await _downloadFile(_url, tempPath);
//    onboardDownloadKey.currentState.showSnackBar(SnackBar(
//      content: Text("Download complete?"),
//    ));
    setState(() {
      _message = "File Downloaded, extracting...";
    });

    List<int> bytes = new File(tempPath).readAsBytesSync();

    debugPrint("extracting files");
    Archive archive = new ZipDecoder().decodeBytes(bytes);

    debugPrint("Extracted");
    String fileList = "";

    Stream<Map> feed_info, routes, trips, stop_times, stops;

    Stream<Map> csvToStream(ArchiveFile file) {
//    List<String> csvToStream(ArchiveFile file) {
      String filePath = '${tempDir.path}/${file.name}';
      final csvCodec = new NaiveCSVTransformer();
      new File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(file.content);
      var input = new File(filePath).openRead();
      return input.transform(utf8.decoder).transform(new LineSplitter()).transform(csvCodec.decoder);
//      return input.transform(utf8.decoder);
    }

    for (ArchiveFile file in archive) {
      debugPrint("Handling ${file.name}");
      _fileContents = "";
      String filename = file.name;
      fileList = "${filename}\n${fileList}";

      switch(file.name) {
        case "feed_info.txt": {
          feed_info = csvToStream(file);
        }
        break;

        case "routes.txt": {
          routes = csvToStream(file);
        }
        break;

        case "trips.txt": {
          trips = csvToStream(file);
        }
        break;

        case "stop_times.txt": {
          stop_times = csvToStream(file);
        }
        break;

        case "stops.txt": {
          stops = csvToStream(file);
        }
        break;

        default:
          continue;
      }
    }
    onboardDownloadKey.currentState.showSnackBar(SnackBar(
      content: Text("Extract complete"),
    ));
    setState(() {
      _message = "Extracted, processing\n$fileList";
    });

    var thing = TranslinkDataProcessor(
      feed_info: feed_info,
      routes: routes,
      trips: trips,
      stop_times: stop_times,
      stops: stops
    );
//    List things = [
//      CsvRebuilder(feed_info, '${tempDir.path}/feed_info_rebuild.csv'),
//      CsvRebuilder(routes, '${tempDir.path}/routes_rebuild.csv'),
//      CsvRebuilder(trips, '${tempDir.path}/trips_rebuild.csv'),
//      CsvRebuilder(stop_times, '${tempDir.path}/stop_times_rebuild.csv'),
//      CsvRebuilder(stops, '${tempDir.path}/stops_rebuild.csv'),
//    ];
    return true;
  }

  @override
  void initState() {
    _message = "This will be downloaded now";
    _isDownloading = true;
    _fetchData();
    print("init");
  }

  Widget build(BuildContext context) {
    return Scaffold(
        key: onboardDownloadKey,
        bottomNavigationBar: BottomAppBar(
            elevation: 0.0,
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FlatButton(
                  child: Row(
                    children: <Widget>[Text("Next"), Icon(Icons.navigate_next)],
                  ),
                  onPressed: _isDownloading ? null : () {

                  },
                ),
              ],
            )),
        body: Container(
          padding: EdgeInsets.all(20.0),
          width: double.infinity, // Fill screen
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                child: Text(
                  "Uplink uses data from Translink for querying",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.0,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                child: Text(
                  _downloadStatus.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: SingleChildScrollView (
                  child: Text(_fileContents ?? ""),
                )
              )
            ],
          )));
  }
}

enum PermissionState {
  GRANTED,
  DENIED,
  SHOW_RATIONALE //  Refer https://developer.android.com/training/permissions/requesting.html#explain
}
