import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main.dart'; // Import to access AudioProvider

class SettingsUI extends StatelessWidget {
  const SettingsUI({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final provider = Provider.of<AudioProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: Text(l10n.settings), elevation: 0),
      body: ListView(
        children: [
          _buildSettingsTile(
            context,
            icon: FontAwesomeIcons.palette,
            title: l10n.theme,
            subtitle: "System default",
          ),
          _buildSettingsTile(
            context,
            icon: FontAwesomeIcons.circleInfo,
            title: l10n.about,
            subtitle: "Version 1.0.0",
          ),
          const Divider(),
          _buildSettingsTile(
            context,
            icon: FontAwesomeIcons.broom,
            title: "Clear Cache",
            subtitle: "Free up storage space",
            onTap: () async {
              await provider.clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cache cleared successfully")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: FaIcon(icon, size: 20, color: colorScheme.onSecondaryContainer),
      ),
      title: Text(title, style: TextStyle(color: colorScheme.onSurface)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            )
          : null,
    );
  }
}
