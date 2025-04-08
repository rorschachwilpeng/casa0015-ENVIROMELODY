class MusicMarker {
  final String id;
  final String title;
  final String location;
  final DateTime createdAt;
  
  MusicMarker({
    required this.id,
    required this.title,
    required this.location,
    required this.createdAt,
  });
  
  @override
  String toString() {
    return '$title ($location)';
  }
} 