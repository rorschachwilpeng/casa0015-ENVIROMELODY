class AppConfig {
  // Suno API configuration 
  // 本地API服务
  static const String sunoApiBaseUrl = 'http://localhost:3000/api';
  
  // 备用API端点 - 也使用本地服务的不同端口
  static const String sunoApiBaseUrlBackup = 'http://127.0.0.1:3000/api';
  
  // Vercel部署API（注释掉，以备需要时使用）
  // static const String sunoApiVercelUrl = 'https://suno-ce3n3w68c-rorschachwilpengs-projects.vercel.app/api';
  
  // API request settings
  static const int apiRequestTimeoutSeconds = 30;  // 本地服务器响应更快，可以减少超时时间
  
  // Music generation request timeout settings
  static const int generateMusicTimeoutSeconds = 300;  // 增加到5分钟
  static const int pollStatusIntervalSeconds = 3;     // 减少轮询间隔
  static const int maxPollAttempts = 60;            // 60次尝试(最多3分钟总等待时间)
  
  // Other configs...
} 