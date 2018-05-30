import 'dart:core';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class TranslinkDataProcessor {
  final String url;
  final String dbName, infoDbName;
  int dbVersion;
  final bool databaseReady;
  Database db,infoDb;

  // Incoming streams from csv data, named according to GTFS spec:
  // https://developers.google.com/transit/gtfs/reference/
  final Stream<Map> feed_info;

  TranslinkDataProcessor({
    this.url: 'http://ns.translink.ca/gtfs/google_transit.zip',
    this.dbName: 'stops.db',
    this.infoDbName: 'feed_info.db',
    @required this.feed_info,
  }) {
    _setupDatabase();
  }

  _setupDatabase() async {
    await _initVersionNumber();
  }

  _initVersionNumber() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String infoPath = join(documentsDirectory.path, infoDbName);
    debugPrint(infoPath);

    await deleteDatabase(infoPath);

    infoDb = await openDatabase(infoPath,
        version: 1,
        onCreate: (Database db, int version) async {
          this.feed_info.listen((Map row) async {
            List<String> values = row['values'];

            // Check for column titles in first row
            if(row['rowNum'] == 0){
              String colNames = values.map((String value) => "$value TEXT").toList().join(",");
              String sql = "CREATE TABLE feed_info($colNames);";
              debugPrint(sql);
              await db.execute(sql);
            } else {
              String cols = values.map((String value) => "\"$value\"").toList().join(",");
              String sql = "INSERT INTO feed_info VALUES($cols);";
              debugPrint(sql);
              await db.execute(sql);
            }
          });
        },
        onOpen: (Database db) async {
          try {
            List<Map> maps = await db.query("feed_info",
              columns: ["feed_start_date"],
              limit: 1,
            );
            if(maps.length != 1)
              throw "Couldn't get database version";

            dbVersion = int.parse(maps[0]["feed_start_date"]);
          } catch (e) {
            rethrow;
          }

          // Close the info db after setting it up, we just need the feed_start_date
          // to use as a version number
          db.close();
        }
    );

  }
}

