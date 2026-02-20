import 'dart:async';
import 'dart:collection';
import 'dart:convert';
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
import 'package:rxdart/rxdart.dart';

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

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _audioQuery = OnAudioQuery();

  MyAudioHandler() {
    Rx.combineLatest3<PlaybackEvent, bool, LoopMode, PlaybackState>(
      _player.playbackEventStream,
      _player.shuffleModeEnabledStream,
      _player.loopModeStream,
      (event, shuffleEnabled, loopMode) => _transformEvent(event),
    ).pipe(playbackState);

    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty) {
        if (index >= 0 && index < queue.value.length) {
          final newItem = queue.value[index];
          mediaItem.add(newItem);
        }
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });
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
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
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
      repeatMode: const {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
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

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      await _player.setShuffleModeEnabled(false);
    } else {
      await _player.setShuffleModeEnabled(true);
      await _player.shuffle();
    }
  }

  Future<void> setPlaylist(List<MediaItem> songs) async {
    queue.add(songs);
    final audioSources = songs
        .map(
          (item) => AudioSource.uri(Uri.file(item.extras?['url']), tag: item),
        )
        .toList();

    final playlist = ConcatenatingAudioSource(children: audioSources);
    await _player.setAudioSource(playlist);
  }
}

enum SortType { titleAZ, titleZA, artistAZ, artistZA, dateNewest, dateOldest }

class AudioProvider extends ChangeNotifier {
  final AudioHandler _audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModel> _allSongs = [];
  List<SongModel> _displayedSongs = [];

  Map<String, List<int>> _playlists = {};
  Map<String, List<int>> get playlists => _playlists;

  bool _hasPermission = false;
  SortType _currentSort = SortType.dateNewest;

  Timer? _sleepTimer;
  DateTime? _sleepTimeEnd;

  static const int _maxCacheSize = 50;
  final LinkedHashMap<int, Uint8List?> _artworkMemoryCache = LinkedHashMap();

  AudioProvider(this._audioHandler) {
    _audioHandler.mediaItem.listen((_) => notifyListeners());
    _loadPlaylists();
  }

  List<SongModel> get songs => _displayedSongs;
  bool get hasPermission => _hasPermission;
  AudioHandler get audioHandler => _audioHandler;
  SortType get currentSort => _currentSort;
  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  String get timeUntilSleep {
    if (_sleepTimeEnd == null) return "";
    final remaining = _sleepTimeEnd!.difference(DateTime.now());
    if (remaining.isNegative) return "0:00";
    return "${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  SongModel? get currentSong {
    final mediaItem = _audioHandler.mediaItem.value;
    if (mediaItem == null) return null;
    try {
      return _allSongs.firstWhere((s) => s.id.toString() == mediaItem.id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/playlists.json');
      if (await file.exists()) {
        final String content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        _playlists = json.map(
          (key, value) => MapEntry(key, List<int>.from(value)),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading playlists: $e");
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/playlists.json');
      await file.writeAsString(jsonEncode(_playlists));
      notifyListeners();
    } catch (e) {
      debugPrint("Error saving playlists: $e");
    }
  }

  void createPlaylist(String name) {
    if (!_playlists.containsKey(name)) {
      _playlists[name] = [];
      _savePlaylists();
    }
  }

  void deletePlaylist(String name) {
    _playlists.remove(name);
    _savePlaylists();
  }

  void addToPlaylist(String playlistName, int songId) {
    if (_playlists.containsKey(playlistName)) {
      if (!_playlists[playlistName]!.contains(songId)) {
        _playlists[playlistName]!.add(songId);
        _savePlaylists();
      }
    }
  }

  void removeFromPlaylist(String playlistName, int songId) {
    if (_playlists.containsKey(playlistName)) {
      _playlists[playlistName]!.remove(songId);
      _savePlaylists();
    }
  }

  Future<void> playPlaylist(String playlistName) async {
    if (!_playlists.containsKey(playlistName)) return;

    final songIds = _playlists[playlistName]!;
    if (songIds.isEmpty) return;

    final playlistSongs = _allSongs
        .where((s) => songIds.contains(s.id))
        .toList();

    if (playlistSongs.isEmpty) return;

    final mediaItems = playlistSongs.map((song) {
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
      await _audioHandler.play();
    }
  }

  List<SongModel> getSongsInPlaylist(String playlistName) {
    if (!_playlists.containsKey(playlistName)) return [];
    final ids = _playlists[playlistName]!;
    return _allSongs.where((s) => ids.contains(s.id)).toList();
  }

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimeEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      _audioHandler.pause();
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimeEnd = null;
    notifyListeners();
  }

  Future<Uint8List?> getArtworkBytes(int id) async {
    if (_artworkMemoryCache.containsKey(id)) {
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

      _artworkMemoryCache[id] = bytes;
      if (_artworkMemoryCache.length > _maxCacheSize) {
        _artworkMemoryCache.remove(_artworkMemoryCache.keys.first);
      }
      return bytes;
    } catch (e) {
      return null;
    }
  }

  Future<void> clearCache() async {
    _artworkMemoryCache.clear();
    notifyListeners();
  }

  Future<void> initSongs({bool forceRefresh = false}) async {
    bool audioGranted = await Permission.audio.isGranted;
    bool storageGranted = await Permission.storage.isGranted;

    if (audioGranted || storageGranted) {
      _hasPermission = true;

      Permission.notification.isGranted.then((isGranted) {
        if (!isGranted) Permission.notification.request();
      });
    } else {
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

    if (_audioHandler.queue.value.isEmpty) {
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
    final mediaItems = _displayedSongs.map((song) {
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
      await _audioHandler.skipToQueueItem(index);
      await _audioHandler.play();
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

  void toggleShuffle() {
    final mode = _audioHandler.playbackState.value.shuffleMode;
    if (mode == AudioServiceShuffleMode.all) {
      _audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
    } else {
      _audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
    }
  }

  void toggleLoop() {
    final mode = _audioHandler.playbackState.value.repeatMode;
    switch (mode) {
      case AudioServiceRepeatMode.none:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case AudioServiceRepeatMode.one:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
  }
}
