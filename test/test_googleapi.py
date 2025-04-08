#!/usr/bin/env python3
"""
Google Maps API连通性测试脚本
此脚本测试Google Maps API的各种端点的连接性和可用性
"""

import requests
import json
import time
import sys
import argparse
from datetime import datetime

# 彩色输出
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_success(message):
    """打印成功消息"""
    print(f"{Colors.GREEN}✓ {message}{Colors.ENDC}")

def print_error(message):
    """打印错误消息"""
    print(f"{Colors.RED}✗ {message}{Colors.ENDC}")

def print_info(message):
    """打印信息消息"""
    print(f"{Colors.BLUE}ℹ {message}{Colors.ENDC}")

def print_warning(message):
    """打印警告消息"""
    print(f"{Colors.YELLOW}⚠ {message}{Colors.ENDC}")

def print_header(message):
    """打印标题"""
    print(f"\n{Colors.HEADER}{Colors.BOLD}=== {message} ==={Colors.ENDC}")

def test_internet_connectivity():
    """测试互联网连接"""
    print_header("测试基本互联网连接")
    
    try:
        response = requests.get("https://www.google.com", timeout=5)
        if response.status_code == 200:
            print_success("成功连接到Google")
            return True
        else:
            print_error(f"连接到Google返回了状态码: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print_error(f"连接到Google时出错: {e}")
        return False

def test_maps_api_connectivity():
    """测试Google Maps API连接性"""
    print_header("测试Google Maps API域名连接性")
    
    try:
        response = requests.get("https://maps.googleapis.com", timeout=5)
        if response.status_code < 400:  # 可能返回301或302重定向
            print_success("成功连接到Google Maps API域名")
            return True
        else:
            print_error(f"连接到Google Maps API域名返回了状态码: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print_error(f"连接到Google Maps API域名时出错: {e}")
        return False

def test_geocoding_api(api_key):
    """测试Geocoding API"""
    print_header("测试Geocoding API")
    
    url = f"https://maps.googleapis.com/maps/api/geocode/json?address=London&key={api_key}"
    
    try:
        response = requests.get(url, timeout=5)
        data = response.json()
        
        if response.status_code == 200:
            if "error_message" in data:
                print_error(f"Geocoding API返回错误: {data['error_message']}")
                return False
            elif "results" in data and len(data["results"]) > 0:
                print_success("Geocoding API正常工作")
                print_info(f"找到 {len(data['results'])} 个结果")
                if len(data["results"]) > 0:
                    location = data["results"][0]["geometry"]["location"]
                    print_info(f"London坐标: {location['lat']}, {location['lng']}")
                return True
            else:
                print_warning("Geocoding API返回了有效响应，但没有结果")
                return True
        else:
            print_error(f"Geocoding API返回状态码: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print_error(f"调用Geocoding API时出错: {e}")
        return False
    except (KeyError, json.JSONDecodeError) as e:
        print_error(f"解析Geocoding API响应时出错: {e}")
        return False

def test_static_maps_api(api_key):
    """测试Static Maps API"""
    print_header("测试Static Maps API")
    
    url = f"https://maps.googleapis.com/maps/api/staticmap?center=London&zoom=13&size=600x300&key={api_key}"
    
    try:
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            content_type = response.headers.get('content-type', '')
            if 'image/' in content_type:
                print_success("成功获取静态地图图像")
                print_info(f"内容类型: {content_type}")
                print_info(f"图像大小: {len(response.content)} 字节")
                return True
            else:
                print_error(f"获取到响应，但内容类型不是图像: {content_type}")
                print_info(f"响应内容: {response.text[:200]}")
                return False
        else:
            print_error(f"Static Maps API返回状态码: {response.status_code}")
            print_info(f"响应内容: {response.text[:200]}")
            return False
    except requests.exceptions.RequestException as e:
        print_error(f"调用Static Maps API时出错: {e}")
        return False

def test_directions_api(api_key):
    """测试Directions API"""
    print_header("测试Directions API")
    
    url = f"https://maps.googleapis.com/maps/api/directions/json?origin=London&destination=Manchester&key={api_key}"
    
    try:
        response = requests.get(url, timeout=5)
        data = response.json()
        
        if response.status_code == 200:
            if "error_message" in data:
                print_error(f"Directions API返回错误: {data['error_message']}")
                return False
            elif "routes" in data and len(data["routes"]) > 0:
                print_success("Directions API正常工作")
                if "legs" in data["routes"][0] and len(data["routes"][0]["legs"]) > 0:
                    leg = data["routes"][0]["legs"][0]
                    print_info(f"从 {leg['start_address']} 到 {leg['end_address']}")
                    print_info(f"距离: {leg['distance']['text']}")
                    print_info(f"时间: {leg['duration']['text']}")
                return True
            else:
                print_warning("Directions API返回了有效响应，但没有路线")
                return True
        else:
            print_error(f"Directions API返回状态码: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print_error(f"调用Directions API时出错: {e}")
        return False
    except (KeyError, json.JSONDecodeError) as e:
        print_error(f"解析Directions API响应时出错: {e}")
        return False

def run_all_tests(api_key):
    """运行所有测试"""
    print_header(f"Google Maps API连通性测试 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print_info(f"API密钥: {api_key[:6]}...{api_key[-4:]}")
    
    results = {
        "internet": test_internet_connectivity(),
        "maps_domain": test_maps_api_connectivity(),
        "geocoding": test_geocoding_api(api_key),
        "static_maps": test_static_maps_api(api_key),
        "directions": test_directions_api(api_key)
    }
    
    print_header("测试结果摘要")
    
    total = len(results)
    passed = sum(1 for result in results.values() if result)
    
    for test, result in results.items():
        status = "通过" if result else "失败"
        color = Colors.GREEN if result else Colors.RED
        print(f"{color}{status}{Colors.ENDC}: {test}")
    
    print(f"\n总体结果: {passed}/{total} 测试通过")
    
    if passed == total:
        print_success("所有测试通过！Google Maps API工作正常。")
    elif passed >= total / 2:
        print_warning(f"部分测试通过 ({passed}/{total})。可能存在一些API访问问题。")
    else:
        print_error(f"大多数测试失败 ({total-passed}/{total})。Google Maps API可能存在严重连接问题。")

def main():
    parser = argparse.ArgumentParser(description='测试Google Maps API连通性')
    parser.add_argument('api_key', help='Google Maps API密钥')
    
    args = parser.parse_args()
    
    run_all_tests(args.api_key)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("使用方法: python test_google_maps_api.py YOUR_API_KEY")
        sys.exit(1)
    
    main()