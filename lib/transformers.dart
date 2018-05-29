import 'dart:async';
import 'package:flutter/foundation.dart';

//class naiveCSVTransformer {
//  StreamTransformer decoder;
//  List<dynamic> currRow = [];
//
//  void _handleData(String data, EventSink sink) {
//    List<String> rows = data.split("\n");
//
//    for(String row in rows) {
//      List<String> cells = row.split(",").map((String cell) => cell.trim());
//      sink.add(cells);
//    }
//
//  }
//
//  naiveCSVTransformer(){
//    decoder = new StreamTransformer.fromHandlers(
//        handleData: _handleData,
//    );
//  }
//}

