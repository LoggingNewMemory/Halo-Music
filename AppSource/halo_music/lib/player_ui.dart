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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.star_border,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QueryArtworkWidget(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      artworkHeight: 500,
                      artworkWidth: 500,
                      size: 1000,
                      quality: 100,
                      keepOldArtwork: true,
                      artworkBorder: BorderRadius.circular(20),
                      artworkFit: BoxFit.cover,
                      nullArtworkWidget: Center(
                        child: Icon(
                          Icons.music_note,
                          size: 120,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.artist ?? "Unknown Artist",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              _PlayerSlider(
                duration: Duration(milliseconds: song.duration ?? 0),
                audioHandler: provider.audioHandler,
              ),
              const SizedBox(height: 10),
              StreamBuilder<PlaybackState>(
                stream: provider.playbackStateStream,
                builder: (context, snapshot) {
                  final playbackState = snapshot.data;
                  final playing = playbackState?.playing ?? false;
                  final shuffleMode =
                      playbackState?.shuffleMode ??
                      AudioServiceShuffleMode.none;
                  final repeatMode =
                      playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: shuffleMode == AudioServiceShuffleMode.all
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 28,
                        ),
                        onPressed: provider.toggleShuffle,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.skip_previous,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 36,
                        ),
                        onPressed: provider.playPrevious,
                      ),
                      Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        child: IconButton(
                          iconSize: 32,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          onPressed: provider.togglePlay,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.skip_next,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 36,
                        ),
                        onPressed: provider.playNext,
                      ),
                      IconButton(
                        icon: Icon(
                          repeatMode == AudioServiceRepeatMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: repeatMode != AudioServiceRepeatMode.none
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 28,
                        ),
                        onPressed: provider.toggleLoop,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
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
                activeTrackColor: Theme.of(context).colorScheme.onSurface,
                inactiveTrackColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.3),
                thumbColor: Theme.of(context).colorScheme.onSurface,
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                ),
                overlayColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.1),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatDuration(widget.duration),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
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
