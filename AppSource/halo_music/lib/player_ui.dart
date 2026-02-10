import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'main.dart';

class PlayerUI extends StatelessWidget {
  const PlayerUI({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AudioProvider>(context);
    final song = provider.currentSong;

    if (song == null) return const SizedBox.shrink();

    // Text color scheme (ensures visibility on dark background)
    const textColor = Colors.white;
    const secondaryTextColor = Colors.white70;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BLURRED BACKGROUND
          QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            artworkFit: BoxFit.cover,
            size: 500, // Reduced from 1000 for performance
            quality: 90,
            nullArtworkWidget: Container(color: Colors.black),
          ),
          // Blur Effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),

          // 2. CONTENT
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // --- Artwork ---
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        artworkHeight: 500,
                        artworkWidth: 500,
                        size: 1000,
                        quality: 100,
                        keepOldArtwork: true,
                        nullArtworkWidget: Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.music_note,
                            size: 100,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // --- Song Title ---
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // --- Artist ---
                Text(
                  song.artist ?? "Unknown Artist",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: secondaryTextColor),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // --- Fixed Slider & Progress ---
                _PlayerSlider(
                  duration: Duration(milliseconds: song.duration ?? 0),
                  audioHandler: provider.audioHandler,
                ),

                const SizedBox(height: 20),

                // --- Controls ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 50,
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                      ),
                      onPressed: provider.playPrevious,
                    ),
                    const SizedBox(width: 20),

                    // Play/Pause
                    StreamBuilder<PlaybackState>(
                      stream: provider.playbackStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: IconButton(
                            iconSize: 60,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                            ),
                            onPressed: provider.togglePlay,
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 20),
                    IconButton(
                      iconSize: 50,
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                      ),
                      onPressed: provider.playNext,
                    ),
                  ],
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- SEPARATE SLIDER WIDGET FOR BUG FIX ---
class _PlayerSlider extends StatefulWidget {
  final Duration duration;
  final AudioHandler audioHandler;

  const _PlayerSlider({required this.duration, required this.audioHandler});

  @override
  State<_PlayerSlider> createState() => _PlayerSliderState();
}

class _PlayerSliderState extends State<_PlayerSlider> {
  // Local state to track sliding
  double? _dragValue;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final totalSeconds = widget.duration.inSeconds.toDouble();

        // If dragging, use local value. If not, use stream value.
        double sliderValue = _isDragging
            ? _dragValue!
            : position.inSeconds.toDouble().clamp(
                0.0,
                totalSeconds > 0 ? totalSeconds : 0.0,
              );

        // Ensure max is never 0 to prevent division by zero errors
        final max = totalSeconds > 0 ? totalSeconds : 1.0;

        // Safety check if song changed but UI hasn't caught up
        if (sliderValue > max) sliderValue = max;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                trackHeight: 4.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8.0,
                ),
              ),
              child: Slider(
                min: 0.0,
                max: max,
                value: sliderValue,
                onChanged: (value) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = value;
                  });
                },
                onChangeEnd: (value) async {
                  // Only seek when user lets go
                  await widget.audioHandler.seek(
                    Duration(seconds: value.toInt()),
                  );
                  setState(() {
                    _isDragging = false;
                    _dragValue = null;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(
                      _isDragging
                          ? Duration(seconds: _dragValue!.toInt())
                          : position,
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    _formatDuration(widget.duration),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inMinutes}:$seconds"; // Simplified to match design
  }
}
