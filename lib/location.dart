import 'dart:math';

import 'package:geolocation/geolocation.dart';
import 'package:flutter/material.dart';

import 'dart:async';

class _InheritedLocationContainer extends InheritedWidget {
  final LocationContainerState data;

  const _InheritedLocationContainer({
    Key key,
    @required this.data,
    @required Widget child
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(_InheritedLocationContainer oldWidget) => true;

}

class LocationContainer extends StatefulWidget {
  final Widget child;
  final LocationResult location;

  LocationContainer({
    @required this.child,
    this.location
  });

  static LocationContainerState of(BuildContext context) =>
      (context.inheritFromWidgetOfExactType(_InheritedLocationContainer) as _InheritedLocationContainer).data;

  @override
  LocationContainerState createState() => new LocationContainerState();
}

class LocationContainerState extends State<LocationContainer> {
  LocationResult location;
  StreamSubscription<LocationResult> subscription;

  void _updateLocation(LocationResult _location) {
    if(_location.isSuccessful)
      setState(() {
        location = _location;
      });
  }

  @override
  void initState() {
    super.initState();
    _waitForPermission();
  }

  void _waitForPermission() async {
    GeolocationResult result = await Geolocation.isLocationOperational();
    while(!result.isSuccessful)
      result = await Geolocation.isLocationOperational();

    subscription = Geolocation.locationUpdates(
      accuracy: LocationAccuracy.best,
      displacementFilter: 0.0,
      inBackground: false,
    ).listen((LocationResult result) {
      _updateLocation(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return new _InheritedLocationContainer(data: this, child: widget.child);
  }

}

// geolocation doesn't provide a constructor for Location
class MyLocation {
  double lat, lon;
  MyLocation(this.lat, this.lon);

  MyLocation.fromLocation(Location location) {
    lat = location.latitude;
    lon = location.longitude;
  }

}


// Radius of the Earth at Vancouver (m)
const double _vancRadius = 6365909.533052556;

// Approximate Vancouver as a flat surface _vancRadius away from the center of
// of the Earth, calculate distance between angles
double distanceApprox(MyLocation first, MyLocation second) {
  double dlon = (first.lon - second.lon).abs();
  double dlat = (first.lat - second.lat).abs();
  double dx = _vancRadius*tan(dlon*pi/180);
  double dy = _vancRadius*tan(dlat*pi/180);
  double dist = sqrt(pow(dx,2) + pow(dy,2));
  return dist;
}

