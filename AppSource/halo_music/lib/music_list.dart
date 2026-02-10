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
    // Initialize songs after the widget is built
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

  // --- TOP CONTROL BAR (Search & Sort) ---
  Widget _buildTopControlBar(BuildContext context, AudioProvider provider) {
    if (_isSearching) {
      // Show Search TextField
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Search songs, artists...",
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () {
                // Clear search and exit search mode
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
                provider.search(''); // Reset list
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
      // Show Icons (Sort, Refresh, Search)
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
              provider.initSongs();
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

  // --- SORT BOTTOM SHEET ---
  void _showSortBottomSheet(BuildContext context, AudioProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sort By",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
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
        padding: const EdgeInsets.all(8.0), // Increased for better touch area
        child: FaIcon(icon, size: 20, color: Colors.grey[800]),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    return "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
