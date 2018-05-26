import 'package:flutter/material.dart';
import 'package:uplink_flutter/models/stop.dart';

class BusStopListItemView extends StatefulWidget {
  BusStopListItemView(this.stop);
  final BusStop stop;

  @override
  BusStopListItemViewState createState() => BusStopListItemViewState();
}

class BusStopListItemViewState extends State<BusStopListItemView> {
  BusStop stop;

  @override
  void initState() {
    super.initState();
    stop = widget.stop;
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
        initiallyExpanded: false,
//        onExpansionChanged: (b) => movieState.isExpanded = b,
//        children: <Widget>[
//          Container(
//            padding: EdgeInsets.all(10.0),
//            child: RichText(
//              text: TextSpan(
//                text: movieState.overview,
//                style: TextStyle(
//                  fontSize: 14.0,
//                  fontWeight: FontWeight.w300,
//                ),
//              ),
//            ),
//          )
//        ],
//        leading: IconButton(
//          icon: movieState.favored ? Icon(Icons.star) : Icon(Icons.star_border),
//          color: Colors.white,
//          onPressed: () {
//            setState(() => movieState.favored = !movieState.favored);
//            movieState.favored == true
//                ? db.addMovie(movieState)
//                : db.deleteMovie(movieState.id);
//          },
//        ),
        title: Container(
            padding: EdgeInsets.all(10.0),
            child: Row(
              children: <Widget>[
                Text(stop.id),
                Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[

                      ],
                    )
                )
              ],
            )));
  }
}