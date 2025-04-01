import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../utils/config.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:async';
import 'dart:developer';

class SunoApiService {
  final http.Client _client = http.Client();
  final Logger _logger = Logger();
  
  final String baseUrl;
  
  SunoApiService({String? baseUrl}) 
      : baseUrl = baseUrl ?? AppConfig.sunoApiBaseUrl {
    _logger.i('SunoAPI: 初始化，基础URL: ${this.baseUrl}');
  }
  
  // 测试API连接 - 对baseUrl直接测试
  Future<bool> testConnection() async {
    _logger.i('测试API连接: $baseUrl');
    
    try {
      // 尝试API提供的健康检查端点
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/get_limit'  // 如果baseUrl已包含/api
          : '$baseUrl/api/get_limit';  // 如果baseUrl不包含/api
          
      _logger.i('测试URL: $url');
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      _logger.i('API测试响应: ${response.statusCode}');
      
      // 只有200状态码才返回true
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('API连接测试失败: $e');
      return false;
    }
  }
  
  // 获取API配额信息
  Future<dynamic> getApiLimits() async {
    _logger.i('获取API配额信息');
    
    try {
      // 直接使用baseUrl，添加get_limit但不重复/api
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/get_limit'  // 如果baseUrl已经包含/api
          : '$baseUrl/api/get_limit';  // 如果baseUrl不包含/api
          
      _logger.i('获取配额URL: $url');
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: AppConfig.apiRequestTimeoutSeconds));
      
      _logger.i('配额响应: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('获取配额失败: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('获取配额失败: $e');
      throw e;
    }
  }
  
  // 生成音乐
  Future<dynamic> generateMusic(String prompt) async {
    _logger.i('生成音乐请求: $prompt');
    
    try {
      // 构建正确的URL，避免重复/api
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/generate'  // 如果baseUrl已经包含/api
          : '$baseUrl/api/generate';  // 如果baseUrl不包含/api
          
      _logger.i('生成音乐URL: $url');
      
      final requestBody = {'prompt': prompt};
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: AppConfig.generateMusicTimeoutSeconds));
      
      _logger.i('生成响应: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('生成音乐失败: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('生成音乐失败: $e');
      throw e;
    }
  }
  
  // 获取音乐信息
  Future<dynamic> getMusicInfo(String id) async {
    _logger.i('获取音乐信息: ID=$id');
    
    try {
      // 构建正确的URL，避免重复/api
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/get?ids=$id'  // 如果baseUrl已经包含/api
          : '$baseUrl/api/get?ids=$id';  // 如果baseUrl不包含/api
          
      _logger.i('获取音乐信息URL: $url');
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: AppConfig.apiRequestTimeoutSeconds));
      
      _logger.i('获取信息响应: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('获取音乐信息失败: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('获取音乐信息失败: $e');
      throw e;
    }
  }
  
  void dispose() {
    _client.close();
  }
} 