import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import '../services/suno_api_service.dart';
import '../models/suno_music.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MusicGenerationScreen extends StatefulWidget {
  const MusicGenerationScreen({super.key});

  @override
  _MusicGenerationScreenState createState() => _MusicGenerationScreenState();
}

class _MusicGenerationScreenState extends State<MusicGenerationScreen> {
  final TextEditingController _promptController = TextEditingController();
  final SunoApiService _apiService = SunoApiService();
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isLoading = false;
  bool _isApiConnected = false;
  String? _errorMessage;
  SunoMusic? _generatedMusic;
  String? _generatedMusicId;
  
  // Status information display
  String _statusMessage = '';
  int _pollAttempt = 0;
  int _maxPollAttempts = 60;

  @override
  void initState() {
    super.initState();
    _testApiConnection();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Test API connection
  Future<void> _testApiConnection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isConnected = await _apiService.testConnection();
      setState(() {
        _isApiConnected = isConnected;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isApiConnected = false;
        _isLoading = false;
        _errorMessage = 'Unable to connect to API: $e';
      });
    }
  }

  // Generate music
  Future<void> _generateMusic() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a prompt';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedMusic = null;
      _statusMessage = 'Sending generation request...';
    });

    try {
      // Send generation request
      _logger.i('Sending music generation request: $prompt');
      
      final response = await _apiService.generateMusic(prompt);
      _logger.i('Generation response: $response');
      
      // Check response type and handle correctly
      String? musicId;
      
      if (response is List && response.isNotEmpty) {
        // Handle list type response - API returned an array
        final firstItem = response[0];
        if (firstItem is Map && firstItem.containsKey('id')) {
          musicId = firstItem['id'].toString();
        }
      } else if (response is Map && response.containsKey('id')) {
        // Handle object type response
        musicId = response['id'].toString();
      }
      
      if (musicId != null) {
        _generatedMusicId = musicId;
        setState(() {
          _statusMessage = 'Request submitted, ID: $_generatedMusicId, waiting for processing...';
        });
        
        await _pollMusicStatus(_generatedMusicId!);
      } else {
        throw Exception('Unable to get music ID from response');
      }
    } catch (e) {
      _logger.e('Failed to generate music: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to generate music: $e';
        _statusMessage = '';
      });
    }
  }

  // Poll music generation status
  Future<void> _pollMusicStatus(String id) async {
    int attempts = 0;
    const maxAttempts = 60;
    
    _logger.i('Starting to poll music status: ID=$id');
    
    while (attempts < maxAttempts) {
      try {
        attempts++;
        setState(() {
          _pollAttempt = attempts;
          _statusMessage = 'Checking status, attempt $_pollAttempt/$maxAttempts...';
        });
        
        final response = await _apiService.getMusicInfo(id);
        _logger.i('Status response: $response');
        
        // Extract status
        String? status;
        Map<String, dynamic>? musicData;
        
        if (response is Map) {
          if (response.containsKey('status')) {
            status = response['status'];
            musicData = response;
          } else if (response.containsKey('items') && 
                    response['items'] is List && 
                    response['items'].isNotEmpty) {
            final item = response['items'][0];
            if (item is Map && item.containsKey('status')) {
              status = item['status'];
              musicData = Map<String, dynamic>.from(item);
            }
          }
        } else if (response is List && response.isNotEmpty) {
          final item = response[0];
          if (item is Map && item.containsKey('status')) {
            status = item['status'];
            musicData = Map<String, dynamic>.from(item);
          }
        }
        
        _logger.i('Music status: $status');
        
        if (status == 'complete') {
          _logger.i('Music generation complete!');
          
          if (musicData != null) {
            final sunoMusic = SunoMusic.fromJson(musicData);
            setState(() {
              _generatedMusic = sunoMusic;
              _isLoading = false;
              _statusMessage = 'Music generation complete!';
            });
            
            if (sunoMusic.audioUrl.isNotEmpty) {
              await _playAudio(sunoMusic.audioUrl);
            }
            return;
          }
        } else if (status == 'failed') {
          _logger.e('Music generation failed');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Music generation failed';
            _statusMessage = '';
          });
          return;
        }
        
        // Continue polling
        await Future.delayed(const Duration(seconds: 3));
      } catch (e) {
        _logger.e('Polling error: $e');
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    
    // Timeout
    _logger.w('Polling timeout');
    setState(() {
      _isLoading = false;
      _errorMessage = 'Generation timeout, ID: $_generatedMusicId';
      _statusMessage = '';
    });
    
    _showTimeoutDialog();
  }
  
  // Show timeout dialog
  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Generation Taking Longer Than Expected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Music generation is in progress but needs more time. This doesn\'t mean it failed - AI generation of high-quality music typically takes several minutes.'),
              const SizedBox(height: 8),
              Text('Music ID: $_generatedMusicId', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('You can choose to check the status again or try later.'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Copy ID'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _generatedMusicId ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID copied to clipboard')),
                );
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Check Status Again'),
              onPressed: () {
                Navigator.of(context).pop();
                if (_generatedMusicId != null) {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                    _statusMessage = 'Checking status again...';
                    _pollAttempt = 0;
                  });
                  _pollMusicStatus(_generatedMusicId!);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Play audio
  Future<void> _playAudio(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      _logger.e('Error playing audio: $e');
      setState(() {
        _errorMessage = 'Unable to play audio: $e';
      });
    }
  }

  Future<void> _testDirectApiCall() async {
    setState(() {
      _statusMessage = 'Performing direct API test...';
      _isLoading = true;
    });
    
    try {
      final client = http.Client();
      final url = 'http://localhost:3000/api/generate'; // or use 127.0.0.1
      
      _logger.i('Sending direct POST request to: $url');
      
      final response = await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'prompt': 'Test generating a short music clip'}),
      ).timeout(const Duration(seconds: 30));
      
      _logger.i('Direct test response code: ${response.statusCode}');
      _logger.i('Direct test response content: ${response.body}');
      
      setState(() {
        _statusMessage = 'Direct API test complete: ${response.statusCode}';
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Direct API test failed: $e');
      setState(() {
        _errorMessage = 'Direct API test failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Music Generation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API connection status
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: _isApiConnected ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(
                    _isApiConnected ? Icons.check_circle : Icons.error,
                    color: _isApiConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    _isApiConnected ? 'API connected successfully' : 'API connection failed',
                    style: TextStyle(
                      color: _isApiConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _testApiConnection,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16.0),
            
            // Prompt input
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Enter prompt',
                hintText: 'Example: A light and cheerful pop song with an upbeat rhythm and catchy melody',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: _isApiConnected && !_isLoading,
            ),
            
            const SizedBox(height: 16.0),
            
            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isApiConnected && !_isLoading) ? _generateMusic : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          ),
                          SizedBox(width: 16.0),
                          Text('Generating...'),
                        ],
                      )
                    : const Text('Generate Music'),
              ),
            ),
            
            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16.0),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            
            const SizedBox(height: 24.0),
            
            // Status information display
            if (_statusMessage.isNotEmpty && _isLoading) ...[
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_generatedMusicId != null) ...[
                      const SizedBox(height: 8.0),
                      Text('Music ID: $_generatedMusicId'),
                    ],
                  ],
                ),
              ),
            ],
            
            // Generation result
            if (_generatedMusic != null) ...[
              Text(
                'Generated Music:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8.0),
              Card(
                elevation: 4.0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _generatedMusic!.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8.0),
                      Text('Prompt: ${_generatedMusic!.prompt}'),
                      const SizedBox(height: 16.0),
                      const Text('Playback controls:'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => _playAudio(_generatedMusic!.audioUrl),
                          ),
                          IconButton(
                            icon: const Icon(Icons.pause),
                            onPressed: () => _audioPlayer.pause(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: () => _audioPlayer.stop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Direct test button
            ElevatedButton(
              onPressed: _testDirectApiCall,
              child: Text('Test API Directly'),
            ),
          ],
        ),
      ),
    );
  }
} 