import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
// import 'package:typed_data/src/typed_buffer.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  var _currentPosition;
  BitmapDescriptor? riderIcon;
  BitmapDescriptor? driverIcon;
  // MqttServerClient? driverClient;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCurrentLocation();
  }

  // driver icon
  void loadDriverIcon() async {
    driverIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/icons/ic_car.png',
    );
  }

  // rider icon
  void loadRiderIcon() async {
    riderIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/icons/ic_marker.png',
    );
  }

  //getting the current location
  void getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });
      loadRiderIcon();
      loadDriverIcon();
      mqttDriverApp();
    } catch (e) {
      print(e);
    }
  }

  final MqttServerClient driverClient =
      MqttServerClient.withPort("test.mosquitto.org", "DriverClient", 1883);

  mqttDriverApp() {
    driverClient.onConnected = onDriverConnected;
    driverClient.onDisconnected = onDriverDisconnected;
    driverClient.onSubscribed = onDriverSubscribed;
    driverClient.connect();
  }

  void onDriverConnected() {
    print('Driver client connected');
    publishDriverLocation();
  }

  void onDriverDisconnected() {
    print('Driver client disconnected');
  }

  void onDriverSubscribed(String topic) {
    print('Driver client subscribed to topic: $topic');
  }

  void publishDriverLocation() {
    final driverLocation =
        '${_currentPosition.latitude},${_currentPosition.longitude}';
    print(driverLocation); // Example driver location
    final builder = MqttClientPayloadBuilder();
    builder.addString(driverLocation);

    driverClient.publishMessage(
      'driver_location', // MQTT topic to publish to
      MqttQos.atLeastOnce, // Quality of Service level
      builder.payload!, // Location data payload
    );

    print('Driver location published: $driverLocation');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Map'),
      ),
      body: _currentPosition != null
          ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition.latitude,
                  _currentPosition.longitude,
                ), // Set the initial camera position
                zoom: 18.0, // Set the initial zoom level
              ),
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                setState(() {
                  _markers.add(
                    Marker(
                      markerId: MarkerId('Driver'),
                      position: LatLng(
                        _currentPosition.latitude,
                        _currentPosition.longitude,
                      ),
                      icon: driverIcon!,
                      infoWindow: InfoWindow(title: 'Current Location'),
                    ),
                  );
                });
                _controller.complete(controller);
              },
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
