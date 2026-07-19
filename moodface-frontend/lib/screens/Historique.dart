import 'package:flutter/material.dart';
import 'dart:io';
import 'coach_recommendations.dart';
import '../data_store.dart';
import '../translations.dart';
import '../widgets/journal_editor.dart';
import '../mood_service.dart';


class Historique extends StatefulWidget {
  final bool isTab;
  const Historique({super.key, this.isTab = false});

  @override
  State<Historique> createState() => _HistoriqueState();
}

class _HistoriqueState extends State<Historique> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filtrage dynamique de l'historique en fonction de la recherche
    final filteredHistory = DataStore().historyData.where((item) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;

      final translatedEmotion = Translations.translateEmotion(item.userDeclaredEmotion ?? item.emotion).toLowerCase();
      final originalEmotion = (item.userDeclaredEmotion ?? item.emotion).toLowerCase();

      return translatedEmotion.contains(query) || originalEmotion.contains(query);
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0, /*suppression de l'ombre de l'appbar*/
        centerTitle: true,
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab ? null : Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF4A148C), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          Translations.t('nav_history'),
          style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.w900, letterSpacing: -0.5),
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
        child: Column(
          children: [
            const SizedBox(height: 100),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.08),
                      blurRadius: 20, /*plus le blurRadius est élevé, plus l'ombre est floue*/
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: Translations.t('search_analyses'),
                    hintStyle: const TextStyle(color: Colors.black, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.purple),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded( /*permet à la ListView de prendre tout l'espace restant*/
              child: filteredHistory.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final item = filteredHistory[index];
                        return _buildHistoryCard(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 70, color: Colors.purple.shade200),
          const SizedBox(height: 15),
          Text(
            Translations.t('no_analyses') ?? "Aucun résultat trouvé",
            style: TextStyle(
              fontSize: 16,
              color: Colors.purple.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Vérifiez l'orthographe du sentiment recherché",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 60), // Compensation visuelle
        ],
      ),
    );
  }

  Widget _buildHistoryCard(AnalysisRecord item) {
    final imagePath = item.localImagePath;
    final fileExists = imagePath != null && File(imagePath).existsSync();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CoachRecommendationsScreen(
              emotion: item.userDeclaredEmotion ?? item.emotion,
              confidence: double.tryParse(item.confidence.replaceAll('%', '')) ?? 100.0,
            ),
          ),
        );
      },
      onLongPress: () {
        _showDeleteConfirmationDialog(context, item);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.shade50),
        ),
        child: Row(
          children: [
            // Image de l'analyse ou Portrait placeholder
            fileExists
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(imagePath),
                      width: 65,
                      height: 65,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [item.color.withOpacity(0.2), item.color.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.portrait_rounded, color: item.color.withOpacity(0.4), size: 40),
                  ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        Translations.translateEmotion(item.userDeclaredEmotion ?? item.emotion),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                      const SizedBox(width: 8),
                      Icon(item.icon, size: 18, color: item.color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildMetaInfo(Icons.calendar_today_rounded, item.date),
                      _buildMetaInfo(Icons.access_time_rounded, item.time),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                item.confidence,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, AnalysisRecord item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  Translations.t('delete_title') ?? "Supprimer l'analyse",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            Translations.t('delete_confirm') ?? "Voulez-vous vraiment supprimer cette analyse de votre historique ?",
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                Translations.t('cancel') ?? "Annuler",
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context); // Close the dialog
                
                // Sauvegarde pour restauration éventuelle en cas d'échec
                final indexInStore = DataStore().historyData.indexOf(item);
                
                // 1. Mise à jour optimiste : Retrait immédiat de l'interface
                setState(() {
                  DataStore().historyData.remove(item);
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Analyse supprimée avec succès."),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );

                // 2. Appel API en arrière-plan
                if (item.id != null) {
                  bool success = await MoodService().deleteHistoryRecord(item.id!);
                  
                  if (!success) {
                    // En cas d'erreur de connexion ou d'échec de suppression, on restaure l'élément
                    setState(() {
                      if (indexInStore != -1) {
                        DataStore().historyData.insert(indexInStore, item);
                      } else {
                        DataStore().historyData.add(item);
                      }
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Échec de la suppression sur le serveur. Élément restauré."),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: Text(
                Translations.t('delete') ?? "Supprimer",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
