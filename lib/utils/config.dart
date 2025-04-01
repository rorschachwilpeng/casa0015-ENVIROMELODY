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
  
  // Other configs...
} 