import 'dart:core';
import 'dart:async';

// Simple implementation of CSV to List conversion because package:csv is broken.
// Assumes all values are strings, doesn't handle quoting.
// Outputs a Map for each row with a row number and a List of values
class NaiveCSVTransformer {
  StreamTransformer decoder;
  int _rowNum = 0;

  void _handleData(String input, EventSink<Map> sink) {
    List<String> data = input.split("\n");
    for (String line in data) {
      List<String> cells = line.split(",").map((cell) => cell.trim()).toList();
      Map row = {
        'rowNum': _rowNum,
        'values': cells,
      };
      sink.add(row);
      _rowNum++;
    }
  }

  NaiveCSVTransformer(){
    decoder = new StreamTransformer<String, Map>.fromHandlers(
        handleData: _handleData,
    );
  }
}

