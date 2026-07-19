import 'package:flutter/material.dart';
import '../data_store.dart';
import '../mood_service.dart';
import '../translations.dart';

void showJournalEditorBottomSheet({
  required BuildContext context,
  required AnalysisRecord record,
  required VoidCallback onSave,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return JournalEditorSheet(
        record: record,
        onSave: onSave,
      );
    },
  );
}

class JournalEditorSheet extends StatefulWidget {
  final AnalysisRecord record;
  final VoidCallback onSave;

  const JournalEditorSheet({
    super.key,
    required this.record,
    required this.onSave,
  });

  @override
  State<JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends State<JournalEditorSheet> {
  late TextEditingController _noteController;
  late bool _isCorrectEmotion;
  String? _selectedEmotion;
  final List<String> _selectedTags = [];
  bool _isSaving = false;

  final List<String> _availableEmotions = [
    "Heureux",
    "Triste",
    "Neutre",
    "En colère",
    "Surpris",
    "Peur",
    "Dégoût",
  ];

  final List<String> _availableTags = [
    "Travail 💼",
    "Famille 👥",
    "Fatigue 🔋",
    "Études 📚",
    "Santé 🩺",
    "Amour ❤️",
    "Loisirs 🎨",
    "Stress ⚡",
    "Relaxation 🧘",
  ];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.record.note);
    
    // Si l'émotion déclarée est déjà renseignée et différente de l'émotion détectée
    if (widget.record.userDeclaredEmotion != null &&
        widget.record.userDeclaredEmotion != widget.record.emotion) {
      _isCorrectEmotion = false;
      _selectedEmotion = widget.record.userDeclaredEmotion;
    } else {
      _isCorrectEmotion = widget.record.userDeclaredEmotion == null ||
          widget.record.userDeclaredEmotion == widget.record.emotion;
      _selectedEmotion = widget.record.emotion;
    }

    if (widget.record.tags != null) {
      _selectedTags.addAll(widget.record.tags!);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    final finalEmotion = _isCorrectEmotion ? widget.record.emotion : (_selectedEmotion ?? widget.record.emotion);
    final finalNote = _noteController.text.trim();

    bool success = true;
    // Si l'analyse est liée au backend et dispose d'un identifiant
    if (widget.record.id != null) {
      success = await MoodService().updateJournalRecord(
        widget.record.id!,
        finalNote,
        _selectedTags,
        finalEmotion,
      );
    }

    if (success) {
      // Mettre à jour l'objet localement
      widget.record.note = finalNote;
      widget.record.tags = List.from(_selectedTags);
      widget.record.userDeclaredEmotion = finalEmotion;
      widget.record.icon = DataStore().getEmotionIcon(finalEmotion);
      widget.record.color = DataStore().getEmotionColor(finalEmotion);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Journal émotionnel enregistré avec succès ! 🌟"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSave();
        Navigator.pop(context); // Fermer le bottom sheet
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de l'enregistrement. Veuillez réessayer."),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Adapter le layout au clavier virtuel
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: 24 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre de drag
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Titre principal
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Color(0xFF8E24AA), size: 28),
                const SizedBox(width: 12),
                const Text(
                  "Journal Émotionnel 📝",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Section 1 : Validation de l'émotion détectée
            const Text(
              "L'IA a détecté que vous êtes :",
              style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.record.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.record.color.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(widget.record.icon, color: widget.record.color, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "${Translations.translateEmotion(widget.record.emotion)} (${widget.record.confidence})",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.record.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            const Text(
              "Est-ce bien ce que vous ressentez ?",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                      child: Text(
                        "Oui, tout à fait",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    selected: _isCorrectEmotion,
                    selectedColor: Colors.green.shade100,
                    labelStyle: TextStyle(
                      color: _isCorrectEmotion ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                    side: BorderSide(
                      color: _isCorrectEmotion ? Colors.green.shade300 : Colors.grey.shade300,
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        _isCorrectEmotion = true;
                        _selectedEmotion = widget.record.emotion;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                      child: Text(
                        "Non, corriger",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    selected: !_isCorrectEmotion,
                    selectedColor: Colors.red.shade100,
                    labelStyle: TextStyle(
                      color: !_isCorrectEmotion ? Colors.red.shade800 : Colors.grey.shade700,
                    ),
                    side: BorderSide(
                      color: !_isCorrectEmotion ? Colors.red.shade300 : Colors.grey.shade300,
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        _isCorrectEmotion = false;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            // Si "Non, corriger" est sélectionné, afficher les options d'émotion
            if (!_isCorrectEmotion) ...[
              const SizedBox(height: 15),
              const Text(
                "Quelle émotion ressentez-vous réellement ?",
                style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableEmotions.map((emotion) {
                  final isSelected = _selectedEmotion == emotion;
                  return ChoiceChip(
                    label: Text(emotion),
                    selected: isSelected,
                    selectedColor: const Color(0xFF9C27B0).withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF4A148C) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade300,
                    ),
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() {
                          _selectedEmotion = emotion;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 25),

            // Section 2 : Note personnelle
            const Text(
              "Que ressentez-vous ? (Note personnelle)",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Décrivez ce qui se passe dans votre esprit, vos émotions, vos pensées du moment...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 15),

            // Section 3 : Ajouter des tags
            const Text(
              "Associer à des aspects de votre vie (Tags)",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  selectedColor: const Color(0xFF8E24AA).withOpacity(0.15),
                  checkmarkColor: const Color(0xFF4A148C),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF4A148C) : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF8E24AA) : Colors.grey.shade300,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 35),

            // Bouton de validation
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Enregistrer dans mon journal",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
