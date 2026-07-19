import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data_store.dart';
import '../translations.dart';
import '../pdf_service.dart';

class StatistiquesScreen extends StatefulWidget {
  final bool isTab;
  const StatistiquesScreen({super.key, this.isTab = false});

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  int _selectedPeriod = 1; // 0: Jour, 1: Semaine, 2: Mois

  @override
  void initState() {
    super.initState();
  }

  List<AnalysisRecord> getFilteredRecords() {
    final now = DateTime.now();
    final allRecords = DataStore().historyData;
    switch (_selectedPeriod) {
      case 0: // Jour: last 24 hours
        final limit = now.subtract(const Duration(hours: 24));
        return allRecords.where((r) => r.timestamp.isAfter(limit)).toList();
      case 1: // Semaine: last 7 days
        final limit = now.subtract(const Duration(days: 7));
        return allRecords.where((r) => r.timestamp.isAfter(limit)).toList();
      case 2: // Mois: last 30 days
        final limit = now.subtract(const Duration(days: 30));
        return allRecords.where((r) => r.timestamp.isAfter(limit)).toList();
      default:
        return allRecords;
    }
  }

  List<AnalysisRecord> getTodayRecords() {
    final now = DateTime.now();
    final allRecords = DataStore().historyData;
    return allRecords
        .where(
          (r) =>
              r.timestamp.year == now.year &&
              r.timestamp.month == now.month &&
              r.timestamp.day == now.day,
        )
        .toList();
  }

  List<AnalysisRecord> getWeeklyRecords() {
    final now = DateTime.now();
    final allRecords = DataStore().historyData;
    final limit = now.subtract(const Duration(days: 7));
    return allRecords.where((r) => r.timestamp.isAfter(limit)).toList();
  }

  List<AnalysisRecord> getMonthlyRecords() {
    final now = DateTime.now();
    final allRecords = DataStore().historyData;
    final limit = now.subtract(const Duration(days: 30));
    return allRecords.where((r) => r.timestamp.isAfter(limit)).toList();
  }

  double _getMoodValue(String emotion) {
    switch (emotion.toLowerCase()) {
      case "heureux":
      case "happy":
        return 5.0;
      case "surpris":
      case "surprise":
        return 4.0;
      case "neutre":
      case "neutral":
        return 3.0;
      case "triste":
      case "sad":
        return 2.0;
      case "peur":
      case "fear":
        return 1.5;
      case "dégoût":
      case "degout":
      case "disgust":
        return 1.0;
      case "en colère":
      case "colère":
      case "angry":
        return 1.0;
      default:
        return 3.0;
    }
  }

  Widget _buildDominantTextBanner() {
    final filtered = getFilteredRecords();
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.purple.shade50.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.shade100, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Colors.purple.shade400,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Pas assez de données pour cette période pour déterminer l'émotion la plus fréquente.",
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final domInfo = DataStore().getDominantEmotionWithPct(filtered);
    final emotionText = Translations.translateEmotion(
      domInfo['emotion'] as String,
    );
    final pct = domInfo['pct'] as int;
    final color = DataStore().getEmotionColor(domInfo['emotion'] as String);

    String periodText = "Cette semaine";
    if (_selectedPeriod == 0) {
      periodText = "Aujourd'hui";
    } else if (_selectedPeriod == 2) {
      periodText = "Ce mois-ci";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.3,
                ),
                children: [
                  TextSpan(
                    text: "$periodText, votre émotion la plus fréquente est : ",
                  ),
                  TextSpan(
                    text: "$emotionText — $pct %.",
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedInsights() {
    final allRecords = DataStore().historyData;
    if (allRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    final stabilityScore = DataStore().calculateEmotionalStability(allRecords);
    final positiveDaysList = DataStore().getMostPositiveDays(allRecords);
    final positiveDaysStr = positiveDaysList.join(" & ");
    final negPeaksStr = DataStore().getNegativeEmotionPeaks(allRecords);

    final todayRecords = getTodayRecords();
    final weeklyRecords = getWeeklyRecords();
    final monthlyRecords = getMonthlyRecords();

    final todayDom = DataStore().getDominantEmotionWithPct(todayRecords);
    final weekDom = DataStore().getDominantEmotionWithPct(weeklyRecords);
    final monthDom = DataStore().getDominantEmotionWithPct(monthlyRecords);

    String getEmoji(String emotion) {
      switch (emotion.toLowerCase()) {
        case "heureux":
        case "happy":
          return "😊";
        case "triste":
        case "sad":
          return "😢";
        case "neutre":
        case "neutral":
          return "😐";
        case "surpris":
        case "surprise":
          return "😲";
        case "peur":
        case "fear":
          return "😨";
        case "dégoût":
        case "degout":
        case "disgust":
          return "🤢";
        case "en colère":
        case "colère":
        case "angry":
          return "😡";
        default:
          return "😶";
      }
    }

    String getStabilityLabel(int score) {
      if (score >= 80) return "Excellente Stabilité";
      if (score >= 60) return "Stabilité Modérée";
      return "Humeur Fluctuante";
    }

    Color getStabilityColor(int score) {
      if (score >= 80) return Colors.green;
      if (score >= 60) return Colors.orange;
      return Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Analyses Émotionnelles Avancées"),
        const SizedBox(height: 15),

        // 1. Stability Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: stabilityScore / 100.0,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        getStabilityColor(stabilityScore),
                      ),
                    ),
                  ),
                  Text(
                    "$stabilityScore%",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: getStabilityColor(stabilityScore),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Stabilité Émotionnelle",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getStabilityLabel(stabilityScore),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: getStabilityColor(stabilityScore),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stabilityScore >= 80
                          ? "Vos transitions d'humeur sont très équilibrées."
                          : stabilityScore >= 60
                          ? "Variations d'humeur modérées et tout à fait naturelles."
                          : "Transitions d'humeur rapides. N'hésitez pas à vous reposer.",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),

        // 2. Row of 2 Cards: Positive Days & Negative Peaks
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wb_sunny_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Jours les plus Positifs",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        positiveDaysStr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Humeur la plus clémente",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.trending_up,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Pics de Négativité",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        negPeaksStr.split(" - ")[0],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.redAccent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        negPeaksStr.contains(" - ")
                            ? negPeaksStr.split(" - ")[1]
                            : "Période de vulnérabilité",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),

        // 3. Comparatif Temporel Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Comparatif Émotionnel Dominant",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A148C),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildTemporalCapsule(
                      label: "Aujourd'hui",
                      emotion: todayDom['emotion'] as String,
                      pct: todayDom['pct'] as int,
                      emoji: getEmoji(todayDom['emotion'] as String),
                      color: DataStore().getEmotionColor(
                        todayDom['emotion'] as String,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildTemporalCapsule(
                      label: "Semaine",
                      emotion: weekDom['emotion'] as String,
                      pct: weekDom['pct'] as int,
                      emoji: getEmoji(weekDom['emotion'] as String),
                      color: DataStore().getEmotionColor(
                        weekDom['emotion'] as String,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildTemporalCapsule(
                      label: "Mois",
                      emotion: monthDom['emotion'] as String,
                      pct: monthDom['pct'] as int,
                      emoji: getEmoji(monthDom['emotion'] as String),
                      color: DataStore().getEmotionColor(
                        monthDom['emotion'] as String,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemporalCapsule({
    required String label,
    required String emotion,
    required int pct,
    required String emoji,
    required Color color,
  }) {
    final translated = Translations.translateEmotion(emotion);
    final hasData = emotion != "Aucune";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasData ? color.withOpacity(0.08) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasData ? color.withOpacity(0.2) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                hasData ? translated : "Aucune",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasData ? color : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasData) ...[
                const SizedBox(height: 2),
                Text(
                  "$pct%",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      /*permet à l'appbar d'être transparente et de se superposer au contenu de l'écran*/
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab
            ? null
            : Container(
                margin: const EdgeInsets.all(8),
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
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF4A148C),
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
        title: Text(
          Translations.t('nav_stats'),
          style: const TextStyle(
            color: Color(0xFF4A148C),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            fontSize: 20,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFBF6FF), Colors.white],
          ),
        ),
        child: SafeArea(
          /*permet de ne pas superposer le contenu avec la barre d'état et la barre de navigation du téléphone*/
          bottom: false,
          /*permet de ne pas ajouter de padding en bas, car nous avons déjà un espace suffisant pour la barre de navigation*/
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildPeriodSelector(),
                const SizedBox(height: 20),
                _buildDominantTextBanner(),
                _buildMainStatCard(),
                const SizedBox(height: 30),

                _buildAdvancedInsights(),
                const SizedBox(height: 30),

                // Evolution Section
                _buildSectionHeader(Translations.t('mood_evolution')),
                const SizedBox(height: 15),
                SizedBox(height: 240, child: _buildTrendChart()),

                const SizedBox(height: 30),

                // Distribution Section
                _buildSectionHeader(Translations.t('global_dist')),
                const SizedBox(height: 15),
                _buildDistributionCard(),

                const SizedBox(height: 30),
                _buildPdfGeneratorCard(),

                const SizedBox(
                  height: 40,
                ), // Space at bottom for safe area / nav bar
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4A148C),
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _buildPeriodButton(Translations.t('period_day'), 0),
          _buildPeriodButton(Translations.t('period_week'), 1),
          _buildPeriodButton(Translations.t('period_month'), 2),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int index) {
    bool isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF4A148C)
                  : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainStatCard() {
    final filtered = getFilteredRecords();
    final last = filtered.isNotEmpty ? filtered.first : null;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Translations.t('last_mood'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  last != null
                      ? Translations.translateEmotion(
                          last.userDeclaredEmotion ?? last.emotion,
                        )
                      : Translations.t('none'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (last != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 16,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    last.confidence,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final records = getFilteredRecords().reversed.toList();

    if (records.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              Translations.t('not_enough_data'),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    List<FlSpot> spots = [];
    if (records.length == 1) {
      spots = [
        FlSpot(
          0,
          _getMoodValue(records[0].userDeclaredEmotion ?? records[0].emotion),
        ),
        FlSpot(
          1,
          _getMoodValue(records[0].userDeclaredEmotion ?? records[0].emotion),
        ),
      ];
    } else {
      for (int i = 0; i < records.length; i++) {
        spots.add(
          FlSpot(
            i.toDouble(),
            _getMoodValue(records[i].userDeclaredEmotion ?? records[i].emotion),
          ),
        );
      }
    }

    int labelInterval = (records.length / 4).ceil();
    if (labelInterval < 1) labelInterval = 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 25, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0.0,
          maxY: 6.0,
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1.0,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 1:
                      return const Center(
                        child: Text('😢', style: TextStyle(fontSize: 14)),
                      );
                    case 3:
                      return const Center(
                        child: Text('😐', style: TextStyle(fontSize: 14)),
                      );
                    case 5:
                      return const Center(
                        child: Text('😊', style: TextStyle(fontSize: 14)),
                      );
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: labelInterval.toDouble(),
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < records.length) {
                    final rec = records[index];
                    String displayTime = rec.time;
                    if (rec.time.contains(' ')) {
                      displayTime = rec.time.split(' ')[0];
                    }
                    if (_selectedPeriod == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                          displayTime,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    String displayDate = rec.date.length >= 5
                        ? rec.date.substring(0, 5)
                        : rec.date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        displayDate,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: records.length > 1,
              gradient: const LinearGradient(
                colors: [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: records.length <= 5),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A1B9A).withOpacity(0.15),
                    const Color(0xFF6A1B9A).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionCard() {
    final filteredRecords = getFilteredRecords();
    final total = filteredRecords.length;

    int happyCount = 0;
    int neutralCount = 0;
    int sadCount = 0;
    int surpriseCount = 0;
    int fearCount = 0;
    int colereCount = 0;
    int degoutCount = 0;

    for (var r in filteredRecords) {
      final emotionLower = (r.userDeclaredEmotion ?? r.emotion).toLowerCase();
      if (emotionLower == "heureux" || emotionLower == "happy") {
        happyCount++;
      } else if (emotionLower == "neutre" || emotionLower == "neutral") {
        neutralCount++;
      } else if (emotionLower == "triste" || emotionLower == "sad") {
        sadCount++;
      } else if (emotionLower == "surpris" || emotionLower == "surprise") {
        surpriseCount++;
      } else if (emotionLower == "peur" || emotionLower == "fear") {
        fearCount++;
      } else if (emotionLower == "colère" ||
          emotionLower == "en colère" ||
          emotionLower == "colere" ||
          emotionLower == "angry") {
        colereCount++;
      } else if (emotionLower == "dégoût" ||
          emotionLower == "degout" ||
          emotionLower == "disgust") {
        degoutCount++;
      }
    }

    double happyVal = total > 0 ? happyCount / total : 0.0;
    double neutralVal = total > 0 ? neutralCount / total : 0.0;
    double sadVal = total > 0 ? sadCount / total : 0.0;
    double surpriseVal = total > 0 ? surpriseCount / total : 0.0;
    double fearVal = total > 0 ? fearCount / total : 0.0;
    double colereVal = total > 0 ? colereCount / total : 0.0;
    double degoutVal = total > 0 ? degoutCount / total : 0.0;

    String getPct(int count) {
      if (total == 0) return "0%";
      return "${(count / total * 100).toStringAsFixed(0)}%";
    }

    bool hasData = total > 0;

    List<PieChartSectionData> sections = [];
    final legendItems = <Widget>[];

    if (hasData) {
      if (happyVal > 0) {
        sections.add(
          PieChartSectionData(
            value: happyVal,
            color: Colors.green,
            radius: 18,
            showTitle: false,
          ),
        );
        legendItems.add(
          _buildLegendItem(
            Translations.translateEmotion("Heureux"),
            getPct(happyCount),
            Colors.green,
          ),
        );
      }
      if (neutralVal > 0) {
        sections.add(
          PieChartSectionData(
            value: neutralVal,
            color: Colors.orange,
            radius: 18,
            showTitle: false,
          ),
        );
        legendItems.add(
          _buildLegendItem(
            Translations.translateEmotion("Neutre"),
            getPct(neutralCount),
            Colors.orange,
          ),
        );
      }
      if (sadVal > 0) {
        sections.add(
          PieChartSectionData(
            value: sadVal,
            color: Colors.blue,
            radius: 18,
            showTitle: false,
          ),
        );
        legendItems.add(
          _buildLegendItem(
            Translations.translateEmotion("Triste"),
            getPct(sadCount),
            Colors.blue,
          ),
        );
      }
      if (surpriseVal > 0) {
        sections.add(
          PieChartSectionData(
            value: surpriseVal,
            color: Colors.purple,
            radius: 18,
            showTitle: false,
          ),
        );
        legendItems.add(
          _buildLegendItem(
            Translations.translateEmotion("Surpris"),
            getPct(surpriseCount),
            Colors.purple,
          ),
        );
      }
      if (fearVal > 0) {
        sections.add(
          PieChartSectionData(
            value: fearVal,
            color: Colors.indigo,
            radius: 18,
            showTitle: false,
          ),
        );
        legendItems.add(
          _buildLegendItem(
            Translations.translateEmotion("Peur"),
            getPct(fearCount),
            Colors.indigo,
          ),
        );
      }
      if (colereVal > 0) {
        sections.add(
          PieChartSectionData(
            value: colereVal,
            color: Colors.red,
            radius: 18,
            showTitle: false,
          ),
        );
        legendItems.add(
          _buildLegendItem(
            Translations.translateEmotion("Colère"),
            getPct(colereCount),
            Colors.red,
          ),
        );
      }
      if (degoutVal > 0) {
        sections.add(
          PieChartSectionData(
            value: degoutVal,
            color: Colors.brown,
            radius: 18,
            showTitle: false,
          ),
        );
        legendItems.add(
          _buildLegendItem(
            Translations.translateEmotion("Dégoût"),
            getPct(degoutCount),
            Colors.brown,
          ),
        );
      }
    }

    if (sections.isEmpty) {
      sections = [
        PieChartSectionData(
          value: 1,
          color: Colors.grey.shade200,
          radius: 18,
          showTitle: false,
        ),
      ];
      legendItems.add(
        Text(
          Translations.t('no_data'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 45,
                    sections: sections,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$total",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                  Text(
                    Translations.t('total'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 25),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: legendItems,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfGeneratorCard() {
    final filtered = getFilteredRecords();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF4A148C).withOpacity(0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF4A148C).withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Rapport de Synthèse PDF",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Télécharger et exporter les statistiques complètes de votre humeur.",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          ElevatedButton(
            onPressed: () async {
              if (filtered.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Pas assez de données pour générer un rapport PDF",
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              String periodLabel = "Semaine";
              if (_selectedPeriod == 0) periodLabel = "Jour";
              if (_selectedPeriod == 2) periodLabel = "Mois";

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: Colors.purple),
                ),
              );

              try {
                await PdfService.generateAndOpenReport(
                  records: filtered,
                  periodName: periodLabel,
                );
              } catch (e) {
                debugPrint("Erreur PDF: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erreur de génération : $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  Navigator.pop(context); // Fermer le loader
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Icon(Icons.download_rounded, size: 20),
          ),
        ],
      ),
    );
  }

}
