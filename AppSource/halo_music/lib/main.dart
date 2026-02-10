import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import 'music_list.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AudioHandler? audioHandler;
  String? initError;

  try {
    audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.halo_music.channel.audio',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: true,
      ),
    );
  } catch (e) {
    initError = e.toString();
    debugPrint("CRITICAL ERROR: AudioService failed to start: $e");
  }

  if (audioHandler == null) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "Audio Service Failed to Start.\n\nError:\n$initError\n\nTry running 'flutter clean'.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider(audioHandler!)),
      ],
      child: const HaloMusicApp(),
    ),
  );
}

class HaloMusicApp extends StatelessWidget {
  const HaloMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Halo Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const MusicListScreen(),
    );
  }
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _audioQuery = OnAudioQuery();

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Sync the current song from the Queue to the Notification.
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty) {
        if (index >= 0 && index < queue.value.length) {
          final newItem = queue.value[index];

          // 1. Immediately update text info (Title/Artist)
          mediaItem.add(newItem);

          // 2. Fetch and update artwork asynchronously
          _updateNotificationWithArtwork(newItem);
        }
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  /// ------------------------------------------------------------------
  /// STANDALONE ARTWORK LOGIC
  /// 1. Cleans up old 'cover_*.jpg' files to save space.
  /// 2. Generates 'cover_{songId}.jpg' so the URI is unique.
  /// 3. Updates the Notification with this physical file.
  /// ------------------------------------------------------------------
  Future<void> _updateNotificationWithArtwork(MediaItem item) async {
    try {
      final int songId = int.parse(item.id);
      final tempDir = await getTemporaryDirectory();
      final File artworkFile = File('${tempDir.path}/cover_$songId.jpg');

      // --- CLEANUP: Delete other cover files ---
      try {
        final dir = Directory(tempDir.path);
        final List<FileSystemEntity> files = dir.listSync();
        for (var file in files) {
          if (file is File) {
            final filename = file.uri.pathSegments.last;
            // Delete if it's a cover file AND NOT the one we need right now
            if (filename.startsWith("cover_") &&
                filename.endsWith(".jpg") &&
                filename != "cover_$songId.jpg") {
              await file.delete();
            }
          }
        }
      } catch (e) {
        debugPrint("Cleanup warning: $e");
      }

      // --- CHECK CACHE: If this song's art exists, use it ---
      if (await artworkFile.exists()) {
        mediaItem.add(item.copyWith(artUri: Uri.file(artworkFile.path)));
        return;
      }

      // --- GENERATE: Extract bytes from OnAudioQuery ---
      final Uint8List? bytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1000,
        quality: 100,
      );

      // --- SAVE & UPDATE ---
      if (bytes != null && bytes.isNotEmpty) {
        await artworkFile.writeAsBytes(bytes);
        mediaItem.add(item.copyWith(artUri: Uri.file(artworkFile.path)));
      } else {
        // No artwork? Clear the URI so it doesn't show previous song's art
        mediaItem.add(item.copyWith(artUri: null));
      }
    } catch (e) {
      debugPrint("Error generating notification thumbnail: $e");
      mediaItem.add(item.copyWith(artUri: null));
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    if (_player.shuffleModeEnabled) {
      index = _player.shuffleIndices![index];
    }
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) _player.play();
  }

  Future<void> setPlaylist(List<MediaItem> songs) async {
    queue.add(songs);

    final audioSources = songs.map((item) {
      final path = item.extras?['url'] as String;
      // Use Uri.file to handle special characters in paths correctly
      return AudioSource.uri(Uri.file(path), tag: item);
    }).toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: audioSources),
    );
  }
}

class AudioProvider extends ChangeNotifier {
  final AudioHandler _audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModel> _songs = [];
  bool _hasPermission = false;

  AudioProvider(this._audioHandler) {
    _audioHandler.playbackState.listen((_) => notifyListeners());
    _audioHandler.mediaItem.listen((_) => notifyListeners());
  }

  List<SongModel> get songs => _songs;
  bool get hasPermission => _hasPermission;
  bool get isPlaying => _audioHandler.playbackState.value.playing;

  SongModel? get currentSong {
    final mediaItem = _audioHandler.mediaItem.value;
    if (mediaItem == null) return null;
    try {
      return _songs.firstWhere((s) => s.id.toString() == mediaItem.id);
    } catch (e) {
      return null;
    }
  }

  Future<void> initSongs() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.audio,
      Permission.storage,
      Permission.notification,
    ].request();

    if (statuses[Permission.audio] == PermissionStatus.granted ||
        statuses[Permission.storage] == PermissionStatus.granted) {
      _hasPermission = true;
    } else {
      _hasPermission = false;
      notifyListeners();
      return;
    }

    List<SongModel> fetchedSongs = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    _songs = fetchedSongs.where((e) => (e.duration ?? 0) > 10000).toList();

    if (_songs.isEmpty) {
      notifyListeners();
      return;
    }

    // Initial load: ArtUri is NULL.
    // It will be filled by _updateNotificationWithArtwork in MyAudioHandler.
    final mediaItems = _songs.map((song) {
      return MediaItem(
        id: song.id.toString(),
        album: song.album ?? "Unknown Album",
        title: song.title,
        artist: song.artist ?? "Unknown Artist",
        duration: Duration(milliseconds: song.duration ?? 0),
        artUri: null,
        extras: {'url': song.data},
      );
    }).toList();

    if (_audioHandler is MyAudioHandler) {
      await (_audioHandler as MyAudioHandler).setPlaylist(mediaItems);
    }

    notifyListeners();
  }

  Future<void> playSong(int index) async {
    await _audioHandler.skipToQueueItem(index);
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  void togglePlay() {
    if (isPlaying) {
      _audioHandler.pause();
    } else {
      _audioHandler.play();
    }
  }

  void playNext() => _audioHandler.skipToNext();
  void playPrevious() => _audioHandler.skipToPrevious();
}
