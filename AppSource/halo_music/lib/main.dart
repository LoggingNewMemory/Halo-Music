import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart'; // MIGRATION: New import

// Note: You will need to update this file to handle AssetEntity instead of SongModel
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

  // MIGRATION: Changed from SongModel to AssetEntity
  List<AssetEntity> _songs = [];
  int _currentIndex = -1;
  bool _isPlaying = false;

  AudioPlayer get audioPlayer => _audioPlayer;
  List<AssetEntity> get songs => _songs;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;

  AssetEntity? get currentSong =>
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
    // MIGRATION: PhotoManager handles permissions (including Android 13+)
    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    if (!ps.isAuth) {
      // Handle permission denied: Open settings or show dialog
      PhotoManager.openSetting();
      return;
    }

    // MIGRATION: Fetch audio albums (paths) first
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.audio,
    );

    if (paths.isEmpty) return;

    // Usually the first path is "Recent" or "All"
    final AssetPathEntity path = paths.first;

    // Fetch total count to get all assets
    final int count = await path.assetCountAsync;

    // Fetch assets (paginated usually, but getting all here for simplicity)
    final List<AssetEntity> assets = await path.getAssetListRange(
      start: 0,
      end: count,
    );

    // MIGRATION: Filter duration.
    // AssetEntity duration is in SECONDS. Your original check was > 10000ms (10s).
    _songs = assets.where((e) => e.duration > 10).toList();

    notifyListeners();
  }

  Future<void> playSong(int index) async {
    _currentIndex = index;
    try {
      final song = _songs[index];

      // MIGRATION: Must await .file to get the IO File object
      final file = await song.file;

      if (file != null) {
        // Load file path into just_audio
        await _audioPlayer.setAudioSource(AudioSource.file(file.path));
        _audioPlayer.play();
      }
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
