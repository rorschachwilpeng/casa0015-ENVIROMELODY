import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/flutter_map_service.dart';
import '../models/weather_service.dart'; // 引入天气服务

// 定义 FlagInfo 类（放在文件顶部，所有类外部）
class FlagInfo {
  final LatLng position;
  final WeatherData? weatherData;
  final DateTime createdAt;
  final String? musicTitle; // 如果生成了音乐，存储音乐标题
  
  FlagInfo({
    required this.position,
    this.weatherData,
    required this.createdAt,
    this.musicTitle,
  });
}

// 在文件顶部定义一个类来管理地图状态
class MapState {
  LatLng center;
  double zoom;
  bool isReady = false;
  
  MapState({
    required this.center,
    required this.zoom,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Flutter Map Service
  final FlutterMapService _mapService = FlutterMapService();
  
  // 天气服务
  final WeatherService _weatherService = WeatherService();
  
  // Map Controller
  MapController _mapController = MapController();
  
  // State Variables
  bool _isMapReady = false;
  bool _isLoadingLocation = false;
  bool _isLoadingWeather = false; // 新增：天气数据加载状态
  bool _isPlacingFlag = false; // 是否正在放置红旗
  
  // Music Markers List
  final List<String> _musicMarkers = [];
  
  // 选中的位置和天气数据
  LatLng? _selectedLocation;
  WeatherData? _weatherData;
  
  // Define a constant for the country zoom level
  static const double COUNTRY_ZOOM_LEVEL = 6.0; // Country zoom level
  
  // 跟踪上次点击的时间和位置
  DateTime? _lastTapTime;
  LatLng? _lastTapPosition;
  static const _doubleTapThreshold = Duration(milliseconds: 300); // 双击阈值
  
  // 在_HomeScreenState类中添加
  final List<String> _weatherMarkerIds = [];
  
  // FlagInfo 存储映射 - 保留，但删除类定义
  final Map<String, FlagInfo> _flagInfoMap = {};
  
  // 添加一个静态变量，用于控制是否是首次加载
  static bool _isFirstLoad = true;
  
  // 在 _HomeScreenState 类中添加这些变量
  LatLng? _mapCenterPosition;
  double? _mapZoomLevel = COUNTRY_ZOOM_LEVEL;
  
  // 使用这个状态对象
  late MapState _mapState;
  
  // 在类中添加
  LatLng _currentCenter = LatLng(51.5074, -0.1278); // 伦敦默认位置
  double _currentZoom = 6.0;
  
  // 在 _HomeScreenState 类中添加这些变量，用于保存上一次的地图状态
  LatLng _lastMapCenter = LatLng(51.5074, -0.1278); // 伦敦默认位置
  double _lastMapZoom = 6.0; // 默认缩放级别
  bool _hasInitializedOnce = false; // 用于跟踪是否已经初始化过
  
  @override
  void initState() {
    super.initState();
    // 添加页面生命周期观察者
    WidgetsBinding.instance.addObserver(this);
    
    // 初始化地图状态
    _mapState = MapState(
      center: _mapService.getDefaultLocation(),
      zoom: COUNTRY_ZOOM_LEVEL,
    );
    
    _initMapService();
    
    // 异步初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationService();
      _loadPersistentFlags();
    });
    
    // 监听地图缩放和移动事件
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove) {
        // 更新缩放级别
        _mapService.updateZoom(event.zoom);
        // 更新我们自己的状态变量
        _updateMapState();
      }
    });
    
    // 设置缩放变化回调，在缩放变化时触发界面重绘
    _mapService.setZoomChangedCallback((zoom) {
      if (mounted) {
        setState(() {
          // 空的setState，仅用于触发界面重绘，使所有标记根据新的缩放级别更新大小
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 可以在这里重新检查状态并初始化
    if (!_isMapReady && _mapController != null) {
      _onMapReady();
    }
  }
  
  // 监听页面状态变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 当应用从后台恢复时
      if (_hasInitializedOnce) {
        // 如果之前已经初始化过，仅重新创建控制器但不移动到当前位置
        _mapController = MapController();
        _initMapService();
        
        // 在下一帧绘制完成后，恢复到上一次的地图位置和缩放级别
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isMapReady) {
            try {
              _mapController.move(_lastMapCenter, _lastMapZoom);
            } catch (e) {
              print('恢复地图位置时出错: $e');
            }
          }
        });
      } else {
        // 如果是第一次初始化，允许定位到当前位置
        _mapController = MapController();
        _initMapService();
        _hasInitializedOnce = true;
      }
    } else if (state == AppLifecycleState.paused) {
      // 当应用进入后台时，保存当前地图状态
      try {
        _lastMapCenter = _mapController.center;
        _lastMapZoom = _mapController.zoom;
      } catch (e) {
        print('保存地图位置时出错: $e');
      }
    }
  }
  
  void _initMapService() {
    // 只有在第一次初始化时才自动移动到当前位置
    _mapService.initMap(_mapController, autoMoveToCurrentLocation: !_hasInitializedOnce);
  }
  
  Future<void> _initLocationService() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });
      
      await _mapService.getCurrentLocation();
      
      if (_isMapReady) {
        await _mapService.moveToCurrentLocation();
      }
    } catch (e) {
      print("📍 Location error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    // 添加这行代码，确保在销毁时清除所有标记
    _mapService.clearMarkers();
    WidgetsBinding.instance.removeObserver(this);
    _mapService.dispose();
    super.dispose();
  }
  
  // When the map is ready
  void _onMapReady() {
    print("DEBUG: The map is ready");
    setState(() {
      _mapState.isReady = true;
      _isMapReady = true;
    });
    
    // 仅在首次加载并且 _hasInitializedOnce 为 false 时自动定位
    if (_isFirstLoad && !_hasInitializedOnce) {
      _goToCurrentLocation();
      _isFirstLoad = false;
      _hasInitializedOnce = true;
    } else {
      // 如果不是首次加载，恢复到上一次保存的位置
      try {
        _mapController.move(_lastMapCenter, _lastMapZoom);
      } catch (e) {
        print('恢复地图位置时出错: $e');
      }
    }
  }
  
  // Go to current location
  Future<void> _goToCurrentLocation() async {
    if (!_isMapReady || _mapController == null) return;
    
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      await _mapService.moveToCurrentLocation();
    } catch (e) {
      print('Error moving to current location: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot access your location')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }
  
  // 获取点击位置的天气数据
  Future<void> _getWeatherForLocation(LatLng location, String flagId) async {
    if (!_isMapReady) return;
    
    setState(() {
      _isLoadingWeather = true;
      _selectedLocation = location;
    });
    
    try {
      // 获取天气数据
      final weatherData = await _weatherService.getWeatherByLocation(
        location.latitude, 
        location.longitude
      );
      
      if (mounted) {
        setState(() {
          _weatherData = weatherData;
          
          // 创建红旗信息
          FlagInfo flagInfo = FlagInfo(
            position: location,
            weatherData: weatherData,
            createdAt: DateTime.now(),
          );
          
          // 保存到本地状态
          _flagInfoMap[flagId] = flagInfo;
          
          // 同时保存到持久服务中
          if (flagId.isNotEmpty) {
            _mapService.saveFlagInfo(flagId, flagInfo);
          }
        });
      }
    } catch (e) {
      print('Error getting weather data: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取天气数据失败')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  // 修改 _updateFlagMarkerTapEvent 方法
  void _updateFlagMarkerTapEvent(String flagId, WeatherData weatherData) {
    // 这个方法需要修改 FlutterMapService 来支持
    // 如果 FlutterMapService 不支持更新已有标记的事件
    // 可以考虑移除并重新添加标记
    
    // 从 LocationData 转换为 LatLng
    LatLng latLng = LatLng(
      weatherData.location!.latitude,  // 根据实际 LocationData 结构调整
      weatherData.location!.longitude  // 根据实际 LocationData 结构调整
    );
    
    // 尝试多种匹配方式
    int removedCount = 0;
    
    // 1. 使用精确匹配
    _mapService.removeMarker(flagId);
    
    // 2. 如果精确匹配没有删除任何标记，尝试包含匹配
    if (removedCount == 0) {
      _mapService.addMarker(
        id: flagId,
        position: latLng,
        title: '',
        icon: _buildFlagMarkerIcon(),
        onTap: () {
          _showFlagInfoWindow(flagId, latLng);
        },
        onLongPress: () {
          _showDeleteMarkerDialog(flagId);
        },
      );
    }
  }

  // 双击地图事件处理
  void _handleMapDoubleTap(TapPosition tapPosition, LatLng location) {
    print('Double tapped at: ${location.latitude}, ${location.longitude}');
    
    // 获取该位置的天气数据
    _getWeatherForLocation(location, '');
    
    // 移动到该位置并稍微放大
    _mapController.move(location, _mapController.zoom + 1);
  }
  
  // 构建天气标记图标
  Widget _buildWeatherMarkerIcon() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        _getWeatherIcon(),
        color: _getWeatherColor(),
        size: _mapService.calculateMarkerSize(15.0),
      ),
    );
  }
  
  // 根据天气状况获取图标
  IconData _getWeatherIcon() {
    if (_weatherData == null) return Icons.cloud;
    
    final condition = _weatherData!.weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return Icons.wb_sunny;
    } else if (condition.contains('cloud')) {
      return Icons.cloud;
    } else if (condition.contains('rain')) {
      return Icons.water_drop;
    } else if (condition.contains('snow')) {
      return Icons.ac_unit;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Icons.cloud;
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return Icons.air;
    } else {
      return Icons.cloud;
    }
  }
  
  // 根据天气状况获取颜色
  Color _getWeatherColor() {
    if (_weatherData == null) return Colors.grey;
    
    final condition = _weatherData!.weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return Colors.orange;
    } else if (condition.contains('cloud')) {
      return Colors.blueGrey;
    } else if (condition.contains('rain')) {
      return Colors.blue;
    } else if (condition.contains('snow')) {
      return Colors.lightBlue;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Colors.grey;
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return Colors.deepPurple;
    } else {
      return Colors.grey;
    }
  }
  
  // 修改地图点击事件处理方法
  void _handleMapTap(TapPosition tapPosition, LatLng location) {
    _saveCurrentMapState(); // 保存当前地图状态
    
    print('地图被点击，放置红旗模式: $_isPlacingFlag');
    
    if (_isPlacingFlag) {
      // 在点击位置放置红旗
      _placeFlagAndGetWeather(location);
      
      // 重置标记状态
      setState(() {
        _isPlacingFlag = false;
      });
      
    } else {
      // 当不在放置红旗模式时，检查是否点击了附近的红旗
      _checkFlagNearby(location);
    }
  }
  
  // 检查点击位置附近是否有红旗
  void _checkFlagNearby(LatLng tapLocation) {
    // 遍历所有红旗信息
    String? nearestFlagId;
    double minDistance = double.infinity;
    final double threshold = 0.005; // 约500米左右的阈值
    
    _flagInfoMap.forEach((flagId, flagInfo) {
      final LatLng flagPos = flagInfo.position;
      
      // 计算距离（简单欧几里得距离）
      final double dist = sqrt(
        pow(tapLocation.latitude - flagPos.latitude, 2) + 
        pow(tapLocation.longitude - flagPos.longitude, 2)
      );
      
      // 如果在阈值内且是最近的，记录这个旗帜
      if (dist < threshold && dist < minDistance) {
        minDistance = dist;
        nearestFlagId = flagId;
      }
    });
    
    // 如果找到最近的红旗，显示其信息
    if (nearestFlagId != null) {
      final flagInfo = _flagInfoMap[nearestFlagId]!;
      _showFlagInfoWindow(nearestFlagId!, flagInfo.position);
    }
  }
  
  // 修改放置红旗方法
  void _placeFlagAndGetWeather(LatLng location) {
    print('放置红旗于: ${location.latitude}, ${location.longitude}');
    
    // 生成唯一的红旗ID
    String flagId = 'flag_${DateTime.now().millisecondsSinceEpoch}';
    
    // 添加红旗标记
    _mapService.addMarker(
      id: flagId,
      position: location,
      title: '',
      icon: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          Icons.flag,
          color: Colors.red,
          size: _mapService.calculateMarkerSize(15.0),
        ),
      ),
      onTap: () {
        print('红旗被点击: $flagId');
        _showFlagInfoWindow(flagId, location);
      },
      onLongPress: () {
        _showDeleteMarkerDialog(flagId);
      },
    );
    
    // 移动到该位置
    _safelyMoveMap(location, _mapController.zoom);
    
    // 获取该位置的天气数据
    _getWeatherForLocation(location, flagId);
    
    // 刷新UI以确保标记显示
    setState(() {});
  }
  
  // 构建红旗标记图标
  Widget _buildFlagMarkerIcon() {
    return Container(
      // 增加一个透明的点击区域
      width: 40,
      height: 40,
      alignment: Alignment.center,
      color: Colors.transparent, // 透明背景，增大点击区域
      child: Icon(
        Icons.flag,
        color: Colors.red,
        size: _mapService.calculateMarkerSize(15.0), // 稍微增大图标
      ),
    );
  }
  
  // 添加新方法：显示删除标记对话框
  void _showDeleteMarkerDialog(String markerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标记'),
        content: const Text('您确定要删除这个标记吗？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              _deleteFlag(markerId);
              
              // 如果删除的是天气标记，也清除天气数据
              if (markerId.contains('weather_')) {
                setState(() {
                  _weatherData = null;
                });
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _goToCurrentLocation,
            tooltip: 'Refresh map',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _isFirstLoad ? _mapService.getDefaultLocation() : _lastMapCenter,
              zoom: _isFirstLoad ? COUNTRY_ZOOM_LEVEL : _lastMapZoom,
              onMapReady: _onMapReady,
              onTap: _handleMapTap,
              onPositionChanged: _handleMapMoved,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.soundscape_app',
              ),
              MarkerLayer(
                markers: _mapService.markers,
              ),
            ],
          ),
          
          if (_isLoadingLocation)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('定位中...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          
          if (_isLoadingWeather)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('获取天气数据...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          
          if (_weatherData != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildWeatherCard(_weatherData!),
            ),
          
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildZoomButton(
                  icon: Icons.add,
                  onPressed: () {
                    double currentZoom = _mapZoomLevel ?? COUNTRY_ZOOM_LEVEL;
                    double newZoom = currentZoom + 1;
                    if (newZoom > 17) newZoom = 17;
                    
                    _safelyMoveMap(_mapCenterPosition ?? _mapService.getDefaultLocation(), newZoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildZoomButton(
                  icon: Icons.remove,
                  onPressed: () {
                    double currentZoom = _mapController.zoom;
                    double newZoom = currentZoom - 1;
                    if (newZoom < 3) newZoom = 3;
                    
                    _mapController.move(
                      _mapController.center,
                      newZoom
                    );
                  },
                ),
              ],
            ),
          ),
          
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMapButton(
                      icon: _isPlacingFlag ? Icons.cancel : Icons.flag,
                      label: _isPlacingFlag ? '取消放置' : '放置红旗',
                      onTap: _toggleFlagPlacementMode,
                    ),
                    _buildMapButton(
                      icon: Icons.my_location,
                      label: 'My Location',
                      onTap: _goToCurrentLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_isPlacingFlag)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Container(
                alignment: Alignment.center,
                color: Colors.red.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      '点击地图放置红旗',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildWeatherCard(WeatherData weatherData) {
    final location = weatherData.location?.getFormattedLocation() ?? weatherData.cityName;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _weatherData = null;
                      for (var id in _weatherMarkerIds) {
                        _mapService.removeMarker(id);
                      }
                      _weatherMarkerIds.clear();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${weatherData.temperature.toStringAsFixed(1)}°',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Image.network(
                            weatherData.getIconUrl(),
                            width: 40,
                            height: 40,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                _getWeatherIcon(),
                                size: 40,
                                color: _getWeatherColor(),
                              );
                            },
                          ),
                        ],
                      ),
                      Text(
                        weatherData.weatherDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWeatherDetailRow(
                        Icons.thermostat_outlined, 
                        '体感温度', 
                        '${weatherData.feelsLike.toStringAsFixed(1)}°C'
                      ),
                      const SizedBox(height: 4),
                      _buildWeatherDetailRow(
                        Icons.water_drop_outlined, 
                        '湿度', 
                        '${weatherData.humidity}%'
                      ),
                      const SizedBox(height: 4),
                      _buildWeatherDetailRow(
                        Icons.air, 
                        '风速', 
                        '${weatherData.windSpeed} m/s'
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.music_note),
                label: const Text('根据天气生成音乐'),
                onPressed: () {
                  _showGenerateMusicDialog(weatherData, '');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWeatherDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  void _showGenerateMusicDialog(WeatherData weatherData, String flagId) {
    final prompt = weatherData.buildMusicPrompt();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('根据天气生成音乐'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '将使用以下Prompt生成音乐:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              width: double.infinity,
              child: Text(prompt),
            ),
            const SizedBox(height: 16),
            const Text(
              '您可以修改此Prompt以满足需求:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '编辑Prompt...',
              ),
              maxLines: 5,
              controller: TextEditingController(text: prompt),
              onChanged: (value) {
                // 在这里存储修改后的Prompt
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              _generateMusicAndUpdateFlag(weatherData, flagId);
            },
            child: const Text('生成音乐'),
          ),
        ],
      ),
    );
  }
  
  void _generateMusicAndUpdateFlag(WeatherData weatherData, String flagId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      
      final musicTitle = '${weatherData.cityName}的${weatherData.weatherDescription}音乐';
      
      if (_flagInfoMap.containsKey(flagId)) {
        setState(() {
          final flagInfo = _flagInfoMap[flagId]!;
          final updatedInfo = FlagInfo(
            position: flagInfo.position,
            weatherData: flagInfo.weatherData,
            createdAt: flagInfo.createdAt,
            musicTitle: musicTitle,
          );
          
          _flagInfoMap[flagId] = updatedInfo;
          
          _mapService.saveFlagInfo(flagId, updatedInfo);
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功生成音乐: $musicTitle')),
      );
    });
  }
  
  Widget _buildMapButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  void _toggleFlagPlacementMode() {
    print('切换放置红旗模式，当前状态: $_isPlacingFlag');
    
    setState(() {
      _isPlacingFlag = !_isPlacingFlag;
    });
    
    print('切换后状态: $_isPlacingFlag');
    
    if (_isPlacingFlag) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请在地图上点击一个位置来放置红旗'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }
  
  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        padding: EdgeInsets.zero,
        iconSize: 20,
        onPressed: onPressed,
        tooltip: icon == Icons.add ? 'Zoom in' : 'Zoom out',
      ),
    );
  }

  void _showWeatherCard(WeatherData weatherData) {
    setState(() {
      _weatherData = weatherData;
      
      if (_selectedLocation == null || 
          (_selectedLocation!.latitude != weatherData.location?.latitude || 
           _selectedLocation!.longitude != weatherData.location?.longitude)) {
        
        _selectedLocation = LatLng(
          weatherData.location?.latitude ?? 0,
          weatherData.location?.longitude ?? 0
        );
        
        _mapController.move(_selectedLocation!, _mapController.zoom);
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('显示${weatherData.cityName}的天气信息'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMusicDetails(String title) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.album, color: Colors.purple),
                SizedBox(width: 10),
                Text('基于天气生成的音乐'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 10),
                Text(
                  '创建于 ${DateTime.now().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('播放'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('播放音乐: $title')),
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('分享'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('分享功能即将推出')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFlagInfoWindow(String flagId, LatLng position) {
    print('尝试显示红旗信息浮窗: $flagId');
    
    final flagInfo = _flagInfoMap[flagId];
    if (flagInfo == null) {
      print('错误: 找不到红旗信息: $flagId');
      return;
    }
    
    print('成功找到红旗信息，准备显示浮窗');
    
    _mapController.move(position, _mapController.zoom);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '标记信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '位置: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '创建于: ${flagInfo.createdAt.toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (flagInfo.weatherData != null) ...[
              const Divider(),
              const Text(
                '天气信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _getWeatherIconForData(flagInfo.weatherData!),
                    color: _getWeatherColorForData(flagInfo.weatherData!),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${flagInfo.weatherData!.cityName}: ${flagInfo.weatherData!.temperature.toStringAsFixed(1)}°C, ${flagInfo.weatherData!.weatherDescription}',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '湿度: ${flagInfo.weatherData!.humidity}%, 风速: ${flagInfo.weatherData!.windSpeed} m/s',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            
            if (flagInfo.musicTitle != null) ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.music_note, size: 16, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    '已生成音乐: ${flagInfo.musicTitle}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (flagInfo.musicTitle == null && flagInfo.weatherData != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.music_note),
                      label: const Text('生成音乐'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showGenerateMusicDialog(flagInfo.weatherData!, flagId);
                      },
                    ),
                  ),
                  
                if (flagInfo.musicTitle != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('播放音乐'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('播放音乐: ${flagInfo.musicTitle}')),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(width: 8),
                
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('删除标记'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteFlag(flagId);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWeatherIconForData(WeatherData weatherData) {
    final condition = weatherData.weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return Icons.wb_sunny;
    } else if (condition.contains('cloud')) {
      return Icons.cloud;
    } else if (condition.contains('rain')) {
      return Icons.water_drop;
    } else if (condition.contains('snow')) {
      return Icons.ac_unit;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Icons.cloud;
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return Icons.air;
    } else {
      return Icons.cloud;
    }
  }

  Color _getWeatherColorForData(WeatherData weatherData) {
    final condition = weatherData.weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return Colors.orange;
    } else if (condition.contains('cloud')) {
      return Colors.blueGrey;
    } else if (condition.contains('rain')) {
      return Colors.blue;
    } else if (condition.contains('snow')) {
      return Colors.lightBlue;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Colors.grey;
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return Colors.deepPurple;
    } else {
      return Colors.grey;
    }
  }

  void _deleteFlag(String flagId) {
    print('开始删除标记: $flagId');
    
    setState(() {
      // 1. 保存所有需要保留的标记信息（除了要删除的）
      Map<String, FlagInfo> flagsToKeep = {};
      _flagInfoMap.forEach((id, info) {
        if (id != flagId) {
          flagsToKeep[id] = info;
        }
      });
      
      // 2. 清空所有现有标记
      _mapService.clearMarkers();
      _flagInfoMap.clear();
      
      // 3. 从服务状态中移除
      _mapService.removeFlagInfo(flagId);
      
      // 4. 重新添加所有需要保留的标记
      flagsToKeep.forEach((id, info) {
        _flagInfoMap[id] = info;
        
        // 重新添加标记到地图
        _mapService.addMarker(
          id: id,
          position: info.position,
          title: '',
          icon: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.flag,
              color: Colors.red,
              size: _mapService.calculateMarkerSize(15.0),
            ),
          ),
          onTap: () {
            _showFlagInfoWindow(id, info.position);
          },
          onLongPress: () {
            _showDeleteMarkerDialog(id);
          },
        );
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('标记已删除')),
    );
  }

  void _loadPersistentFlags() {
    final persistentFlags = _mapService.persistentFlagMap;
    
    // 先清除所有标记
    _mapService.clearMarkers();
    
    setState(() {
      _flagInfoMap.clear(); // 清除本地状态
      _flagInfoMap.addAll(persistentFlags); // 添加持久化的状态
      
      // 重新为每个红旗创建标记
      _flagInfoMap.forEach((id, info) {
        _mapService.addMarker(
          id: id,
          position: info.position,
          title: '',
          icon: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.flag,
              color: Colors.red,
              size: _mapService.calculateMarkerSize(15.0),
            ),
          ),
          onTap: () {
            _showFlagInfoWindow(id, info.position);
          },
          onLongPress: () {
            _showDeleteMarkerDialog(id);
          },
        );
      });
    });
  }

  void _updateMapState() {
    try {
      _mapCenterPosition = _mapController.center;
      _mapZoomLevel = _mapController.zoom;
    } catch (e) {
      print("获取地图状态失败: $e");
      _mapCenterPosition = _mapService.getDefaultLocation();
      _mapZoomLevel = COUNTRY_ZOOM_LEVEL;
    }
  }

  void _safelyMoveMap(LatLng position, double zoom) {
    if (_mapController != null) {
      try {
        _mapController.move(position, zoom);
        _mapCenterPosition = position;
        _mapZoomLevel = zoom;
      } catch (e) {
        print('移动地图失败: $e');
        _mapCenterPosition = position;
        _mapZoomLevel = zoom;
      }
    }
  }

  void _handleMapMoved(MapPosition position, bool hasGesture) {
    setState(() {
      _currentCenter = position.center!;
      _currentZoom = position.zoom!;
      
      // 更新最后的地图状态
      _lastMapCenter = position.center!;
      _lastMapZoom = position.zoom!;
    });
  }

  bool isMapControllerReady() {
    if (_mapController == null) return false;
    
    try {
      // 尝试读取一个属性或调用一个方法
      var center = _mapController.center;
      return true; // 如果没有抛出异常，说明控制器就绪
    } catch (e) {
      return false; // 捕获到异常，说明控制器未就绪
    }
  }

  // 添加一个方法来保存当前地图状态
  void _saveCurrentMapState() {
    try {
      _lastMapCenter = _mapController.center;
      _lastMapZoom = _mapController.zoom;
    } catch (e) {
      print('保存地图状态失败: $e');
    }
  }
} 