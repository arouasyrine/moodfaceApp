import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:moodface/screens/login.dart';
import 'camera.dart';
import 'Historique.dart';
import 'statistiques.dart';
import 'profil.dart';
import '../data_store.dart';
import '../translations.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,// Empêche le redimensionnement lorsque le clavier apparaît
      extendBodyBehindAppBar: true,/* Permet à l'arrière-plan de s'étendre derrière l'AppBar pour un effet plus immersif */
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 10, top: 10, bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF4A148C), size: 20),
            onPressed: () {
              DataStore().clear();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen(cameras: widget.cameras)),
              );
            },
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3E5F5), Colors.white],
          ),
        ),
        child: SafeArea(/*SafeArea pour éviter que le contenu ne soit caché par les bords de l'écran*/
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,/*Alignement à gauche pour tous les enfants de la colonne*/
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${Translations.t('hello')}, ${DataStore().userName ?? 'Utilisateur'} 👋",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4A148C),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        Translations.t('dashboard'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.purple.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Stats Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  padding: const EdgeInsets.all(22),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(/*Stack permet de superposer des widgets les uns sur les autres, ici pour le texte et l'icône d'analyse en arrière-plan*/
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Translations.t('total_analyses'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "${DataStore().totalAnalyses}",
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "+${DataStore().totalAnalyses} ${Translations.t('this_month')}",
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Positioned(
                        right: -10,
                        bottom: -10,
                        child: Opacity(/*Opacity permet de rendre le widget semi-transparent, ici pour l'icône d'analyse en arrière-plan*/
                          opacity: 0.2,
                          child: Icon(Icons.analytics_rounded, size: 80, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // Latest Emotion
                // Latest Emotion
                (() {
                  final last = DataStore().lastRecord;
                  if (last == null) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          Translations.t('no_analyses'),
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 25),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: last.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            last.icon,
                            size: 30,
                            color: last.color,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Translations.t('last_mood'),
                                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        Translations.translateEmotion(last.emotion),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded, size: 10, color: Colors.grey.shade400),
                                          const SizedBox(width: 4),
                                          Text(
                                            last.date,
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(Icons.access_time_rounded, size: 10, color: Colors.grey.shade400),
                                          const SizedBox(width: 4),
                                          Text(
                                            last.time,
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: last.color,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      last.confidence,
                                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                })(),
                const SizedBox(height: 15),
                // Partition
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Translations.t('global_dist'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      _buildEmotionProgress(Translations.translateEmotion("Heureux"), DataStore().getEmotionPercentage("Heureux"), DataStore().getEmotionPercentageValue("Heureux"), Icons.sentiment_satisfied_alt_outlined, Colors.green),
                      _buildEmotionProgress(Translations.translateEmotion("Neutre"), DataStore().getEmotionPercentage("Neutre"), DataStore().getEmotionPercentageValue("Neutre"), Icons.sentiment_neutral_outlined, Colors.orange),
                      _buildEmotionProgress(Translations.translateEmotion("Triste"), DataStore().getEmotionPercentage("Triste"), DataStore().getEmotionPercentageValue("Triste"), Icons.sentiment_dissatisfied_outlined, Colors.blue),
                      _buildEmotionProgress(Translations.translateEmotion("Surpris"), DataStore().getEmotionPercentage("Surpris"), DataStore().getEmotionPercentageValue("Surpris"), Icons.auto_awesome_rounded, Colors.purple),
                      _buildEmotionProgress(Translations.translateEmotion("Peur"), DataStore().getEmotionPercentage("Peur"), DataStore().getEmotionPercentageValue("Peur"), Icons.scuba_diving_rounded, Colors.indigo),
                      _buildEmotionProgress(Translations.translateEmotion("En colère"), DataStore().getEmotionPercentage("En colère"), DataStore().getEmotionPercentageValue("En colère"), Icons.sentiment_very_dissatisfied_outlined, Colors.red),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CameraScreen(cameras: widget.cameras)),
                            );
                            setState(() {});
                          },
                          label: Text(Translations.t('new_analysis'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C27B0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 8,
                            shadowColor: Colors.purple.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (index == 1) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CameraScreen(cameras: widget.cameras),
              ),
            );
            setState(() {});
          } else if (index == 2) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Historique(),
              ),
            );
            setState(() {});
          } else if (index == 3) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StatistiquesScreen(),
              ),
            );
            setState(() {});
          } else if (index == 4) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilScreen(cameras: widget.cameras),
              ),
            );
            setState(() {});
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,/*Permet d'afficher plus de 3 items sans les faire basculer en mode "shifting"*/
        selectedItemColor: const Color(0xFF6A1B9A),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: Translations.t('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.camera_alt_outlined),
            activeIcon: const Icon(Icons.camera_alt),
            label: Translations.t('nav_analysis'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: Translations.t('nav_history'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: Translations.t('nav_stats'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: Translations.t('nav_profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionProgress(
    String label,
    String percentage,
    double value,/*valeur de progression entre 0 et 1 pour le LinearProgressIndicator*/
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 65,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2E2F),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(/*ClipRRect permet de découper le LinearProgressIndicator avec des coins arrondis*/
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),/*AlwaysStoppedAnimation permet de définir une couleur fixe pour le LinearProgressIndicator*/
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

