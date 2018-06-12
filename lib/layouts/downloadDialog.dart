import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uplink_flutter/database.dart';
import 'package:uplink_flutter/transformers.dart';

class DownloadDialog extends StatefulWidget {
  @override
  _DownloadDialogState createState() => new _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {

  String _dialogTitle;
  double _downloadValue;
  bool _determinate;
  bool _done;
  int dbVersion;
  static const String _url = 'http://ns.translink.ca/gtfs/google_transit.zip';
  static Directory _tempDir;
  static String _tempPath;

  _downloadFile(String url, String filename) async {
    Dio dio = new Dio();
    try {
      await dio.download(url, filename,
        onProgress: (recieved, total) {
//          debugPrint((recieved.toDouble()/total).toString());
          setState(() {
            _downloadValue = (recieved.toDouble()/total);
          });
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  String _storeArchiveFile(ArchiveFile file) {
    String filePath = '${_tempDir.path}/${file.name}';
    new File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(file.content);
    return filePath;
  }

  int _lineCount(String filePath) {
    return new File(filePath).readAsLinesSync().length;
  }

  Stream<Map> _csvToStream(String filePath) {
    final csvCodec = new NaiveCSVTransformer();

    var input = new File(filePath).openRead();
    return input.transform(utf8.decoder).transform(new LineSplitter()).transform(csvCodec.decoder);
  }

  Future<bool> _fetchData() async {
    _tempDir = await getTemporaryDirectory();
    _tempPath = '${_tempDir.path}/google_transit.zip';
    debugPrint(_tempPath);

    setState(() {
      _determinate = true;
    });

    debugPrint("Downloading");
    await _downloadFile(_url, _tempPath);
    debugPrint("done downloading");

    setState(() {
      _determinate = false;
      _dialogTitle = "Extracting...";
    });

    debugPrint("Extracting zip");
    File zipFile = new File(_tempPath);
    List<int> bytes = zipFile.readAsBytesSync();
    zipFile.delete();

    setState(() {
      _dialogTitle = "Processing data...";
    });

    Archive archive = new ZipDecoder().decodeBytes(bytes);
    debugPrint("done extracting");

    Stream<Map> feed_info, routes, trips, stop_times, stops;
    int feed_info_lines, routes_lines, trips_lines, stop_times_lines, stops_lines;
    String filePath;

    debugPrint("Processing");
    for (ArchiveFile file in archive) {
      String filename = file.name;
      switch (file.name) {
        case "feed_info.txt":
          filePath = _storeArchiveFile(file);
          feed_info = _csvToStream(filePath);
          feed_info_lines  = _lineCount(filePath);
          debugPrint("Processed feed_info");
          break;
        case "routes.txt":
          filePath = _storeArchiveFile(file);
          routes = _csvToStream(filePath);
          routes_lines = _lineCount(filePath);
          debugPrint("Processed routes");
          break;
        case "trips.txt":
          filePath = _storeArchiveFile(file);
          trips = _csvToStream(filePath);
          trips_lines = _lineCount(filePath);
          debugPrint("Processed trips");
          break;
        case "stop_times.txt":
          filePath = _storeArchiveFile(file);
          stop_times = _csvToStream(filePath);
          stop_times_lines = _lineCount(filePath);
          debugPrint("Processed stop_times");
          break;
        case "stops.txt":
          filePath = _storeArchiveFile(file);
          stops = _csvToStream(filePath);
          stops_lines = _lineCount(filePath);
          debugPrint("Processed stops");
          break;
        default:
          continue;
      }
    }
    debugPrint("done Processing");

    setState(() {
      _dialogTitle = "Setting up database...";
      _downloadValue = 0.0;
      _determinate = false;
    });

    TranslinkDataProcessor processor = TranslinkDataProcessor(
      feed_info: feed_info,
      routes: routes,
      trips: trips,
      stop_times: stop_times,
      stops: stops,
      feed_info_lines: feed_info_lines,
      routes_lines: routes_lines,
      trips_lines: trips_lines,
      stop_times_lines: stop_times_lines,
      stops_lines: stops_lines,
    );

    processor.statusController.stream.listen((String data) {
      setState(() {
        _dialogTitle = data;
      });
    });
    processor.progressController.stream.listen((double data) {

      setState(() {
        if(data == 420.0){
          _done = true;
        }
        if(data < 0.0) {
          _determinate = false;
          _downloadValue = 0.0;
        } else {
          if(data > 1.0)
            data = 1.0;
          _determinate = true;
          _downloadValue = data;
        }

      });
    });

    await processor.setupDatabase();
    setState(() {
      dbVersion = processor.dbVersion;
    });
  }

  @override
  void initState() {
    super.initState();
    _done = false;
    _dialogTitle = "Downloading data...";
    _determinate = false;
    _fetchData();
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: AlertDialog(
        title: Text(_dialogTitle),
        content: LinearProgressIndicator(
          value: _determinate ? _downloadValue : null,
        ),
        actions: <Widget>[
          FlatButton(
            child: Text("Close"),
            onPressed: _done ? () {
              Navigator.of(context, rootNavigator: true).pop(dbVersion);
            } : null,
          )
        ],
      )
    );
  }
}