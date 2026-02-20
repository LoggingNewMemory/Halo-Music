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
                  confirmDismiss: (direction) async =>
                      await _confirmDeleteDialog(context, playlistName),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: () {
                            provider.playPlaylist(playlistName);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PlayerUI(),
                              ),
                            );
                          },
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'rename') {
                              _showRenamePlaylistDialog(
                                context,
                                provider,
                                playlistName,
                              );
                            } else if (value == 'delete') {
                              bool delete =
                                  await _confirmDeleteDialog(
                                    context,
                                    playlistName,
                                  ) ??
                                  false;
                              if (delete) {
                                provider.deletePlaylist(playlistName);
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename Playlist'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete Playlist',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  void _showRenamePlaylistDialog(
    BuildContext context,
    AudioProvider provider,
    String oldName,
  ) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename Playlist"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "New Playlist Name"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty && newName != oldName) {
                  // Workaround: Create new, copy over songs, and delete the old one
                  final existingSongs = provider.getSongsInPlaylist(oldName);
                  provider.createPlaylist(newName);
                  for (var song in existingSongs) {
                    provider.addToPlaylist(newName, song.id);
                  }
                  provider.deletePlaylist(oldName);
                  Navigator.pop(context);
                }
              },
              child: const Text("Rename"),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmDeleteDialog(
    BuildContext context,
    String playlistName,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Playlist?"),
        content: Text("Are you sure you want to delete '$playlistName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
            icon: const Icon(Icons.add),
            tooltip: 'Add Song',
            onPressed: () => _showAddSongsBottomSheet(context, provider),
          ),
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 64, color: colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text("Playlist is empty"),
                  TextButton(
                    onPressed: () =>
                        _showAddSongsBottomSheet(context, provider),
                    child: const Text("Add Songs"),
                  ),
                ],
              ),
            )
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PlayerUI()),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: colorScheme.error,
                      tooltip: 'Remove Song',
                      onPressed: () {
                        provider.removeFromPlaylist(playlistName, song.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Removed ${song.title}")),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddSongsBottomSheet(BuildContext context, AudioProvider provider) {
    final allSongs = provider.songs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Add Songs to Playlist",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: Consumer<AudioProvider>(
                      builder: (context, currentProvider, child) {
                        final existingSongs = currentProvider
                            .getSongsInPlaylist(playlistName)
                            .map((s) => s.id)
                            .toSet();
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: allSongs.length,
                          itemBuilder: (context, index) {
                            final song = allSongs[index];
                            final isAdded = existingSongs.contains(song.id);

                            return ListTile(
                              leading: Icon(
                                Icons.music_note,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artist ?? "Unknown",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                isAdded
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                color: isAdded ? Colors.green : null,
                              ),
                              onTap: () {
                                if (!isAdded) {
                                  currentProvider.addToPlaylist(
                                    playlistName,
                                    song.id,
                                  );
                                } else {
                                  currentProvider.removeFromPlaylist(
                                    playlistName,
                                    song.id,
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
