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
  
  // 播放列表
  List<MusicItem> _playlist = [];
  
  // 当前播放索引
  int _currentIndex = -1;
  
  // 获取当前播放列表
  List<MusicItem> get playlist => List.unmodifiable(_playlist);
  
  // 获取当前播放索引
  int get currentIndex => _currentIndex;
  
  // 判断是否有下一首歌曲
  bool get hasNext => _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
  
  // 判断是否有上一首歌曲
  bool get hasPrevious => _playlist.isNotEmpty && _currentIndex > 0;
  
  // Internal constructor
  AudioPlayerManager._internal() {
    // Initialize the player state listener
    _player.playerStateStream.listen((state) {
      //print("Playback State Changed: Playing=${state.playing}, Processing=${state.processingState}");
      
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
      // Save music item information
      if (musicItem != null) {
        _currentMusic = musicItem;
        
        // Update playlist and current index
        int existingIndex = _playlist.indexWhere((item) => item.id == musicId);
        if (existingIndex >= 0) {
          // If song is already in the playlist, set current index directly
          _currentIndex = existingIndex;
        } else {
          // Otherwise, add to playlist and set it as the current song
          _playlist.add(musicItem);
          _currentIndex = _playlist.length - 1;
        }
      }
      
      // If the same song is already playing, return
      if (_currentMusicId == musicId && _player.playing) {
        return;
      }
      
      // Set current music ID (before playing operation)
      _currentMusicId = musicId;
      
      // Notify listeners before playing to update UI
      notifyListeners();
      
      // If another song is playing, stop it first
      if (_player.playing) {
        await _player.stop();
      }
      
      // Try to set audio source and play
      await _player.setUrl(audioUrl);
      await _player.play();
      
      // Notify listeners after playing to update UI
      notifyListeners();
    } catch (e) {
      print('Play music failed: $e');
      notifyListeners();
      rethrow;
    }
  }
  
  // Pause playback
  Future<void> pauseMusic() async {
    if (_player.playing) {
      await _player.pause();
      notifyListeners();
    }
  }
  
  // Resume playback
  Future<void> resumeMusic() async {
    try {
      if (_currentMusicId != null && !_player.playing) {
        await _player.play();
        notifyListeners();
      }
    } catch (e) {
      print('Resume playback failed: $e');
      notifyListeners();
    }
  }
  
  // Stop playback
  Future<void> stopMusic() async {
    await _player.stop();
    _currentMusicId = null;
    notifyListeners();
  }
  
  // Play next song
  Future<bool> playNext() async {
    if (!hasNext) return false;
    
    try {
      // Move to next index
      _currentIndex++;
      MusicItem nextMusic = _playlist[_currentIndex];
      
      // Play next song
      await playMusic(nextMusic.id, nextMusic.audioUrl, musicItem: nextMusic);
      return true;
    } catch (e) {
      print('Play next failed: $e');
      return false;
    }
  }
  
  // Play previous song
  Future<bool> playPrevious() async {
    if (!hasPrevious) return false;
    
    try {
      // Move to previous index
      _currentIndex--;
      MusicItem prevMusic = _playlist[_currentIndex];
      
      // Play previous song
      await playMusic(prevMusic.id, prevMusic.audioUrl, musicItem: prevMusic);
      return true;
    } catch (e) {
      print('Play previous failed: $e');
      return false;
    }
  }
  
  // Set playlist
  void setPlaylist(List<MusicItem> songs, {int initialIndex = 0}) {
    if (songs.isEmpty) return;
    
    _playlist = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);
    
    // If initial index is provided, immediately play that song
    if (_playlist.isNotEmpty) {
      final initialSong = _playlist[_currentIndex];
      playMusic(initialSong.id, initialSong.audioUrl, musicItem: initialSong);
    }
  }
  
  // Seek to specific position
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
    notifyListeners();
  }
  
  // Get current playback position
  Stream<Duration> get positionStream => _player.positionStream;
  
  // Get audio total duration
  Duration? get duration => _player.duration;
  
  // Add this getter to expose the audioPlayer
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  // Get current position
  Duration get position => _player.position;
  
  // Clean up resources
  @override
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