import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/display_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/call_screen.dart';
import 'services/webrtc_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data['type'] == 'call') {
    final params = CallKitParams(
      id: message.data['uuid'] ?? 'call_id_${DateTime.now().millisecondsSinceEpoch}',
      nameCaller: message.data['callerName'] ?? 'Unknown Caller',
      appName: 'Vylithra',
      avatar: 'https://i.pravatar.cc/100', // You can pass actual avatar in data
      handle: message.data['hasVideo'] == 'true' ? 'Video Call' : 'Voice Call',
      type: 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{'userId': message.data['senderId']},
      headers: <String, dynamic>{'apiKey': 'vylithra_key'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        backgroundUrl: 'assets/test.png',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: '',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    DisplayService().init();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Fatal Error during Startup:\n$e\n\n$stackTrace',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupCallKitListener();
    _setupGlobalWebRTC();
  }

  void _setupGlobalWebRTC() {
    WebRTCService().ensureInitialized();
    WebRTCService().onIncomingCall = (incomingData) {
      final callerId = incomingData['from']?.toString() ?? '';
      final callerName = (incomingData['callerName'] != null && incomingData['callerName'].toString().isNotEmpty)
          ? incomingData['callerName'].toString()
          : 'Incoming Call';
      final isVideo = incomingData['isVideo'] == true;
      if (callerId.isNotEmpty) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              webrtcService: WebRTCService(),
              isIncoming: true,
              autoAccept: false,
              targetUserId: callerId,
              targetUsername: callerName,
              isVideoCall: isVideo,
              incomingData: incomingData,
            ),
          ),
        );
      }
    };

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.data['type'] == 'call') {
        final params = CallKitParams(
          id: message.data['uuid'] ?? 'call_id_${DateTime.now().millisecondsSinceEpoch}',
          nameCaller: message.data['callerName'] ?? 'Unknown Caller',
          appName: 'Vylithra',
          avatar: 'https://i.pravatar.cc/100',
          handle: message.data['hasVideo'] == 'true' ? 'Video Call' : 'Voice Call',
          type: 0,
          duration: 30000,
          textAccept: 'Accept',
          textDecline: 'Decline',
          missedCallNotification: const NotificationParams(
            showNotification: true,
            isShowCallback: true,
            subtitle: 'Missed call',
            callbackText: 'Call back',
          ),
          extra: <String, dynamic>{'userId': message.data['senderId']},
          headers: <String, dynamic>{'apiKey': 'vylithra_key'},
          android: const AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            ringtonePath: 'system_ringtone_default',
            backgroundColor: '#0955fa',
            backgroundUrl: 'assets/test.png',
            actionColor: '#4CAF50',
          ),
          ios: const IOSParams(
            iconName: 'CallKitLogo',
            handleType: '',
            supportsVideo: true,
            maximumCallGroups: 2,
            maximumCallsPerCallGroup: 1,
            audioSessionMode: 'default',
            audioSessionActive: true,
            audioSessionPreferredSampleRate: 44100.0,
            audioSessionPreferredIOBufferDuration: 0.005,
            supportsDTMF: true,
            supportsHolding: true,
            supportsGrouping: false,
            supportsUngrouping: false,
            ringtonePath: 'system_ringtone_default',
          ),
        );
        await FlutterCallkitIncoming.showCallkitIncoming(params);
      }
    });
  }

  void _setupCallKitListener() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      switch (event?.event) {
        case Event.actionCallAccept:
          final body = event?.body;
          if (body != null) {
            final extra = body['extra'] is Map ? Map<String, dynamic>.from(body['extra']) : {};
            final callerId = extra['userId']?.toString() ?? '';
            final callerName = body['nameCaller']?.toString() ?? 'Incoming Call';
            final isVideo = (body['handle']?.toString().contains('Video') ?? false) || (body['hasVideo'] == 'true');
            if (callerId.isNotEmpty) {
              await WebRTCService().ensureInitialized();
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    webrtcService: WebRTCService(),
                    isIncoming: true,
                    autoAccept: true,
                    targetUserId: callerId,
                    targetUsername: callerName,
                    isVideoCall: isVideo,
                    incomingData: {
                      'from': callerId,
                      'isVideo': isVideo,
                      'callerName': callerName,
                    },
                  ),
                ),
              );
            }
          }
          break;
        case Event.actionCallDecline:
          final body = event?.body;
          final extra = (body != null && body['extra'] is Map) ? Map<String, dynamic>.from(body['extra']) : {};
          final callerId = extra['userId']?.toString();
          await WebRTCService().ensureInitialized();
          WebRTCService().rejectCall(callerId);
          break;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Vylithra',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode, // Controlled by ThemeProvider
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF6F0), // Cream vintage background
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFD2691E), // Muted copper/sepia accent
          secondary: Color(0xFFA0522D), // Siena
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF3E2723), // Deep sepia text
        ),
        textTheme: GoogleFonts.loraTextTheme(
          ThemeData.light().textTheme,
        ).apply(
          bodyColor: const Color(0xFF3E2723),
          displayColor: const Color(0xFF3E2723),
        ).copyWith(
          displayLarge: GoogleFonts.playfairDisplay(),
          displayMedium: GoogleFonts.playfairDisplay(),
          displaySmall: GoogleFonts.playfairDisplay(),
          headlineLarge: GoogleFonts.playfairDisplay(),
          headlineMedium: GoogleFonts.playfairDisplay(),
          headlineSmall: GoogleFonts.playfairDisplay(),
          titleLarge: GoogleFonts.playfairDisplay(),
          titleMedium: GoogleFonts.playfairDisplay(),
          titleSmall: GoogleFonts.playfairDisplay(),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF2C241B), // Dark Academia Espresso
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD2691E), // Muted copper/sepia accent
          secondary: Color(0xFFA0522D), // Siena
          surface: Color(0xFF3E2723), // Dark sepia card background
          onSurface: Color(0xFFFAF6F0), // Cream text
        ),
        textTheme: GoogleFonts.loraTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: const Color(0xFFFAF6F0),
          displayColor: const Color(0xFFFAF6F0),
        ).copyWith(
          displayLarge: GoogleFonts.playfairDisplay(),
          displayMedium: GoogleFonts.playfairDisplay(),
          displaySmall: GoogleFonts.playfairDisplay(),
          headlineLarge: GoogleFonts.playfairDisplay(),
          headlineMedium: GoogleFonts.playfairDisplay(),
          headlineSmall: GoogleFonts.playfairDisplay(),
          titleLarge: GoogleFonts.playfairDisplay(),
          titleMedium: GoogleFonts.playfairDisplay(),
          titleSmall: GoogleFonts.playfairDisplay(),
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isInitialized) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }
          if (auth.isAuthenticated) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
