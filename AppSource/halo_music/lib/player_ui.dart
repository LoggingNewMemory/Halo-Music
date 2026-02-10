import 'dart:io';
import 'dart:typed_data';
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

    // Use white for text on top of dark/blurred backgrounds for readability
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
          // 1. SOLID BASE COLOR
          Container(color: colorScheme.surfaceContainer),

          // 2. BACKGROUND IMAGE
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

                // --- REAL HI-RES BADGE ---
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

// --- UPDATED WIDGET: Real File Header Parsing for Accurate Hi-Res ---
class _FormatBadge extends StatefulWidget {
  final SongModel song;
  final ColorScheme colorScheme;

  const _FormatBadge({required this.song, required this.colorScheme});

  @override
  State<_FormatBadge> createState() => _FormatBadgeState();
}

class _FormatBadgeState extends State<_FormatBadge> {
  String _sampleRate = "44.1kHz";
  String _bitDepth = "16bit";
  bool _isHiRes = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealMetadata();
  }

  @override
  void didUpdateWidget(covariant _FormatBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _loadRealMetadata();
    }
  }

  Future<void> _loadRealMetadata() async {
    final path = widget.song.data;
    final extension = widget.song.displayName
        .split('.')
        .last
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Default values
    int rate = 44100;
    int bits = 16;

    try {
      final file = File(path);
      if (await file.exists()) {
        if (extension == 'FLAC') {
          final data = await _parseFlacHeader(file);
          if (data != null) {
            rate = data['rate']!;
            bits = data['bits']!;
          }
        } else if (extension == 'WAV') {
          final data = await _parseWavHeader(file);
          if (data != null) {
            rate = data['rate']!;
            bits = data['bits']!;
          }
        } else {
          // Fallback for MP3/AAC (Standard compressed usually 44.1/16 equiv)
          rate = 44100;
          bits = 16;
        }
      }
    } catch (e) {
      debugPrint("Error reading metadata: $e");
    }

    // Hi-Res Logic: Usually defined as > 16-bit or > 48kHz
    // Common Hi-Res: 24-bit/48kHz, 24-bit/96kHz, etc.
    final isHiRes = (rate > 48000) || (bits > 16);

    // Format strings
    String rateStr = (rate >= 1000)
        ? "${(rate / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}kHz"
        : "${rate}Hz";

    if (mounted) {
      setState(() {
        _sampleRate = rateStr;
        _bitDepth = "${bits}bit";
        _isHiRes = isHiRes;
        _isLoading = false;
      });
    }
  }

  // Pure Dart FLAC Header Parser
  // Reads the STREAMINFO block to get exact Hz and Bits
  Future<Map<String, int>?> _parseFlacHeader(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      // Read first 42 bytes (Header + StreamInfo)
      final bytes = await raf.read(42);
      await raf.close();

      // Check 'fLaC' signature
      if (bytes[0] != 0x66 ||
          bytes[1] != 0x4C ||
          bytes[2] != 0x61 ||
          bytes[3] != 0x43) {
        return null;
      }

      // StreamInfo block starts at byte 8 (after fLaC + 4 byte block header)
      // Actually block header is 4 bytes.
      // Metadata Block Header (4 bytes):
      // [0]: LastBlockFlag(1) + BlockType(7). Type 0 = StreamInfo.
      // [1-3]: Length(24). StreamInfo length is 34.
      // Data starts at index 8.

      // Relevant data is at the end of the 34-byte block.
      // Bytes 10-12 relative to data start contain SampleRate.
      // File Absolute Index = 8 (header end) + 10 = 18.

      // Layout from FLAC Spec:
      // ...
      // Sample Rate: 20 bits
      // Channels: 3 bits
      // Bits Per Sample: 5 bits
      // Total Samples: 36 bits

      // We need absolute bytes 18, 19, 20, 21.
      final b0 = bytes[18]; // SR high
      final b1 = bytes[19]; // SR mid
      final b2 = bytes[20]; // SR low + Channels + BPS high
      final b3 = bytes[21]; // BPS low + Total Samples

      // Sample Rate (20 bits): b0 + b1 + high 4 of b2
      final sampleRate = (b0 << 12) | (b1 << 4) | ((b2 & 0xF0) >> 4);

      // Bits Per Sample (5 bits): last bit of b2 + high 4 of b3
      final bps = ((b2 & 0x01) << 4) | ((b3 & 0xF0) >> 4) + 1;

      return {'rate': sampleRate, 'bits': bps};
    } catch (e) {
      return null;
    }
  }

  // Pure Dart WAV Header Parser
  Future<Map<String, int>?> _parseWavHeader(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(44); // Standard WAV header size
      await raf.close();

      // Check 'RIFF'
      if (bytes[0] != 0x52 || bytes[1] != 0x49) return null;

      // Check 'fmt ' at offset 12
      // Sample Rate at offset 24 (4 bytes, little endian)
      final sampleRate =
          bytes[24] | (bytes[25] << 8) | (bytes[26] << 16) | (bytes[27] << 24);

      // Bits Per Sample at offset 34 (2 bytes, little endian)
      final bitsPerSample = bytes[34] | (bytes[35] << 8);

      return {'rate': sampleRate, 'bits': bitsPerSample};
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.song.displayName
        .split('.')
        .last
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Calculate Average Bitrate (Realtime calculation)
    // For FLAC this is compressed bitrate (file size), not PCM bitrate.
    final int bitrate =
        (widget.song.duration != null && widget.song.duration! > 0)
        ? ((widget.song.size * 8) / widget.song.duration!).round()
        : 0;

    // Common Text Style
    final textStyle = TextStyle(
      color: _isHiRes ? widget.colorScheme.primary : Colors.white70,
      fontWeight: _isHiRes ? FontWeight.bold : FontWeight.w500,
      fontSize: 12,
      letterSpacing: 0.5,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isHiRes
            ? widget.colorScheme.primary.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: _isHiRes
            ? Border.all(
                color: widget.colorScheme.primary.withOpacity(0.5),
                width: 1,
              )
            : null,
        boxShadow: _isHiRes
            ? [
                BoxShadow(
                  color: widget.colorScheme.primary.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: AnimatedOpacity(
        opacity: _isLoading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isHiRes ? Icons.bolt_rounded : Icons.music_note_rounded,
              size: 16,
              color: _isHiRes ? widget.colorScheme.primary : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              "$extension • $_sampleRate • $_bitDepth • ${bitrate}kbps",
              style: textStyle,
            ),
          ],
        ),
      ),
    );
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
