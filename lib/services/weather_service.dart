import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class WeatherService {
  static const String _apiKey = '8ba59ebfaa6920e25cfe5cf058bee23b';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<Map<String, dynamic>> getWeather(double lat, double lon) async {
    // Use mock data on web for testing
    if (kIsWeb) {
      await Future.delayed(const Duration(seconds: 1));
      return _getMockWeatherData();
    }

    try {
      // Use reverse geocoding to get accurate location name
      final url = '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=ja';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Weather API Response: $data'); // Debug log
        return data;
      } else {
        print('Weather API Error: ${response.statusCode}');
        return _getMockWeatherData();
      }
    } catch (e) {
      print('Weather API Error: $e');
      return _getMockWeatherData();
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts(double lat, double lon) async {
    // Mock alerts for testing
    return [
      {
        'title': '大雨警報',
        'description': '今後6時間以内に大雨が予想されます',
        'severity': 'medium',
        'icon': '⚠️',
      },
      {
        'title': '強風注意報',
        'description': '風速15m/s以上の強風に注意',
        'severity': 'low',
        'icon': '🌪️',
      },
    ];
  }

  Map<String, dynamic> _getMockWeatherData() {
    return {
      'name': '足立区, 東京', // Updated for Adachi, Tokyo
      'main': {
        'temp': 15.0,
        'feels_like': 14.0,
        'humidity': 53,
      },
      'weather': [
        {
          'main': 'Clear',
          'description': '晴天',
        }
      ],
      'wind': {
        'speed': 0.45,
      },
    };
  }

  String getWeatherIcon(String weatherMain) {
    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }
}