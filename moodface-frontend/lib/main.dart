import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/login.dart';
import 'notification_service.dart';

late List<CameraDescription> cameras;

Future<void> main() async/*la fonction main est asynchrone car nous devons attendre l'initialisation des caméras avant de lancer l'application*/ {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  await NotificationService().init();
  runApp(const MoodFaceApp());
}

class MoodFaceApp extends StatelessWidget {
  const MoodFaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,//supprime le bandeau de debug en haut à droite de l'application
      title: 'MoodFace AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color.fromARGB(255, 179, 88, 193),
        visualDensity: VisualDensity.adaptivePlatformDensity,/*ajuster la densité visuelle selon la plateforme*/
      ),
      // Start with LoginScreen
      home: LoginScreen(cameras: cameras),
    );
  }
}
