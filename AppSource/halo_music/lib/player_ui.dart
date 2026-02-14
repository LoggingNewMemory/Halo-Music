import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // Required for ImageFilter
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

    return Scaffold(
      extendBodyBehindAppBar: true, // Allows background to go behind AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.star_border, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // --- LAYER 1: Blurred Background Image ---
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: QueryArtworkWidget(
                key: ValueKey(song.id),
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                size: 500,
                quality: 100,
                nullArtworkWidget: Container(
                  color: const Color(0xFF2C2238), // Fallback dark color
                ),
              ),
            ),
          ),

          // --- LAYER 2: Blur Effect & Dark Overlay ---
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
              child: Container(
                color: Colors.black.withOpacity(
                  0.5,
                ), // Darkens the background for readability
              ),
            ),
          ),

          // --- LAYER 3: Main UI Content ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Left align content
                children: [
                  const SizedBox(height: 20),

                  // 1. Central Album Art (Clean & Sharp)
                  Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkHeight: 500,
                            artworkWidth: 500,
                            size: 1000,
                            quality: 100,
                            keepOldArtwork: true,
                            nullArtworkWidget: Container(
                              color: Colors.white10,
                              child: const Icon(
                                Icons.music_note,
                                size: 120,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 2. Song Info (Left Aligned)
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist ?? "Unknown Artist",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),

                  const Spacer(),

                  // 3. Slider & Time
                  _PlayerSlider(
                    duration: Duration(milliseconds: song.duration ?? 0),
                    audioHandler: provider.audioHandler,
                  ),

                  const SizedBox(height: 10),

                  // 4. Controls
                  StreamBuilder<PlaybackState>(
                    stream: provider.playbackStateStream,
                    builder: (context, snapshot) {
                      final playbackState = snapshot.data;
                      final playing = playbackState?.playing ?? false;
                      final shuffleMode =
                          playbackState?.shuffleMode ??
                          AudioServiceShuffleMode.none;
                      final repeatMode =
                          playbackState?.repeatMode ??
                          AudioServiceRepeatMode.none;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Shuffle
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: shuffleMode == AudioServiceShuffleMode.all
                                  ? Theme.of(context).primaryColor
                                  : Colors.white70,
                              size: 28,
                            ),
                            onPressed: provider.toggleShuffle,
                          ),

                          // Previous
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous,
                              color: Colors.white,
                              size: 36,
                            ),
                            onPressed: provider.playPrevious,
                          ),

                          // Play/Pause (White Circle)
                          Container(
                            height: 70,
                            width: 70,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: IconButton(
                              iconSize: 32,
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                color: Colors.black87,
                              ),
                              onPressed: provider.togglePlay,
                            ),
                          ),

                          // Next
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next,
                              color: Colors.white,
                              size: 36,
                            ),
                            onPressed: provider.playNext,
                          ),

                          // Repeat
                          IconButton(
                            icon: Icon(
                              repeatMode == AudioServiceRepeatMode.one
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                              color: repeatMode != AudioServiceRepeatMode.none
                                  ? Theme.of(context).primaryColor
                                  : Colors.white70,
                              size: 28,
                            ),
                            onPressed: provider.toggleLoop,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSlider extends StatefulWidget {
  final Duration duration;
  final AudioHandler audioHandler;

  const _PlayerSlider({required this.duration, required this.audioHandler});

  @override
  State<_PlayerSlider> createState() => _PlayerSliderState();
}

class _PlayerSliderState extends State<_PlayerSlider> {
  double? _dragValue;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final totalSeconds = widget.duration.inSeconds.toDouble();
        final max = totalSeconds > 0 ? totalSeconds : 1.0;

        double sliderValue = _isDragging
            ? _dragValue!
            : position.inSeconds.toDouble().clamp(0.0, max);

        if (sliderValue > max) sliderValue = max;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                ),
                overlayColor: Colors.white.withOpacity(0.2),
                trackShape: const RectangularSliderTrackShape(),
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
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(
                      _isDragging
                          ? Duration(seconds: _dragValue!.toInt())
                          : position,
                    ),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    _formatDuration(widget.duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    return "$minutes:$seconds";
  }
}
