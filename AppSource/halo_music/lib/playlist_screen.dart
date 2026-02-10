import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'main.dart'; // To access AudioProvider and SongModel
import 'player_ui.dart'; // To navigate to player

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AudioProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Playlists"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreatePlaylistDialog(context, provider),
          ),
        ],
      ),
      body: provider.playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.listUl,
                    size: 64,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text("No Playlists Yet"),
                  TextButton(
                    onPressed: () =>
                        _showCreatePlaylistDialog(context, provider),
                    child: const Text("Create One"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: provider.playlists.length,
              itemBuilder: (context, index) {
                final playlistName = provider.playlists.keys.elementAt(index);
                final songCount = provider.playlists[playlistName]!.length;

                return Dismissible(
                  key: Key(playlistName),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Delete Playlist?"),
                        content: Text(
                          "Are you sure you want to delete '$playlistName'?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              "Delete",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    provider.deletePlaylist(playlistName);
                  },
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.music_note,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(playlistName),
                    subtitle: Text("$songCount songs"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailScreen(playlistName: playlistName),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () {
                        provider.playPlaylist(playlistName);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PlayerUI()),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, AudioProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("New Playlist"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Playlist Name"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  provider.createPlaylist(controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistName;
  const PlaylistDetailScreen({super.key, required this.playlistName});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AudioProvider>(context);
    final songs = provider.getSongsInPlaylist(playlistName);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            onPressed: () {
              if (songs.isNotEmpty) {
                provider.playPlaylist(playlistName);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerUI()),
                );
              }
            },
          ),
        ],
      ),
      body: songs.isEmpty
          ? const Center(child: Text("Empty Playlist"))
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return Dismissible(
                  key: Key("${playlistName}_${song.id}"),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) {
                    provider.removeFromPlaylist(playlistName, song.id);
                  },
                  child: ListTile(
                    leading: SizedBox(
                      width: 50,
                      height: 50,
                      child: ClipOval(
                        child: FutureBuilder<Uint8List?>(
                          future: provider.getArtworkBytes(song.id),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              );
                            }
                            return Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.music_note,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(song.artist ?? "Unknown"),
                    onTap: () {
                      provider.playPlaylist(playlistName);
                      // We need to skip to this specific song, but playPlaylist resets the queue.
                      // Ideally, we'd handle this index matching, but for now simple playback is fine.
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PlayerUI()),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
