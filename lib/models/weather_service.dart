import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// 天气服务类 - 负责与OpenWeather API通信获取天气数据
class WeatherService {
  // 单例模式
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();
  
  // OpenWeather API密钥 - 这里需要替换为您的实际API密钥
  final String _apiKey = '9a5b95af3b09cae239fea38a996a8094';
  
  // API基础URL
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  final String _geoUrl = 'http://api.openweathermap.org/geo/1.0';
  
  /// 根据经纬度获取天气数据
  Future<WeatherData?> getWeatherByLocation(double latitude, double longitude) async {
    try {
      // 构建API请求URL - 使用metric单位制（摄氏度）
      final url = '$_baseUrl/weather?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';
      
      developer.log('获取天气数据: $url', name: 'WeatherService');
      
      // 发送请求并等待响应
      final response = await http.get(Uri.parse(url));
      
      // 检查响应状态
      if (response.statusCode == 200) {
        // 解析JSON响应
        final data = json.decode(response.body);
        final locationData = await getLocationInfo(latitude, longitude);
        
        return WeatherData.fromJson(data, locationData);
      } else {
        // 处理错误响应
        developer.log(
          'OpenWeather API 错误: ${response.statusCode}',
          name: 'WeatherService',
          error: response.body
        );
        return null;
      }
    } catch (e) {
      // 捕获并记录任何异常
      developer.log(
        '获取天气数据出错',
        name: 'WeatherService',
        error: e.toString()
      );
      return null;
    }
  }
  
  /// 获取指定坐标的地理位置信息 (反向地理编码)
  Future<LocationData?> getLocationInfo(double latitude, double longitude) async {
    try {
      // OpenWeather Geocoding API
      final url = '$_geoUrl/reverse?lat=$latitude&lon=$longitude&limit=1&appid=$_apiKey';
      
      developer.log('获取位置信息: $url', name: 'WeatherService');
      
      // 发送请求并等待响应
      final response = await http.get(Uri.parse(url));
      
      // 检查响应状态
      if (response.statusCode == 200) {
        // 解析JSON响应
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LocationData.fromJson(data[0]);
        }
        return null;
      } else {
        // 处理错误响应
        developer.log(
          'OpenWeather Geocoding API 错误: ${response.statusCode}',
          name: 'WeatherService',
          error: response.body
        );
        return null;
      }
    } catch (e) {
      // 捕获并记录任何异常
      developer.log(
        '获取位置信息出错',
        name: 'WeatherService',
        error: e.toString()
      );
      return null;
    }
  }
  
  /// 获取天气图标URL
  String getWeatherIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }
  
  /// 根据经纬度获取5天天气预报
  Future<List<ForecastData>?> getForecastByLocation(double latitude, double longitude) async {
    try {
      // 构建API请求URL
      final url = '$_baseUrl/forecast?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';
      
      developer.log('获取天气预报: $url', name: 'WeatherService');
      
      // 发送请求并等待响应
      final response = await http.get(Uri.parse(url));
      
      // 检查响应状态
      if (response.statusCode == 200) {
        // 解析JSON响应
        final data = json.decode(response.body);
        
        if (data['list'] != null && data['list'] is List) {
          final List<dynamic> forecastList = data['list'];
          return forecastList.map((item) => ForecastData.fromJson(item)).toList();
        }
        
        return [];
      } else {
        // 处理错误响应
        developer.log(
          'OpenWeather Forecast API 错误: ${response.statusCode}',
          name: 'WeatherService',
          error: response.body
        );
        return null;
      }
    } catch (e) {
      // 捕获并记录任何异常
      developer.log(
        '获取天气预报出错',
        name: 'WeatherService',
        error: e.toString()
      );
      return null;
    }
  }
}

/// 天气数据模型
class WeatherData {
  final String cityName;       // 城市名称
  final String countryCode;    // 国家代码
  final double temperature;    // 温度 (摄氏度)
  final double feelsLike;      // 体感温度
  final double tempMin;        // 最低温度
  final double tempMax;        // 最高温度
  final int humidity;          // 湿度 (%)
  final double windSpeed;      // 风速 (米/秒)
  final int windDegree;        // 风向 (度)
  final double? windGust;      // 阵风速度 (米/秒，可能为空)
  final int pressure;          // 气压 (百帕)
  final String weatherMain;    // 天气主要状况 (例如: Rain, Snow, Clear)
  final String weatherDescription; // 天气详细描述
  final String weatherIcon;    // 天气图标代码
  final int cloudsPercent;     // 云量 (%)
  final int visibility;        // 能见度 (米)
  final DateTime sunrise;      // 日出时间
  final DateTime sunset;       // 日落时间
  final DateTime timestamp;    // 数据获取时间戳
  final int timezone;          // 时区偏移 (秒)
  
  // 位置信息
  final LocationData? location;
  
  WeatherData({
    required this.cityName,
    required this.countryCode,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.windDegree,
    this.windGust,
    required this.pressure,
    required this.weatherMain,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.cloudsPercent,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.timestamp,
    required this.timezone,
    this.location,
  });
  
  /// 从OpenWeather API JSON响应创建WeatherData对象
  factory WeatherData.fromJson(Map<String, dynamic> json, [LocationData? locationData]) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];
    final clouds = json['clouds'];
    final sys = json['sys'];
    
    return WeatherData(
      cityName: json['name'] ?? 'Unknown',
      countryCode: sys['country'] ?? '',
      temperature: (main['temp'] ?? 0).toDouble(),
      feelsLike: (main['feels_like'] ?? 0).toDouble(),
      tempMin: (main['temp_min'] ?? 0).toDouble(),
      tempMax: (main['temp_max'] ?? 0).toDouble(),
      humidity: main['humidity'] ?? 0,
      windSpeed: (wind['speed'] ?? 0).toDouble(),
      windDegree: wind['deg'] ?? 0,
      windGust: wind['gust'] != null ? (wind['gust']).toDouble() : null,
      pressure: main['pressure'] ?? 0,
      weatherMain: weather['main'] ?? '',
      weatherDescription: weather['description'] ?? '',
      weatherIcon: weather['icon'] ?? '',
      cloudsPercent: clouds['all'] ?? 0,
      visibility: json['visibility'] ?? 0,
      sunrise: DateTime.fromMillisecondsSinceEpoch((sys['sunrise'] ?? 0) * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch((sys['sunset'] ?? 0) * 1000),
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['dt'] ?? 0) * 1000),
      timezone: json['timezone'] ?? 0,
      location: locationData,
    );
  }
  
  /// 获取天气时段 (早晨、中午、傍晚、夜晚)
  String getDayPeriod() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'midday';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
  }
  
  /// 获取天气状况描述 (用于UI显示)
  String getWeatherCondition() {
    return weatherDescription;
  }
  
  /// 将温度映射到情感描述
  List<String> getTemperatureMood() {
    if (temperature >= 30) {
      return ['hot', 'energetic'];
    } else if (temperature >= 20) {
      return ['warm', 'cheerful'];
    } else if (temperature >= 10) {
      return ['cool', 'calm'];
    } else if (temperature >= 0) {
      return ['cold', 'melancholic'];
    } else {
      return ['freezing', 'contemplative'];
    }
  }
  
  /// 将天气状况映射到情感描述
  List<String> getWeatherMood() {
    final condition = weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return ['bright', 'cheerful'];
    } else if (condition.contains('cloud')) {
      return ['changing', 'thoughtful'];
    } else if (condition.contains('rain')) {
      return ['melancholic', 'introspective'];
    } else if (condition.contains('snow')) {
      return ['pure', 'quiet'];
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return ['mysterious', 'vague'];
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return ['restless', 'dynamic'];
    } else {
      return ['neutral', 'balanced'];
    }
  }
  
  /// 构建音乐生成用的Prompt
  String buildMusicPrompt() {
    final dayPeriod = getDayPeriod();
    final temperatureMoods = getTemperatureMood();
    final weatherMoods = getWeatherMood();
    final locationName = location?.getFormattedLocation() ?? cityName;
    
    return '''
A $dayPeriod photo taken at $locationName.
The weather is $weatherDescription and $temperature degrees. The date is ${timestamp.year}-${timestamp.month}-${timestamp.day}.
The mood is ${temperatureMoods[0]} and ${weatherMoods[0]}.
''';
  }
  
  /// 获取天气图标URL
  String getIconUrl() {
    return 'https://openweathermap.org/img/wn/$weatherIcon@2x.png';
  }
}

/// 天气预报数据模型
class ForecastData {
  final DateTime timestamp;    // 预报时间
  final double temperature;    // 温度 (摄氏度)
  final double feelsLike;      // 体感温度
  final double tempMin;        // 最低温度
  final double tempMax;        // 最高温度
  final int humidity;          // 湿度 (%)
  final double windSpeed;      // 风速 (米/秒)
  final int windDegree;        // 风向 (度)
  final String weatherMain;    // 天气主要状况
  final String weatherDescription; // 天气详细描述
  final String weatherIcon;    // 天气图标代码
  final int cloudsPercent;     // 云量 (%)
  final int visibility;        // 能见度 (米)
  final double pop;            // 降水概率 (0-1)
  
  ForecastData({
    required this.timestamp,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.windDegree,
    required this.weatherMain,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.cloudsPercent,
    required this.visibility,
    required this.pop,
  });
  
  /// 从OpenWeather API JSON响应创建ForecastData对象
  factory ForecastData.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];
    final clouds = json['clouds'];
    
    return ForecastData(
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['dt'] ?? 0) * 1000),
      temperature: (main['temp'] ?? 0).toDouble(),
      feelsLike: (main['feels_like'] ?? 0).toDouble(),
      tempMin: (main['temp_min'] ?? 0).toDouble(),
      tempMax: (main['temp_max'] ?? 0).toDouble(),
      humidity: main['humidity'] ?? 0,
      windSpeed: (wind['speed'] ?? 0).toDouble(),
      windDegree: wind['deg'] ?? 0,
      weatherMain: weather['main'] ?? '',
      weatherDescription: weather['description'] ?? '',
      weatherIcon: weather['icon'] ?? '',
      cloudsPercent: clouds['all'] ?? 0,
      visibility: json['visibility'] ?? 0,
      pop: (json['pop'] ?? 0).toDouble(),
    );
  }
  
  /// 获取天气图标URL
  String getIconUrl() {
    return 'https://openweathermap.org/img/wn/$weatherIcon@2x.png';
  }
  
  /// 获取格式化的时间字符串 (HH:MM)
  String getFormattedTime() {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

/// 位置数据模型 (用于反向地理编码)
class LocationData {
  final String name;           // 城市名称
  final String country;        // 国家代码
  final String state;          // 州/省
  final Map<String, String>? localNames; // 不同语言的名称
  final double latitude;       // 纬度
  final double longitude;      // 经度
  
  LocationData({
    required this.name,
    required this.country,
    required this.state,
    this.localNames,
    required this.latitude,
    required this.longitude,
  });
  
  /// 从OpenWeather Geocoding API响应创建LocationData对象
  factory LocationData.fromJson(Map<String, dynamic> json) {
    // 处理localNames字段，将其转换为Map<String, String>
    Map<String, String>? localNames;
    if (json['local_names'] != null) {
      localNames = {};
      (json['local_names'] as Map<String, dynamic>).forEach((key, value) {
        if (value is String) {
          localNames![key] = value;
        }
      });
    }
    
    return LocationData(
      name: json['name'] ?? 'Unknown',
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      localNames: localNames,
      latitude: (json['lat'] ?? 0).toDouble(),
      longitude: (json['lon'] ?? 0).toDouble(),
    );
  }
  
  /// 获取格式化的位置字符串
  String getFormattedLocation() {
    if (state.isNotEmpty) {
      return '$name, $state';
    }
    return '$name, $country';
  }
  
  /// 获取指定语言的地名 (如果有)
  String? getLocalName(String languageCode) {
    return localNames?[languageCode];
  }
  
  /// 获取中文地名 (如果有)
  String? getChineseName() {
    return getLocalName('zh');
  }
  
  /// 转换为LatLng对象 (用于地图)
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}