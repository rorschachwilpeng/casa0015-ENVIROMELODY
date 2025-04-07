import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:developer' as developer;

class AudioPlayerManager extends ChangeNotifier {
  // Singleton instance
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  
  // Factory constructor to get the singleton instance
  factory AudioPlayerManager() => _instance;
  
  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Current playing music ID
  String? _currentMusicId;
  
  // Whether it is playing
  bool _isPlaying = false;
  
  // Internal constructor
  AudioPlayerManager._internal() {
    // Initialize the player state listener
    _audioPlayer.playerStateStream.listen((state) {
      final bool wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      
      // If the playback state changes, notify the listener
      if (wasPlaying != _isPlaying) {
        notifyListeners();
      }
      
      // If the playback ends, clear the current music ID
      if (state.processingState == ProcessingState.completed) {
        _currentMusicId = null;
        notifyListeners();
      }
    });
  }
  
  // Get the current playing music ID
  String? get currentMusicId => _currentMusicId;
  
  // Whether it is playing
  bool get isPlaying => _isPlaying;
  
  // Play music
  Future<void> playMusic(String musicId, String audioUrl) async {
    try {
      // If the same song is already playing, return directly
      if (_currentMusicId == musicId && _isPlaying) {
        return;
      }
      
      // If another song is playing, stop it first
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      
      // Record logs
      developer.log('Start playing music: $musicId', name: 'AudioPlayerManager');
      developer.log('Audio URL: $audioUrl', name: 'AudioPlayerManager');
      
      // Set the current music ID
      _currentMusicId = musicId;
      
      // Try to set the audio source and play
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
      
      // Notify the listener
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log('Failed to play music: $e', error: e, stackTrace: stackTrace, name: 'AudioPlayerManager');
      rethrow; // Rethrow the exception, let the caller handle it
    }
  }
  
  // Pause playback
  Future<void> pauseMusic() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      notifyListeners();
    }
  }
  
  // Resume playback
  Future<void> resumeMusic() async {
    if (!_isPlaying && _currentMusicId != null) {
      await _audioPlayer.play();
      notifyListeners();
    }
  }
  
  // Stop playback
  Future<void> stopMusic() async {
    await _audioPlayer.stop();
    _currentMusicId = null;
    notifyListeners();
  }
  
  // Seek to a specific position
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }
  
  // Get the current playback position
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  
  // Get the total duration of the audio
  Duration? get duration => _audioPlayer.duration;
  
  // Clean up resources
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // Add this public method
  void disposePlayer() {
    _audioPlayer.dispose();
  }
} 