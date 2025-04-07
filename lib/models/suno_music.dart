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
    // Try to get the nested music data
    Map<String, dynamic> musicData = json;
    
    // If the response contains the data or music field, try to get the music information
    if (json.containsKey('data') && json['data'] is Map) {
      musicData = json['data'];
    } else if (json.containsKey('music') && json['music'] is Map) {
      musicData = json['music'];
    } else if (json.containsKey('result') && json['result'] is Map) {
      // Vercel API may wrap the result in the result field
      musicData = json['result'];
    }

    // Try various possible field names - adapt to different response formats of Vercel API
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

    // Helper function: safe get ID
    String safeGetId() {
      // Get directly from musicData
      if (musicData.containsKey('id') && musicData['id'] != null) {
        return musicData['id'].toString();
      }
      
      // Extract from path or URL
      if (musicData.containsKey('path') && musicData['path'] != null) {
        final String path = musicData['path'].toString();
        final RegExp idRegex = RegExp(r'([a-zA-Z0-9]{8,})');
        final match = idRegex.firstMatch(path);
        if (match != null) {
          return match.group(1) ?? '';
        }
      }
      
      // Extract from audioUrl
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