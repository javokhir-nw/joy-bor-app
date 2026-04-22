// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', val);

    // Firestore da fcmToken ni tozalash/tiklash
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      if (!val) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmToken': ''});
      } else {
        await saveFcmToken();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
        ),
        title: const Text('Sozlamalar',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Ko'rinish ──
            _sectionLabel('🎨 Ko\'rinish'),
            const SizedBox(height: 8),
            _buildCard([
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (_, mode, _) => _SwitchTile(
                  icon: mode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  label: 'Tungi rejim',
                  value: mode == ThemeMode.dark,
                  onChanged: (val) {
                    themeNotifier.value =
                        val ? ThemeMode.dark : ThemeMode.light;
                    _saveTheme(val);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Til ──
            _sectionLabel('🌐 Til'),
            const SizedBox(height: 8),
            _buildCard([
              _LangTile(
                label: "O'zbek",
                flag: '🇺🇿',
                selected: langNotifier.value == 'uz',
                onTap: () => _setLang('uz'),
              ),
              Divider(color: AppColors.divider, height: 1, indent: 52),
              _LangTile(
                label: 'Русский',
                flag: '🇷🇺',
                selected: langNotifier.value == 'ru',
                onTap: () => _setLang('ru'),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Bildirishnomalar ──
            _sectionLabel('🔔 Bildirishnomalar'),
            const SizedBox(height: 8),
            _buildCard([
              _SwitchTile(
                icon: Icons.notifications_outlined,
                label: 'Push bildirishnomalar',
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
            ]),
            const SizedBox(height: 20),

            // ── Ilova haqida ──
            _sectionLabel('ℹ️ Ilova haqida'),
            const SizedBox(height: 8),
            _buildCard([
              _InfoTile(label: 'Versiya', value: '1.0.0'),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
  }

  Future<void> _setLang(String lang) async {
    langNotifier.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', lang);
    setState(() {});
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8));

  Widget _buildCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      );
}

// ── Switch tile ──
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ── Lang tile ──
class _LangTile extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _LangTile({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(label,
          style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontSize: 15,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w500)),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
          : null,
      horizontalTitleGap: 8,
      minLeadingWidth: 0,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ── Info tile ──
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}