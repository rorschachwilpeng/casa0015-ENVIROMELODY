import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/music_item.dart';
import 'dart:developer' as developer;

class MusicLibraryManager extends ChangeNotifier {
  // Singleton instance
  static final MusicLibraryManager _instance = MusicLibraryManager._internal();
  
  // Factory constructor to get the singleton instance
  factory MusicLibraryManager() => _instance;
  
  // Internal constructor
  MusicLibraryManager._internal();
  
  // Music library list
  List<MusicItem> _musicLibrary = [];
  
  // Whether it has been initialized
  bool _initialized = false;
  
  // SharedPreferences的key
  final String _storageKey = 'music_library';
  
  // Get all music
  List<MusicItem> get allMusic => List.unmodifiable(_musicLibrary);
  
  // Initialize and load from storage
  Future<void> initialize() async {
    if (_initialized) return;
    
    await loadFromStorage();
    
    // Fix invalid URLs
    await fixInvalidUrls();
    
    _initialized = true;
    notifyListeners();
  }
  
  // Add music
  Future<void> addMusic(MusicItem music) async {
    // Check if the music with the same ID already exists
    final existingIndex = _musicLibrary.indexWhere((item) => item.id == music.id);
    
    if (existingIndex >= 0) {
      // Update existing music
      _musicLibrary[existingIndex] = music;
    } else {
      // Add new music
      _musicLibrary.add(music);
    }
    
    // Save to storage
    await saveToStorage();
    
    // Add notification mechanism, for example using ValueNotifier or Stream
    debugPrint('Music added to library: ${music.title}');
    notifyListeners();
  }
  
  // Remove music
  Future<bool> removeMusic(String id) async {
    final previousLength = _musicLibrary.length;
    _musicLibrary.removeWhere((music) => music.id == id);
    
    // Check if the removal is successful
    final removed = previousLength > _musicLibrary.length;
    
    if (removed) {
      await saveToStorage();
      debugPrint('Music removed from library: $id');
      notifyListeners();
    }
    
    return removed;
  }
  
  // Get music details
  MusicItem? getMusicById(String id) {
    try {
      return _musicLibrary.firstWhere((music) => music.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // Save to storage
  Future<void> saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert the music library to a JSON string list
      final jsonList = _musicLibrary.map((music) => jsonEncode(music.toJson())).toList();
      
      // Save the string list
      await prefs.setStringList(_storageKey, jsonList);
      
      debugPrint('Music library saved to storage: ${_musicLibrary.length} items');
    } catch (e) {
      debugPrint('Error saving music library: $e');
    }
  }
  
  // Load from storage
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get the string list
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      
      // Convert to MusicItem list
      _musicLibrary = jsonList.map((jsonStr) {
        try {
          final json = jsonDecode(jsonStr);
          return MusicItem.fromJson(json);
        } catch (e) {
          debugPrint('Error parsing music item: $e');
          return null;
        }
      }).whereType<MusicItem>().toList();
      
      debugPrint('Music library loaded from storage: ${_musicLibrary.length} items');
    } catch (e) {
      debugPrint('Error loading music library: $e');
      _musicLibrary = [];
    }
  }
  
  // Clear the library
  Future<void> clearLibrary() async {
    _musicLibrary.clear();
    await saveToStorage();
    debugPrint('Music library cleared');
    notifyListeners();
  }
  
  // Add a fix method
  Future<void> fixInvalidUrls() async {
    bool hasChanges = false;
    
    for (int i = 0; i < _musicLibrary.length; i++) {
      final music = _musicLibrary[i];
      
      // Check if it contains placeholder URL
      if (music.audioUrl.contains('your-api-base-url.com')) {
        // Extract the actual file path
        String originalUrl = music.audioUrl;
        String newUrl = '';
        
        // Try to extract the local path part
        final pathMatch = RegExp(r'/Users/.+\.mp3').firstMatch(originalUrl);
        if (pathMatch != null) {
          newUrl = pathMatch.group(0) ?? '';
          if (!newUrl.startsWith('file://')) {
            newUrl = 'file://$newUrl';
          }
        }
        
        if (newUrl.isNotEmpty) {
          _musicLibrary[i] = music.copyWith(audioUrl: newUrl);
          hasChanges = true;
          
          developer.log('Fixed audio URL: $originalUrl -> $newUrl', name: 'MusicLibraryManager');
        }
      }
    }
    
    if (hasChanges) {
      await saveToStorage();
      developer.log('Fixed invalid audio URLs', name: 'MusicLibraryManager');
      notifyListeners();
    }
  }
} 