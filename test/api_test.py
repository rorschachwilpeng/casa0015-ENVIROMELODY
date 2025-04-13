import requests

# 你的 WeatherAPI API Key
API_KEY = "39b7c09931b445c9a9d190003242712"

# 你想查询的城市
CITY = "Syndey"

# WeatherAPI 的请求 URL
URL = f"http://api.weatherapi.com/v1/current.json?key={API_KEY}&q={CITY}&aqi=yes"

def fetch_weather():
    try:
        response = requests.get(URL)
        data = response.json()

        if "error" in data:
            print("❌ Error:", data["error"]["message"])
            return

        # 提取天气信息
        location = data["location"]["name"]
        temp_c = data["current"]["temp_c"]
        wind_kph = data["current"]["wind_kph"]
        humidity = data["current"]["humidity"]
        co2 = data["current"]["air_quality"]["co"] if "air_quality" in data["current"] else "N/A"
        condition = data["current"]["condition"]["text"]

        # 输出天气数据
        print(f"🌍 Weather in {location}:")
        print(f"🌡️ Temperature: {temp_c}°C")
        print(f"💨 Wind Speed: {wind_kph} km/h")
        print(f"💧 Humidity: {humidity}%")
        print(f"🌫️ CO₂ Concentration: {co2} ppm")
        print(f"☁️ Condition: {condition}")

    except Exception as e:
        print("❌ Failed to fetch weather data:", str(e))

# 运行测试
fetch_weather()
