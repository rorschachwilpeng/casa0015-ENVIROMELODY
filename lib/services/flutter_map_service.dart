import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../screens/home_screen.dart'; // 导入 FlagInfo 类

// 将 typedef 定义移动到类外部
typedef ZoomChangedCallback = void Function(double zoom);

// Flutter Map Map Service
class FlutterMapService extends ChangeNotifier {
  // Singleton Pattern
  static final FlutterMapService _instance = FlutterMapService._internal();
  factory FlutterMapService() => _instance;
  FlutterMapService._internal();
  
  // Default location: London (latitude 51.5074, longitude -0.1278)
  final LatLng _defaultLocation = const LatLng(51.5074, -0.1278);
  
  // Location Service
  final Location _locationService = Location();
  
  // Current Location
  LocationData? _currentLocation;
  LatLng? get currentLatLng => _currentLocation != null 
      ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!) 
      : _defaultLocation;
  
  // Map Controller
  MapController? _mapController;
  
  // Marker Collection
  final List<Marker> _markers = [];
  List<Marker> get markers => _markers;
  
  // Add constant at the top of the class
  static const double COUNTRY_ZOOM_LEVEL = 6.0; // Country zoom level
  
  // 添加缩放比例相关属性
  double _currentZoom = COUNTRY_ZOOM_LEVEL;
  double get currentZoom => _currentZoom;
  
  // 标记尺寸比例参考值
  static const double BASE_ZOOM = 10.0; // 基准缩放级别
  static const double BASE_MARKER_SIZE = 30.0; // 基准标记大小
  
  // 缩放变化回调
  ZoomChangedCallback? _onZoomChanged;
  
  // 设置缩放变化回调
  void setZoomChangedCallback(ZoomChangedCallback callback) {
    _onZoomChanged = callback;
  }
  
  // 根据缩放级别计算标记大小
  double calculateMarkerSize(double baseSize) {
    // 缩放系数：缩放级别越大，标记越小；缩放级别越小，标记越大
    double zoomFactor = math.pow(0.85, _currentZoom - BASE_ZOOM).toDouble();
    // 限制最小/最大大小
    return math.max(15.0, math.min(baseSize * zoomFactor, 50.0));
  }
  
  // 更新当前缩放级别
  void updateZoom(double zoom) {
    _currentZoom = zoom;
    // 通知监听器缩放变化
    if (_onZoomChanged != null) {
      _onZoomChanged!(_currentZoom);
    }
  }
  
  // 添加一个属性来控制是否自动移动到当前位置
  bool _autoMoveToCurrentLocation = false;
  
  // 修改 initMap 方法，添加一个参数来控制是否自动移动
  void initMap(MapController controller, {bool autoMoveToCurrentLocation = false}) {
    _mapController = controller;
    _autoMoveToCurrentLocation = autoMoveToCurrentLocation;
    _checkLocationPermission();
  }
  
  // Check location permission
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    PermissionStatus permissionStatus;
    
    try {
      // Check if location service is enabled
      serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          developer.log('Location services are disabled', name: 'FlutterMapService');
          return false;
        }
      }
      
      // Check location permission
      permissionStatus = await _locationService.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _locationService.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          developer.log('Location permissions are denied', name: 'FlutterMapService');
          return false;
        }
      }
      
      // Get current location
      await getCurrentLocation();
      
      // 只有当 _autoMoveToCurrentLocation 为 true 时才自动移动
      if (_autoMoveToCurrentLocation && _mapController != null) {
        await moveToCurrentLocation();
      }
      
      return true;
    } catch (e) {
      developer.log('Error checking location permission: $e', name: 'FlutterMapService');
      return false;
    }
  }
  
  // Get current location
  Future<void> getCurrentLocation() async {
    try {
      // 确保超时情况下也设置合理的默认值
      final locationData = await _locationService.getLocation()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print("DEBUG: Get location timeout");
        _currentLocation = LocationData.fromMap({
          'latitude': _defaultLocation.latitude,
          'longitude': _defaultLocation.longitude,
          'accuracy': 0.0,
          'altitude': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
          'heading': 0.0,
          'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });
        return _currentLocation!;
      });
      
      _currentLocation = locationData;
      developer.log('Current location: ${locationData.latitude}, ${locationData.longitude}', 
                  name: 'FlutterMapService');
    } catch (e) {
      // 确保任何错误情况下也设置默认值
      _currentLocation = LocationData.fromMap({
        'latitude': _defaultLocation.latitude,
        'longitude': _defaultLocation.longitude,
        'accuracy': 0.0,
        'altitude': 0.0,
        'speed': 0.0,
        'speed_accuracy': 0.0,
        'heading': 0.0,
        'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
      });
      print("DEBUG: Error getting location: $e");
    }
  }
  
  // 移动到当前位置
  Future<void> moveToCurrentLocation() async {
    try {
      await getCurrentLocation();
      
      if (_mapController == null) {
        print("地图控制器未初始化");
        return;
      }
      
      // 直接尝试使用控制器，不检查 state 属性
      try {
        // 如果控制器未就绪，这里会抛出异常，会被下面的 catch 捕获
        _mapController!.move(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          COUNTRY_ZOOM_LEVEL
        );
        print("成功移动地图到当前位置");
      } catch (e) {
        print("移动地图失败: $e");
      }
    } catch (e) {
      print("移动到当前位置时出错: $e");
    }
  }
  
  // Add marker
  void addMarker({
    required String id,
    required LatLng position,
    required String title,
    String? snippet,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Widget? icon,
  }) {
    print('添加标记 - ID: $id, 位置: ${position.latitude}, ${position.longitude}');
    print('点击事件是否设置: ${onTap != null}');
    
    // 移除同ID的标记
    _markers.removeWhere((marker) => marker.key.toString().contains(id));
    
    // 添加新标记
    final marker = Marker(
      point: position,
      width: 40, // 确保足够大的点击区域
      height: 40, // 确保足够大的点击区域
      builder: (context) {
        return GestureDetector(
          onTap: () {
            print('标记被点击: $id');
            if (onTap != null) onTap();
          },
          onLongPress: onLongPress,
          child: icon ?? 
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.red, size: calculateMarkerSize(15.0)),
                if (title.isNotEmpty)
                  Text(
                    title, 
                    style: TextStyle(
                      fontSize: calculateMarkerSize(10.0),
                      fontWeight: FontWeight.bold
                    ),
                  ),
              ],
            ),
        );
      },
    );
    
    _markers.add(marker);
    
    // 确保通知监听器，这样标记会显示在地图上
    notifyListeners();
  }
  
  // Add music marker
  void addMusicMarker({
    required String id,
    required String title,
    LatLng? position,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final LatLng markerPosition = position ?? (currentLatLng ?? _defaultLocation);
    
    addMarker(
      id: 'music_$id',
      position: markerPosition,
      title: title,
      onTap: onTap,
      onLongPress: onLongPress,
      icon: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, color: Colors.purple, size: calculateMarkerSize(15.0)),
            Text(
              title, 
              style: TextStyle(
                fontSize: calculateMarkerSize(10.0),
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
    
    developer.log('Added music marker: $title at ${markerPosition.latitude}, ${markerPosition.longitude}', 
                 name: 'FlutterMapService');
  }
  
  // Remove marker
  void removeMarker(String id) {
    print('开始删除标记: $id，当前标记数量: ${_markers.length}');
    
    // 打印所有标记的ID以进行调试
    print('所有标记的ID: ${_markers.map((m) => m.key.toString()).join(", ")}');
    
    // 尝试多种匹配方式
    int removedCount = 0;
    
    // 1. 使用精确匹配
    _markers.removeWhere((marker) {
      bool shouldRemove = marker.key.toString() == 'Key("$id")';
      if (shouldRemove) removedCount++;
      return shouldRemove;
    });
    
    // 2. 如果精确匹配没有删除任何标记，尝试包含匹配
    if (removedCount == 0) {
      _markers.removeWhere((marker) {
        bool shouldRemove = marker.key.toString().contains(id);
        if (shouldRemove) removedCount++;
        return shouldRemove;
      });
    }
    
    print('总共删除了 $removedCount 个标记，剩余 ${_markers.length} 个');
    
    // 确保通知界面刷新
    notifyListeners();
  }
  
  // Clear all markers
  void clearMarkers() {
    _markers.clear();
  }
  
  // Get default location
  LatLng getDefaultLocation() {
    return _defaultLocation;
  }
  
  // Calculate distance between two points (meters)
  double calculateDistance(LatLng start, LatLng end) {
    final Distance distance = const Distance();
    return distance.as(LengthUnit.Meter, start, end);
  }
  
  // Dispose resources
  void dispose() {
    // Flutter Map has no resources to dispose
  }
  
  // 新增方法：清除所有天气标记
  void clearAllWeatherMarkers() {
    _markers.removeWhere((marker) => marker.key.toString().contains('weather_'));
  }
  
  // 添加新方法：更新标记的点击事件
  void updateMarkerTapEvent(String id, VoidCallback? onTap) {
    // 找到匹配ID的标记
    int index = _markers.indexWhere((marker) => marker.key.toString().contains(id));
    
    if (index != -1) {
      // 获取原始标记
      Marker oldMarker = _markers[index];
      
      // 创建一个新标记，复制除点击事件外的所有属性
      Marker newMarker = Marker(
        key: oldMarker.key,
        point: oldMarker.point,
        width: oldMarker.width,
        height: oldMarker.height,
        builder: (context) {
          // 假设原始builder创建了一个GestureDetector
          // 这里我们需要包装原始widget以更新其onTap属性
          // 注意：这是一个简化示例，实际实现可能更复杂
          Widget originalWidget = oldMarker.builder(context);
          
          // 如果原始widget是GestureDetector，我们可以尝试复制并修改它
          if (originalWidget is GestureDetector) {
            return GestureDetector(
              onTap: onTap,
              onLongPress: originalWidget.onLongPress,
              child: originalWidget.child,
            );
          }
          
          // 否则，返回原始widget（不更新点击事件）
          return originalWidget;
        },
      );
      
      // 用新标记替换旧标记
      _markers[index] = newMarker;
    }
  }
  
  // 添加 notifyListeners 方法，如果不是 ChangeNotifier 的子类
  void notifyListeners() {
    // 重新构建依赖该服务的 Widget
    super.notifyListeners();
  }
  
  // 在 FlutterMapService 类中添加这个方法
  void clearAndRebuildMarkers(String excludeId) {
    // 保存所有不含指定ID的标记
    final markersToKeep = _markers.where((marker) => !marker.key.toString().contains(excludeId)).toList();
    
    // 清空标记列表
    _markers.clear();
    
    // 重新添加保留的标记
    _markers.addAll(markersToKeep);
    
    // 通知监听器
    notifyListeners();
  }
  
  // 添加红旗信息持久化映射
  final Map<String, FlagInfo> _persistentFlagMap = {};
  // 红旗信息持久化映射的getter
  Map<String, FlagInfo> get persistentFlagMap => _persistentFlagMap;
  
  // 保存红旗信息
  void saveFlagInfo(String flagId, FlagInfo flagInfo) {
    _persistentFlagMap[flagId] = flagInfo;
    // 通知监听器更新
    notifyListeners();
  }
  
  // 移除红旗信息
  void removeFlagInfo(String flagId) {
    print('移除红旗信息: $flagId');
    // 从持久化映射中移除
    _persistentFlagMap.remove(flagId);
    // 同时移除相应的标记
    removeMarker(flagId);
    // 通知监听器更新
    notifyListeners();
  }
}