import 'package:flutter/material.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final List<Map<String, dynamic>> _mockMusicList = [
    {
      'title': 'London Jazz on a Rainy Day',
      'location': 'London',
      'date': '2023-05-15',
      'url': 'https://example.com/music1.mp3',
    },
    {
      'title': 'Tokyo Urban Electronic',
      'location': 'Tokyo',
      'date': '2023-06-22',
      'url': 'https://example.com/music2.mp3',
    },
    {
      'title': 'Paris Cafe Piano',
      'location': 'Paris',
      'date': '2023-07-10',
      'url': 'https://example.com/music3.mp3',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Music Library'),
      ),
      body: ListView.builder(
        itemCount: _mockMusicList.length,
        itemBuilder: (context, index) {
          final music = _mockMusicList[index];
          return ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(music['title']),
            subtitle: Text('${music['location']} · ${music['date']}'),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                // TODO: Implement music playback
              },
            ),
            onTap: () {
              // TODO: Navigate to music details page
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Create new playlist
        },
        child: const Icon(Icons.playlist_add),
      ),
    );
  }
} 