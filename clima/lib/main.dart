import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const ClimaApp());
}

class ClimaApp extends StatelessWidget {
  const ClimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: const PantallaClima(),
    );
  }
}

class PantallaClima extends StatefulWidget {
  const PantallaClima({super.key});

  @override
  State<PantallaClima> createState() => _PantallaClimaState();
}

class _PantallaClimaState extends State<PantallaClima> {
  double _temperatura = 0;
  String _ciudad = "Cargando...";
  String _descripcion = "";
  bool _isLoading = true;
  String _errorMessage = "";
  String _weatherIcon = "☀️";
  double _latitud = 40.4168;
  double _longitud = -3.7038;
  String _horaActual = "";
  double _sensacionTermica = 0;
  int _humedad = 0;
  double _velocidadViento = 0;

  @override
  void initState() {
    super.initState();
    _initClima();
    _actualizarHora();
  }

  void _actualizarHora() {
    final now = DateTime.now();
    setState(() {
      _horaActual = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _initClima() async {
    try {
      final tienePermisos = await _verificarPermisos();
      if (!tienePermisos) {
        throw Exception("Permisos de ubicación no concedidos");
      }

      await _obtenerUbicacion();
      await _obtenerClima();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  Future<bool> _verificarPermisos() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _obtenerUbicacion() async {
    try {
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _latitud = posicion.latitude;
        _longitud = posicion.longitude;
        _ciudad = "Tu ubicación";
      });
    } catch (e) {
      throw Exception("No se pudo obtener la ubicación");
    }
  }

  Future<void> _obtenerClima() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
            'latitude=$_latitud&longitude=$_longitud&'
            'current_weather=true&hourly=temperature_2m,relativehumidity_2m,windspeed_10m&timezone=auto',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _procesarDatosClima(data);
      } else {
        throw Exception("Error en la API: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error al obtener el clima: ${e.toString()}");
    }
  }

  void _procesarDatosClima(Map<String, dynamic> data) {
    final weatherData = data['current_weather'];
    final weatherCode = weatherData['weathercode'];
    final hourly = data['hourly'];
    final now = DateTime.now();
    final currentHourIndex = now.hour;

    setState(() {
      _temperatura = weatherData['temperature'];
      _descripcion = _obtenerDescripcionClima(weatherCode);
      _weatherIcon = _obtenerIconoClima(weatherCode);
      _sensacionTermica = _temperatura - 2; // Simulación de sensación térmica
      _humedad = (hourly['relativehumidity_2m'] as List).length > currentHourIndex
          ? (hourly['relativehumidity_2m'][currentHourIndex]?.toInt() ?? 60)
          : 60;
      _velocidadViento = (hourly['windspeed_10m'] as List).length > currentHourIndex
          ? (hourly['windspeed_10m'][currentHourIndex]?.toDouble() ?? 10.0)
          : 10.0;
      _isLoading = false;
      _errorMessage = "";
    });
  }

  String _obtenerDescripcionClima(int weatherCode) {
    switch (weatherCode) {
      case 0: return "Despejado";
      case 1: return "Parcialmente nublado";
      case 2: return "Nublado";
      case 3: return "Cubierto";
      case 45: case 48: return "Niebla";
      case 51: case 53: case 55: return "Llovizna";
      case 61: case 63: case 65: return "Lluvia";
      case 80: case 81: case 82: return "Lluvia intensa";
      default: return "Condición desconocida";
    }
  }

  String _obtenerIconoClima(int weatherCode) {
    switch (weatherCode) {
      case 0: return "☀️";
      case 1: return "⛅";
      case 2: return "☁️";
      case 3: return "🌫️";
      case 45: case 48: return "🌁";
      case 51: case 53: case 55: return "🌧️";
      case 61: case 63: case 65: return "🌧️";
      case 80: case 81: case 82: return "🌧️💨";
      default: return "❓";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Clima Actual", style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white
        )),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on, color: Colors.white),
            onPressed: _initClima,
          ),
        ],
      ),
      body: _buildContenido(),
    );
  }

  Widget _buildContenido() {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[400]!,
              Colors.blue[600]!,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCircle(
                color: Colors.white,
                size: 50.0,
              ),
              const SizedBox(height: 20),
              Text("Obteniendo datos del clima...",
                  style: GoogleFonts.poppins(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[400]!,
              Colors.blue[600]!,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 50, color: Colors.white),
                const SizedBox(height: 20),
                Text(_errorMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                    )),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: _initClima,
                  child: Text("Reintentar",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _getBackgroundGradient(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Tarjeta principal del clima
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue[400]!,
                                Colors.blue[600]!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_ciudad,
                                          style: GoogleFonts.poppins(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          )),
                                      Text(_horaActual,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: Colors.white.withOpacity(0.8),
                                          )),
                                    ],
                                  ),
                                  Text(_weatherIcon,
                                      style: const TextStyle(fontSize: 40)),
                                ],
                              ),
                              const SizedBox(height: 30),
                              Text("$_temperatura°",
                                  style: GoogleFonts.poppins(
                                    fontSize: 80,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                  )),
                              Text(_descripcion,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    color: Colors.white,
                                  )),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Tarjetas de información adicional
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.air,
                              title: "Viento",
                              value: "${_velocidadViento.toStringAsFixed(1)} km/h",
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.water_drop,
                              title: "Humedad",
                              value: "$_humedad%",
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.thermostat,
                              title: "Sensación",
                              value: "${_sensacionTermica.toStringAsFixed(1)}°",
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.location_on,
                              title: "Ubicación",
                              value: "${_latitud.toStringAsFixed(2)}, ${_longitud.toStringAsFixed(2)}",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Text("Actualizado: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.blue),
            const SizedBox(height: 8),
            Text(title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 5),
            Text(value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                )),
          ],
        ),
      ),
    );
  }

  List<Color> _getBackgroundGradient() {
    if (_descripcion.contains("Lluvia") || _descripcion.contains("Llovizna")) {
      return [Colors.grey[600]!, Colors.grey[800]!];
    } else if (_descripcion.contains("Nublado") || _descripcion.contains("Cubierto")) {
      return [Colors.grey[400]!, Colors.grey[600]!];
    } else if (_descripcion.contains("Niebla")) {
      return [Colors.grey[300]!, Colors.grey[500]!];
    } else {
      // Día soleado/despejado
      return [Colors.blue[400]!, Colors.blue[600]!];
    }
  }
}