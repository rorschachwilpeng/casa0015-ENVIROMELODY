class AppConfig {
  // Suno API configuration 
  // Local API service
  static const String sunoApiBaseUrl = 'http://localhost:3000/api';
  
  // Backup API endpoint - also using local service on different port
  static const String sunoApiBaseUrlBackup = 'http://127.0.0.1:3000/api';
  
  // Vercel deployed API (commented out, available if needed)
  // static const String sunoApiVercelUrl = 'https://suno-ce3n3w68c-rorschachwilpengs-projects.vercel.app/api';
  
  // API request settings
  static const int apiRequestTimeoutSeconds = 30;  // Local server responds faster, can reduce timeout
  
  // Music generation request timeout settings
  static const int generateMusicTimeoutSeconds = 300;  // Increased to 5 minutes
  static const int pollStatusIntervalSeconds = 3;     // Reduced polling interval
  static const int maxPollAttempts = 60;            // 60 attempts (maximum 3 minutes total waiting time)
  
  // Stability AI configuration
  static const String stabilityApiKey = "sk-hzdHSi39PEEm3eaR0TrKqeeXf2Nu6grJhrLCbdwIu28jCXP2"; // 您的API密钥
  static const int defaultGenerationSteps = 30;
  static const int defaultAudioDurationSeconds = 20;
  static const String defaultAudioFormat = "mp3";
  
  // Other configs...
  
  // 辅助方法：验证API密钥
  static bool isStabilityApiKeyValid() {
    return stabilityApiKey.isNotEmpty && 
           stabilityApiKey.startsWith("sk-") && 
           stabilityApiKey.length > 20;
  }
  
  // 辅助方法：获取API密钥状态信息
  static String getStabilityApiKeyStatus() {
    if (stabilityApiKey.isEmpty) {
      return "API密钥为空";
    } else if (!stabilityApiKey.startsWith("sk-")) {
      return "API密钥格式不正确，应以'sk-'开头";
    } else if (stabilityApiKey.length < 20) {
      return "API密钥长度不足，可能不是有效密钥";
    } else {
      return "API密钥格式有效，长度: ${stabilityApiKey.length}";
    }
  }
  
  // Stability AI API基础URL
  static const String stabilityApiBaseUrl = "https://api.stability.ai";
  static const String stabilityAudioEndpoint = "/v2beta/audio/generations";
  
  // 获取完整的API URL
  static String getStabilityAudioUrl() {
    return "$stabilityApiBaseUrl$stabilityAudioEndpoint";
  }
  
  // 诊断信息：显示所有配置的概要
  static Map<String, dynamic> getDiagnosticInfo() {
    return {
      "stabilityApiKeyValid": isStabilityApiKeyValid(),
      "stabilityApiKeyStatus": getStabilityApiKeyStatus(),
      "stabilityApiKeyLength": stabilityApiKey.length,
      "stabilityApiKeyPrefix": stabilityApiKey.isNotEmpty ? 
          stabilityApiKey.substring(0, stabilityApiKey.length > 5 ? 5 : stabilityApiKey.length) : "",
      "stabilityApiUrl": getStabilityAudioUrl(),
      "timeoutSettings": {
        "apiRequestTimeoutSeconds": apiRequestTimeoutSeconds,
        "generateMusicTimeoutSeconds": generateMusicTimeoutSeconds,
        "pollStatusIntervalSeconds": pollStatusIntervalSeconds,
        "maxPollAttempts": maxPollAttempts,
      },
      "generationDefaults": {
        "steps": defaultGenerationSteps,
        "durationSeconds": defaultAudioDurationSeconds,
        "format": defaultAudioFormat,
      }
    };
  }
} 
