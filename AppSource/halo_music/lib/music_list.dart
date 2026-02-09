import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'l10n/app_localizations.dart';
import 'main.dart';
import 'player_ui.dart';
import 'settings_ui.dart';

class MusicListScreen extends StatefulWidget {
  const MusicListScreen({super.key});

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<AudioProvider>(context, listen: false).initSongs();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AudioProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsUI()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _topButton(context, l10n.sort, FontAwesomeIcons.sort),
                _topButton(
                  context,
                  l10n.refresh,
                  FontAwesomeIcons.arrowsRotate,
                  onTap: () {
                    provider.initSongs();
                  },
                ),
                _topButton(
                  context,
                  l10n.search,
                  FontAwesomeIcons.magnifyingGlass,
                ),
              ],
            ),
          ),

          Expanded(
            child: provider.songs.isEmpty
                ? Center(child: Text(l10n.permissionDenied))
                : ListView.builder(
                    itemCount: provider.songs.length,
                    itemBuilder: (context, index) {
                      final song = provider.songs[index];
                      return ListTile(
                        leading: SizedBox(
                          width: 50,
                          height: 50,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            // MIGRATION: Use AssetEntityImage
                            child: AssetEntityImage(
                              song,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize.square(100),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.music_note),
                                );
                              },
                            ),
                          ),
                        ),
                        title: Text(
                          song.title ??
                              "Unknown Title", // AssetEntity title can be nullable
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // MIGRATION: AssetEntity does not have artist/album metadata.
                        // We display the file type or duration as subtitle instead.
                        subtitle: Text(
                          song.mimeType ?? "Audio",
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(_formatDuration(song.duration)),
                        onTap: () {
                          provider.playSong(index);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlayerUI()),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _topButton(
    BuildContext context,
    String text,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    // Wrap in Material/InkWell for tap effect
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    // MIGRATION: Input is now Seconds (int), not Milliseconds
    final duration = Duration(seconds: seconds);
    return "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
