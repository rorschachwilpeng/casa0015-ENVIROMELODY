import 'package:flutter/material.dart';

enum MusicVibe {
  calm,
  energetic,
  cozy,
  chill,
  // Add more as needed
}

enum MusicGenre {
  jazz,
  lofi,
  ambient,
  environmentAmbient,
  // Add more as needed
}

// Extension method to make enums more user-friendly
extension MusicVibeExtension on MusicVibe {
  String get name {
    switch (this) {
      case MusicVibe.calm:
        return '平静';
      case MusicVibe.energetic:
        return '活力';
      case MusicVibe.cozy:
        return '舒适';
      case MusicVibe.chill:
        return '放松';
      default:
        return '';
    }
  }
  
  IconData get icon {
    switch (this) {
      case MusicVibe.calm:
        return Icons.spa;
      case MusicVibe.energetic:
        return Icons.flash_on;
      case MusicVibe.cozy:
        return Icons.local_fire_department;
      case MusicVibe.chill:
        return Icons.ac_unit;
      default:
        return Icons.music_note;
    }
  }
}

extension MusicGenreExtension on MusicGenre {
  String get name {
    switch (this) {
      case MusicGenre.jazz:
        return '爵士';
      case MusicGenre.lofi:
        return '低保真';
      case MusicGenre.ambient:
        return '环境音';
      case MusicGenre.environmentAmbient:
        return '自然环境';
      default:
        return '';
    }
  }
  
  IconData get icon {
    switch (this) {
      case MusicGenre.jazz:
        return Icons.music_note;
      case MusicGenre.lofi:
        return Icons.headphones;
      case MusicGenre.ambient:
        return Icons.surround_sound;
      case MusicGenre.environmentAmbient:
        return Icons.nature;
      default:
        return Icons.music_note;
    }
  }
} 