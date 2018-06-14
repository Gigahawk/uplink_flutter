import 'dart:core';
import 'dart:async';
import 'dart:io';
import 'package:geolocation/geolocation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:uplink_flutter/location.dart';
import 'package:uplink_flutter/models/stop.dart';

class TranslinkDataProcessor {
  final String url;
  final String dbName, infoDbName;
  int dbVersion;
  final bool databaseReady;
  Database db,infoDb;

  Directory _documentsDirectory, _tempDirectory;
  String _infoPath, _dbPath;

  // Incoming streams from csv data, named according to GTFS spec:
  // https://developers.google.com/transit/gtfs/reference/
  final Stream<Map> feed_info, routes, trips, stop_times, stops;
  int feed_info_lines, routes_lines, trips_lines, stop_times_lines, stops_lines;
  int totalLines;
  int _currentProgress;
  dbInsertBuilder routesBuilder, tripsBuilder, stop_timesBuilder, stopsBuilder;

  StreamController<double> progressController;
  StreamController<String> statusController;

  TranslinkDataProcessor({
    this.url: 'http://ns.translink.ca/gtfs/google_transit.zip',
    this.dbName: 'stops.db',
    this.infoDbName: 'feed_info.db',
    @required this.feed_info,
    @required this.routes,
    @required this.trips,
    @required this.stop_times,
    @required this.stops,
    @required this.feed_info_lines,
    @required this.routes_lines,
    @required this.trips_lines,
    @required this.stop_times_lines,
    @required this.stops_lines,
  }) {
    assert(routes != null);
    assert(trips != null);
    assert(stop_times != null);
    assert(stops != null);
    _currentProgress = 0;
    totalLines =
        (routes_lines - 1) + (trips_lines - 1) +
            (stop_times_lines - 1) + (stops_lines + 1);
    debugPrint(totalLines.toString());

    progressController = new StreamController<double>();
    statusController = new StreamController<String>();
    routesBuilder = new dbInsertBuilder("routes");
    tripsBuilder = new dbInsertBuilder("trips");
    stop_timesBuilder = new dbInsertBuilder("stop_times");
    stopsBuilder = new dbInsertBuilder("stops");
  }

  setupDatabase() async {
    _documentsDirectory = await getApplicationDocumentsDirectory();
    _tempDirectory = await getTemporaryDirectory();
    _infoPath = join(_documentsDirectory.path, infoDbName);
    _dbPath = join(_documentsDirectory.path, dbName);
    await _initVersionNumber();
    await _initDatabase();
  }

  // This should use batch for efficiency but it doesnt seem to work
  _mapToDb(Map map, Database db, String tableName, int max) async {
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
      await db.execute(sql);
    }
    progressController.add(rowNum.toDouble()/max);
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
      builder.addEntry(values);
      if(rowNum % 10000 == 0) {
        _currentProgress += 10000;
        debugPrint("$_currentProgress/$totalLines");
        progressController.add(_currentProgress.toDouble()/totalLines);
        debugPrint("Committing $tableName row ${map['rowNum']}");
        await db.execute(builder.getQuery());
        debugPrint("Done $tableName row ${map['rowNum']}");
      }
    }
  }

  _initVersionNumber() async {
    debugPrint(_infoPath);

    statusController.add("Verifying date");
    progressController.add(0.0);
    if(feed_info == null){
      debugPrint("Warning: feed info not found");
      DateTime now = DateTime.now();
      String year = now.year.toString();
      progressController.add(0.2);
      String month = now.month.toString().padLeft(2,'0');
      String day = now.day.toString().padLeft(2,'0');
      String date = year + month + day;
      debugPrint(date);
      progressController.add(0.7);
      dbVersion = int.parse(date);
      progressController.add(1.0);
      return;
    }


    await deleteDatabase(_infoPath);

    infoDb = await openDatabase(_infoPath,
        version: 1,
        onCreate: (Database db, int version) async {
          debugPrint("Creating");
          this.feed_info.listen((Map row) async {
              await _mapToDb(row, db, "feed_info", feed_info_lines);
            },
            onDone: () {
              progressController.add(1.0);
              File("${_tempDirectory.path}/feed_info.txt").delete();
          });
        },
        onOpen: (Database db) async {
          progressController.add(-1.0);
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
    debugPrint(_dbPath);

    statusController.add("Setting up database...");
    progressController.add(0.0);

    db = await openDatabase(_dbPath,
      version: dbVersion,
      onCreate: (Database db, int version) async {
        Batch batch = db.batch();
        debugPrint("Creating stops database");

        for(List list in [[this.routes,"routes",routesBuilder],[this.trips, "trips", tripsBuilder], [this.stop_times, "stop_times", stop_timesBuilder], [this.stops ,"stops", stopsBuilder]]){
          debugPrint("Setting up ${list[1]}");
          StreamSubscription sub = list[0].listen((Map row) async {
            await _mapToBuilder(row, db, list[2], list[1]);
          });

          Future future = sub.asFuture();

          debugPrint("Waiting for ${list[1]}");
          Future.wait([future]).then((List e) async {
            debugPrint("Commiting ${list[1]}");
            await db.execute(list[2].getQuery());
            debugPrint("done ${list[1]}");

            File("${_tempDirectory.path}/${list[1]}.txt").delete();

            if(list[1] == "stop_times") {
              debugPrint("collapsing database");
              await _collapseDatabase(db);
              debugPrint("done");
            }
          });
        }
      }
    );
  }

  // Create new table stop_routes linking stops to routes
  _collapseDatabase(Database db) async {
    statusController.add("Cleaning up...");
    progressController.add(-1.0);
    debugPrint("Creating stop_routes");
    const String sql = """
    CREATE TABLE stop_routes AS
    SELECT DISTINCT routes.route_short_name, routes.route_long_name, stops.stop_code, stops.stop_name, trips.trip_headsign FROM routes
    JOIN trips ON routes.route_id = trips.route_id
    JOIN stop_times ON trips.trip_id = stop_times.trip_id
    JOIN stops ON stop_times.stop_id = stops.stop_id;
    """;
    debugPrint(sql);
    await db.execute(sql);
    progressController.add(0.0);
    debugPrint("Done");

    debugPrint("Deleting routes");
    await db.delete("routes");
    progressController.add(0.2);
    debugPrint("Deleting trips");
    await db.delete("trips");
    progressController.add(0.4);
    debugPrint("Deleting stop_times");
    await db.delete("stop_times");
    progressController.add(0.8);
    const String sqlDelete = """
    DROP TABLE routes;
    DROP TABLE trips;
    DROP TABLE stop_times;
    """;
    debugPrint(sqlDelete);
    await db.execute(sqlDelete);
    statusController.add("Done");
    progressController.add(420.0);
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
      _reset();
      return "${raw.substring(0, raw.length - 1)};";
    }
  }
}

class TranslinkDbAdapter {
  static Database _db;
  TranslinkDbAdapter(String path) {
    _setupDatabase(path);
  }

  _setupDatabase(String path) async {
    _db = await openReadOnlyDatabase(path);
  }

  Future<List<BusStop>> findStopsById(String id) async {
    if(_db == null){
      return null;
    }
    List<BusStop> busStops = [];
    List<Map> stops = await _db.query("stops",
      columns: ["stop_lat", "stop_lon", "stop_code", "stop_name"],
      where: "stop_code LIKE '$id%'",
      limit: 5,
    );
    debugPrint("Got ${stops.length.toString()} stops");

    for(Map stop in stops) {
      Map busStop = Map.from(stop);
      List<Map> routes = await _db.query("stop_routes",
          columns: ["route_short_name", "route_long_name", "trip_headsign"],
          where: "stop_code = ?",
          whereArgs: [stop["stop_code"]]
      );
      debugPrint("Got ${routes.length.toString()} routes");
      busStop["routes"] = routes;
      busStops.add(BusStop.fromMap(busStop));
    }

    return busStops;
  }

  Future<List<BusStop>> findStopsByLocation(location) async {
    if(_db == null){
      return null;
    }
    MyLocation myLocation;
    if(location is Location)
      myLocation = MyLocation.fromLocation(location);
    else if(location is MyLocation)
      myLocation = location;
    else
      return null;
    double lat = myLocation.lat;
    double lon = myLocation.lon;

    List<BusStop> busStops = [];
    List<Map> stops = await _db.query("stops",
      columns: ["stop_lat", "stop_lon", "stop_code", "stop_name"],
      orderBy: "ABS(($lat - stop_lat)*($lat - stop_lat) + ($lon - stop_lon)*($lon - stop_lon))",
      limit: 5,
    );
//    debugPrint("Got ${stops.length.toString()} stops");

    for(Map stop in stops) {
      Map busStop = Map.from(stop);
      List<Map> routes = await _db.query("stop_routes",
          columns: ["route_short_name", "route_long_name", "trip_headsign"],
          where: "stop_code = ?",
          whereArgs: [stop["stop_code"]]
      );
//      debugPrint("Got ${routes.length.toString()} routes");
      busStop["routes"] = routes;
      busStops.add(BusStop.fromMap(busStop, fromGPS: true));
    }

    return busStops;
  }

}