import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import '../mood_service.dart';
import '../data_store.dart'; 
import '../notification_service.dart';
import 'coach_recommendations.dart';
import 'chatbot.dart';
import '../widgets/journal_editor.dart';



class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool isTab;
  final VoidCallback? onCloseTab;
  const CameraScreen({super.key, required this.cameras, this.isTab = false, this.onCloseTab});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin{//SingleTickerProviderStateMixin est utilisé pour fournir un ticker (un signal de synchronisation) à l'AnimationController, ce qui est nécessaire pour les animations dans Flutter.
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isRearCameraSelected = false;//indique si la caméra arrière est sélectionnée (false par défaut pour utiliser la caméra avant en premier)
  bool _isProcessing = false;//indique si une analyse est en cours pour éviter de lancer plusieurs analyses simultanément
  final MoodService _moodService = MoodService();
  FlashMode _flashMode = FlashMode.off;
  
  late AnimationController _scanController;//AnimationController pour gérer l'animation du scan de détection des émotions, il contrôle la durée et le comportement de l'animation qui simule un balayage de haut en bas dans la zone de détection.
  late Animation<double> _scanAnimation;//Animation<double> pour définir la progression de l'animation du scan, elle interpolera entre 0 et 1 pour déplacer le scan de haut en bas dans la zone de détection.

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      // Rechercher la caméra avant par défaut
      int startingIndex = widget.cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front
      );
      // Si aucune caméra avant n'est trouvée, utiliser la première caméra disponible
      if (startingIndex == -1) {
        startingIndex = 0;
      }
      _isRearCameraSelected = widget.cameras[startingIndex].lensDirection == CameraLensDirection.back;
      _initCamera(widget.cameras[startingIndex]);
    }

    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,/*vsync est nécessaire pour les animations, il permet de synchroniser l'animation avec le rafraîchissement de l'écran pour une meilleure performance et fluidité*/
    )..repeat(reverse: true);/*..repeat(reverse: true) permet de faire boucler l'animation en inversant la direction à chaque cycle, créant ainsi un effet de va-et-vient pour le scan*/
    
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_scanController);/*Tween<double>(begin: 0.0, end: 1.0) définit une interpolation linéaire entre 0 et 1 pour l'animation, ce qui correspond à la position du scan de haut en bas dans la zone de détection*/
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
    );
    
    try {
      _initializeControllerFuture = controller.initialize();
      await _initializeControllerFuture;
      _controller = controller;
      
      // Tenter d'appliquer le mode flash actuel
      try {
        await _controller!.setFlashMode(_flashMode);
      } catch (_) {
        _flashMode = FlashMode.off;
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Erreur initialisation caméra: $e");
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    FlashMode newMode;
    switch (_flashMode) {
      case FlashMode.off:
        newMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newMode = FlashMode.always;
        break;
      case FlashMode.always:
        newMode = FlashMode.off;
        break;
      default:
        newMode = FlashMode.off;
    }
    
    try {
      await _controller!.setFlashMode(newMode);
      setState(() {
        _flashMode = newMode;
      });
    } catch (e) {
      debugPrint("Erreur changement mode flash: $e");
      _showError("Flash non supporté sur cette caméra");
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      default:
        return Icons.flash_off_rounded;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();/*Dispose du CameraController pour libérer les ressources utilisées par la caméra lorsque le widget est retiré de l'arbre des widgets*/
    _scanController.dispose();/*Dispose de l'AnimationController pour libérer les ressources utilisées par l'animation lorsque le widget est retiré de l'arbre des widgets*/
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_isProcessing || _controller == null || _initializeControllerFuture == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _initializeControllerFuture;
      final XFile picture = await _controller!.takePicture();
      
      final result = await _moodService.sendImageToBackend(
        File(picture.path),
        userId: DataStore().userId,
      );

      if (mounted) {
        if (result != null && result['status'] == 'success') {
          final recordId = result['record_id'] as int?;
          final record = _saveToDataStore(result['emotion'], result['confidence'].toDouble(), picture.path, recordId: recordId);
          NotificationService().sendAnalysisNotification(result['emotion'], "${result['confidence'].toDouble()}%");
          NotificationService().configureScheduledNotifications();
          _showResult(result['emotion'], result['confidence'].toDouble(), record);
        } else {
          _showError(result?['message'] ?? "Erreur d'analyse");
        }
      }
    } catch (e) {
      debugPrint("Erreur capture: $e");
      _showError("Erreur lors de la capture");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  AnalysisRecord _saveToDataStore(String emotionRaw, double confidence, String? originalImagePath, {int? recordId}) {
    final emotionFrench = _translateEmotion(emotionRaw);
    final icon = _getEmotionIcon(emotionFrench);
    final color = _getEmotionColor(emotionFrench);
    
    final now = DateTime.now();
    final formattedDate = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    final pmAm = now.hour >= 12 ? 'PM' : 'AM';
    final hour12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final formattedTime = "${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $pmAm";

    String? savedPath;
    if (originalImagePath != null) {
      try {
        final file = File(originalImagePath);
        if (file.existsSync()) {
          final dir = DataStore().documentsDirectoryPath;
          if (dir != null) {
            final targetPath = recordId != null
                ? "$dir/analysis_id_$recordId.png"
                : "$dir/analysis_${now.millisecondsSinceEpoch}.png";
            file.copySync(targetPath);
            savedPath = targetPath;
          }
        }
      } catch (e) {
        debugPrint("Erreur lors de la copie locale de l'image de l'analyse : $e");
      }
    }

    final newRecord = AnalysisRecord(
      id: recordId,
      date: formattedDate,
      time: formattedTime,
      emotion: emotionFrench,
      confidence: "${confidence.toStringAsFixed(0)}%",
      icon: icon,
      color: color,
      timestamp: now,
      imagePath: savedPath,
    );

    DataStore().addRecord(newRecord);
    return newRecord;
  }

  String _translateEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy": return "Heureux";
      case "sad": return "Triste";
      case "neutral": return "Neutre";
      case "angry": return "En colère";
      case "surprise": return "Surpris";
      case "fear": return "Peur";
      case "disgust": return "Dégoût";
      default: return emotion;
    }
  }

  void _showResult(String emotionRaw, double confidence, AnalysisRecord record) {
    final detectedEmotion = _translateEmotion(emotionRaw);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getEmotionColor(detectedEmotion).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getEmotionIcon(detectedEmotion),
                      color: _getEmotionColor(detectedEmotion), 
                      size: 70
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Analyse Terminée",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    detectedEmotion,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Score de confiance : ${confidence.toStringAsFixed(1)}%",
                    style: TextStyle(fontSize: 16, color: _getEmotionColor(detectedEmotion), fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop(); // Ferme le dialogue de résultat
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => CoachRecommendationsScreen(
                              emotion: detectedEmotion,
                              confidence: confidence,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.psychology_outlined, color: Colors.white),
                      label: const Text(
                        "CONSEILS DU COACH",
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getEmotionColor(detectedEmotion),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop(); // Ferme le dialogue de résultat
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => ChatbotScreen(
                              initialEmotion: detectedEmotion,
                              initialConfidence: confidence,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
                      label: const Text(
                        "DISCUTER DE L'ANALYSE",
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Fermer le dialogue de résultat
                        showJournalEditorBottomSheet(
                          context: context,
                          record: record,
                          onSave: () {
                            // Rafraîchir l'UI si besoin
                          },
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
                      label: const Text(
                        "COMPLÉTER MON JOURNAL 📝",
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop(); // Ferme le dialogue de résultat
                        if (widget.isTab) {
                          widget.onCloseTab?.call();
                        } else {
                          navigator.pop(); // Ferme la caméra et retourne à l'accueil
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _getEmotionColor(detectedEmotion).withOpacity(0.5), width: 1.5),
                        foregroundColor: _getEmotionColor(detectedEmotion),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text(
                        "RETOURNER À L'ACCUEIL",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case "Heureux": return Icons.sentiment_very_satisfied;
      case "Triste": return Icons.sentiment_very_dissatisfied;
      case "Neutre": return Icons.sentiment_neutral;
      case "En colère": return Icons.sentiment_very_dissatisfied;
      case "Surpris": return Icons.face;
      case "Peur": return Icons.surround_sound;
      case "Dégoût": return Icons.sentiment_dissatisfied;
      default: return Icons.mood;
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case "Heureux": return Colors.green;
      case "Triste": return Colors.blue;
      case "Neutre": return Colors.orange;
      case "En colère": return Colors.red;
      case "Surpris": return Colors.purple;
      case "Peur": return Colors.indigo;
      case "Dégoût": return Colors.brown;
      default: return Colors.grey;
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _isProcessing = true;
        });
        
        final result = await _moodService.sendImageToBackend(
          File(image.path),
          userId: DataStore().userId,
        );

        if (mounted) {
          if (result != null && result['status'] == 'success') {
            final recordId = result['record_id'] as int?;
            final record = _saveToDataStore(
              result['emotion'],
              result['confidence'].toDouble(),
              image.path,
              recordId: recordId,
            );
            NotificationService().sendAnalysisNotification(result['emotion'], "${result['confidence'].toDouble()}%");
            NotificationService().configureScheduledNotifications();
            _showResult(result['emotion'], result['confidence'].toDouble(), record);
          } else {
            _showError(result?['message'] ?? "Erreur d'analyse");
          }
        }
      }
    } catch (e) {
      debugPrint("Erreur galerie: $e");
      _showError("Erreur lors de la sélection");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_controller != null && _initializeControllerFuture != null)
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return ClipRect(
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: 100,
                          height: 100 * _controller!.value.aspectRatio,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
              },
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          _buildScanningOverlay(),
          if (_isProcessing) _buildProcessingOverlay(),
          _buildCameraInterface(),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          SizedBox(
            width: 200,
            height: 280,
            child: AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      top: _scanAnimation.value * 280,
                      child: Container(
                        width: 200,
                        height: 3,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withOpacity(0.6),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ],
                          gradient: const LinearGradient(
                            colors: [Colors.transparent, Colors.purpleAccent, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 5),
            SizedBox(height: 25),
            Text(
              "Analyse IA en cours...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraInterface() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassButton(
                  widget.isTab ? Icons.arrow_back_ios_new_rounded : Icons.close, 
                  () {
                    if (widget.isTab) {
                      widget.onCloseTab?.call();
                    } else {
                      Navigator.pop(context);
                    }
                  }
                ),
                const Text(
                  "SCANNER D'HUMEUR IA",
                  style: TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
                _buildGlassButton(_getFlashIcon(), _toggleFlash),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGlassButton(Icons.photo_library, _pickImageFromGallery),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera, color: Colors.purple, size: 35),
                    ),
                  ),
                ),
                _buildGlassButton(Icons.flip_camera_ios, () {
                  if (widget.cameras.length > 1) {
                    setState(() => _isRearCameraSelected = !_isRearCameraSelected);
                    // On tente d'abord de trouver la caméra correspondante à la direction de lentille voulue
                    final targetDirection = _isRearCameraSelected 
                        ? CameraLensDirection.back 
                        : CameraLensDirection.front;
                    int targetIndex = widget.cameras.indexWhere((c) => c.lensDirection == targetDirection);
                    if (targetIndex == -1) {
                      targetIndex = _isRearCameraSelected ? 0 : 1;
                    }
                    _initCamera(widget.cameras[targetIndex]);
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
