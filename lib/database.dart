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

  Directory documentsDirectory;
  String infoPath, dbPath;

  // Incoming streams from csv data, named according to GTFS spec:
  // https://developers.google.com/transit/gtfs/reference/
  final Stream<Map> feed_info, routes, trips, stop_times, stops;
  dbInsertBuilder routesBuilder, tripsBuilder, stop_timesBuilder, stopsBuilder;

  TranslinkDataProcessor({
    this.url: 'http://ns.translink.ca/gtfs/google_transit.zip',
    this.dbName: 'stops.db',
    this.infoDbName: 'feed_info.db',
    @required this.feed_info,
    @required this.routes,
    @required this.trips,
    @required this.stop_times,
    @required this.stops,
  }) {
    _setupDatabase();
    routesBuilder = new dbInsertBuilder("routes");
    tripsBuilder = new dbInsertBuilder("trips");
    stop_timesBuilder = new dbInsertBuilder("stop_times");
    stopsBuilder = new dbInsertBuilder("stops");
  }

  _setupDatabase() async {
    documentsDirectory = await getApplicationDocumentsDirectory();
    infoPath = join(documentsDirectory.path, infoDbName);
    dbPath = join(documentsDirectory.path, dbName);
    await _initVersionNumber();
    await _initDatabase();
  }

  // This should use batch for efficiency but it doesnt seem to work
  _mapToDb(Map map, Database db, String tableName) async {
    List<String> values = map['values'];

    // Check for column titles in first row
    if(map['rowNum'] == 0){
      if(tableName == null){
        String e = 'Please provide a tableName for this data: ${values.toString()}';
        throw e;
      }

      String colNames = values.map((String value) => "$value TEXT").toList().join(",");
      String sql = "CREATE TABLE $tableName($colNames);";
      debugPrint(sql);
      await db.execute(sql);
    } else {
      String cols = values.map((String value) => "\"$value\"").toList().join(",");
      String sql = "INSERT INTO $tableName VALUES($cols);";
//      debugPrint(sql);
      // Inserts can happen async, order isnt very important
      await db.execute(sql);
//      bool shouldPrint = map['rowNum'] % 100 ? true : false;
//      if(shouldPrint)
//        debugPrint("Committed $tableName row ${map['rowNum']}");
    }
  }

  _mapToBatch(Map map,Database db, Batch batch, String tableName) async {
    List<String> values = map['values'];
    int rowNum = map['rowNum'];

    // Check for column titles in first row
    if(rowNum == 0){
      if(tableName == null){
        String e = 'Please provide a tableName for this data: ${values.toString()}';
        throw e;
      }

      String colNames = values.map((String value) => "$value TEXT").toList().join(",");
      String sql = "CREATE TABLE $tableName($colNames);";
      debugPrint(sql);
      await db.execute(sql);
    } else {
      String cols = values.map((String value) => "\"$value\"").toList().join(",");
      String sql = "INSERT INTO $tableName VALUES($cols);";
//      debugPrint(sql);
      // Inserts can happen async, order isnt very important
      batch.execute(sql);
//      await batch.commit(noResult: true);
      if(rowNum % 100000 == 0) {
        debugPrint("Committing $tableName row ${map['rowNum']}");
        await batch.commit(noResult: true);
        debugPrint("Done $tableName row ${map['rowNum']}");
      }
    }
  }

  _mapToBuilder(Map map,Database db, dbInsertBuilder builder, String tableName) async {
    List<String> values = map['values'];
    int rowNum = map['rowNum'];

    // Check for column titles in first row
    if(rowNum == 0){
      if(tableName == null){
        String e = 'Please provide a tableName for this data: ${values.toString()}';
        throw e;
      }

      String colNames = values.map((String value) => "$value TEXT").toList().join(",");
      String sql = "CREATE TABLE $tableName($colNames);";
      debugPrint(sql);
      await db.execute(sql);
    } else {
//      String cols = values.map((String value) => "\"$value\"").toList().join(",");
//      String sql = "INSERT INTO $tableName VALUES($cols);";
//      debugPrint(sql);
      // Inserts can happen async, order isnt very important
      builder.addEntry(values);
//      await batch.commit(noResult: true);
      if(rowNum % 10000 == 0) {
        debugPrint("Committing $tableName row ${map['rowNum']}");
        await db.execute(builder.getQuery());
        debugPrint("Done $tableName row ${map['rowNum']}");
      }
    }
  }

  _initVersionNumber() async {
    debugPrint(infoPath);

    await deleteDatabase(infoPath);

    infoDb = await openDatabase(infoPath,
        version: 1,
        onCreate: (Database db, int version) async {
          debugPrint("Creating");
          this.feed_info.listen((Map row) async {
            await _mapToDb(row, db, "feed_info");
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
            debugPrint("Got db version as $dbVersion");
          } catch (e) {
            rethrow;
          }
        }
    );
  }

  _initDatabase() async {
    debugPrint(dbPath);

    db = await openDatabase(dbPath,
      version: dbVersion,
      onCreate: (Database db, int version) async {
        Batch batch = db.batch();
        debugPrint("Creating stops database");

        for(List list in [[this.routes,"routes",routesBuilder],[this.trips, "trips", tripsBuilder], [this.stop_times, "stop_times", stop_timesBuilder], [this.stops ,"stops", stopsBuilder]]){
          debugPrint("Setting up ${list[1]}");
          StreamSubscription sub = list[0].listen((Map row) async {
//            await _mapToBatch(row, db, batch, list[1]);
            await _mapToBuilder(row, db, list[2], list[1]);
//            await _mapToDb(row, db, "routes");
          });

          Future future = sub.asFuture();

          debugPrint("Waiting for ${list[1]}");
          Future.wait([future]).then((List e) async {
            debugPrint("Commiting ${list[1]}");
//            await batch.commit(noResult: true);
            await db.execute(list[2].getQuery());
            debugPrint("done ${list[1]}");

            if(list[1] == "stop_times") {
              debugPrint("collapsing database");
              await _collapseDatabase(db);
              debugPrint("done");
            }
          });

        }
//        List<StreamSubscription> subscriptions = [
//          this.routes.listen((Map row) async {
//            await _mapToBatch(row, db, batch, "routes");
////            await _mapToDb(row, db, "routes");
//          }),
//          this.trips.listen((Map row) async {
//            await _mapToBatch(row, db, batch, "trips");
////            await _mapToDb(row, db, "trips");
//          }),
//          this.stop_times.listen((Map row) async {
//            await _mapToBatch(row, db, batch, "stop_times");
////            await _mapToDb(row, db, "stop_times");
//          }),
//          this.stops.listen((Map row) async {
//            await _mapToBatch(row, db, batch, "stops");
////            await _mapToDb(row, db, "stops");
//          })
//        ];
//
//        List<Future> futures = subscriptions.map((StreamSubscription sub) => sub.asFuture()).toList();
//
//        debugPrint("Waiting for streams to close");
//
//        Future.wait(futures).then((List e) async {
//          debugPrint("Streamse closed, commiting to db");
//          await batch.commit(noResult: true);
//          debugPrint("Committed");
//          debugPrint(e.toString());
//          subscriptions.forEach((s) {
//            s.cancel();
//          });
//          subscriptions.clear();
//          futures.clear();
//          _collapseDatabase(db);
//        });
      }
    );
  }

  // Create new table stop_routes linking stops to routes
  _collapseDatabase(Database db) async {
    debugPrint("Creating stop_routes");
    const String sql = """
    CREATE TABLE stop_routes AS
    SELECT DISTINCT routes.route_short_name, routes.route_long_name, stops.stop_code, stops.stop_name FROM routes
    JOIN trips ON routes.route_id = trips.route_id
    JOIN stop_times ON trips.trip_id = stop_times.trip_id
    JOIN stops ON stop_times.stop_id = stops.stop_id;
    """;
    debugPrint(sql);
    await db.execute(sql);
    debugPrint("Done");

    debugPrint("Deleting extra tables");
//    const String sqlDelete = """
//    DROP TABLE routes;
//    DROP TABLE trips;
//    DROP TABLE stop_times;
//    """;
//    debugPrint(sqlDelete);
//    await db.execute(sqlDelete);
    await db.delete("routes");
    await db.delete("trips");
    await db.delete("stop_times");
    debugPrint("Done");

  }
}

class dbInsertBuilder {
  final String tableName;
  StringBuffer _query;
  bool hasValues;

  dbInsertBuilder(this.tableName) {
    hasValues = false;
    _query = new StringBuffer("INSERT INTO ${this.tableName} VALUES");
  }

  void addEntry(List<String> row){
    hasValues = true;
    _query.write("(${row.map((String value) => "\"$value\"").toList().join(",")}),");
  }

  void _reset() {
    _query.clear();
    _query = new StringBuffer("INSERT INTO ${this.tableName} VALUES");
    hasValues = false;
  }

  String getQuery() {
    if(hasValues) {
      String raw = _query.toString();
//      debugPrint("Releasing query:");
//      debugPrint(raw);
      _reset();
      return "${raw.substring(0, raw.length - 1)};";
    }
  }
}
