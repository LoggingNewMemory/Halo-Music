import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'main.dart';

class PlayerUI extends StatefulWidget {
  const PlayerUI({super.key});

  @override
  State<PlayerUI> createState() => _PlayerUIState();
}

class _PlayerUIState extends State<PlayerUI> {
  PageController? _pageController;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Widget _buildArtworkCard(int songId, ColorScheme colorScheme) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        // Added vertical margin to give the shadow room to render without overlapping
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: QueryArtworkWidget(
            id: songId,
            type: ArtworkType.AUDIO,
            artworkHeight: 500,
            artworkWidth: 500,
            size: 1000,
            quality: 100,
            keepOldArtwork: true,
            artworkBorder: BorderRadius.circular(20),
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
    );
  }

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
          Column(
            children: [
              const SizedBox(height: 100),

              // --- ARTWORK CAROUSEL ---
              SizedBox(
                // Slightly increased height to accommodate the vertical margin and shadow
                height: MediaQuery.of(context).size.width * 0.9,
                child: StreamBuilder<List<MediaItem>>(
                  stream: provider.audioHandler.queue,
                  builder: (context, queueSnapshot) {
                    final queue = queueSnapshot.data ?? [];
                    final currentIndex = queue.indexWhere(
                      (item) => item.id == song.id.toString(),
                    );

                    // Fallback to static single artwork if queue is unavailable
                    if (queue.isEmpty || currentIndex == -1) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildArtworkCard(song.id, colorScheme),
                      );
                    }

                    // Initialize or Sync PageController securely without triggering rebuild loops
                    if (_pageController == null) {
                      _pageController = PageController(
                        initialPage: currentIndex,
                        viewportFraction: 0.75,
                      );
                    } else if (_pageController!.hasClients) {
                      final currentPage =
                          _pageController!.page?.round() ??
                          _pageController!.initialPage;
                      final isScrolling =
                          _pageController!.position.isScrollingNotifier.value;

                      if (currentPage != currentIndex && !isScrolling) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_pageController?.hasClients ?? false) {
                            _pageController!.animateToPage(
                              currentIndex,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }
                    }

                    return PageView.builder(
                      clipBehavior: Clip
                          .none, // <--- Prevents the shadow from being clipped into a straight line
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: queue.length,
                      onPageChanged: (index) {
                        if (index != currentIndex) {
                          provider.audioHandler.skipToQueueItem(index);
                        }
                      },
                      itemBuilder: (context, index) {
                        final item = queue[index];
                        final int songId = int.tryParse(item.id) ?? song.id;

                        return AnimatedBuilder(
                          animation: _pageController!,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_pageController!.position.haveDimensions) {
                              value = _pageController!.page! - index;
                            } else {
                              value = (currentIndex - index).toDouble();
                            }

                            // Dynamic scaling and fading based on scroll distance
                            double scale = (1 - (value.abs() * 0.15)).clamp(
                              0.8,
                              1.0,
                            );
                            double opacity = (1 - (value.abs() * 0.5)).clamp(
                              0.4,
                              1.0,
                            );

                            return Center(
                              child: Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: opacity,
                                  child: GestureDetector(
                                    onTap: () {
                                      // Allow tapping on side-covers to fast switch
                                      if (index != currentIndex) {
                                        _pageController?.animateToPage(
                                          index,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOut,
                                        );
                                      }
                                    },
                                    child: child,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: _buildArtworkCard(songId, colorScheme),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Wrapper for details & controls
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    bottom: 40.0,
                  ),
                  child: Column(
                    children: [
                      // --- REAL HI-RES BADGE (CENTERED & TOP) ---
                      Center(
                        child: _FormatBadge(
                          song: song,
                          colorScheme: colorScheme,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // --- TEXT INFO (LEFT ALIGNED) ---
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- Song Title (Marquee) ---
                            SizedBox(
                              height: 35,
                              child: MarqueeWidget(
                                child: Text(
                                  song.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // --- Artist (Marquee) ---
                            SizedBox(
                              height: 25,
                              child: MarqueeWidget(
                                child: Text(
                                  song.artist ?? "Unknown Artist",
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: secondaryTextColor,
                                        fontSize: 16,
                                      ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // --- Slider ---
                      _PlayerSlider(
                        duration: Duration(milliseconds: song.duration ?? 0),
                        audioHandler: provider.audioHandler,
                        colorScheme: colorScheme,
                      ),

                      const SizedBox(height: 24),

                      // --- Controls ---
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
                              // Shuffle Button
                              IconButton(
                                icon: Icon(
                                  Icons.shuffle,
                                  color:
                                      shuffleMode == AudioServiceShuffleMode.all
                                      ? colorScheme.primary
                                      : Colors.white60,
                                ),
                                onPressed: provider.toggleShuffle,
                              ),

                              IconButton(
                                iconSize: 45,
                                icon: const Icon(
                                  Icons.skip_previous_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: provider.playPrevious,
                              ),

                              // Play/Pause
                              Container(
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
                              ),

                              IconButton(
                                iconSize: 45,
                                icon: const Icon(
                                  Icons.skip_next_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: provider.playNext,
                              ),

                              // Loop Button
                              IconButton(
                                icon: Icon(
                                  repeatMode == AudioServiceRepeatMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  color:
                                      repeatMode != AudioServiceRepeatMode.none
                                      ? colorScheme.primary
                                      : Colors.white60,
                                ),
                                onPressed: provider.toggleLoop,
                              ),
                            ],
                          );
                        },
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Custom Marquee Widget ---
class MarqueeWidget extends StatefulWidget {
  final Widget child;
  final Duration pauseDuration;
  final Duration animationDuration;

  const MarqueeWidget({
    super.key,
    required this.child,
    this.pauseDuration = const Duration(seconds: 2),
    this.animationDuration = const Duration(seconds: 4),
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animate());
  }

  void _animate() async {
    if (!_scrollController.hasClients) return;

    // Only animate if the text is wider than the screen
    if (_scrollController.position.maxScrollExtent > 0) {
      await Future.delayed(widget.pauseDuration);
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.animationDuration,
          curve: Curves.linear,
        );
      }
      await Future.delayed(widget.pauseDuration);
      if (_scrollController.hasClients) {
        // Jump back to start
        _scrollController.jumpTo(0.0);
        _animate();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: widget.child,
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
          rate = 44100;
          bits = 16;
        }
      }
    } catch (e) {
      debugPrint("Error reading metadata: $e");
    }

    final isHiRes = (rate > 48000) || (bits > 16);

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
  Future<Map<String, int>?> _parseFlacHeader(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(42);
      await raf.close();

      if (bytes[0] != 0x66 ||
          bytes[1] != 0x4C ||
          bytes[2] != 0x61 ||
          bytes[3] != 0x43) {
        return null;
      }

      final b0 = bytes[18];
      final b1 = bytes[19];
      final b2 = bytes[20];
      final b3 = bytes[21];

      final sampleRate = (b0 << 12) | (b1 << 4) | ((b2 & 0xF0) >> 4);
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
      final bytes = await raf.read(44);
      await raf.close();

      if (bytes[0] != 0x52 || bytes[1] != 0x49) return null;

      final sampleRate =
          bytes[24] | (bytes[25] << 8) | (bytes[26] << 16) | (bytes[27] << 24);

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

    final int bitrate =
        (widget.song.duration != null && widget.song.duration! > 0)
        ? ((widget.song.size * 8) / widget.song.duration!).round()
        : 0;

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
