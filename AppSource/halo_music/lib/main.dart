import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import 'music_list.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AudioProvider())],
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

// State Management
class AudioProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModel> _songs = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _hasPermission = false;

  AudioPlayer get audioPlayer => _audioPlayer;
  List<SongModel> get songs => _songs;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get hasPermission => _hasPermission;

  SongModel? get currentSong =>
      _currentIndex != -1 ? _songs[_currentIndex] : null;

  AudioProvider() {
    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      if (_isPlaying != isPlaying) {
        _isPlaying = isPlaying;
        notifyListeners();
      }

      if (processingState == ProcessingState.completed) {
        playNext();
      }
    });
  }

  Future<void> initSongs() async {
    // Request permissions using permission_handler
    // Android 13+ needs AUDIO, older needs STORAGE
    var statusAudio = await Permission.audio.status;
    var statusStorage = await Permission.storage.status;

    if (!statusAudio.isGranted && !statusStorage.isGranted) {
      // Request both to cover different Android versions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.audio,
        Permission.storage,
      ].request();

      if (statuses[Permission.audio] == PermissionStatus.granted ||
          statuses[Permission.storage] == PermissionStatus.granted) {
        _hasPermission = true;
      } else {
        _hasPermission = false;
        notifyListeners();
        return;
      }
    } else {
      _hasPermission = true;
    }

    // Fetch songs using OnAudioQuery
    List<SongModel> fetchedSongs = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // Filter duration > 10 seconds (10000 ms) and remove non-music types if necessary
    _songs = fetchedSongs.where((e) => (e.duration ?? 0) > 10000).toList();

    notifyListeners();
  }

  Future<void> playSong(int index) async {
    _currentIndex = index;
    try {
      final song = _songs[index];
      // OnAudioQuery provides the direct path in song.data
      await _audioPlayer.setAudioSource(AudioSource.file(song.data));
      _audioPlayer.play();
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
    notifyListeners();
  }

  void togglePlay() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void playNext() {
    if (_currentIndex < _songs.length - 1) {
      playSong(_currentIndex + 1);
    }
  }

  void playPrevious() {
    if (_currentIndex > 0) {
      playSong(_currentIndex - 1);
    }
  }
}
