import 'dart:async';
import 'dart:collection'; // Added for LRU Cache
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
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
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else {
          lightScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
          darkScheme = ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'Halo Music',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
            appBarTheme: AppBarTheme(
              backgroundColor: lightScheme.surface,
              foregroundColor: lightScheme.onSurface,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
            appBarTheme: AppBarTheme(
              backgroundColor: darkScheme.surface,
              foregroundColor: darkScheme.onSurface,
            ),
          ),
          themeMode: ThemeMode.system,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const MusicListScreen(),
        );
      },
    );
  }
}

// --- AUDIO HANDLER ---
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

  // OPTIMIZATION 1: Use Temporary Directory
  Future<Directory> _getArtworkCacheDirectory() async {
    // Switch to getTemporaryDirectory so OS can clear it if storage is low
    final tempDir = await getTemporaryDirectory();
    final artworkDir = Directory('${tempDir.path}/artwork_cache');
    if (!await artworkDir.exists()) {
      await artworkDir.create(recursive: true);
    }
    return artworkDir;
  }

  Future<void> clearArtworkCache() async {
    try {
      final cacheDir = await _getArtworkCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint("Artwork cache cleared.");
      }
    } catch (e) {
      debugPrint("Error clearing artwork cache: $e");
    }
  }

  Future<void> _updateNotificationWithArtwork(MediaItem item) async {
    try {
      final int songId = int.parse(item.id);
      final cacheDir = await _getArtworkCacheDirectory();
      final File artworkFile = File('${cacheDir.path}/cover_$songId.jpg');

      if (await artworkFile.exists()) {
        mediaItem.add(item.copyWith(artUri: Uri.file(artworkFile.path)));
        return;
      }

      // OPTIMIZATION 2: Reduce Quality and Size
      // Notifications are small. We don't need 1000px images.
      final Uint8List? bytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 300, // Reduced from 1000
        quality: 75, // Reduced from 100
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

enum SortType { titleAZ, titleZA, artistAZ, artistZA, dateNewest, dateOldest }

class AudioProvider extends ChangeNotifier {
  final AudioHandler _audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModel> _allSongs = [];
  List<SongModel> _displayedSongs = [];

  bool _hasPermission = false;
  SortType _currentSort = SortType.dateNewest;

  // OPTIMIZATION 3: LRU Cache (LinkedHashMap)
  // Replaces the standard Map to limit memory usage
  static const int _maxCacheSize = 50;
  final LinkedHashMap<int, Uint8List?> _artworkMemoryCache = LinkedHashMap();

  AudioProvider(this._audioHandler) {
    _audioHandler.mediaItem.listen((_) => notifyListeners());
  }

  List<SongModel> get songs => _displayedSongs;
  bool get hasPermission => _hasPermission;
  AudioHandler get audioHandler => _audioHandler;
  SortType get currentSort => _currentSort;

  SongModel? get currentSong {
    final mediaItem = _audioHandler.mediaItem.value;
    if (mediaItem == null) return null;
    try {
      return _allSongs.firstWhere((s) => s.id.toString() == mediaItem.id);
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> getArtworkBytes(int id) async {
    // Check if in cache
    if (_artworkMemoryCache.containsKey(id)) {
      // Move to end (most recently used)
      final data = _artworkMemoryCache.remove(id);
      _artworkMemoryCache[id] = data;
      return data;
    }

    try {
      final Uint8List? bytes = await _audioQuery.queryArtwork(
        id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 200,
        quality: 80,
      );

      // Add to cache
      _artworkMemoryCache[id] = bytes;

      // Enforce Max Size (LRU Eviction)
      if (_artworkMemoryCache.length > _maxCacheSize) {
        _artworkMemoryCache.remove(_artworkMemoryCache.keys.first);
      }

      return bytes;
    } catch (e) {
      // Don't cache errors excessively, but return null
      return null;
    }
  }

  Future<void> clearCache() async {
    _artworkMemoryCache.clear();
    if (_audioHandler is MyAudioHandler) {
      await (_audioHandler as MyAudioHandler).clearArtworkCache();
    }
    notifyListeners();
  }

  Future<void> initSongs({bool forceRefresh = false}) async {
    if (_audioHandler.playbackState.value.playing) {
      await _audioHandler.pause();
    }

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

    if (forceRefresh) {
      await clearCache();
    }

    List<SongModel> fetchedSongs = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    _allSongs = fetchedSongs.where((e) => (e.duration ?? 0) > 10000).toList();
    _displayedSongs = List.from(_allSongs);

    _applySort();

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

  void search(String query) {
    if (query.isEmpty) {
      _displayedSongs = List.from(_allSongs);
    } else {
      _displayedSongs = _allSongs.where((song) {
        return song.title.toLowerCase().contains(query.toLowerCase()) ||
            (song.artist?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
    }
    _applySort();
    notifyListeners();
  }

  void sort(SortType type) {
    _currentSort = type;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    switch (_currentSort) {
      case SortType.titleAZ:
        _displayedSongs.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SortType.titleZA:
        _displayedSongs.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
      case SortType.artistAZ:
        _displayedSongs.sort(
          (a, b) => (a.artist ?? "").toLowerCase().compareTo(
            (b.artist ?? "").toLowerCase(),
          ),
        );
        break;
      case SortType.artistZA:
        _displayedSongs.sort(
          (a, b) => (b.artist ?? "").toLowerCase().compareTo(
            (a.artist ?? "").toLowerCase(),
          ),
        );
        break;
      case SortType.dateNewest:
        _displayedSongs.sort(
          (a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0),
        );
        break;
      case SortType.dateOldest:
        _displayedSongs.sort(
          (a, b) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0),
        );
        break;
    }
  }

  Future<void> playSong(int index) async {
    final songToPlay = _displayedSongs[index];
    final originalIndex = _allSongs.indexOf(songToPlay);

    if (originalIndex != -1) {
      await _audioHandler.skipToQueueItem(originalIndex);
    }
  }

  Future<void> seek(Duration position) async =>
      await _audioHandler.seek(position);

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
