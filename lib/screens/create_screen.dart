import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import '../services/suno_api_service.dart';
import '../models/suno_music.dart';
import 'dart:developer' as developer;
import '../utils/config.dart';
import 'dart:async'; // 支持Timer和Stopwatch
import 'dart:io'; // 添加SocketException支持
import 'package:flutter/services.dart'; // Add Clipboard support

class CreateScreen extends StatefulWidget {
  const CreateScreen({Key? key}) : super(key: key);

  @override
  _CreateScreenState createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _promptController = TextEditingController();
  late SunoApiService _apiService;
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isLoading = false;
  bool _isApiConnected = false;
  String? _errorMessage;
  SunoMusic? _generatedMusic;
  String? _generatedMusicId;
  String _statusMessage = "";
  
  // 添加API积分信息状态
  int? _remainingCredits;
  int? _dailyLimit;
  bool _isLoadingCredits = false;
  
  // 添加音频播放状态跟踪
  bool _isPlaying = false;
  
  // 添加用于取消轮询的变量
  bool _isCancelled = false;
  Timer? _pollingTimer;
  
  // API服务地址
  String _currentApiUrl = AppConfig.sunoApiBaseUrl;
  bool _usingBackupUrl = false;

  @override
  void initState() {
    super.initState();
    _apiService = SunoApiService(baseUrl: _currentApiUrl);
    _testApiConnection();
    
    // 添加音频播放状态监听
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
    
    // 初始化后检查API额度
    _checkApiQuota();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _audioPlayer.dispose();
    _cancelPolling(); // 确保在页面销毁时取消任何进行中的轮询
    _apiService.dispose(); // 关闭HTTP客户端
    super.dispose();
  }

  // 切换API服务地址
  void _switchApiUrl() {
    // Store old service to dispose it properly
    final oldApiService = _apiService;
    
    setState(() {
      _usingBackupUrl = !_usingBackupUrl;
      _currentApiUrl = _usingBackupUrl 
          ? AppConfig.sunoApiBaseUrlBackup 
          : AppConfig.sunoApiBaseUrl;
      
      // Create new API service with updated URL
      _apiService = SunoApiService(baseUrl: _currentApiUrl);
      _statusMessage = "Switched to ${_usingBackupUrl ? 'backup' : 'primary'} API server";
    });
    
    // Dispose the old service after creating the new one
    oldApiService.dispose();
    developer.log('Old API service disposed, new service created with URL: $_currentApiUrl');
    
    // Test the new connection
    _testApiConnection();
  }

  // Test API connection
  Future<void> _testApiConnection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = "Testing API connection...";
    });

    try {
      developer.log('Starting API connection test...');
      final isConnected = await _apiService.testConnection();
      developer.log('API connection test result: $isConnected');
      
      setState(() {
        _isApiConnected = isConnected;
        _isLoading = false;
        _statusMessage = isConnected ? "API connection successful" : "API connection failed";
      });
      
      // If connection failed and not using backup URL, try using backup URL
      if (!isConnected && !_usingBackupUrl) {
        _showTryBackupDialog();
      }
    } on TimeoutException catch (e) {
      developer.log('API connection test timeout: $e', error: e);
      setState(() {
        _isApiConnected = false;
        _isLoading = false;
        _errorMessage = 'Connection timeout: Please ensure the Suno API service is running';
        _statusMessage = "";
      });
      _showTryBackupDialog();
    } on SocketException catch (e) {
      developer.log('API connection test network error: $e', error: e);
      setState(() {
        _isApiConnected = false;
        _isLoading = false;
        _errorMessage = 'Network error: Unable to connect to API service';
        _statusMessage = "";
      });
      _showTryBackupDialog();
    } catch (e) {
      developer.log('API connection test error: $e', error: e);
      setState(() {
        _isApiConnected = false;
        _isLoading = false;
        _errorMessage = 'Unable to connect to API: $e';
        _statusMessage = "";
      });
    }
  }
  
  // Show dialog to try backup URL
  void _showTryBackupDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Connection Failed'),
        content: const Text('Unable to connect to main API service. Do you want to try using the backup address?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _switchApiUrl();
            },
            child: const Text('Try Backup Address'),
          ),
        ],
      ),
    );
  }

  // Cancel polling and generation process
  void _cancelPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      _pollingTimer!.cancel();
    }
    _isCancelled = true;
    developer.log('Music generation process cancelled');
  }
  
  // Cancel music generation
  void _cancelGeneration() {
    _cancelPolling();
    setState(() {
      _isLoading = false;
      _statusMessage = "Generation cancelled";
    });
    developer.log('User cancelled music generation');
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

    // Reset cancellation status
    _isCancelled = false;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedMusic = null;
      _statusMessage = "Sending generation request...";
    });

    try {
      // Add timer to detect if request is stuck
      Timer requestTimer = Timer(Duration(seconds: 5), () {
        if (_isLoading && _statusMessage == "Sending generation request...") {
          developer.log('Request seems stuck, showing prompt information');
          setState(() {
            _statusMessage = "Sending generation request... (Request is taking longer than expected, still waiting for response)";
          });
          
          // Add a second timer to check if request is really stuck
          Timer(Duration(seconds: 15), () {
            if (_isLoading && _statusMessage.startsWith("Sending generation request...")) {
              setState(() {
                _statusMessage = "Sending generation request... (Server is taking a long time to respond, you may continue waiting or cancel)";
              });
            }
          });
        }
      });
      
      // Send generation request
      developer.log('Starting music generation request, prompt: $prompt');
      final Stopwatch stopwatch = Stopwatch()..start();
      
      final response = await _apiService.generateMusic(prompt);
      
      stopwatch.stop();
      developer.log('Generation request completed in ${stopwatch.elapsed.inMilliseconds} ms');
      
      // Cancel timer
      requestTimer.cancel();
      
      // Log detailed response structure for debugging
      developer.log('Received generation response: $response');
      developer.log('Response structure - Type: ${response.runtimeType}, Keys: ${response.keys.toList()}');
      
      // Check if cancelled
      if (_isCancelled) {
        developer.log('Generation request cancelled');
        return;
      }
      
      // Get generated music ID
      final musicId = getMusicId(response);
      if (musicId != null) {
        _generatedMusicId = musicId;
        developer.log('Received music ID: $_generatedMusicId');
        
        // Poll for music generation status
        setState(() {
          _statusMessage = "Generation started, waiting for result... (ID: $_generatedMusicId)";
        });
        await _pollMusicStatus(_generatedMusicId!);
      } else {
        throw Exception('无法从响应中获取音乐ID');
      }
    } on TimeoutException catch (e) {
      // Check if cancelled
      if (_isCancelled) {
        developer.log('Generation request cancelled');
        return;
      }
      
      developer.log('Music generation request timed out: $e', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Request timed out: Server response time exceeded ${AppConfig.generateMusicTimeoutSeconds} seconds. The server might be busy or experiencing issues.';
        _statusMessage = "";
      });
      
      _showRetryDialog();
    } on SocketException catch (e) {
      if (_isCancelled) return;
      
      developer.log('Network connection error: $e', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: Unable to connect to API service. Error: ${e.message}';
        _statusMessage = "";
      });
      
      _showTryBackupDialog();
    } catch (e) {
      // Check if cancelled
      if (_isCancelled) {
        developer.log('Generation request cancelled');
        return;
      }
      
      developer.log('Error generating music: $e', error: e);
      
      // 检查是否是500错误
      if (e.toString().contains('500')) {
        developer.log('Detected 500 server error, checking API quota status');
        // 检查API额度状态，帮助诊断问题
        try {
          final quotaInfo = await _apiService.getApiLimits();
          
          int? remainingCredits;
          if (quotaInfo.containsKey('remaining_credits')) {
            remainingCredits = quotaInfo['remaining_credits'];
          } else if (quotaInfo.containsKey('credits') && quotaInfo['credits'] is Map) {
            remainingCredits = quotaInfo['credits']['remaining'];
          }
          
          if (remainingCredits != null && remainingCredits < 5) {
            // 积分不足，显示特定的错误信息
            setState(() {
              _isLoading = false;
              _errorMessage = 'Music generation failed: Insufficient credits (remaining: $remainingCredits). Each generation requires at least 5-10 credits.';
              _statusMessage = "";
            });
            return;
          } else {
            // 积分充足，可能是服务器临时问题
            setState(() {
              _isLoading = false;
              _errorMessage = 'Server error (500): The Suno API server encountered an internal error. This could be due to server load or temporary issues. Try again later.';
              _statusMessage = "";
            });
          }
        } catch (quotaError) {
          // 无法获取额度信息，回退到通用错误
          setState(() {
            _isLoading = false;
            _errorMessage = 'Server error (500): Could not determine cause. Check your network connection and Suno account status.';
            _statusMessage = "";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error generating music: ${e.toString()}';
          _statusMessage = "";
        });
      }
      
      // If specific error messages that suggest API server issues
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Cannot connect')) {
        _showTryBackupDialog();
      }
    }
  }
  
  // Show retry dialog
  void _showRetryDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Timeout'),
        content: const Text('Music generation request timed out. Do you want to retry or try using the backup API address?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateMusic();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _switchApiUrl();
              Future.delayed(Duration(seconds: 1), () {
                if (_isApiConnected) {
                  _generateMusic();
                }
              });
            },
            child: const Text('Use Backup Address'),
          ),
        ],
      ),
    );
  }

  // 轮询检查音乐生成状态
  Future<void> _pollMusicStatus(String id) async {
    bool isCompleted = false;
    int attempts = 0;
    final maxAttempts = AppConfig.maxPollAttempts;
    final pollInterval = Duration(seconds: AppConfig.pollStatusIntervalSeconds);
    final totalEstimatedTime = maxAttempts * pollInterval.inSeconds; // Total polling time in seconds
    
    developer.log('Starting music status polling, ID: $id, max attempts: $maxAttempts, polling interval: ${pollInterval.inSeconds} seconds');
    developer.log('Total maximum polling time: ${totalEstimatedTime ~/ 60} minutes ${totalEstimatedTime % 60} seconds');
    
    // Display ID in the UI for manual reference
    setState(() {
      _statusMessage = "Starting music generation. ID: $id (Total wait time up to ${totalEstimatedTime ~/ 60} min)";
    });
    
    // Async polling method that can be cancelled
    Future<void> pollOnce() async {
      if (_isCancelled || isCompleted || attempts >= maxAttempts) {
        return;
      }
      
      try {
        final int remainingAttempts = maxAttempts - attempts;
        final int remainingTimeSeconds = remainingAttempts * pollInterval.inSeconds;
        final int remainingMinutes = remainingTimeSeconds ~/ 60;
        final int remainingSeconds = remainingTimeSeconds % 60;
        
        developer.log('Polling attempt ${attempts + 1}/$maxAttempts (Remaining time: ~${remainingMinutes}m ${remainingSeconds}s)');
        setState(() {
          _statusMessage = "Generating... attempt ${attempts + 1}/$maxAttempts (Est. remaining: ${remainingMinutes}m ${remainingSeconds}s)";
        });
        
        final musicInfo = await _apiService.getMusicInfo(id);
        developer.log('Music status response: $musicInfo');
        developer.log('Response structure - Type: ${musicInfo.runtimeType}, Keys: ${musicInfo.keys.toList()}');
        
        if (_isCancelled) {
          return; // Check if cancelled during info retrieval
        }
        
        // Try different response formats to find the status
        Map<String, dynamic>? itemToUse;
        String statusMessage = "unknown";
        
        // Format 1: Response has 'items' array
        if (musicInfo.containsKey('items') && 
            musicInfo['items'] is List && 
            musicInfo['items'].isNotEmpty) {
          
          final item = musicInfo['items'][0];
          if (item is Map) {
            itemToUse = Map<String, dynamic>.from(item);
            statusMessage = item['status'] ?? "unknown";
          }
        } 
        // Format 2: Response is the item itself
        else if (musicInfo.containsKey('id') && musicInfo.containsKey('status')) {
          itemToUse = musicInfo;
          statusMessage = musicInfo['status'] ?? "unknown";
        }
        // Format 3: Response has a different structure
        else {
          developer.log('Unknown response format, raw response: $musicInfo');
          // Try to find any status field in the response
          String? status;
          if (musicInfo.containsKey('status')) {
            status = musicInfo['status'];
            statusMessage = status ?? "unknown";
          } else {
            // Look for status in any nested objects
            musicInfo.forEach((key, value) {
              if (value is Map && value.containsKey('status')) {
                status = value['status'];
                statusMessage = status ?? "unknown";
              }
            });
          }
          
          if (status != null) {
            itemToUse = {'id': id, 'status': status};
          }
        }
        
        // Log the status message
        developer.log('Current status: $statusMessage (Attempt ${attempts + 1}/$maxAttempts)');
        
        // Process the found item if any
        if (itemToUse != null) {
          final status = itemToUse['status'];
          developer.log('Current music status: $status');
          
          if (status == 'complete') {
            developer.log('Music generation completed!');
            isCompleted = true;
            
            // Create SunoMusic object from the item
            final sunoMusic = SunoMusic.fromJson(itemToUse);
            developer.log('Generated music information: title=${sunoMusic.title}, audioUrl=${sunoMusic.audioUrl}');
            
            setState(() {
              _generatedMusic = sunoMusic;
              _isLoading = false;
              _statusMessage = "Generation completed!";
            });
            
            // Auto-play the generated music
            if (sunoMusic.audioUrl.isNotEmpty) {
              developer.log('Starting music playback: ${sunoMusic.audioUrl}');
              await _playAudio(sunoMusic.audioUrl);
            } else {
              developer.log('Cannot play audio: audio URL is empty', error: 'Empty audio URL');
              setState(() {
                _errorMessage = 'Music generation completed, but no audio URL was provided';
              });
            }
          } else if (status == 'failed') {
            developer.log('Music generation failed', error: 'Status is failed');
            isCompleted = true;
            setState(() {
              _isLoading = false;
              _errorMessage = 'Music generation failed';
              _statusMessage = "Generation failed!";
            });
          } else {
            // Other status like 'processing' or 'submitted'
            developer.log('Music is being processed, status: $status');
            setState(() {
              _statusMessage = "AI is creating music, status: $status (Attempt ${attempts + 1}/$maxAttempts)";
            });
          }
        } else {
          developer.log('Could not find status information in the response');
          setState(() {
            _statusMessage = "Generating... (status unknown, attempt ${attempts + 1}/$maxAttempts)";
          });
        }
      } on TimeoutException catch (e) {
        developer.log('Music status polling timeout: $e', error: e);
        // Continue trying after timeout
        if (!_isCancelled && !isCompleted) {
          attempts++;
          _pollingTimer = Timer(pollInterval, pollOnce);
        }
        return;
      } on SocketException catch (e) {
        developer.log('Music status polling network error: $e', error: e);
        // Continue trying after network error
        if (!_isCancelled && !isCompleted) {
          attempts++;
          _pollingTimer = Timer(pollInterval, pollOnce);
        }
        return;
      } catch (e) {
        developer.log('Music status polling error: $e', error: e);
        developer.log('Error type: ${e.runtimeType}');
      }
      
      if (!isCompleted && !_isCancelled) {
        attempts++;
        developer.log('Waiting for ${pollInterval.inSeconds} seconds before checking status again...');
        // Use Timer instead of Future.delayed to allow cancellation
        _pollingTimer = Timer(pollInterval, () {
          if (!_isCancelled) {
            pollOnce();
          }
        });
      }
    }
    
    // Start first polling attempt
    await pollOnce();
    
    // If not completed but reached max attempts, and not cancelled
    if (!isCompleted && !_isCancelled && attempts >= maxAttempts) {
      developer.log('Music generation timed out', error: 'Reached max attempts');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Music generation timed out after ${maxAttempts * pollInterval.inSeconds} seconds';
        _statusMessage = "Generation timed out!";
      });
      
      // Music might still be generating in the background, show info
      _showTimeoutInfoDialog(id);
    }
  }
  
  // Show timeout info dialog
  void _showTimeoutInfoDialog(String id) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generation Taking Longer Than Expected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The music generation process is taking longer than the maximum waiting time of ${AppConfig.maxPollAttempts * AppConfig.pollStatusIntervalSeconds} seconds.'),
            const SizedBox(height: 12),
            const Text('This doesn\'t mean the generation has failed. Suno API might still be processing your request in the background.'),
            const SizedBox(height: 12),
            Text('Music ID: $id', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('You can either:'),
            const Text('• Check the status again now'),
            const Text('• Continue waiting and check later'),
            const Text('• Try generating a different music piece'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Check status again with current ID
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _statusMessage = "Checking status again...";
              });
              _pollMusicStatus(id);
            },
            child: const Text('Check Status Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Copy ID to clipboard
              _copyIdToClipboard(id);
            },
            child: const Text('Copy ID for Later'),
          ),
        ],
      ),
    );
  }
  
  // Copy ID to clipboard
  void _copyIdToClipboard(String id) {
    // Use Flutter's Clipboard API
    Clipboard.setData(ClipboardData(text: id)).then((_) {
      developer.log('ID copied to clipboard: $id');
      
      // Show confirmation to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Music ID copied: $id'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    });
  }

  // 播放音频
  Future<void> _playAudio(String url) async {
    try {
      developer.log('Setting audio URL: $url');
      await _audioPlayer.setUrl(url);
      developer.log('Starting audio playback');
      await _audioPlayer.play();
    } catch (e) {
      developer.log('Error playing audio: $e', error: e);
      setState(() {
        _errorMessage = 'Unable to play audio: $e';
      });
    }
  }

  // 检查API额度信息
  Future<void> _checkApiQuota() async {
    try {
      setState(() {
        _isLoadingCredits = true;
      });
      
      developer.log('Checking API quota information...');
      final quotaInfo = await _apiService.getApiLimits();
      developer.log('API quota information received: $quotaInfo');
      
      // 尝试从返回数据中提取关键信息
      int? remainingCredits;
      int? dailyLimit;
      
      // 处理不同可能的响应格式
      if (quotaInfo.containsKey('remaining_credits')) {
        remainingCredits = quotaInfo['remaining_credits'];
      } else if (quotaInfo.containsKey('credits') && quotaInfo['credits'] is Map) {
        remainingCredits = quotaInfo['credits']['remaining'];
        dailyLimit = quotaInfo['credits']['limit'];
      }
      
      // 更新状态
      setState(() {
        _remainingCredits = remainingCredits;
        _dailyLimit = dailyLimit;
        _isLoadingCredits = false;
        
        // 如果积分不足，显示警告
        if (remainingCredits != null && remainingCredits < 10) {
          _errorMessage = 'Warning: Low API credits remaining ($remainingCredits). Music generation may fail.';
        }
      });
      
      // 记录找到的信息
      if (remainingCredits != null) {
        developer.log('Remaining API credits: $remainingCredits');
        if (dailyLimit != null) {
          developer.log('Daily credit limit: $dailyLimit');
        }
      } else {
        developer.log('Could not determine remaining API credits from response: $quotaInfo');
      }
    } catch (e) {
      developer.log('Error checking API quota: $e', error: e);
      setState(() {
        _isLoadingCredits = false;
      });
      // 不在UI上显示这个错误，因为这只是诊断信息
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Music'),
        actions: [
          // 添加菜单按钮
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'switch_api') {
                _switchApiUrl();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'switch_api',
                child: Text('Switch API Address'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView( // 添加滚动支持
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // API连接状态
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isApiConnected ? 'Suno API connection successful' : 'Suno API connection failed',
                            style: TextStyle(
                              color: _isApiConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Current API: ${_usingBackupUrl ? 'backup address' : 'primary address'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          // 显示API积分信息
                          if (_remainingCredits != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.music_note,
                                  size: 12,
                                  color: _remainingCredits! < 10 ? Colors.red : Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Credits: $_remainingCredits${_dailyLimit != null ? ' / $_dailyLimit' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _remainingCredits! < 10 ? Colors.red : Colors.blue,
                                  ),
                                ),
                                if (_isLoadingCredits)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // 添加检查积分按钮
                        if (_isApiConnected) 
                          IconButton(
                            icon: const Icon(Icons.monetization_on, size: 20),
                            onPressed: _isLoadingCredits ? null : _checkApiQuota,
                            tooltip: 'Check Credits',
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _isLoading ? null : _testApiConnection,
                          tooltip: 'Test Connection',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // 提示词输入
              TextField(
                controller: _promptController,
                decoration: const InputDecoration(
                  labelText: 'Describe the music you want',
                  hintText: 'For example: A happy pop song with a cheerful rhythm and catchy melody',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: _isApiConnected && !_isLoading,
              ),
              
              const SizedBox(height: 16.0),
              
              // 生成/取消按钮
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? Row(
                        children: [
                          // 取消按钮
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _cancelGeneration,
                              icon: const Icon(Icons.cancel, color: Colors.white),
                              label: const Text('Cancel Generation'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ElevatedButton(
                        onPressed: (_isApiConnected && !_isLoading) ? _generateMusic : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: const Text('Generate Music'),
                      ),
              ),
              
              // 状态消息和进度指示器
              if (_isLoading) ...[
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              // 错误消息
              if (_errorMessage != null) ...[
                const SizedBox(height: 16.0),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24.0),
              
              // 生成结果
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
                        // 优化标题显示，处理可能的乱码和文本溢出
                        Text(
                          _safeText(_generatedMusic!.title, 'Untitled Music'),
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8.0),
                        // 优化提示词显示
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prompt:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                _safeText(_generatedMusic!.prompt, 'No prompt'),
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            const Text('ID: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Expanded(
                              child: Text(
                                _generatedMusic!.id,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14),
                              onPressed: () => _copyIdToClipboard(_generatedMusic!.id),
                              tooltip: 'Copy ID',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        const Text('Audio Controls:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play'),
                              onPressed: () => _playAudio(_generatedMusic!.audioUrl),
                            ),
                            const SizedBox(width: 8.0),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.pause),
                              label: const Text('Pause'),
                              onPressed: () => _audioPlayer.pause(),
                            ),
                            const SizedBox(width: 8.0),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                              onPressed: () => _audioPlayer.stop(),
                            ),
                          ],
                        ),
                        // 添加歌曲播放状态指示器
                        if (_isPlaying) ...[
                          const SizedBox(height: 16.0),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                              ),
                              SizedBox(width: 8.0),
                              Text('Playing audio...', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // 添加安全文本处理方法，处理可能的乱码和null值
  String _safeText(String? text, String defaultValue) {
    if (text == null || text.isEmpty) {
      return defaultValue;
    }
    
    try {
      // 过滤掉不可打印字符和控制字符
      final filteredText = text
          .replaceAll(RegExp(r'[\p{Cc}\p{Cf}\p{Co}\p{Cn}]', unicode: true), '')
          .trim();
          
      // 如果过滤后文本长度明显变短或为空，可能是乱码
      if (filteredText.isEmpty || filteredText.length < text.length / 2) {
        developer.log('Detected potentially corrupted text: $text');
        return defaultValue;
      }
      
      // 检查文本是否含有过多特殊字符
      if (filteredText.runes.where((rune) => 
        (rune < 32 || (rune > 126 && rune < 160)) && 
        rune != 10 && rune != 13).length > filteredText.length / 3) {
        developer.log('Text contains too many special characters: $text');
        return defaultValue;
      }
      
      return filteredText;
    } catch (e) {
      developer.log('Error processing text: $e', error: e);
      return defaultValue;
    }
  }

  String? getMusicId(dynamic response) {
    if (response is List && response.isNotEmpty) {
      // 如果是列表，取第一个元素
      final firstItem = response[0];
      if (firstItem is Map && firstItem.containsKey('id')) {
        return firstItem['id'].toString();
      }
    } else if (response is Map && response.containsKey('id')) {
      // 如果直接是Map对象
      return response['id'].toString();
    }
    
    // 找不到ID
    return null;
  }
} 