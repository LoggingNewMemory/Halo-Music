import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'l10n/app_localizations.dart';
import 'main.dart';

class PlayerUI extends StatelessWidget {
  const PlayerUI({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AudioProvider>(context);
    final song = provider.currentSong;
    final l10n = AppLocalizations.of(context)!;

    if (song == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Song Name
            Text(
              song.title ?? "Unknown Title",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // Artwork
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AssetEntityImage(
                    song,
                    // FIX: Changed to false.
                    // True = tries to load MP3 as Image (Fails).
                    // False = tries to load embedded Artwork/Thumbnail (Works).
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(
                      500,
                    ), // Request higher quality thumb
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.music_note,
                        size: 100,
                        color: Colors.grey,
                      );
                    },
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Progress Bar
            StreamBuilder<Duration>(
              stream: provider.audioPlayer.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = Duration(seconds: song.duration);

                final currentSeconds = position.inSeconds.toDouble();
                final totalSeconds = total.inSeconds.toDouble();

                final sliderValue = currentSeconds.clamp(
                  0.0,
                  totalSeconds > 0 ? totalSeconds : 0.0,
                );
                final sliderMax = totalSeconds > 0 ? totalSeconds : 1.0;

                return Column(
                  children: [
                    Slider(
                      value: sliderValue,
                      max: sliderMax,
                      onChanged: (value) {
                        provider.audioPlayer.seek(
                          Duration(seconds: value.toInt()),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position)),
                          Text(_formatDuration(total)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 50,
                  icon: const Icon(Icons.skip_previous),
                  onPressed: provider.playPrevious,
                ),
                const SizedBox(width: 20),
                IconButton(
                  iconSize: 70,
                  icon: Icon(
                    provider.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  onPressed: provider.togglePlay,
                ),
                const SizedBox(width: 20),
                IconButton(
                  iconSize: 50,
                  icon: const Icon(Icons.skip_next),
                  onPressed: provider.playNext,
                ),
              ],
            ),

            const Spacer(),

            // Up Next
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.upNext, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 5),
                  Text(
                    provider.songs.length > provider.currentIndex + 1
                        ? (provider.songs[provider.currentIndex + 1].title ??
                              "-")
                        : "-",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    return "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
