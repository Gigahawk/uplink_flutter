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
import 'package:csv/csv.dart';

//import 'package:uplink_flutter/transformers.dart';

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

    List<List<dynamic>> routesList, tripsList, stop_timesList;


//    for (ArchiveFile file in archive) {
//      switch (file.name) {
//
//        case "routes.txt":
//          {
//            onboardDownloadKey.currentState.showSnackBar(SnackBar(
//              content: Text("Processing routes"),
//            ));
//            setState(() {
//              _message = "Processing routes";
////              _fileContents = file.content.toString();
//            });
//            await Future.delayed(Duration(seconds: 4));
//          }
////          routesList = const CsvToListConverter().convert(file.content.toString());
//          break;
//        case "trips.txt":
//          {
//            onboardDownloadKey.currentState.showSnackBar(SnackBar(
//              content: Text("Processing trips"),
//            ));
//            setState(() {
//              _message = "Processing trips";
////              _fileContents = file.content.toString();
//            });
////          tripsList = const CsvToListConverter().convert(file.content.toString());
//
//            await Future.delayed(Duration(seconds: 4));
//          }
//          break;
//        case "stop_times.txt":
//          {
//            onboardDownloadKey.currentState.showSnackBar(SnackBar(
//              content: Text("Processing stop_times"),
//            ));
//            setState(() {
//              _message = "Processing stop_times";
////              _fileContents = file.content.toString();
//            });
//            //stop_timesList = const CsvToListConverter().convert(file.content.toString());
//            await Future.delayed(Duration(seconds: 4));
//          }
//          break;
//        default:
//          continue;
//      }
//      fileList = "${file.name}\n${fileList}";
//    }

//    for (ArchiveFile file in archive) {
//      debugPrint("Handling ${file.name}");
//      _fileContents = "";
//      String filename = file.name;
//      fileList = "${filename}\n${fileList}";
//      List<int> data = file.content;
//      var newFile = new File('${tempDir.path}/$filename');
//      var sink = newFile.openWrite();
//      Stream<int> stream = dataStream(data);
//      stream.listen((data) {
//        debugPrint("Writing ${data.toString()} to ${file.name}");
//        sink.write(data);
//        debugPrint("Done");
//      },
//      onDone: () async {
//        await sink.flush();
//        await sink.close();
//        debugPrint("Done ${file.name}");
//      });

    for (ArchiveFile file in archive) {
      debugPrint("Handling ${file.name}");
      _fileContents = "";
      String filename = file.name;
      fileList = "${filename}\n${fileList}";
//      var newFile = new File('${tempDir.path}/$filename');
//      var sink = newFile.openWrite();
//      Stream<int> stream = new Stream.fromIterable(file.content);
//      stream.listen((data) {
//        debugPrint("Writing ${data.toString()} to ${file.name}");
//        sink.write(data);
//        debugPrint("Done");
//      },
//          onDone: () async {
//            await sink.flush();
//            await sink.close();
//            debugPrint("Done ${file.name}");
//          });

      new File('${tempDir.path}/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(file.content);
      var input = new File('${tempDir.path}/$filename').openRead();
//      final csvCodec = new naiveCSVTransformer();
      void handleData(String input, EventSink<Iterable<String>> sink) {
//        print("Hnadling data");
        List<String> data = input.split("\n");
//        print("Made a list of lines");
        for (String line in data) {
//          print("Made a list of cells");
          List<String> cells = line.split(",");
//          List<String> cells = line.split(",").map((String cell) => cell.trim());
//          print("Adding cells");
          sink.add(cells);
//          sink.add(line);
        }
      }
      StreamTransformer transformer = new StreamTransformer<String,Iterable<String>>.fromHandlers(
        handleData: handleData,
      );
      final fields = await input.transform(utf8.decoder).transform(transformer).toList();

      for(var field in fields){
//        debugPrint(fields.runtimeType.toString());
        String row = "";
        for(var cell in field){
          row = "$row;$cell";
        }
        debugPrint(row);
      }





      break;
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
