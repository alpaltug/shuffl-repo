import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';

import 'package:my_flutter_app/screens/login/login.dart';

// import 'package:my_flutter_app/screens/forgot_password/forgot_password.dart';
// import 'package:my_flutter_app/screens/create_profile/create_profile.dart';
// import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
// import 'package:my_flutter_app/screens/signin/signin.dart';



void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shuffl',
      theme: ThemeData(
        scaffoldBackgroundColor: kBackgroundColor,
        primaryColor: kPrimaryColor,
        textTheme: Theme.of(context).textTheme.apply(bodyColor: kTextColor),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const Login(),
    );
  }
}

 