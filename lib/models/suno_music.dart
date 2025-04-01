class SunoMusic {
  final String id;
  final String title;
  final String audioUrl;
  final String prompt;
  final String status;
  final DateTime createdAt;
  
  SunoMusic({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.prompt,
    required this.status,
    required this.createdAt,
  });
  
  factory SunoMusic.fromJson(Map<String, dynamic> json) {
    // 尝试获取嵌套在内部的音乐数据
    Map<String, dynamic> musicData = json;
    
    // 如果响应中有data或music字段，则尝试从中获取音乐信息
    if (json.containsKey('data') && json['data'] is Map) {
      musicData = json['data'];
    } else if (json.containsKey('music') && json['music'] is Map) {
      musicData = json['music'];
    } else if (json.containsKey('result') && json['result'] is Map) {
      // Vercel API可能会将结果包装在result字段中
      musicData = json['result'];
    }

    // 尝试各种可能的字段名称 - 适配Vercel API可能的不同响应格式
    String? audioUrl = musicData['audio_url'] ?? 
                      musicData['audioUrl'] ?? 
                      musicData['url'] ?? 
                      musicData['audio_file'] ??
                      musicData['audioFile'] ?? 
                      '';
                      
    String? title = musicData['title'] ?? 
                   musicData['name'] ?? 
                   'Untitled Music';
                   
    String? promptText = musicData['prompt'] ?? 
                        musicData['description'] ?? 
                        musicData['text'] ?? 
                        '';
                        
    String? statusValue = musicData['status'] ??
                         musicData['state'] ??
                         'unknown';

    // 辅助函数：安全获取ID
    String safeGetId() {
      // 直接从musicData获取
      if (musicData.containsKey('id') && musicData['id'] != null) {
        return musicData['id'].toString();
      }
      
      // 从路径或URL中提取
      if (musicData.containsKey('path') && musicData['path'] != null) {
        final String path = musicData['path'].toString();
        final RegExp idRegex = RegExp(r'([a-zA-Z0-9]{8,})');
        final match = idRegex.firstMatch(path);
        if (match != null) {
          return match.group(1) ?? '';
        }
      }
      
      // 从audioUrl中提取
      if (audioUrl != null && audioUrl.isNotEmpty) {
        final RegExp idRegex = RegExp(r'([a-zA-Z0-9]{8,})\.mp3');
        final match = idRegex.firstMatch(audioUrl);
        if (match != null) {
          return match.group(1) ?? '';
        }
      }
      
      return '';
    }

    return SunoMusic(
      id: safeGetId(),
      title: title ?? '',
      audioUrl: audioUrl ?? '',
      prompt: promptText ?? '',
      status: statusValue ?? 'unknown',
      createdAt: _parseDateTime(musicData['created_at'] ?? 
                               musicData['createdAt'] ?? 
                               musicData['timestamp'] ??
                               musicData['date']),
    );
  }
  
  // Parse date time safely
  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }
    
    try {
      if (dateValue is String) {
        // Try to parse various date formats
        if (dateValue.contains('T') || dateValue.contains('-')) {
          return DateTime.parse(dateValue);
        } else if (dateValue.length == 10 && int.tryParse(dateValue) != null) {
          // Unix timestamp (seconds)
          return DateTime.fromMillisecondsSinceEpoch(int.parse(dateValue) * 1000);
        }
      } else if (dateValue is int) {
        // Handle Unix timestamp (milliseconds or seconds)
        return dateValue > 9999999999
            ? DateTime.fromMillisecondsSinceEpoch(dateValue) // milliseconds
            : DateTime.fromMillisecondsSinceEpoch(dateValue * 1000); // seconds
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    
    return DateTime.now();
  }
  
  // Check if the music object is valid
  bool get isValid => id.isNotEmpty && (audioUrl.isNotEmpty || status != 'complete');
  
  // Get friendly date display
  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'audio_url': audioUrl,
      'prompt': prompt,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  @override
  String toString() {
    return 'SunoMusic{id: $id, title: $title, audioUrl: ${audioUrl.substring(0, audioUrl.length > 20 ? 20 : audioUrl.length)}..., status: $status}';
  }
} 