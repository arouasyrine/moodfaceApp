import 'package:flutter/material.dart';
import '../mood_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  void _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF9C27B0),
          ),
        ),
      );

      final result = await MoodService().forgotPassword(_emailController.text.trim());

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result != null && result['status'] == 'success') {
        _showSuccessDialog(result);
      } else {
        final errorMsg = result != null && result['message'] != null
            ? result['message']
            : "Impossible de contacter le serveur. Veuillez réessayer.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    final resetLink = result['reset_link'];
    final bool isSimulation = resetLink != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isSimulation ? "Mode Simulation" : "Demande traitée",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
        ),
        content: Text(
          isSimulation
              ? "Un lien de réinitialisation a été généré en mode simulation car le serveur de messagerie (SMTP) n'est pas configuré :\n\n$resetLink\n\nVeuillez l'ouvrir dans votre navigateur pour modifier le mot de passe."
              : "Si cette adresse e-mail correspond à un compte, un lien de réinitialisation a été envoyé par e-mail.",
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to Login
            },
            child: const Text(
              "OK",
              style: TextStyle(color: Color(0xFF9C27B0), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF4A148C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3E5F5),
                  Colors.white,
                  Color(0xFFEDE7F6),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 50),
                  _buildForgotPasswordForm(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.lock_reset_rounded, size: 60, color: Colors.purple.shade700),
        ),
        const SizedBox(height: 30),
        const Text(
          "Mot de passe oublié ?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4A148C),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "Entrez votre adresse email pour recevoir\nun lien de réinitialisation.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.purple.shade900.withOpacity(0.5),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextFormField(
             
              controller: _emailController,
              style: const TextStyle(fontSize: 15 , color: Colors.black),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.email_outlined, color: Colors.purple.shade300, size: 22),
                hintText: "Email",
                hintStyle: const TextStyle(color: Colors.black, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Veuillez entrer votre email';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Email invalide';
                return null;
              },
            ),
          ),
          const SizedBox(height: 30),
          _buildResetButton(),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _handleResetPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: const Text(
          "Réinitialiser le mot de passe",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
