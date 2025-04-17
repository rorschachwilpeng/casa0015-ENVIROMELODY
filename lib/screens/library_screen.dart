import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_item.dart';
import '../services/music_library_manager.dart';
import 'dart:developer' as developer;
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../services/audio_player_manager.dart';
import 'dart:async'; // Add timer support
import '../widgets/audio_visualizer.dart';
import '../widgets/music_player_card.dart';
import '../services/playlist_manager.dart';

// Define the sort option enum
enum SortOption {
  newest, // newest created (default)
  oldest, // oldest created
  duration // duration
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicLibraryManager _libraryManager = MusicLibraryManager();
  final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
  final PlaylistManager _playlistManager = PlaylistManager();
  
  bool _isLoading = true;
  
  // Add sort related state variables
  SortOption _currentSortOption = SortOption.newest; // Default to newest created
  List<MusicItem> _filteredMusicList = []; // Filtered music list after sorting
  
  // Search related state variables
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce; // For implementing search throttling
  
  // Add new state variable
  bool _showMusicPlayer = false;
  
  // 多选相关状态变量
  bool _isMultiSelectMode = false;
  Set<String> _selectedMusicIds = <String>{};
  
  @override
  void initState() {
    super.initState();
    _loadLibrary();
    
    // 确保添加了正确的监听器
    _audioPlayerManager.addListener(_onAudioPlayerChanged);
    _libraryManager.addListener(_refreshLibrary);
    
    print("LibraryScreen: Initialization completed");
    
    // 设置文本输入监听器
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    print("LibraryScreen: Destruction");
    
    // Remove listeners
    _audioPlayerManager.removeListener(_onAudioPlayerChanged);
    _libraryManager.removeListener(_refreshLibrary);
    _searchController.removeListener(_onSearchChanged);
    
    // Release resources
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    
    super.dispose();
  }
  
  void _onAudioPlayerChanged() {
    if (mounted) {
      setState(() {
        // When the playback state changes, automatically show the player
        if (_audioPlayerManager.isPlaying && !_showMusicPlayer) {
          _showMusicPlayer = true;
        }
      });
      //print("LibraryScreen: Playback state updated: Playing=${_audioPlayerManager.isPlaying}, Music ID=${_audioPlayerManager.currentMusicId}");
    }
  }
  
  void _refreshLibrary() {
    if (mounted) {
      setState(() {});
      _filterAndSortMusic(); // Refresh when the music library is updated
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
      
      // Apply sorting
      _filterAndSortMusic();
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
  
  // Apply sorting method
  void _filterAndSortMusic() {
    if (!mounted) return;
    
    final allMusic = _libraryManager.allMusic;
    List<MusicItem> filteredList = [];
    
    // Apply search filtering
    if (_searchQuery.isEmpty) {
      filteredList = List<MusicItem>.from(allMusic);
    } else {
      final query = _searchQuery.toLowerCase();
      filteredList = allMusic.where((music) {
        final titleMatch = music.title.toLowerCase().contains(query);
        final promptMatch = music.prompt.toLowerCase().contains(query);
        final idMatch = music.id.toLowerCase().contains(query);
        return titleMatch || promptMatch || idMatch;
      }).toList();
    }
    
    // Apply sorting
    switch (_currentSortOption) {
      case SortOption.newest:
        filteredList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        filteredList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.duration:
        filteredList.sort((a, b) => a.title.length.compareTo(b.title.length));
        break;
    }
    
    if (mounted) {
      setState(() {
        _filteredMusicList = filteredList;
      });
    }
  }

  // Change sort option
  void _changeSortOption(SortOption option) {
    setState(() {
      _currentSortOption = option;
    });
    
    // Apply new sorting
    _filterAndSortMusic();
  }
  
  // Get sort option display text
  String _getSortOptionLabel(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return 'Newest created';
      case SortOption.oldest:
        return 'Oldest created';
      case SortOption.duration:
        return 'Audio duration';
    }
  }
  
  // Build sort control UI
  Widget _buildSortControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Sorting method: ', style: TextStyle(color: Colors.grey[600])),
          DropdownButton<SortOption>(
            value: _currentSortOption,
            underline: Container(height: 1, color: Colors.grey[300]),
            icon: const Icon(Icons.arrow_drop_down),
            items: SortOption.values.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option == SortOption.newest || option == SortOption.oldest 
                          ? Icons.access_time 
                          : Icons.timer,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(_getSortOptionLabel(option)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (option) {
              if (option != null) {
                _changeSortOption(option);
              }
            },
          ),
        ],
      ),
    );
  }
  
  // Play music
  Future<void> _playMusic(MusicItem music) async {
    try {
      // 获取当前所有音乐列表
      final List<MusicItem> allMusic = _filteredMusicList;
      
      // 找到当前选择的音乐在列表中的索引
      final int currentIndex = allMusic.indexWhere((item) => item.id == music.id);
      
      // 设置播放列表，并从当前选择的歌曲开始播放
      _playlistManager.setPlaylist(allMusic, initialIndex: currentIndex > -1 ? currentIndex : 0);
      
      // 如果播放器不可见，则显示它
      if (!_showMusicPlayer) {
        setState(() {
          _showMusicPlayer = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放音乐失败: ${e.toString()}')),
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
      // If the music is currently playing, stop playing
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

  // Search text change processing
  void _onSearchChanged() {
    // Cancel the previous delay search (if any)
    _searchDebounce?.cancel();
    
    // Use Timer to implement throttling to prevent frequent searches
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        _filterAndSortMusic();
      }
    });
  }
  
  // Toggle search state
  void _toggleSearch() {
    if (!mounted) return;
    
    setState(() {
      _isSearching = !_isSearching;
      
      if (_isSearching) {
        // When searching, focus on the input box
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _searchFocusNode.requestFocus();
        });
      } else {
        // When disabling search, clear the search content
        _searchController.clear();
        _searchQuery = '';
        if (mounted) _filterAndSortMusic();
      }
    });
  }
  
  // Clear search content
  void _clearSearch() {
    if (!mounted) return;
    
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
    _filterAndSortMusic();
  }

  @override
  Widget build(BuildContext context) {
    final musicList = _filteredMusicList;
    final hasSearchResults = _searchQuery.isNotEmpty && musicList.isNotEmpty;
    final noSearchResults = _searchQuery.isNotEmpty && musicList.isEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? _buildSearchBar() 
            : Text(_isMultiSelectMode 
                ? 'Selected ${_selectedMusicIds.length} items' 
                : 'My music library'),
        actions: [
          // Display the multi-select button (when not in search mode and not in multi-select mode)
          if (!_isSearching && !_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _toggleMultiSelectMode,
              tooltip: 'Multi-select mode',
            ),
          
          // When not in multi-select mode, display the search button
          if (!_isSearching && !_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
              tooltip: 'Search',
            ),
        
          // When not in multi-select mode and not in search mode, display the refresh button
          if (!_isSearching && !_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadLibrary,
              tooltip: 'Refresh',
            ),
        
          // When in multi-select mode, display the select/deselect all button
          if (_isMultiSelectMode)
            IconButton(
              icon: Icon(
                _selectedMusicIds.length == musicList.length 
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedMusicIds.length == musicList.length) {
                    // Deselect all
                    _selectedMusicIds.clear();
                  } else {
                    // Select all
                    _selectedMusicIds = musicList.map((music) => music.id).toSet();
                  }
                });
              },
              tooltip: _selectedMusicIds.length == musicList.length 
                  ? 'Deselect all' 
                  : 'Select all',
            ),
        ],
        // When in search mode, adjust titleSpacing
        titleSpacing: _isSearching ? 0 : null,
        // When in search mode, display the back button
        leading: _isSearching 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _toggleSearch,
              )
            : (_isMultiSelectMode 
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleMultiSelectMode,
                  )
                : null),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Only display the sort control when not in search mode and not in multi-select mode
                      if (!_isSearching && !_isMultiSelectMode)
                        _buildSortControls(),
                      
                      // Display the current search status information
                      if (_isSearching && _searchQuery.isNotEmpty)
                        _buildSearchStatusBar(),
                      
                      // Main content area
                      Expanded(
                        child: musicList.isEmpty && !_searchQuery.isNotEmpty
                            ? _buildEmptyView() // Empty library view
                            : noSearchResults
                                ? _buildEmptySearchResultView() // Empty search result view
                                : RefreshIndicator(
                                    onRefresh: _loadLibrary,
                                    child: ListView.builder(
                                      itemCount: musicList.length,
                                      itemBuilder: (context, index) {
                                        final music = musicList[index];
                                        final bool isPlaying = _audioPlayerManager.currentMusicId == music.id && 
                                                            _audioPlayerManager.isPlaying;
                                        final bool isSelected = _selectedMusicIds.contains(music.id);
                                        
                                        return _isMultiSelectMode
                                            ? _buildMultiSelectListItem(music, isPlaying, isSelected)
                                            : _buildRegularListItem(music, isPlaying, index);
                                      },
                                    ),
                                  ),
                      ),
                    ],
                  ),
          ),
          
          // 如果当前有音乐在播放，显示音乐播放器卡片
          if (_audioPlayerManager.currentMusic != null)
            _buildMusicPlayer(),
        ],
      ),
      // Bottom delete button (displayed when in multi-select mode and there are selected items)
      bottomNavigationBar: _isMultiSelectMode && _selectedMusicIds.isNotEmpty
          ? BottomAppBar(
              color: Colors.red,
              child: InkWell(
                onTap: _deleteSelectedMusic,
                child: Container(
                  height: 56.0,
                  alignment: Alignment.center,
                  child: Text(
                    'Delete selected (${_selectedMusicIds.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            )
          : null,
      // Add sort button (when in search mode)
      floatingActionButton: _isSearching
          ? FloatingActionButton(
              onPressed: _showSortOptionsDialog,
              child: const Icon(Icons.sort),
              tooltip: 'Sort',
            )
          : null,
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

  // Add diagnostic method
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

  // Highlight the matching text
  Widget _highlightText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    int start = 0;
    int indexOfMatch;
    
    while (true) {
      indexOfMatch = lowerText.indexOf(lowerQuery, start);
      if (indexOfMatch < 0) {
        // No more matches
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      
      if (indexOfMatch > start) {
        // Add the non-matching part
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      
      // Add the matching part (highlighted)
      spans.add(
        TextSpan(
          text: text.substring(indexOfMatch, indexOfMatch + query.length),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            backgroundColor: Color(0x33AACCFF), // Semi-transparent background color
          ),
        ),
      );
      
      // Move to the next position
      start = indexOfMatch + query.length;
    }
    
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // Build the search bar
  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search music...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          // Hide the keyboard
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }

  // Build the empty search result view
  Widget _buildEmptySearchResultView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No matching music',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try using different keywords to search',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear search'),
            onPressed: _clearSearch,
          ),
        ],
      ),
    );
  }

  // Add multi-select mode toggle method
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        // When exiting multi-select mode, clear the selected items
        _selectedMusicIds.clear();
      }
    });
  }

  // Add batch delete method
  Future<void> _deleteSelectedMusic() async {
    if (_selectedMusicIds.isEmpty) return;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text('Are you sure you want to delete the selected ${_selectedMusicIds.length} music files? This action cannot be undone.'),
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
      // If the currently playing music is also in the deletion list, stop playing first
      if (_selectedMusicIds.contains(_audioPlayerManager.currentMusicId) && 
          _audioPlayerManager.isPlaying) {
        _audioPlayerManager.stopMusic();
      }
      
      // Execute batch deletion
      final removedCount = await _libraryManager.removeMultipleMusic(_selectedMusicIds.toList());
      
      // Update the interface state
      setState(() {
        _selectedMusicIds.clear();
        _isMultiSelectMode = false;
      });
      
      // Show a prompt
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $removedCount music files')),
        );
      }
    }
  }

  // List item for multi-select mode
  Widget _buildMultiSelectListItem(MusicItem music, bool isPlaying, bool isSelected) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Colors.blue.withOpacity(0.3)
            : Theme.of(context).primaryColor.withOpacity(0.1),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.blue)
            : const Icon(Icons.music_note),
      ),
      title: Text(
        music.title.isEmpty ? 'Untitled Music' : music.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            music.prompt.isEmpty ? 'No prompt' : music.prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            music.createdAt.toString().substring(0, 16),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedMusicIds.add(music.id);
            } else {
              _selectedMusicIds.remove(music.id);
            }
          });
        },
      ),
      onTap: () {
        setState(() {
          if (_selectedMusicIds.contains(music.id)) {
            _selectedMusicIds.remove(music.id);
          } else {
            _selectedMusicIds.add(music.id);
          }
        });
      },
    );
  }

  // List item for regular mode
  Widget _buildRegularListItem(MusicItem music, bool isPlaying, int index) {
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
            title: const Text('Confirm delete'),
            content: const Text('Are you sure you want to delete this music file?'),
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
        title: _searchQuery.isEmpty
            ? Text(
                music.title.isEmpty ? 'Untitled Music' : music.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : _highlightText(
                music.title.isEmpty ? 'Untitled Music' : music.title,
                _searchQuery,
              ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _searchQuery.isEmpty
                ? Text(
                    music.prompt.isEmpty ? 'No prompt' : music.prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : _highlightText(
                    music.prompt.isEmpty ? 'No prompt' : music.prompt,
                    _searchQuery,
                  ),
            Text(
              music.createdAt.toString().substring(0, 16),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
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
          // 可以导航到详情页
        },
        onLongPress: () => _showMusicOptions(music),
      ),
    );
  }

  // Add or modify search status bar build method
  Widget _buildSearchStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Search results: "${_searchQuery}" ${_filteredMusicList.isEmpty ? "(No matches)" : "(${_filteredMusicList.length} items)"}',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              onPressed: _clearSearch,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(50, 30),
              ),
            ),
        ],
      ),
    );
  }

  // Add sort options dialog method
  void _showSortOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select sort option'),
        children: SortOption.values.map((option) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _changeSortOption(option);
            },
            child: Row(
              children: [
                Icon(
                  option == SortOption.newest || option == SortOption.oldest 
                      ? Icons.access_time 
                      : Icons.timer,
                  color: _currentSortOption == option 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[600],
                ),
                const SizedBox(width: 16),
                Text(
                  _getSortOptionLabel(option),
                  style: TextStyle(
                    color: _currentSortOption == option 
                        ? Theme.of(context).primaryColor 
                        : null,
                    fontWeight: _currentSortOption == option 
                        ? FontWeight.bold 
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 在 LibraryScreen 中添加显示音乐播放器的方法
  Widget _buildMusicPlayer() {
    // 确保有当前播放的音乐
    if (_audioPlayerManager.currentMusic == null) return const SizedBox.shrink();
    
    return MusicPlayerCard(
      musicItem: _audioPlayerManager.currentMusic!,
      audioPlayer: _audioPlayerManager.audioPlayer,
      onClose: () {
        setState(() {
          _showMusicPlayer = false;
        });
        _audioPlayerManager.pauseMusic();
      },
      hasPrevious: _playlistManager.hasPrevious,
      hasNext: _playlistManager.hasNext,
      onPrevious: () async {
        bool success = await _playlistManager.playPrevious();
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有上一首歌曲')),
          );
        }
      },
      onNext: () async {
        bool success = await _playlistManager.playNext();
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有下一首歌曲')),
          );
        }
      },
    );
  }
} 