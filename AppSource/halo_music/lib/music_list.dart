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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: false,
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlayerUI()),
        );
      },
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(36), // Fully rounded
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Hero(
                tag: 'mini_player_art',
                child: ClipOval(
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkHeight: 56,
                    artworkWidth: 56,
                    size: 200,
                    quality: 85,
                    nullArtworkWidget: Container(
                      width: 56,
                      height: 56,
                      color: colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.music_note,
                        color: colorScheme.onSecondaryContainer,
                      ),
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
                      fontSize: 15,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    song.artist ?? "Unknown Artist",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: provider.playPrevious,
                ),
                StreamBuilder<PlaybackState>(
                  stream: provider.playbackStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                      onPressed: provider.togglePlay,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: provider.playNext,
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControlBar(BuildContext context, AudioProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isSearching) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: "Search...",
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            prefixIcon: Icon(Icons.search, color: colorScheme.onSurface),
            suffixIcon: IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSurface),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
                provider.search('');
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
            FontAwesomeIcons.arrowDownAZ,
            onTap: () => _showSortBottomSheet(context, provider),
          ),
          const Spacer(),
          _topButton(
            context,
            FontAwesomeIcons.arrowsRotate,
            onTap: () {
              provider.initSongs(forceRefresh: true);
            },
          ),
          const SizedBox(width: 16),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sort By", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
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
          Icon(
            Icons.lock_person,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(l10n.permissionDenied),
          const SizedBox(height: 16),
          FilledButton(
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FaIcon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
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
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 50,
        height: 50,
        // BACK TO CIRCLE (ClipOval)
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
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        song.artist ?? "Unknown Artist",
        maxLines: 1,
        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        _CachedSongTile._formatDuration(song.duration ?? 0),
        style: TextStyle(color: colorScheme.outline),
      ),
      onTap: onTap,
    );
  }

  static String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    return "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
