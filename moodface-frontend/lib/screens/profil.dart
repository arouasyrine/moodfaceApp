import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import '../data_store.dart';
import '../mood_service.dart';
import '../translations.dart';
import 'login.dart';
import 'notifications_settings.dart';
import 'package:image_cropper/image_cropper.dart';

class ProfilScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool isTab;
  final VoidCallback? onCloseTab;
  const ProfilScreen({super.key, required this.cameras, this.isTab = false, this.onCloseTab});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  int _imageKey = 0; // ← ajoute cette variable dans ton State

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        // Étape 1 : ouvre l'éditeur de recadrage
        final CroppedFile? croppedImage = await ImageCropper().cropImage(
          sourcePath: image.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Modifier la photo',
              toolbarColor: Colors.deepPurple,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: false,
            ),
            IOSUiSettings(title: 'Modifier la photo'),
          ],
        );

        if (croppedImage != null) {
          final file = File(croppedImage.path);

          // Vérifie que le fichier existe vraiment avant de continuer
          if (await file.exists()) {
            await DataStore().saveProfileImage(croppedImage.path);
            if (DataStore().profileImagePath != null) {
              await FileImage(File(DataStore().profileImagePath!)).evict();
            }
            if (mounted) {
              setState(() {
                _imageKey++;
              });
            }
          }
        }
        
      }
    } catch (e) {
      debugPrint("Erreur sélection image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible de modifier l'image de profil"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: DataStore().userName);
    final emailController = TextEditingController(text: DataStore().userEmail);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            "Infos Personnelles",
            style: TextStyle(
              color: Color(0xFF4A148C),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: "Nom complet",
                    labelStyle: const TextStyle(color: Color(0xFF6A1B9A)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6A1B9A)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Le nom ne peut pas être vide";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: const TextStyle(color: Color(0xFF6A1B9A)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6A1B9A)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "L'email ne peut pas être vide";
                    }
                    if (!RegExp(
                      r'^[^@]+@[^@]+\.[^@]+',
                    ).hasMatch(value.trim())) {
                      return "Email invalide";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 10,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Annuler",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final userId = DataStore().userId;
                  if (userId == null) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                  );

                  final newName = nameController.text.trim();
                  final newEmail = emailController.text.trim();

                  final result = await MoodService().updateUser(
                    userId,
                    newName,
                    newEmail,
                  );

                  if (mounted) {
                    Navigator.pop(context); // Close loader
                  }

                  if (result != null) {
                    DataStore().userName = newName;
                    DataStore().userEmail = newEmail;

                    if (mounted) {
                      Navigator.pop(context); // Close edit dialog
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profil mis à jour avec succès"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Erreur de mise à jour du profil. L'email est peut-être déjà utilisé.",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Sauvegarder",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageSelectionBottomSheet() {
    final languages = Translations.supportedLanguages;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      Translations.t('settings_language'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: languages.length,
                      itemBuilder: (context, index) {
                        return _buildLanguageTile(languages[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  Widget _buildLanguageTile(String languageName) {
    final isSelected = DataStore().appLanguage == languageName;
    return ListTile(
      title: Text(
        languageName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF6A1B9A) : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF6A1B9A))
          : null,
      onTap: () {
        setState(() {
          DataStore().appLanguage = languageName;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showSecurityDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "Modifier le mot de passe",
                style: TextStyle(
                  color: Color(0xFF4A148C),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: "Ancien mot de passe",
                          labelStyle: const TextStyle(color: Color(0xFF6A1B9A)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureOld
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF6A1B9A),
                            ),
                            onPressed: () =>
                                setStateDialog(() => obscureOld = !obscureOld),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? "Entrez votre ancien mot de passe"
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: "Nouveau mot de passe",
                          labelStyle: const TextStyle(color: Color(0xFF6A1B9A)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF6A1B9A),
                            ),
                            onPressed: () =>
                                setStateDialog(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 6
                            ? "Minimum 6 caractères"
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: "Confirmer le mot de passe",
                          labelStyle: const TextStyle(color: Color(0xFF6A1B9A)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF6A1B9A),
                            ),
                            onPressed: () => setStateDialog(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text) {
                            return "Les mots de passe ne correspondent pas";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Annuler",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final userId = DataStore().userId;
                      if (userId == null) return;

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6A1B9A),
                          ),
                        ),
                      );

                      final result = await MoodService().changePassword(
                        userId,
                        oldPasswordController.text,
                        newPasswordController.text,
                      );

                      if (mounted) {
                        Navigator.pop(context); // Close loader
                      }

                      if (result != null) {
                        if (mounted) {
                          Navigator.pop(context); // Close security dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Mot de passe modifié avec succès"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Erreur : l'ancien mot de passe est incorrect",
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Confirmer",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHelpCenterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Text(
                    "Centre d'Aide FAQ",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      children: [
                        _buildFaqItem(
                          "Comment fonctionne l'analyse d'émotions ?",
                          "L'application utilise un algorithme d'intelligence artificielle en backend pour analyser votre expression faciale sur l'image fournie, déterminant l'émotion dominante et le taux de confiance.",
                        ),
                        _buildFaqItem(
                          "Mes images sont-elles enregistrées ?",
                          "Non, pour des raisons de confidentialité, les images reçues par le serveur sont immédiatement supprimées après l'analyse.",
                        ),
                        _buildFaqItem(
                          "Comment modifier mes info personnelles ?",
                          "Allez dans l'onglet 'Infos Personnelles' sous vos paramètres pour modifier votre nom et votre adresse e-mail.",
                        ),
                        _buildFaqItem(
                          "Comment gérer les alertes d'humeur ?",
                          "Accédez au menu 'Notifications' pour configurer les alertes d'humeur dominante selon la fréquence désirée.",
                        ),
                        _buildFaqItem(
                          "Comment puis-je réinitialiser mes données ?",
                          "Vous pouvez effacer l'historique local en vous déconnectant de l'application.",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      color: const Color(0xFFFBF6FF),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.withOpacity(0.05)),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A148C),
            fontSize: 14,
          ),
        ),
        iconColor: const Color(0xFF6A1B9A),
        textColor: const Color(0xFF6A1B9A),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.topLeft,
        children: [
          Text(
            answer,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 25),
                child: Text(
                  "Photo de profil",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF6A1B9A),
                ),
                title: const Text("Prendre une photo en direct"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Color(0xFF6A1B9A),
                ),
                title: const Text("Choisir depuis la galerie"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
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
          Translations.t('profile_title'),
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
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 5),
              // Profile Header
              _buildProfileHeader(),
              const SizedBox(height: 15),
              // Stats summary
              _buildStatsRow(),
              const SizedBox(height: 20),
              // Settings list
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(25, 25, 25, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel(Translations.t('settings_section')),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          children: [
                            _buildSettingsTile(
                              Icons.person_outline_rounded,
                              Translations.t('settings_personal_info'),
                              DataStore().userName ?? "Syrine",
                              const Color(0xFF6A1B9A),
                              onTap: _showEditProfileDialog,
                            ),
                            _buildSettingsTile(
                              Icons.notifications_none_rounded,
                              Translations.t('settings_notifications'),
                              DataStore().notificationsEnabled
                                  ? (DataStore().notificationFrequencies.isEmpty
                                        ? Translations.t('none')
                                        : DataStore().notificationFrequencies
                                              .map((f) => Translations.translateFrequency(f))
                                              .join(', '))
                                  : Translations.t('disabled'),
                              Colors.blueAccent,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationsSettingsScreen(),
                                  ),
                                );
                                setState(() {});
                              },
                            ),
                            _buildSettingsTile(
                              Icons.language_rounded,
                              Translations.t('settings_language'),
                              DataStore().appLanguage,
                              Colors.orangeAccent,
                              onTap: _showLanguageSelectionBottomSheet,
                            ),

                            _buildSettingsTile(
                              Icons.lock_outline_rounded,
                              Translations.t('settings_security'),
                              Translations.t('manage'),
                              Colors.greenAccent.shade700,
                              onTap: _showSecurityDialog,
                            ),
                            _buildSettingsTile(
                              Icons.help_outline_rounded,
                              Translations.t('settings_help_center'),
                              Translations.t('consult'),
                              Colors.blueGrey,
                              onTap: _showHelpCenterBottomSheet,
                            ),
                            const SizedBox(height: 15),
                            _buildLogoutButton(),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _showImageSourceBottomSheet(context),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFFB39DDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6A1B9A).withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 43,
                  backgroundColor: const Color(0xFFF3E5F5),
                  backgroundImage: DataStore().profileImagePath != null
                      ? FileImage(File(DataStore().profileImagePath!))
                            as ImageProvider
                      : null,
                  key: ValueKey(_imageKey), // ← AJOUTÉ
                  child: DataStore().profileImagePath == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: Color(0xFF6A1B9A),
                        )
                      : null,
                ),
              ),
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          DataStore().userName ?? "Syrine",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4A148C),
            letterSpacing: -0.5,
          ),
        ),
        Text(
          Translations.t('premium_member'),
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final last = DataStore().lastRecord;
    final total = DataStore().totalAnalyses;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 35),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(Translations.t('stats_analyses'), "$total"),
          _buildVerticalDivider(),
          _buildStatItem(
            Translations.t('stats_precision'),
            total > 0 ? last?.confidence ?? "94%" : "0%",
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            Translations.t('stats_mood'),
            total > 0
                ? last?.emotion ?? Translations.t('none')
                : Translations.t('none'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF6A1B9A),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 18, width: 1, color: Colors.grey.withOpacity(0.1));
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Colors.grey.shade400,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String trailing,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (trailing.isNotEmpty)
                    Expanded(
                      child: Text(
                        trailing,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: MaterialButton(
        onPressed: () {
          DataStore().clear();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LoginScreen(cameras: widget.cameras),
            ),
            (route) => false,
          );
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
            const SizedBox(width: 10),
            Text(
              Translations.t('logout'),
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
