import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart';

class BusStop {
  BusStop({
    @required this.id,
    @required this.name,
    @required this.desc,
    @required this.lat,
    @required this.lon,
    @required this.routes,
  });

  String id, name, desc;
  double lat, lon;
  List<BusRoute> routes;

  BusStop.fromMap(Map map) {
    List<Map> m_routes = map["routes"];
    id = map["stop_code"];
    name = map["stop_name"];
    desc = map["stop_desc"];
    lat = double.parse(map["stop_lat"]);
    lon = double.parse(map["stop_lon"]);
    routes = m_routes.map((Map route) {
      return BusRoute.fromMap(route);
    }).toList();
  }

  printInfo() {
    debugPrint("id: $id");
    debugPrint("name: $name");
    for(BusRoute route in routes) {
      debugPrint("${route.id}, ${route.name}");
    }
  }
}

class BusRoute {
  BusRoute({
    @required this.id,
    @required this.name,
    this.desc,
  });

  String id, name, desc;

  BusRoute.fromMap(Map map) {
    id = map["route_short_name"];
    name = map["route_long_name"];
  }
}