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
    final colorScheme = Theme.of(context).colorScheme;

    if (song == null) return const SizedBox.shrink();

    // Use white for text on top of dark/blurred backgrounds for readability,
    // but tint the background elements with system color.
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
          // 1. SOLID BASE COLOR (Prevents white flash during song change)
          Container(color: colorScheme.surfaceContainer),

          // 2. BACKGROUND IMAGE WITH ANIMATED SWITCHER
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Container(
              key: ValueKey(song.id),
              width: double.infinity,
              height: double.infinity,
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                size: 500,
                quality: 90,
                nullArtworkWidget: Container(
                  color: colorScheme.primaryContainer,
                  child: Center(
                    child: Icon(
                      Icons.music_note,
                      size: 200,
                      color: colorScheme.onPrimaryContainer.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. BLUR EFFECT
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
            child: Container(color: Colors.transparent),
          ),

          // 4. SYSTEM COLOR TINT OVERLAY
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary.withOpacity(0.2),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // 5. FOREGROUND CONTENT
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              children: [
                const SizedBox(height: 60),
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        artworkHeight: 500,
                        artworkWidth: 500,
                        size: 1000,
                        quality: 100,
                        keepOldArtwork: true,
                        nullArtworkWidget: Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.music_note,
                            size: 120,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

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

                const SizedBox(height: 16),

                // --- BITRATE / FORMAT DETECTOR ---
                _FormatBadge(song: song, colorScheme: colorScheme),

                const Spacer(),

                // --- Slider ---
                _PlayerSlider(
                  duration: Duration(milliseconds: song.duration ?? 0),
                  audioHandler: provider.audioHandler,
                  colorScheme: colorScheme,
                ),

                const SizedBox(height: 24),

                // --- Controls ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 45,
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                      ),
                      onPressed: provider.playPrevious,
                    ),
                    const SizedBox(width: 24),

                    // Play/Pause
                    StreamBuilder<PlaybackState>(
                      stream: provider.playbackStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primaryContainer,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            iconSize: 36,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            onPressed: provider.togglePlay,
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 24),
                    IconButton(
                      iconSize: 45,
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

// --- NEW WIDGET: Bitrate/Format Badge ---
class _FormatBadge extends StatelessWidget {
  final SongModel song;
  final ColorScheme colorScheme;

  const _FormatBadge({required this.song, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    // 1. Detect File Extension (e.g., 'flac', 'wav', 'mp3')
    final extension = song.displayName
        .split('.')
        .last
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    final isHiRes =
        extension == 'flac' ||
        extension == 'wav' ||
        extension == 'aiff' ||
        extension == 'dsd';

    // 2. Calculate Bitrate Estimate
    // Formula: (Size in bits) / (Duration in seconds) = bps
    // Result divided by 1000 = kbps
    // (Size * 8) / (Duration_ms / 1000) / 1000  => (Size * 8) / Duration_ms
    final int bitrate = (song.duration != null && song.duration! > 0)
        ? ((song.size * 8) / song.duration!).round()
        : 0;

    if (isHiRes) {
      // --- HI-RES DISPLAY (Thunder Icon) ---
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              "${extension.toUpperCase()} / Hi-Res Audio",
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else {
      // --- STANDARD DISPLAY (Music Icon + Bitrate) ---
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note_rounded,
              size: 14,
              color: Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              bitrate > 0 ? "$bitrate kbps" : extension.toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _PlayerSlider extends StatefulWidget {
  final Duration duration;
  final AudioHandler audioHandler;
  final ColorScheme colorScheme;

  const _PlayerSlider({
    required this.duration,
    required this.audioHandler,
    required this.colorScheme,
  });

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
                activeTrackColor: widget.colorScheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                trackHeight: 4.0,
                overlayColor: widget.colorScheme.primary.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
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
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inMinutes}:$seconds";
  }
}
