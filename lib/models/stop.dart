import 'package:meta/meta.dart';

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

//  Movie.fromJson(Map json)
//      : title = json["title"],
//        posterPath = json["poster_path"],
//        id = json["id"].toString(),
//        overview = json["overview"],
//        favored = false;
//
//  Map<String, dynamic> toMap() {
//    var map = Map<String, dynamic>();
//    map['id'] = id;
//    map['title'] = title;
//    map['poster_path'] = posterPath;
//    map['overview'] = overview;
//    map['favored'] = favored;
//    return map;
//  }
//
//  Movie.fromDb(Map map)
//      : title = map["title"],
//        posterPath = map["poster_path"],
//        id = map["id"].toString(),
//        overview = map["overview"],
//        favored = map['favored'] == 1 ? true : false;
}

class BusRoute {
  BusRoute({
    @required this.id,
    @required this.short_name,
    @required this.long_name,
    this.desc,
  });

  String id, short_name, long_name, desc;
}