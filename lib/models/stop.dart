import 'package:geolocation/geolocation.dart';
import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart';
import 'package:uplink_flutter/location.dart';

class BusStop {
  BusStop({
    @required this.id,
    @required this.name,
    @required this.desc,
    @required lat,
    @required lon,
    @required uncondensedRoutes,
    this.fromGPS:false,
  }):location = MyLocation(lat,lon),
      routes = _condenseRoutes(uncondensedRoutes);


  bool fromGPS;
  String id, name, desc;
  MyLocation location;
  List<BusRoute> routes;

  static List<BusRoute> _condenseRoutes(List<BusRoute> routes) {
    List<BusRoute> res = new List<BusRoute>();
    Map<String, List<BusRoute>> buckets = new Map<String, List<BusRoute>>();

    for(BusRoute route in routes) {
      String id = route.id;
      if(buckets[id] == null)
        buckets[id] = new List<BusRoute>();
      buckets[id].add(route);
    }

    buckets.forEach((String key, List<BusRoute> bucket) {
      List<String> names = new List<String>();
      String fullName;
      for(BusRoute route in bucket) {
        String sign_text = route.name.split(" ").sublist(1).join(" ");
        if(sign_text.split(" ")[0] == "TO")
          sign_text = sign_text.split(" ").sublist(1).join(" ");

        debugPrint(sign_text);

        if(names.length == 0 || !names.any((String name) => name.contains(sign_text) || sign_text.contains(name)))
          names.add(sign_text);
      }
      BusRoute temp = bucket[0];
      fullName = names.join("/");
      BusRoute fullRoute = new BusRoute(stop_id: temp.stop_id, id: temp.id, name: fullName);
      res.add(fullRoute);
    });

    return res;
  }

  BusStop.fromMap(Map map, {this.fromGPS:false}) {
    List<Map> m_routes = map["routes"];
    id = map["stop_code"];
    name = map["stop_name"];
    desc = map["stop_desc"];
    double lat = double.parse(map["stop_lat"]);
    double lon = double.parse(map["stop_lon"]);
    location = MyLocation(lat,lon);
    routes = _condenseRoutes(m_routes.map((Map route) {
      return BusRoute.fromMap(route,id);
    }).toList());
  }

  double currDistance(currLocation) {
//    debugPrint("getting currdistance");
    if(currLocation is Location)
      return distanceApprox(location, MyLocation.fromLocation(currLocation));
    else if(currLocation is MyLocation)
      return distanceApprox(location, currLocation);
    else
      return null;
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
    @required this.stop_id,
    @required this.id,
    @required this.name,
    this.desc,
  }){
    // Remove leading zeros
    id = id.replaceAll(RegExp(r"^[0]*"), "");
  }

  String stop_id, id, name, desc;

  BusRoute.fromMap(Map map, String _stop_id) {
    stop_id = _stop_id;
    id = map["route_short_name"].replaceAll(RegExp(r"^[0]*"), "");
//    name = map["route_long_name"];
    name = map["trip_headsign"];
  }
}