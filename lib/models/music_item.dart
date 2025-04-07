import 'package:flutter/foundation.dart';

class MusicItem {
  final String id;
  final String title;
  final String prompt;
  final String audioUrl;
  final String status;
  final DateTime createdAt;
  
  // Optional: Add a field to represent the music source/API
  final String source;
  
  MusicItem({
    required this.id,
    required this.title,
    required this.prompt,
    required this.audioUrl,
    required this.status,
    required this.createdAt,
    this.source = 'stability', // Default source is stability
  });
  
  // From JSON constructor
  factory MusicItem.fromJson(Map<String, dynamic> json) {
    String audioUrl = json['audio_url'] ?? json['audioUrl'] ?? '';
    
    // Check if it contains placeholder URL, if it does, try to fix it
    if (audioUrl.contains('your-api-base-url.com')) {
      final pathMatch = RegExp(r'/Users/.+\.mp3').firstMatch(audioUrl);
      if (pathMatch != null) {
        String newUrl = pathMatch.group(0) ?? '';
        if (!newUrl.startsWith('file://')) {
          audioUrl = 'file://$newUrl';
        } else {
          audioUrl = newUrl;
        }
      }
    }
    
    return MusicItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Music',
      prompt: json['prompt'] ?? '',
      audioUrl: audioUrl,
      status: json['status'] ?? 'unknown',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      source: json['source'] ?? 'stability',
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'prompt': prompt,
      'audio_url': audioUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'source': source,
    };
  }
  
  // Create from existing SunoMusic object
  factory MusicItem.fromSunoMusic(dynamic sunoMusic) {
    if (sunoMusic == null) return MusicItem.empty();
    
    return MusicItem(
      id: sunoMusic.id,
      title: sunoMusic.title,
      prompt: sunoMusic.prompt,
      audioUrl: sunoMusic.audioUrl,
      status: sunoMusic.status,
      createdAt: sunoMusic.createdAt,
      source: 'stability',
    );
  }
  
  // Empty object, used for initialization or error handling
  factory MusicItem.empty() {
    return MusicItem(
      id: '',
      title: '',
      prompt: '',
      audioUrl: '',
      status: 'empty',
      createdAt: DateTime.now(),
    );
  }
  
  // Copy and modify
  MusicItem copyWith({
    String? id,
    String? title,
    String? prompt,
    String? audioUrl,
    String? status,
    DateTime? createdAt,
    String? source,
  }) {
    return MusicItem(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      audioUrl: audioUrl ?? this.audioUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }
  
  @override
  String toString() {
    return 'MusicItem{id: $id, title: $title, prompt: $prompt, status: $status}';
  }
} 