import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Add state variable to store weather data
  Map<String, dynamic>? _weatherData;
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Add OpenWeather API call function
  Future<void> _fetchWeatherData() async {
    // OpenWeather API key - remember to replace with your own key
    const apiKey = '478d7ef1355596eb44b5a68f91c52c31';
    // Set default city - using London as an example
    const city = 'London';
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Build API URL - using current weather API as an example
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric'
      );
      
      // Send GET request
      final response = await http.get(url);
      
      // Check response status
      if (response.statusCode == 200) {
        // Parse JSON response
        final Map<String, dynamic> data = json.decode(response.body);
        
        setState(() {
          _weatherData = data;
          _isLoading = false;
        });
        
        print('Weather data fetched successfully: ${response.body}');
      } else {
        // Handle error response
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get weather data: ${response.statusCode} - ${response.body}';
        });
        
        print('Failed to get weather data. Status code: ${response.statusCode}');
        print('Error message: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error calling weather API: $e';
      });
      
      print('Error calling weather API: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoundScape'),
        actions: [
          // Add refresh button to app bar
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWeatherData,
            tooltip: 'Refresh weather data',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.all(10),
              width: double.infinity,  // Make container full width
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Weather Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Show weather icon if data is available
                      if (_weatherData != null && !_isLoading)
                        Image.network(
                          'https://openweathermap.org/img/wn/${_weatherData!['weather'][0]['icon']}@2x.png',
                          width: 50,
                          height: 50,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Display weather data or loading state
                  _isLoading 
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'City: ${_weatherData?['name'] ?? 'No data'}, ${_weatherData?['sys']?['country'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.thermostat, size: 16),
                              const SizedBox(width: 5),
                              Text('Temperature: ${_weatherData?['main']?['temp']?.toStringAsFixed(1) ?? 'No data'}°C'),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.wb_sunny, size: 16),
                              const SizedBox(width: 5),
                              Text('Weather: ${_weatherData?['weather']?[0]?['description'] ?? 'No data'}'),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.water_drop, size: 16),
                              const SizedBox(width: 5),
                              Text('Humidity: ${_weatherData?['main']?['humidity'] ?? 'No data'}%'),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.air, size: 16),
                              const SizedBox(width: 5),
                              Text('Wind Speed: ${_weatherData?['wind']?['speed'] ?? 'No data'} m/s'),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.visibility, size: 16),
                              const SizedBox(width: 5),
                              Text('Visibility: ${(_weatherData?['visibility'] != null ? (_weatherData!['visibility'] / 1000).toStringAsFixed(1) : 'No data')} km'),
                            ],
                          ),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Error: $_errorMessage',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _fetchWeatherData,
                      icon: const Icon(Icons.cloud),
                      label: const Text('Get Weather Data'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Map Page',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            const Text('This page will display a map and allow users to select locations'),
          ],
        ),
      ),
    );
  }
} 