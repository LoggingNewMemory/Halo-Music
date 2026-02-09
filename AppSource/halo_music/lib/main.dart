import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';

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

  List<AssetEntity> _songs = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _hasPermission = true; // Track permission state

  AudioPlayer get audioPlayer => _audioPlayer;
  List<AssetEntity> get songs => _songs;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get hasPermission => _hasPermission;

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
    // FIX: Explicitly request AUDIO permissions.
    // Without this, it defaults to Common (Image/Video), causing failures on Android 13+
    // if only READ_MEDIA_AUDIO is in the manifest.
    final PermissionState ps = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.audio,
          mediaLocation: false,
        ),
      ),
    );

    // FIX: Do not auto-open settings. Just update state.
    if (!ps.isAuth) {
      _hasPermission = false;
      notifyListeners();
      return;
    }

    _hasPermission = true;

    // Fetch audio albums (paths)
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.audio,
    );

    if (paths.isEmpty) {
      _songs = [];
      notifyListeners();
      return;
    }

    // Usually the first path is "Recent" or "All"
    final AssetPathEntity path = paths.first;

    final int count = await path.assetCountAsync;

    final List<AssetEntity> assets = await path.getAssetListRange(
      start: 0,
      end: count,
    );

    // Filter duration > 10 seconds
    _songs = assets.where((e) => e.duration > 10).toList();

    notifyListeners();
  }

  Future<void> playSong(int index) async {
    _currentIndex = index;
    try {
      final song = _songs[index];
      final file = await song.file;

      if (file != null) {
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
