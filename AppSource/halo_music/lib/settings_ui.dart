import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main.dart';
import 'visualizers/visualizer_settings.dart'; // Import the new settings

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

          // DYNAMIC VISUALIZER SELECTOR
          ValueListenableBuilder<String>(
            valueListenable: VisualizerSettings.instance,
            builder: (context, currentVisualizer, child) {
              return _buildSettingsTile(
                context,
                icon: FontAwesomeIcons.waveSquare,
                title: "Visualizer Effect",
                subtitle: _getVisualizerName(currentVisualizer),
                onTap: () => _showVisualizerPicker(context, currentVisualizer),
              );
            },
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

  String _getVisualizerName(String key) {
    switch (key) {
      case 'cube':
        return "Holographic Cubes";
      case 'bars':
        return "Classic Bars";
      case 'wave':
        return "Circular Wave";
      case 'none':
        return "Disabled";
      default:
        return "Unknown";
    }
  }

  void _showVisualizerPicker(BuildContext context, String currentVal) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Select Visualizer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _visualizerOption(context, 'wave', "Circular Wave", currentVal),
              _visualizerOption(context, 'bars', "Classic Bars", currentVal),
              _visualizerOption(
                context,
                'cube',
                "Holographic Cubes",
                currentVal,
              ),
              _visualizerOption(context, 'none', "Disabled", currentVal),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _visualizerOption(
    BuildContext context,
    String value,
    String title,
    String currentVal,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = value == currentVal;

    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        VisualizerSettings.instance.setVisualizer(value);
        Navigator.pop(context);
      },
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
