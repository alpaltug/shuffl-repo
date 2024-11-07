// main.dart
import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/login/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/screens/create_profile/create_profile.dart';
import 'package:my_flutter_app/screens/verification/verification_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isRemembered = false;
  bool _isLoading = true;
  User? _user;
  bool _isProfileComplete = false;
  bool _isEmailPasswordUser = false; 

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkRememberMe();
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Determine if the user signed in with email/password
        List<UserInfo> providers = user.providerData;
        _isEmailPasswordUser =
            providers.any((provider) => provider.providerId == 'password');

        if (_isEmailPasswordUser && !user.emailVerified) {
          // User signed in with email/password and hasn't verified email
          setState(() {
            _user = user;
            _isProfileComplete = false;
            _isLoading = false;
          });
          return; // Exit early to stay on VerificationScreen
        }

        // For Google, Apple, or email/password users with verified email, check Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          bool hasRequiredFields = data.containsKey('fullName') &&
              data.containsKey('username') &&
              data.containsKey('description') &&
              data.containsKey('age') &&
              data.containsKey('sexAssignedAtBirth');
          setState(() {
            _user = user;
            _isProfileComplete = hasRequiredFields;
            _isLoading = false;
          });
        } else {
          setState(() {
            _user = user;
            _isProfileComplete = false;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _user = null;
          _isProfileComplete = false;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    bool isRemembered = prefs.getBool('remember_me') ?? false;

    setState(() {
      _isRemembered = isRemembered;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_user != null) {
      if (_isProfileComplete) {
        return MaterialApp(
          navigatorObservers: [routeObserver],
          debugShowCheckedModeBanner: false,
          title: 'Shuffl',
          theme: ThemeData(
            scaffoldBackgroundColor: kBackgroundColor,
            primaryColor: kPrimaryColor,
            textTheme: Theme.of(context).textTheme.apply(bodyColor: kTextColor),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: const HomePage(),
        );
      } else {
        if (_isEmailPasswordUser) {
          return MaterialApp(
            navigatorObservers: [routeObserver],
            debugShowCheckedModeBanner: false,
            title: 'Shuffl',
            theme: ThemeData(
              scaffoldBackgroundColor: kBackgroundColor,
              primaryColor: kPrimaryColor,
              textTheme: Theme.of(context).textTheme.apply(bodyColor: kTextColor),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            home: const VerificationScreen(),
          );
        } else {
          return MaterialApp(
            navigatorObservers: [routeObserver],
            debugShowCheckedModeBanner: false,
            title: 'Shuffl',
            theme: ThemeData(
              scaffoldBackgroundColor: kBackgroundColor,
              primaryColor: kPrimaryColor,
              textTheme: Theme.of(context).textTheme.apply(bodyColor: kTextColor),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            home: CreateProfileRedirect(),
          );
        }
      }
    } else {
      return MaterialApp(
        navigatorObservers: [routeObserver],
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
}

class CreateProfileRedirect extends StatefulWidget {
  const CreateProfileRedirect({Key? key}) : super(key: key);

  @override
  _CreateProfileRedirectState createState() => _CreateProfileRedirectState();
}

class _CreateProfileRedirectState extends State<CreateProfileRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const CreateProfile(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}