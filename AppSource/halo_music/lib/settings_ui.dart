import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsUI extends StatelessWidget {
  const SettingsUI({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.palette),
            title: Text(l10n.theme),
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.circleInfo),
            title: Text(l10n.about),
          ),
        ],
      ),
    );
  }
}
