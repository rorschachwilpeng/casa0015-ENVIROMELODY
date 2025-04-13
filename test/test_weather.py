#!/usr/bin/env python3
# openweather_api_test.py - 测试OpenWeather API响应

import requests
import json
import argparse
from datetime import datetime

def format_json(json_data):
    """格式化JSON数据以便于阅读"""
    return json.dumps(json_data, indent=2, ensure_ascii=False)

def test_weather_api(api_key, latitude, longitude):
    """测试OpenWeather当前天气API"""
    print("\n===== 测试当前天气API =====")
    url = f"https://api.openweathermap.org/data/2.5/weather?lat={latitude}&lon={longitude}&units=metric&appid={api_key}"
    
    try:
        response = requests.get(url)
        response.raise_for_status()  # 如果HTTP请求返回了不成功的状态码，抛出异常
        
        print(f"状态码: {response.status_code}")
        weather_data = response.json()
        
        print("\n完整的API响应:")
        print(format_json(weather_data))
        
        # 提取和显示一些关键信息
        if 'name' in weather_data:
            print(f"\n城市: {weather_data['name']}")
        
        if 'main' in weather_data:
            main = weather_data['main']
            print(f"温度: {main.get('temp', 'N/A')}°C")
            print(f"体感温度: {main.get('feels_like', 'N/A')}°C")
            print(f"湿度: {main.get('humidity', 'N/A')}%")
            print(f"气压: {main.get('pressure', 'N/A')} hPa")
        
        if 'weather' in weather_data and len(weather_data['weather']) > 0:
            weather = weather_data['weather'][0]
            print(f"天气状况: {weather.get('main', 'N/A')} - {weather.get('description', 'N/A')}")
            print(f"天气图标: {weather.get('icon', 'N/A')}")
        
        if 'wind' in weather_data:
            wind = weather_data['wind']
            print(f"风速: {wind.get('speed', 'N/A')} m/s")
            print(f"风向: {wind.get('deg', 'N/A')}°")
        
        if 'sys' in weather_data:
            sys = weather_data['sys']
            # 转换Unix时间戳为可读格式
            if 'sunrise' in sys:
                sunrise_time = datetime.fromtimestamp(sys['sunrise']).strftime('%H:%M:%S')
                print(f"日出: {sunrise_time}")
            if 'sunset' in sys:
                sunset_time = datetime.fromtimestamp(sys['sunset']).strftime('%H:%M:%S')
                print(f"日落: {sunset_time}")
            if 'country' in sys:
                print(f"国家代码: {sys['country']}")
        
    except requests.exceptions.HTTPError as http_err:
        print(f"HTTP错误: {http_err}")
        if response.text:
            print(f"错误详情: {response.text}")
    except Exception as err:
        print(f"发生错误: {err}")

def test_geocoding_api(api_key, latitude, longitude):
    """测试OpenWeather反向地理编码API"""
    print("\n===== 测试反向地理编码API =====")
    url = f"http://api.openweathermap.org/geo/1.0/reverse?lat={latitude}&lon={longitude}&limit=1&appid={api_key}"
    
    try:
        response = requests.get(url)
        response.raise_for_status()
        
        print(f"状态码: {response.status_code}")
        geocoding_data = response.json()
        
        print("\n完整的API响应:")
        print(format_json(geocoding_data))
        
        # 如果响应是一个列表且不为空
        if isinstance(geocoding_data, list) and len(geocoding_data) > 0:
            location = geocoding_data[0]
            print("\n位置信息:")
            print(f"名称: {location.get('name', 'N/A')}")
            print(f"国家: {location.get('country', 'N/A')}")
            print(f"州/省: {location.get('state', 'N/A')}")
            
            # 检查是否有本地化名称
            if 'local_names' in location:
                print("\n不同语言的地名:")
                for lang, name in location['local_names'].items():
                    print(f"  {lang}: {name}")
        
    except requests.exceptions.HTTPError as http_err:
        print(f"HTTP错误: {http_err}")
        if response.text:
            print(f"错误详情: {response.text}")
    except Exception as err:
        print(f"发生错误: {err}")

def test_forecast_api(api_key, latitude, longitude):
    """测试OpenWeather 5天天气预报API"""
    print("\n===== 测试5天天气预报API =====")
    url = f"https://api.openweathermap.org/data/2.5/forecast?lat={latitude}&lon={longitude}&units=metric&appid={api_key}"
    
    try:
        response = requests.get(url)
        response.raise_for_status()
        
        print(f"状态码: {response.status_code}")
        forecast_data = response.json()
        
        # 只显示第一个预报项以避免输出过多
        if 'list' in forecast_data and len(forecast_data['list']) > 0:
            first_forecast = forecast_data['list'][0]
            print("\n第一个预报项:")
            print(format_json(first_forecast))
            
            print(f"\n预报数量: {len(forecast_data['list'])}")
            print("预报时间间隔:")
            for i in range(min(3, len(forecast_data['list']))):
                dt = datetime.fromtimestamp(forecast_data['list'][i]['dt'])
                print(f"  {dt.strftime('%Y-%m-%d %H:%M:%S')}")
        else:
            print("\n完整的API响应:")
            print(format_json(forecast_data))
        
    except requests.exceptions.HTTPError as http_err:
        print(f"HTTP错误: {http_err}")
        if response.text:
            print(f"错误详情: {response.text}")
    except Exception as err:
        print(f"发生错误: {err}")

def main():
    parser = argparse.ArgumentParser(description='测试OpenWeather API响应')
    parser.add_argument('api_key', help='OpenWeather API密钥')
    parser.add_argument('--lat', type=float, default=51.5074, help='纬度 (默认: 伦敦)')
    parser.add_argument('--lon', type=float, default=-0.1278, help='经度 (默认: 伦敦)')
    parser.add_argument('--all', action='store_true', help='测试所有API')
    parser.add_argument('--weather', action='store_true', help='测试天气API')
    parser.add_argument('--geocoding', action='store_true', help='测试地理编码API')
    parser.add_argument('--forecast', action='store_true', help='测试天气预报API')
    
    args = parser.parse_args()
    
    # 如果没有指定具体API，或者指定了--all，则测试所有API
    test_all = args.all or not (args.weather or args.geocoding or args.forecast)
    
    print(f"使用坐标: 纬度 {args.lat}, 经度 {args.lon}")
    
    if test_all or args.weather:
        test_weather_api(args.api_key, args.lat, args.lon)
    
    if test_all or args.geocoding:
        test_geocoding_api(args.api_key, args.lat, args.lon)
    
    if test_all or args.forecast:
        test_forecast_api(args.api_key, args.lat, args.lon)

if __name__ == "__main__":
    main()