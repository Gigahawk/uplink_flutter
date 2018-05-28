import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class OnboardingView extends StatefulWidget {
  @override
  OnboardingState createState() => OnboardingState();
}

// Use GlobalKey to get state of child scaffold so that we can display a
// snackbar warning when the user tries to exit out of the onboarding screen
final GlobalKey<ScaffoldState> onboardPopKey = new GlobalKey<ScaffoldState>();
final GlobalKey<ScaffoldState> onboardPermissionsKey = new GlobalKey<ScaffoldState>();
final GlobalKey<ScaffoldState> onboardDownloadKey = new GlobalKey<ScaffoldState>();

class OnboardingState extends State<OnboardingView> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          onboardPopKey.currentState.showSnackBar(SnackBar(
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

  static var httpClient = new HttpClient();
  Future<File> _downloadFile(String url, String filename) async {
    var request = await httpClient.getUrl(Uri.parse(url));
    var response = await request.close();
    var bytes = await consolidateHttpClientResponseBytes(response);
    File file = new File(filename);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<http.Response> getZip() {
    return http.get(_url);
  }


  Future<bool> _fetchData() async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/google_transit.zip';

    final tempFile = await _downloadFile(_url, tempPath);
    onboardDownloadKey.currentState.showSnackBar(SnackBar(
      content: Text("Download complete?"),
    ));
    setState(() {
      _message = "File Downloaded, extracting...";
    });

    List<int> bytes = new File(tempPath).readAsBytesSync();

    Archive archive = new ZipDecoder().decodeBytes(bytes);

    String fileList = "";

    for (ArchiveFile file in archive) {
      String filename = file.name;
      fileList = "${filename}\n${fileList}";
      List<int> data = file.content;
      new File('${tempDir.path}/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
    }
    onboardDownloadKey.currentState.showSnackBar(SnackBar(
      content: Text("Extract complete"),
    ));
    setState(() {
      _message = "Extracted, processing\n$fileList";
    });
    return true;
  }

  @override
  void initState() {
    _message = "This will be downloaded now";
    _isDownloading = true;
    _fetchData();
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
            ],
          )));
  }
}

enum PermissionState {
  GRANTED,
  DENIED,
  SHOW_RATIONALE //  Refer https://developer.android.com/training/permissions/requesting.html#explain
}
