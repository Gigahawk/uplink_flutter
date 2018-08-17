import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocation/geolocation.dart';
import 'package:uplink_flutter/location.dart';
import 'package:uplink_flutter/models/stop.dart';

class StopView extends StatefulWidget {
  final BusStop stop;

  StopView(this.stop);

  @override
  _StopState createState() => new _StopState();
}

class _StopState extends State<StopView> {

  String _distance = "3m";
  LocationResult _currLocation;

  static const double _elevation = 5.0;
  static ShapeBorder _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20.0),
  );
  static const double _headerHeight = 60.0;
  static const double _headerLineHeight = 1.5;
  static const EdgeInsets _headerPadding = EdgeInsets.only(
    top: 25.0,
    left: 20.0,
    right: 20.0,
  );
  static const Color _headerColor = Color(0xFFFFD51F);
  static const TextStyle _headerStyle = TextStyle(
    color: _headerColor,
    fontWeight: FontWeight.bold,
    fontSize: 20.0
  );

  static const double _footerHeight = 50.0;
  static const EdgeInsets _footerPadding = EdgeInsets.only(
    left: 20.0 + 16.0
  );
  static const TextStyle _footerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 20.0
  );

  Widget _buildRoutes(BuildContext context){
    return Column(
      children: widget.stop.routes.map((BusRoute route) => RouteView(route)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final container = LocationContainer.of(context);
    _currLocation = container.location;
    return Card(
      elevation: _elevation,
      margin: EdgeInsets.all(10.0),
      shape: _cardShape,
      child: Column(
        children: <Widget>[
          Container(
            height: _headerHeight,
            width: double.infinity,
            color: Theme.of(context).primaryColor,
            child: Padding(
              padding: _headerPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(widget.stop.id,
                    textAlign: TextAlign.end,
                    style: _headerStyle,
                  ),
                  Container(
                    color: _headerColor,
                    width: double.infinity,
                    height: _headerLineHeight,
                  )
                ],
              ),
            ),
          ),

          _buildRoutes(context),

          Container(
            margin: EdgeInsets.only(
              top: 8.0
            ),
            color: Colors.grey,
            height: _footerHeight,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: _footerPadding,
                  child: Text("Distance: ${_currLocation != null ? "${widget.stop.currDistance(_currLocation.location).toInt().toString()}m" : "Unknown"}",
                    textAlign: TextAlign.start,
                    style: _footerStyle,
                  ),
                )
              ],
            ),
          )
        ],
      ),

    );
  }

}

class RouteView extends StatefulWidget {
  final BusRoute route;

  RouteView(this.route);

  @override
  _RouteState createState() => new _RouteState();
}

class _RouteState extends State<RouteView> {
  @override
  void initState(){
    super.initState();
    _statusSub = widget.route.status.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    super.dispose();
    _statusSub.cancel();
  }

  static const EdgeInsets _expansionTileChildPadding = const EdgeInsets.only(
    left: 16.0,
    right: 56.0,
  );

  static const EdgeInsets _routePadding = const EdgeInsets.only(
    left: 20.0,
    right: 40.0,
  );

  static StreamSubscription _statusSub;

  static const String _theBus = "33333";
  static const double _routeShortNameWidth = 50.0;
  static const double _routeDataSize = 15.0;
  static const double _routeRowHeight = 1.5;
  static const TextStyle _routeTextStyle = TextStyle(
      color: const Color(0xFF00355D),
      fontWeight: FontWeight.bold,
      fontSize: 20.0,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onLongPress: () {
            HapticFeedback.vibrate();
            setState(() {
              widget.route.isExpanded = true;
            });
            widget.route.getData();
          },
          child: ExpansionTile(
            initiallyExpanded: widget.route.isExpanded ?? false,
            onExpansionChanged: (bool open) {
              widget.route.isExpanded = open;
              // Only get data if there isn't already data
              if(open && widget.route.nextBus == null){
                widget.route.getData();
              }
            },
            title: Padding(
              padding: _routePadding.add(EdgeInsets.only(top: 8.0)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: _routeShortNameWidth,
                    child: Text(widget.route.id,
                      style: _routeTextStyle,
                    ),
                  ),
                  // Needed to make text wrapping work properly,
                  // see https://github.com/flutter/flutter/issues/4128
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.route.name,
                          style: _routeTextStyle,
                        )
                      ],
                    ),
                  )
                ],
              )
            ),
            children: <Widget>[
              Padding(
                padding: _expansionTileChildPadding,
                child: Padding(
                  padding: _routePadding,
                  child: widget.route.nextBus != null ? Row(
                    children: <Widget>[
                      Container(width: _routeShortNameWidth),
                      Text(widget.route.nextBus,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: _routeDataSize,
                        ),
                      ),
                    ],
                  ) : LinearProgressIndicator(),
                ),

              )
            ],
          ),
        ),
        Padding(
          padding: _expansionTileChildPadding.add(_routePadding),
          child: Container(
            color: Theme.of(context).primaryColor,
            width: double.infinity,
            height: _routeRowHeight,
          ),
        )
      ],
    );
  }

}



