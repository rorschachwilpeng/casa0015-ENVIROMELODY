import 'package:flutter/material.dart';
import '../services/deepseek_api_service.dart';
import '../utils/config.dart';

// 这个函数可以在 main.dart 中临时调用来测试 API
Future<void> testDeepSeekApi(BuildContext context) async {
  // 显示加载对话框
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text("正在测试 DeepSeek API...")
        ],
      ),
    ),
  );

  // 初始化服务
  final apiService = DeepSeekApiService(
    apiKey: "sk-fe8c07ad4d344b65856bb0fe6beed2ac",
  );
  
  try {
    // 测试连接
    final connectionSuccess = await apiService.testConnection();
    
    // 如果连接成功，尝试简单的聊天完成
    String? chatResult;
    if (connectionSuccess) {
      chatResult = await apiService.simpleChatCompletion(
        "请生成一个描述雨天的音乐场景的提示词，100字左右。"
      );
    }
    
    // 关闭加载对话框
    Navigator.pop(context);
    
    // 显示结果
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(connectionSuccess ? "API 测试成功" : "API 测试失败"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("连接测试: ${connectionSuccess ? '成功' : '失败'}"),
              if (chatResult != null) ...[
                const SizedBox(height: 16),
                const Text("聊天完成测试结果:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(chatResult),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("确定"),
          ),
        ],
      ),
    );
  } catch (e) {
    // 关闭加载对话框
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // 显示错误
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("测试失败"),
        content: Text("发生错误: $e"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }
} 