import 'package:flutter/material.dart';
import '../data_store.dart';
import '../translations.dart';

class Historique extends StatelessWidget {
  const Historique({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,/*suppression de l'ombre de l'appbar*/
        centerTitle: true,
        leading: Container(
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
                      blurRadius: 20,//plus le blurRadius est élevé, plus l'ombre est floue
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: Translations.t('search_analyses'),
                    hintStyle: const TextStyle(color: Colors.black, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.purple),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(/*permet à la ListView de prendre tout l'espace restant*/
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                itemCount: DataStore().historyData.length,
                itemBuilder: (context, index) {
                  final item = DataStore().historyData[index];
                  return _buildHistoryCard(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(AnalysisRecord item) {
    return Container(
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
          // Image / Portrait placeholder
          Container(
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
                      Translations.translateEmotion(item.emotion),
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
}
