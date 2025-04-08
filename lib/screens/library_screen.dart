import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_item.dart';
import '../services/music_library_manager.dart';
import 'dart:developer' as developer;
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../services/audio_player_manager.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicLibraryManager _libraryManager = MusicLibraryManager();
  final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadLibrary();
    
    // Listen to the audio playback state change
    _audioPlayerManager.addListener(_onAudioPlayerChanged);
    
    // Listen to the music library update
    _libraryManager.addListener(_refreshLibrary);
  }
  
  @override
  void dispose() {
    // Remove the listener
    _audioPlayerManager.removeListener(_onAudioPlayerChanged);
    _libraryManager.removeListener(_refreshLibrary);
    super.dispose();
  }
  
  void _onAudioPlayerChanged() {
    if (mounted) {
      setState(() {});
    }
  }
  
  void _refreshLibrary() {
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when the page is visible
    _loadLibrary();
  }
  
  // Load the music library
  Future<void> _loadLibrary() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _libraryManager.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load music library: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Play music
  Future<void> _playMusic(MusicItem music) async {
    try {
      await _audioPlayerManager.playMusic(music.id, music.audioUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play music: ${e.toString()}')),
        );
      }
    }
  }
  
  // Pause music
  void _pauseMusic() {
    _audioPlayerManager.pauseMusic();
  }
  
  // Delete music
  Future<void> _deleteMusic(String id) async {
    // Show the confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm deletion'),
        content: const Text('Are you sure you want to delete this music? This operation cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // If this music is currently playing, stop playing
      if (_audioPlayerManager.currentMusicId == id && _audioPlayerManager.isPlaying) {
        _audioPlayerManager.stopMusic();
      }
      
      final removed = await _libraryManager.removeMusic(id);
      
      // Refresh the interface
      setState(() {});
      
      // Show the prompt
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(removed ? 'Music has been deleted' : 'Failed to delete'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicList = _libraryManager.allMusic;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My music library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLibrary,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : musicList.isEmpty
              ? _buildEmptyView()
              : RefreshIndicator(
                  onRefresh: _loadLibrary,
                  child: ListView.builder(
                    itemCount: musicList.length,
                    itemBuilder: (context, index) {
                      final music = musicList[index];
                      final bool isPlaying = _audioPlayerManager.currentMusicId == music.id && 
                                            _audioPlayerManager.isPlaying;
                      
                      return Dismissible(
                        key: Key(music.id),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm deletion'),
                              content: const Text('Are you sure you want to delete this music?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) => _deleteMusic(music.id),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            child: const Icon(Icons.music_note),
                          ),
                          title: Text(
                            music.title.isEmpty ? 'Untitled Music' : music.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${music.prompt.isEmpty ? 'No prompt' : music.prompt}\n${music.createdAt.toString().substring(0, 16)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: isPlaying ? Colors.blue : null,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                _pauseMusic();
                              } else {
                                _playMusic(music);
                              }
                            },
                          ),
                          onTap: () {
                            // You can navigate to the details page
                            // Navigator.of(context).push(
                            //   MaterialPageRoute(
                            //     builder: (context) => MusicDetailScreen(music: music),
                            //   ),
                            // );
                          },
                          onLongPress: () => _showMusicOptions(music),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
  
  // Build the empty view
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your music library is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'After generating music, they will be automatically added here',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create new music'),
            onPressed: () {
              // Use pushNamed instead of pop
              Navigator.of(context).pushNamed('/create');
              // Or use your application navigation logic, for example:
              // context.read<NavigationCubit>().navigateToCreate();
            },
          ),
        ],
      ),
    );
  }
  
  // Show the music options menu
  void _showMusicOptions(MusicItem music) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play'),
            onTap: () {
              Navigator.pop(context);
              _playMusic(music);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement the share function
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteMusic(music.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('View details'),
            onTap: () {
              Navigator.pop(context);
              _showMusicInfo(music);
            },
          ),
        ],
      ),
    );
  }

  // Add a diagnostic method
  void _showMusicInfo(MusicItem music) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Music information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Title: ${music.title}'),
              const SizedBox(height: 8),
              Text('ID: ${music.id}'),
              const SizedBox(height: 8),
              Text('Prompt: ${music.prompt}'),
              const SizedBox(height: 8),
              Text('Created at: ${music.createdAt.toString()}'),
              const SizedBox(height: 16),
              Text('Audio URL:'),
              SelectableText(music.audioUrl), 
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Copy the URL to the clipboard
                  Clipboard.setData(ClipboardData(text: music.audioUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL has been copied to the clipboard')),
                  );
                },
                child: const Text('Copy URL'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Check if the URL is accessible
                    final response = await http.head(Uri.parse(music.audioUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('URL status: ${response.statusCode}')),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to check URL: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Check URL accessibility'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 