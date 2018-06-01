import 'dart:core';
import 'dart:async';
import 'package:flutter/foundation.dart';

// Simple implementation of CSV to List conversion because package:csv is broken.
// Assumes all values are strings, doesn't handle quoting.
// Outputs a Map for each row with a row number and a List of values
class NaiveCSVTransformer {
  // Decoder can't be static because it relies on internal state to keep track
  // of row number
  StreamTransformer decoder;
  int _rowNum = 0;
  int _colNum;

  void _handleData(String input, EventSink<Map> sink) {
//    debugPrint("Handling text input");
//    debugPrint(input);
    List<String> data = input.split("\n");
//    debugPrint(data.length.toString());

    for (String line in data) {
      List<String> cells = line.split(",").map((cell) => cell.trim()).toList();
      if(_colNum == null)
        _colNum = cells.length;

      if(cells.length < _colNum)
        return;

      Map row = {
        'rowNum': _rowNum,
        'values': cells,
      };
      if(_rowNum % 100000 == 0)
        debugPrint("csv_converting $_rowNum");
      sink.add(row);
      _rowNum++;
    }
  }

  void _handleDataSingular(String input, EventSink<Map> sink) {
//    debugPrint("Handling text input");
//    debugPrint(input);

    List<String> cells = input.split(",").map((cell) => cell.trim()).toList();
    if(_colNum == null)
      _colNum = cells.length;

    if(cells.length < _colNum)
      return;

    Map row = {
      'rowNum': _rowNum,
      'values': cells,
    };
    if(_rowNum % 100000 == 0)
      debugPrint("csv_converting $_rowNum");
    sink.add(row);
    _rowNum++;
  }
  NaiveCSVTransformer(){
    decoder = new StreamTransformer<String, Map>.fromHandlers(
        handleData: _handleDataSingular,
    );
  }
}

