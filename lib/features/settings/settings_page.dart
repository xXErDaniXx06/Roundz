import 'package:flutter/material.dart';
import 'profile_settings_page.dart';
import 'accessibility_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            icon: Icons.person,
            title: "Profile Settings",
            subtitle: "Avatar, Username, Password",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProfileSettingsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.accessibility_new,
            title: "Accessibility",
            subtitle: "Theme, Font Size",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AccessibilityPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colorScheme.onSurface),
      ),
      title: Text(title,
          style: TextStyle(
              color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 16, color: colorScheme.onSurface.withOpacity(0.4)),
    );
  }
}
