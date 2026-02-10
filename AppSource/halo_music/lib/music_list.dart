import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';

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
    // Initialize songs after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AudioProvider>(context, listen: false).initSongs();
    });
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
                _topButton(context, FontAwesomeIcons.sort),
                _topButton(
                  context,
                  FontAwesomeIcons.arrowsRotate,
                  onTap: () {
                    provider.initSongs();
                  },
                ),
                _topButton(context, FontAwesomeIcons.magnifyingGlass),
              ],
            ),
          ),

          Expanded(
            child: !provider.hasPermission
                ? _buildPermissionDeniedView(l10n)
                : provider.songs.isEmpty
                ? Center(child: Text(l10n.noSongsFound))
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
                            child: QueryArtworkWidget(
                              id: song.id,
                              type: ArtworkType.AUDIO,
                              nullArtworkWidget: Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artist ?? "Unknown Artist",
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(_formatDuration(song.duration ?? 0)),
                        onTap: () {
                          // This calls AudioHandler.skipToQueueItem(index)
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

  Widget _buildPermissionDeniedView(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.permissionDenied),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Provider.of<AudioProvider>(context, listen: false).initSongs();
            },
            child: const Text("Grant Permissions"),
          ),
        ],
      ),
    );
  }

  Widget _topButton(
    BuildContext context,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // Ensures the padding area is clickable
        padding: const EdgeInsets.all(
          2.0,
        ), // Reduced from 8.0 to shrink background size
        child: Icon(icon, size: 15),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    return "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
