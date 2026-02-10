import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AudioProvider>(context, listen: false).initSongs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AudioProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final currentSong = provider.currentSong;

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
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: _buildTopControlBar(context, provider),
              ),
              Expanded(
                child: !provider.hasPermission
                    ? _buildPermissionDeniedView(l10n)
                    : provider.songs.isEmpty
                    ? Center(child: Text(l10n.noSongsFound))
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          bottom: currentSong != null ? 160 : 20,
                        ),
                        itemCount: provider.songs.length,
                        itemBuilder: (context, index) {
                          final song = provider.songs[index];
                          // Uses Custom Cached Tile to prevent scroll lag
                          return _CachedSongTile(
                            song: song,
                            onTap: () => provider.playSong(index),
                          );
                        },
                      ),
              ),
            ],
          ),

          if (currentSong != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: _buildMiniPlayer(context, provider, currentSong),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer(
    BuildContext context,
    AudioProvider provider,
    SongModel song,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlayerUI()),
        );
      },
      child: Container(
        height: 70,
        margin: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          // SYSTEM COLOR
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(35), // Fully rounded ends
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipOval(
                // CIRCLE SHAPE
                child: QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  artworkHeight: 54,
                  artworkWidth: 54,
                  size: 200, // Small render size
                  quality: 85,
                  nullArtworkWidget: Container(
                    width: 54,
                    height: 54,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.music_note,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    song.artist ?? "Unknown Artist",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: provider.playPrevious,
                ),
                StreamBuilder<PlaybackState>(
                  stream: provider.playbackStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(
                        playing ? Icons.pause_circle : Icons.play_circle,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: provider.togglePlay,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: provider.playNext,
                ),
              ],
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControlBar(BuildContext context, AudioProvider provider) {
    if (_isSearching) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Search songs, artists...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
                provider.search('');
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: (value) {
            provider.search(value);
          },
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topButton(
            context,
            FontAwesomeIcons.sort,
            onTap: () => _showSortBottomSheet(context, provider),
          ),
          _topButton(
            context,
            FontAwesomeIcons.arrowsRotate,
            onTap: () {
              provider.initSongs(forceRefresh: true);
            },
          ),
          _topButton(
            context,
            FontAwesomeIcons.magnifyingGlass,
            onTap: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
        ],
      );
    }
  }

  void _showSortBottomSheet(BuildContext context, AudioProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sort By",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _buildSortOption(
                  context,
                  provider,
                  "Title (A-Z)",
                  SortType.titleAZ,
                ),
                _buildSortOption(
                  context,
                  provider,
                  "Title (Z-A)",
                  SortType.titleZA,
                ),
                const Divider(),
                _buildSortOption(
                  context,
                  provider,
                  "Artist (A-Z)",
                  SortType.artistAZ,
                ),
                _buildSortOption(
                  context,
                  provider,
                  "Artist (Z-A)",
                  SortType.artistZA,
                ),
                const Divider(),
                _buildSortOption(
                  context,
                  provider,
                  "Date Added (Newest)",
                  SortType.dateNewest,
                ),
                _buildSortOption(
                  context,
                  provider,
                  "Date Added (Oldest)",
                  SortType.dateOldest,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    AudioProvider provider,
    String text,
    SortType type,
  ) {
    final isSelected = provider.currentSort == type;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        provider.sort(type);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: colorScheme.primary, size: 20),
          ],
        ),
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
        color: Colors.transparent,
        padding: const EdgeInsets.all(8.0),
        child: FaIcon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

// --- CACHED TILE WIDGET ---
class _CachedSongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;

  const _CachedSongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AudioProvider>(context, listen: false);

    return ListTile(
      leading: SizedBox(
        width: 50,
        height: 50,
        child: ClipOval(
          // CIRCLE SHAPE
          child: FutureBuilder<Uint8List?>(
            // Try to get from Memory Cache first
            future: provider.getArtworkBytes(song.id),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              }
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.music_note, color: Colors.black54),
              );
            },
          ),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.artist ?? "Unknown Artist",
        maxLines: 1,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(_CachedSongTile._formatDuration(song.duration ?? 0)),
      onTap: onTap,
    );
  }

  static String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    return "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
