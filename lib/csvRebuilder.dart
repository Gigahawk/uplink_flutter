import 'dart:core';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class CsvRebuilder{
  Stream<Map> stream;
  File rebuild;

  _debugFileSize() async {
    debugPrint(rebuild.lengthSync().toString());
  }

  _debugFileSizeLoop() async {
      new Timer.periodic(const Duration(seconds:3), (Timer t) {
        debugPrint("File size is ${rebuild.lengthSync().toString()}");
      });
  }

  CsvRebuilder(this.stream, String fileName){
    debugPrint("Rebuilding $fileName");
    rebuild = new File(fileName);
    var writer = rebuild.openWrite();
    stream.listen((Map item) {
      List<String> cells = item['values'];
      writer.writeln(cells.join(","));
      int rowNum = item['rowNum'];
      if(rowNum % 10000 == 0){
        debugPrint("Writing line $rowNum for $fileName");
        debugPrint(cells.join(","));
//        if(fileName.contains("stop_times_rebuild.csv")) {
//          _debugFileSize();
//        }
      }
    },
    onDone: () {
      debugPrint("All lines sent, flushing $fileName");
      if(fileName.contains("stop_times_rebuild.csv"))
        _debugFileSizeLoop();
      writer.flush().then((value) {
        debugPrint("Flushed $fileName");
        debugPrint(value.toString());

        writer.close();
        writer.done.then((_) {
          debugPrint("Done $fileName");
        },
            onError: (e) {
              debugPrint("Error with $fileName");
              debugPrint(e);
            }
        );
      });

    });
  }
}