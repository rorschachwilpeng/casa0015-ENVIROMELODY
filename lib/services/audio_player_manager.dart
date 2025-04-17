import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/music_item.dart';

class AudioPlayerManager extends ChangeNotifier {
  // Singleton instance
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  
  // Factory constructor to get the singleton instance
  factory AudioPlayerManager() => _instance;
  
  // Audio player
  final AudioPlayer _player = AudioPlayer();
  
  // Current playing music ID
  String? _currentMusicId;
  
  // Storage current music information
  MusicItem? _currentMusic;
  
  // Internal constructor
  AudioPlayerManager._internal() {
    // Initialize the player state listener
    _player.playerStateStream.listen((state) {
      print("Playback State Changed: Playing=${state.playing}, Processing=${state.processingState}");
      
      // When playback state changes, notify listeners
      notifyListeners();
      
      // If playback ends, clear current music ID
      if (state.processingState == ProcessingState.completed) {
        _currentMusicId = null;
        notifyListeners();
      }
    });
    
    // Add position listener to ensure UI slider updates
    _player.positionStream.listen((_) {
      // Only notify listeners, do not modify state
      // This ensures the UI updates with the playback progress
      notifyListeners();
    });
  }
  
  // Get the current playing music ID
  String? get currentMusicId => _currentMusicId;
  
  // Whether it is playing - directly use player state
  bool get isPlaying => _player.playing;
  
  // Get current music
  MusicItem? get currentMusic => _currentMusic;
  
  // Play music
  Future<void> playMusic(String musicId, String audioUrl, {MusicItem? musicItem}) async {
    try {
      print('Start playing music: $musicId');
      
      // Save music item information
      if (musicItem != null) {
        _currentMusic = musicItem;
      }
      
      // If the same song is already playing, return directly
      if (_currentMusicId == musicId && _player.playing) {
        print('Same music is already playing, no need to repeat');
        return;
      }
      
      // Set current music ID (before playback operation)
      _currentMusicId = musicId;
      
      // Notify listeners before playback to update UI
      print('Before playback update state: ID=$musicId');
      notifyListeners();
      
      // If another song is playing, stop it first
      if (_player.playing) {
        await _player.stop();
      }
      
      // Try to set the audio source and play
      print('Set audio URL and play');
      await _player.setUrl(audioUrl);
      await _player.play();
      
      // Notify listeners after playback to update UI
      print('After playback update state: Playing=${_player.playing}, ID=$_currentMusicId');
      notifyListeners();
    } catch (e) {
      print('Failed to play music: $e');
      notifyListeners();
      rethrow;
    }
  }
  
  // Pause playback
  Future<void> pauseMusic() async {
    print('Attempting to pause music: Current state=${_player.playing}');
    if (_player.playing) {
      await _player.pause();
      print('Music paused: State=${_player.playing}');
      notifyListeners();
    }
  }
  
  // Resume playback
  Future<void> resumeMusic() async {
    try {
      print('Attempting to resume playback: Current state=${_player.playing}, musicId=$_currentMusicId');
      if (_currentMusicId != null && !_player.playing) {
        await _player.play();
        print('Music resumed: State=${_player.playing}');
        notifyListeners();
      }
    } catch (e) {
      print('Error resuming playback: $e');
      notifyListeners();
    }
  }
  
  // Stop playback
  Future<void> stopMusic() async {
    await _player.stop();
    _currentMusicId = null;
    notifyListeners();
    print('Stopped playing music');
  }
  
  // Seek to a specific position
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
    notifyListeners();
  }
  
  // Get the current playback position
  Stream<Duration> get positionStream => _player.positionStream;
  
  // Get the total duration of the audio
  Duration? get duration => _player.duration;
  
  // Add this getter to directly access player state
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  // Get the current position
  Duration get position => _player.position;
  
  // Clean up resources
  void dispose() {
    _player.dispose();
    super.dispose();
  }
  
  // Public method to dispose player
  void disposePlayer() {
    _player.dispose();
  }
  
  // Add this getter to expose the audioPlayer
  AudioPlayer get audioPlayer => _player;
} 