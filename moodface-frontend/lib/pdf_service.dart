import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import 'data_store.dart';

class PdfService {
  static Future<void> generateAndOpenReport({
    required List<AnalysisRecord> records,
    required String periodName,
  }) async {
    final pdf = pw.Document();

    // 1. Calcul des statistiques
    final total = records.length;
    final Map<String, int> emotionCounts = {};
    for (var r in records) {
      final em = r.userDeclaredEmotion ?? r.emotion;
      emotionCounts[em] = (emotionCounts[em] ?? 0) + 1;
    }

    // Trier les émotions par nombre d'occurrences pour déterminer l'humeur dominante
    final sortedEmotions = emotionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dominantMood = sortedEmotions.isNotEmpty ? sortedEmotions.first.key : "Aucune";

    final allRecords = DataStore().historyData;
    final stabilityScore = DataStore().calculateEmotionalStability(allRecords);
    final positiveDaysList = DataStore().getMostPositiveDays(allRecords);
    final positiveDaysStr = positiveDaysList.join(", ");
    final negPeaksStr = DataStore().getNegativeEmotionPeaks(allRecords);

    // 2. Recommandations personnalisées selon l'humeur dominante
    String coachAdvice = "";
    if (dominantMood == "Triste" || dominantMood == "Sad") {
      coachAdvice = "Le coach recommande d'accueillir vos sentiments de tristesse avec douceur. Prenez des boissons chaudes, sortez marcher 15 minutes au grand air, et privilégiez la communication avec un proche de confiance.";
    } else if (dominantMood == "Heureux" || dominantMood == "Happy") {
      coachAdvice = "Une humeur magnifique ! Profitez de cette dynamique positive pour entreprendre des projets créatifs, noter votre joie dans un journal d'humeur, ou simplement appeler un ami pour partager votre énergie positive.";
    } else if (dominantMood == "En colère" || dominantMood == "Angry") {
      coachAdvice = "La colère est une énergie intense. Le coach suggère de pratiquer une respiration abdominale lente (inspiration 4s / expiration 8s) et d'utiliser une activité physique modérée (étirements, course) pour la canaliser.";
    } else if (dominantMood == "Neutre" || dominantMood == "Neutral") {
      coachAdvice = "Un état de paix calme et stable. C'est l'instant parfait pour s'étirer doucement, faire une pause d'écrans de 10 minutes et se fixer un petit objectif inspirant et agréable pour le reste de la journée.";
    } else if (dominantMood == "Peur" || dominantMood == "Fear") {
      coachAdvice = "En cas d'anxiété ou de peur, pratiquez l'ancrage au sol (les deux pieds bien à plat) et une respiration carrée (inspirer 4s / retenir 4s / expirer 4s / retenir 4s). Buvez un grand verre d'eau fraîche lentement.";
    } else {
      coachAdvice = "Pensez à faire une détection d'émotion régulière (matin et soir) pour permettre au coach intelligent d'affiner son diagnostic et de vous proposer un meilleur suivi de votre bien-être.";
    }

    // Détection de stress récurrent le soir (Peur, En colère ou Triste après 17h)
    final eveningStress = records.where((r) {
      final hour = r.timestamp.hour;
      final isEvening = hour >= 17 || hour <= 4;
      final em = r.userDeclaredEmotion ?? r.emotion;
      return isEvening && (em == "Peur" || em == "En colère" || em == "Triste");
    }).length;

    String eveningStressAdvice = "";
    if (eveningStress >= 2) {
      eveningStressAdvice = "Le Coach a détecté plusieurs occurrences de tension/tristesse en soirée. Une routine de détente progressive (tisane, musique relaxante) et une déconnexion stricte des écrans dès 21h00 vous aideraient à passer des nuits plus sereines.";
    }

    // 3. Construction des pages du PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // En-tête du Rapport
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "MoodFace AI",
                          style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.purple,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "Rapport d'Analyse Émotionnelle",
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Généré le : ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}",
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                        ),
                        pw.Text(
                          "Heure : ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1.5, color: PdfColors.purple),
                pw.SizedBox(height: 15),

                // Informations utilisateur
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "INFORMATIONS D'ANALYSE",
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Utilisateur : ${DataStore().userName ?? 'Utilisateur'}", style: const pw.TextStyle(fontSize: 11)),
                          pw.Text("Période : $periodName", style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text("Email : ${DataStore().userEmail ?? 'Non renseigné'}", style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 25),

                // Section 1: Résumé
                pw.Text("1. Résumé de la Période", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                pw.SizedBox(height: 8),
                pw.Text("Total des analyses enregistrées : $total", style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text("Émotion dominante : ", style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(dominantMood, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700)),
                  ],
                ),
                pw.SizedBox(height: 25),

                // Section 2: Répartition des Émotions
                pw.Text("2. Répartition Statistique des Émotions", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ["Émotion", "Occurrences", "Pourcentage"],
                  data: emotionCounts.entries.map((e) {
                    final pct = total > 0 ? "${(e.value / total * 100).toStringAsFixed(1)}%" : "0%";
                    return [e.key, e.value.toString(), pct];
                  }).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.purple800),
                  cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 25),

                // Section 3: Analyses Émotionnelles Avancées
                pw.Text("3. Analyses Émotionnelles Avancées", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Score de Stabilité Émotionnelle :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text("$stabilityScore / 100", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: stabilityScore >= 60 ? PdfColors.green800 : PdfColors.red800)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Jours les plus Positifs :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(positiveDaysStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.green800)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Pics de Négativité :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(negPeaksStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.red800)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 25),

                // Section 4: Recommandations du Coach Intelligent
                pw.Text("4. Recommandations du Coach Intelligent", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.purple50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: PdfColors.purple100),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Plan d'action d'humeur dominante ($dominantMood) :",
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        coachAdvice,
                        style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey900),
                      ),
                      if (eveningStressAdvice.isNotEmpty) ...[
                        pw.SizedBox(height: 12),
                        pw.Text(
                          "Diagnostic IA de soirée :",
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          eveningStressAdvice,
                          style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey900),
                        ),
                      ],
                    ],
                  ),
                ),
                
                pw.Spacer(),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "Ce rapport est généré automatiquement par MoodFace AI pour vous accompagner dans votre bien-être psychologique.",
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Sauvegarde temporaire et ouverture du fichier PDF
    final output = await getTemporaryDirectory();
    final cleanPeriod = periodName.replaceAll(" ", "_").toLowerCase();
    final file = File("${output.path}/rapport_moodface_$cleanPeriod.pdf");
    await file.writeAsBytes(await pdf.save());
    
    try {
      await OpenFilex.open(file.path);
    } catch (e) {
      print("Erreur lors de l'ouverture du PDF : $e");
    }
  }
}
