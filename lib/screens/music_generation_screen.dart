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
  
  // 更新状态信息显示
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

  // 测试API连接
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
        _errorMessage = '无法连接到API: $e';
      });
    }
  }

  // 生成音乐
  Future<void> _generateMusic() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _errorMessage = '请输入提示词';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedMusic = null;
      _statusMessage = '正在发送生成请求...';
    });

    try {
      // 发送生成请求
      _logger.i('发送音乐生成请求: $prompt');
      
      final response = await _apiService.generateMusic(prompt);
      _logger.i('生成响应: $response');
      
      // 检查响应类型并正确处理
      String? musicId;
      
      if (response is List && response.isNotEmpty) {
        // 处理列表类型响应 - API返回了数组
        final firstItem = response[0];
        if (firstItem is Map && firstItem.containsKey('id')) {
          musicId = firstItem['id'].toString();
        }
      } else if (response is Map && response.containsKey('id')) {
        // 处理对象类型响应
        musicId = response['id'].toString();
      }
      
      if (musicId != null) {
        _generatedMusicId = musicId;
        setState(() {
          _statusMessage = '请求已提交，ID: $_generatedMusicId，正在等待处理...';
        });
        
        await _pollMusicStatus(_generatedMusicId!);
      } else {
        throw Exception('无法从响应中获取音乐ID');
      }
    } catch (e) {
      _logger.e('生成音乐失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '生成音乐失败: $e';
        _statusMessage = '';
      });
    }
  }

  // 轮询检查音乐生成状态
  Future<void> _pollMusicStatus(String id) async {
    int attempts = 0;
    const maxAttempts = 60;
    
    _logger.i('开始轮询音乐状态: ID=$id');
    
    while (attempts < maxAttempts) {
      try {
        attempts++;
        setState(() {
          _pollAttempt = attempts;
          _statusMessage = '检查状态，尝试 $_pollAttempt/$maxAttempts...';
        });
        
        final response = await _apiService.getMusicInfo(id);
        _logger.i('状态响应: $response');
        
        // 提取状态
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
        
        _logger.i('音乐状态: $status');
        
        if (status == 'complete') {
          _logger.i('音乐生成完成!');
          
          if (musicData != null) {
            final sunoMusic = SunoMusic.fromJson(musicData);
            setState(() {
              _generatedMusic = sunoMusic;
              _isLoading = false;
              _statusMessage = '音乐生成完成!';
            });
            
            if (sunoMusic.audioUrl.isNotEmpty) {
              await _playAudio(sunoMusic.audioUrl);
            }
            return;
          }
        } else if (status == 'failed') {
          _logger.e('音乐生成失败');
          setState(() {
            _isLoading = false;
            _errorMessage = '音乐生成失败';
            _statusMessage = '';
          });
          return;
        }
        
        // 继续轮询
        await Future.delayed(const Duration(seconds: 3));
      } catch (e) {
        _logger.e('轮询错误: $e');
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    
    // 超时
    _logger.w('轮询超时');
    setState(() {
      _isLoading = false;
      _errorMessage = '生成超时，ID: $_generatedMusicId';
      _statusMessage = '';
    });
    
    _showTimeoutDialog();
  }
  
  // 显示超时对话框
  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('生成时间超出预期'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('音乐生成正在进行，但需要更长时间。这并不意味着失败，AI生成高质量音乐通常需要几分钟。'),
              const SizedBox(height: 8),
              Text('音乐ID: $_generatedMusicId', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('您可以选择再次检查状态，或稍后再试。'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('关闭'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('复制ID'),
              onPressed: () {
                // 需要导入 import 'package:flutter/services.dart';
                Clipboard.setData(ClipboardData(text: _generatedMusicId ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID已复制到剪贴板')),
                );
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('再次检查状态'),
              onPressed: () {
                Navigator.of(context).pop();
                if (_generatedMusicId != null) {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                    _statusMessage = '正在重新检查状态...';
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

  // 播放音频
  Future<void> _playAudio(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      _logger.e('播放音频时出错: $e');
      setState(() {
        _errorMessage = '无法播放音频: $e';
      });
    }
  }

  Future<void> _testDirectApiCall() async {
    setState(() {
      _statusMessage = '正在进行直接API测试...';
      _isLoading = true;
    });
    
    try {
      final client = http.Client();
      final url = 'http://localhost:3000/api/generate'; // 或者使用127.0.0.1
      
      _logger.i('直接发送POST请求到: $url');
      
      final response = await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'prompt': '测试生成简短的音乐片段'}),
      ).timeout(const Duration(seconds: 30));
      
      _logger.i('直接测试响应状态码: ${response.statusCode}');
      _logger.i('直接测试响应内容: ${response.body}');
      
      setState(() {
        _statusMessage = '直接API测试完成: ${response.statusCode}';
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('直接API测试失败: $e');
      setState(() {
        _errorMessage = '直接API测试失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI音乐生成'),
      ),
      body: Padding(
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
                  Text(
                    _isApiConnected ? 'API连接正常' : 'API连接失败',
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
            
            // 提示词输入
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: '输入提示词',
                hintText: '例如: 一首轻松愉快的流行歌曲，带有欢快的节奏和朗朗上口的旋律',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: _isApiConnected && !_isLoading,
            ),
            
            const SizedBox(height: 16.0),
            
            // 生成按钮
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
                          Text('生成中...'),
                        ],
                      )
                    : const Text('生成音乐'),
              ),
            ),
            
            // 错误消息
            if (_errorMessage != null) ...[
              const SizedBox(height: 16.0),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            
            const SizedBox(height: 24.0),
            
            // 状态信息显示
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
                      Text('音乐ID: $_generatedMusicId'),
                    ],
                  ],
                ),
              ),
            ],
            
            // 生成结果
            if (_generatedMusic != null) ...[
              Text(
                '生成的音乐:',
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
                      Text('提示词: ${_generatedMusic!.prompt}'),
                      const SizedBox(height: 16.0),
                      const Text('播放控制:'),
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
            
            // 直接测试按钮
            ElevatedButton(
              onPressed: _testDirectApiCall,
              child: Text('直接测试API'),
            ),
          ],
        ),
      ),
    );
  }
} 