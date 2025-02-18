import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Position? _currentPosition;
  Timer? _timer;
  final String apiUrl = "http://10.0.2.2:8000/location/mobile/"; 
  String? _error;
  final int mascotaId = 6;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _startSendingLocation();
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
    });
  }

  void _startSendingLocation() {
    /*     _timer = Timer.periodic(Duration(seconds: 10), (Timer t) async { */
    _timer = Timer.periodic(Duration(minutes: 1), (Timer t) async {
      if (_currentPosition != null) {
        await _sendLocation(_currentPosition!);
      }
    });
  }

  Future<void> _sendLocation(Position position) async {
    try {
      final Map<String, dynamic> locationData = {
        "latitud": double.parse(position.latitude.toStringAsFixed(6)),
        "longitud": double.parse(position.longitude.toStringAsFixed(6)),
        "mascota": mascotaId,
      };

      print("Intentando enviar ubicación a: $apiUrl");
      print("Datos a enviar: ${jsonEncode(locationData)}");
      
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(locationData),
      );
      
      print("Código de respuesta: ${response.statusCode}");
      print("Respuesta del servidor: ${response.body}");
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error del servidor: ${response.statusCode}\nRespuesta: ${response.body}');
      }
    } catch (e) {
      print("Error detallado enviando ubicación: $e");
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("GPS Sender")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentPosition == null)
                Text("Obteniendo ubicación...")
              else
                Text("Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}"),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Error: $_error",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
