import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/onboarding.dart';
import 'notification_service.dart';
import 'data_store.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  await NotificationService().init();
  await DataStore().initDir();

  runApp(const MoodFaceApp());
}

class MoodFaceApp extends StatelessWidget {
  const MoodFaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: DataStore().languageNotifier,
      builder: (context, language, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MoodFace AI',
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            colorSchemeSeed: const Color.fromARGB(255, 179, 88, 193),
            scaffoldBackgroundColor: const Color(0xFFFBF6FF),
            visualDensity: VisualDensity.adaptivePlatformDensity,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF4A148C)),
              titleTextStyle: TextStyle(
                color: Color(0xFF4A148C),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          home: OnboardingScreen(cameras: cameras),
        );
      },
    );
  }
}
