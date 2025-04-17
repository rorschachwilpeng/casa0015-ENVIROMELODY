import 'package:flutter/foundation.dart';
import '../models/music_item.dart';
import '../services/audio_player_manager.dart';

/// 播放列表管理器，负责处理播放列表相关功能
class PlaylistManager extends ChangeNotifier {
  // 单例实例
  static final PlaylistManager _instance = PlaylistManager._internal();
  
  // 工厂构造函数获取单例实例
  factory PlaylistManager() => _instance;
  
  // 内部构造函数
  PlaylistManager._internal() {
    // 初始化时添加音频播放器的监听器
    _audioPlayerManager.addListener(_onAudioPlayerChanged);
  }
  
  // 音频播放管理器
  final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
  
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
  
  // 当播放状态变化时
  void _onAudioPlayerChanged() {
    // 如果当前没有播放音乐了，可能是播放结束
    if (!_audioPlayerManager.isPlaying && _audioPlayerManager.currentMusicId == null) {
      _currentIndex = -1;
    }
    
    // 通知监听器
    notifyListeners();
  }
  
  // 设置播放列表
  void setPlaylist(List<MusicItem> songs, {int initialIndex = 0}) {
    if (songs.isEmpty) return;
    
    _playlist = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);
    
    // 如果提供了初始索引，立即播放该歌曲
    if (_playlist.isNotEmpty) {
      final initialSong = _playlist[_currentIndex];
      _audioPlayerManager.playMusic(initialSong.id, initialSong.audioUrl, musicItem: initialSong);
    }
    
    notifyListeners();
  }
  
  // 播放下一首歌曲
  Future<bool> playNext() async {
    if (!hasNext) return false;
    
    try {
      // 移动到下一个索引
      _currentIndex++;
      MusicItem nextMusic = _playlist[_currentIndex];
      
      // 播放下一首歌曲
      await _audioPlayerManager.playMusic(nextMusic.id, nextMusic.audioUrl, musicItem: nextMusic);
      notifyListeners();
      return true;
    } catch (e) {
      print('播放下一首失败: $e');
      return false;
    }
  }
  
  // 播放上一首歌曲
  Future<bool> playPrevious() async {
    if (!hasPrevious) return false;
    
    try {
      // 移动到上一个索引
      _currentIndex--;
      MusicItem prevMusic = _playlist[_currentIndex];
      
      // 播放上一首歌曲
      await _audioPlayerManager.playMusic(prevMusic.id, prevMusic.audioUrl, musicItem: prevMusic);
      notifyListeners();
      return true;
    } catch (e) {
      print('播放上一首失败: $e');
      return false;
    }
  }
  
  // 清理资源
  @override
  void dispose() {
    _audioPlayerManager.removeListener(_onAudioPlayerChanged);
    super.dispose();
  }
} 