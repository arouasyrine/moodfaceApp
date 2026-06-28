import 'package:flutter/material.dart';
import '../data_store.dart';
import '../notification_service.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  late bool _notificationsEnabled;
  late List<String> _selectedFrequencies;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = DataStore().notificationsEnabled;
    _selectedFrequencies = List.from(DataStore().notificationFrequencies);
  }

  void _saveSettings() {
    DataStore().notificationsEnabled = _notificationsEnabled;
    DataStore().notificationFrequencies = _selectedFrequencies;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Paramètres de notifications enregistrés"),
        backgroundColor: Colors.green,
        duration: Duration(milliseconds: 800),
      ),
    );

    if (_notificationsEnabled) {
      NotificationService().sendTestNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              )
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF4A148C), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF4A148C), 
            fontWeight: FontWeight.w900, 
            letterSpacing: -0.5,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildIntroCard(),
                const SizedBox(height: 25),
                _buildToggleCard(),
                if (_notificationsEnabled) ...[
                  const SizedBox(height: 25),
                  _buildSectionLabel("FRÉQUENCES DES RAPPORTS D'HUMEUR"),
                  const SizedBox(height: 10),
                  _buildFrequencyOption("Jour", "Notification Quotidienne", "Recevez chaque jour un résumé de votre humeur dominante.", Icons.today_rounded, Colors.green),
                  const SizedBox(height: 12),
                  _buildFrequencyOption("Semaine", "Notification Hebdomadaire", "Recevez chaque semaine un résumé de votre humeur dominante.", Icons.date_range_rounded, Colors.blue),
                  const SizedBox(height: 12),
                  _buildFrequencyOption("Mois", "Notification Mensuelle", "Recevez chaque mois un bilan complet de votre humeur dominante.", Icons.calendar_month_rounded, Colors.purple),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.insights_rounded, color: Colors.white, size: 40),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Humeurs Dominantes",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 4),
                Text(
                  "Sélectionnez une ou plusieurs fréquences pour rester informé de l'évolution de vos émotions dominantes.",
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF6A1B9A), size: 24),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Activer les notifications",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                ),
                Text(
                  "Autoriser l'application à m'envoyer des alertes",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: _notificationsEnabled,
            activeColor: const Color(0xFF6A1B9A),
            activeTrackColor: const Color(0xFFE8D5F5),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade200,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildFrequencyOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedFrequencies.contains(value);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF6A1B9A) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedFrequencies.remove(value);
              } else {
                _selectedFrequencies.add(value);
              }
            });
            _saveSettings();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isSelected)
                  const Icon(Icons.check_box_rounded, color: Color(0xFF6A1B9A), size: 24)
                else
                  Icon(Icons.check_box_outline_blank_rounded, color: Colors.grey.shade300, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
