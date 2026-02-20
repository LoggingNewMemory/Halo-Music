import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class SongCover extends StatelessWidget {
  final int songId;
  final ColorScheme colorScheme;

  const SongCover({super.key, required this.songId, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: QueryArtworkWidget(
            id: songId,
            type: ArtworkType.AUDIO,
            artworkHeight: 500,
            artworkWidth: 500,
            size: 1000,
            quality: 100,
            keepOldArtwork: true,
            artworkBorder: BorderRadius.circular(10),
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
}
