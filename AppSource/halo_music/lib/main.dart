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
            child: Text(
              "Audio Service Failed: $initError",
              style: const TextStyle(color: Colors.red),
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

// --- AUDIO HANDLER (Unchanged mostly, just efficient) ---
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _audioQuery = OnAudioQuery();

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty) {
        if (index >= 0 && index < queue.value.length) {
          final newItem = queue.value[index];
          mediaItem.add(newItem);
          _updateNotificationWithArtwork(newItem);
        }
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });
  }

  Future<void> _updateNotificationWithArtwork(MediaItem item) async {
    try {
      final int songId = int.parse(item.id);
      final tempDir = await getTemporaryDirectory();
      final File artworkFile = File('${tempDir.path}/cover_$songId.jpg');

      if (await artworkFile.exists()) {
        mediaItem.add(item.copyWith(artUri: Uri.file(artworkFile.path)));
        return;
      }

      final Uint8List? bytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1000,
        quality: 100,
      );

      if (bytes != null && bytes.isNotEmpty) {
        await artworkFile.writeAsBytes(bytes);
        mediaItem.add(item.copyWith(artUri: Uri.file(artworkFile.path)));
      } else {
        mediaItem.add(item.copyWith(artUri: null));
      }
    } catch (e) {
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
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) _player.play();
  }

  Future<void> setPlaylist(List<MediaItem> songs) async {
    queue.add(songs);
    final audioSources = songs
        .map(
          (item) => AudioSource.uri(Uri.file(item.extras?['url']), tag: item),
        )
        .toList();
    await _player.setAudioSource(
      ConcatenatingAudioSource(children: audioSources),
    );
  }
}

// --- PROVIDER ---

enum SortType { title, artist, dateAdded }

class AudioProvider extends ChangeNotifier {
  final AudioHandler _audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // _allSongs keeps the original fetched list
  List<SongModel> _allSongs = [];
  // _displayedSongs is what the UI shows (filtered/sorted)
  List<SongModel> _displayedSongs = [];

  bool _hasPermission = false;
  SortType _currentSort = SortType.dateAdded;

  AudioProvider(this._audioHandler) {
    // FIX: Do NOT listen to playbackState here to prevent flickering the whole list.
    // Only listen to mediaItem to know what the current song is.
    _audioHandler.mediaItem.listen((_) => notifyListeners());
  }

  List<SongModel> get songs => _displayedSongs;
  bool get hasPermission => _hasPermission;
  AudioHandler get audioHandler => _audioHandler;

  SongModel? get currentSong {
    final mediaItem = _audioHandler.mediaItem.value;
    if (mediaItem == null) return null;
    try {
      return _allSongs.firstWhere((s) => s.id.toString() == mediaItem.id);
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

    // Filter short clips
    _allSongs = fetchedSongs.where((e) => (e.duration ?? 0) > 10000).toList();
    _displayedSongs = List.from(_allSongs); // Initial display

    if (_allSongs.isEmpty) {
      notifyListeners();
      return;
    }

    final mediaItems = _allSongs.map((song) {
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

  // --- Search Logic ---
  void search(String query) {
    if (query.isEmpty) {
      _displayedSongs = List.from(_allSongs);
    } else {
      _displayedSongs = _allSongs.where((song) {
        return song.title.toLowerCase().contains(query.toLowerCase()) ||
            (song.artist?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
    }
    _applySort(); // Re-sort after filtering
    notifyListeners();
  }

  // --- Sort Logic ---
  void sort(SortType type) {
    _currentSort = type;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    switch (_currentSort) {
      case SortType.title:
        _displayedSongs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortType.artist:
        _displayedSongs.sort(
          (a, b) => (a.artist ?? "").compareTo(b.artist ?? ""),
        );
        break;
      case SortType.dateAdded:
        // Assuming higher ID is newer if dateAdded isn't reliable,
        // but typically dateAdded is best.
        _displayedSongs.sort(
          (a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0),
        );
        break;
    }
  }

  Future<void> playSong(int index) async {
    // We must find the index of the song in the ORIGINAL queue (AudioHandler queue)
    // because displayedSongs might be filtered/sorted.
    final songToPlay = _displayedSongs[index];
    final originalIndex = _allSongs.indexOf(songToPlay);

    if (originalIndex != -1) {
      await _audioHandler.skipToQueueItem(originalIndex);
    }
  }

  Future<void> seek(Duration position) async =>
      await _audioHandler.seek(position);

  // Use a Stream getter for player state to avoid rebuilding the whole provider
  Stream<PlaybackState> get playbackStateStream => _audioHandler.playbackState;

  void togglePlay() {
    if (_audioHandler.playbackState.value.playing) {
      _audioHandler.pause();
    } else {
      _audioHandler.play();
    }
  }

  void playNext() => _audioHandler.skipToNext();
  void playPrevious() => _audioHandler.skipToPrevious();
}
