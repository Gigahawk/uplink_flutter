import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingView extends StatefulWidget{
  @override
  OnboardingState createState() => OnboardingState();
}

// Use GlobalKey to get state of child scaffold so that we can display a
// snackbar warning when the user tries to exit out of the onboarding screen
final GlobalKey<ScaffoldState> onboardKey = new GlobalKey<ScaffoldState>();

class OnboardingState extends State<OnboardingView> {



  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        onboardKey.currentState.showSnackBar(SnackBar(
          content: new Text('no lastCheck'),
          duration: Duration(seconds:3),
        ));
        return false;
      },
      child: Stack(
        children: <Widget>[
          OnboardingLogoPage(),
        ],
      )
    );
  }
}

class OnboardingLogoPage extends StatelessWidget {

  static const _methodChannel = const MethodChannel('runtimepermissions/SMS');

  Widget build(BuildContext context) {
    return Scaffold(
      key: onboardKey,
      bottomNavigationBar: BottomAppBar(
        elevation: 0.0,
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.navigate_next),
              onPressed: () {
                onboardKey.currentState.showSnackBar(SnackBar(
                  content: new Text('grabbing permissions'),
                  duration: Duration(seconds:3),
                ));

                _methodChannel.invokeMethod('hasPermission');

              },
            ),
          ],
        )
      ),
      body: Container(
        width: double.infinity, // Fill screen
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
                "assets/images/logo.png",
                width: 200.0,
                height: 200.0
            ),
            Text(
              "Welcome to Uplink",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 34.0,
              ),
            ),
            Text(
              "Your offline Translink assistant",
              style: TextStyle(
                fontSize: 18.0,
              ),
            )
          ],
        )
      )
    );
  }
}

enum PermissionState {
  GRANTED,
  DENIED,
  SHOW_RATIONALE //  Refer https://developer.android.com/training/permissions/requesting.html#explain
}
