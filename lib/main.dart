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
  int mascotaId = 6;
  final TextEditingController _idController = TextEditingController();
  StreamSubscription<Position>? _positionStreamSubscription;
  final String mascotaApiUrl = "http://10.0.2.2:8000/mascotas/mascotas_id/";
  Map<String, dynamic>? mascotaInfo;

  @override
  void initState() {
    super.initState();
    _idController.text = mascotaId.toString();
    _getMascotaInfo();
    _getLocation();
    _startLocationUpdates();
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

  Future<void> _startLocationUpdates() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,       // Máxima precisión
        distanceFilter: 5,                     // Actualiza cada 5 metros de movimiento
      ),
    ).listen(
      (Position position) {
        print("Nueva ubicación recibida: Lat: ${position.latitude}, Lng: ${position.longitude}");
        setState(() {
          _currentPosition = position;
        });
      },
      onError: (error) {
        print("Error en stream de ubicación: $error");
        setState(() {
          _error = error.toString();
        });
      },
    );

    // Verificar si el stream está activo
    print("Stream de ubicación iniciado: ${_positionStreamSubscription != null}");
  }

  void _startSendingLocation() {
    /*     _timer = Timer.periodic(Duration(seconds: 10), (Timer t) async { */
    _timer = Timer.periodic(Duration(seconds: 10), (Timer t) async {
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
    _positionStreamSubscription?.cancel();
    _idController.dispose();
    super.dispose();
  }

  void _updateMascotaId() {
    int? newId = int.tryParse(_idController.text);
    if (newId != null) {
      setState(() {
        mascotaId = newId;
      });
      _getMascotaInfo();
    } else {
      setState(() {
        _error = 'Por favor ingrese un ID válido';
      });
    }
  }

  Future<void> _getMascotaInfo() async {
    try {
      final response = await http.get(Uri.parse('$mascotaApiUrl$mascotaId'));
      if (response.statusCode == 200) {
        setState(() {
          mascotaInfo = json.decode(response.body);
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Error al obtener información de la mascota';
          mascotaInfo = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
        mascotaInfo = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("GPS Sender")),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _idController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'ID de la Mascota',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _updateMascotaId,
                      child: Text('Actualizar'),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              if (_currentPosition == null)
                Text("Obteniendo ubicación...")
              else
                Column(
                  children: [
                    Text(
                      "Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n"
                      "Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}\n"
                      "Precisión: ${_currentPosition!.accuracy.toStringAsFixed(2)} metros",
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Última actualización: ${DateTime.now().toString()}",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              if (mascotaInfo != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mascotaInfo!['imagen'] != null)
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.memory(
                                  base64Decode(mascotaInfo!['imagen'].toString().split(',').last),
                                  height: 200,
                                  width: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      width: 200,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.pets, size: 50, color: Colors.grey[600]),
                                    );
                                  },
                                ),
                              ),
                            ),
                          SizedBox(height: 16),
                          Text(
                            'Información de la Mascota',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text('Nombre: ${mascotaInfo!['nombre'] ?? 'No disponible'}'),
                          Text('Especie: ${mascotaInfo!['especie'] ?? 'No disponible'}'),
                          Text('Raza: ${mascotaInfo!['raza'] ?? 'No disponible'}'),
                          Text('Edad: ${mascotaInfo!['edad']?.toString() ?? 'No disponible'} años'),
                          Text('Peso: ${mascotaInfo!['peso'] ?? 'No disponible'} kg'),
                          if (mascotaInfo!['dueño_info'] != null) ...[
                            SizedBox(height: 16),
                            Text(
                              'Información del Dueño',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text('Nombre: ${mascotaInfo!['dueño_info']['nombre'] ?? ''} ${mascotaInfo!['dueño_info']['apellido'] ?? ''}'),
                            Text('Teléfono: ${mascotaInfo!['dueño_info']['telefono'] ?? 'No disponible'}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
