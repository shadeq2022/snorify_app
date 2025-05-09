import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:snorify_app/core/models/sensor_reading.dart';
import 'package:snorify_app/core/services/ble_service.dart';
import 'package:snorify_app/core/providers/session_provider.dart';


class BleProvider with ChangeNotifier {
  final BleService _bleService = BleService();

  // Stream subscriptions
  StreamSubscription<List<BluetoothDevice>>? _devicesSubscription;
  StreamSubscription<BluetoothDevice?>? _connectedDeviceSubscription;
  StreamSubscription<SensorReading>? _sensorReadingSubscription;

  // State variables
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  int _currentSesiId = -1;
  final Set<String> _connectingDevices = {};

  // Callbacks
  Function(SensorReading)? onSensorReadingReceived;

  // Getters
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  int get currentSesiId => _currentSesiId;

  // Constructor
  BleProvider() {
    // Initial initialization might happen here, but better to use the public method
  }

  // Public initialize method that can be called from UI
  Future<void> initialize() async {
    await _initialize();
  }

  // Initialize with session provider
  void initializeWithSessionProvider(SessionProvider sessionProvider) {
    // Set callback to handle sensor readings
    onSensorReadingReceived = (reading) {
      print('Sensor reading received in BleProvider: SpO2=${reading.spo2}, Status=${reading.status}');
      sessionProvider.addSensorReading(reading);
    };
    
    // Subscribe to sensor readings from BleService
    _sensorReadingSubscription?.cancel(); // Cancel any existing subscription
    _sensorReadingSubscription = _bleService.sensorReadings.listen((reading) {
      if (onSensorReadingReceived != null) {
        onSensorReadingReceived!(reading);
      }
    });
  }

  // Initialize BLE provider
  Future<void> _initialize() async {
    // Make sure BleService is initialized (permissions, adapter state listeners etc.)
    await _bleService.initialize();

    // Subscribe to streams from BleService
    _devicesSubscription = _bleService.devices.listen((devices) {
      _discoveredDevices = devices;
      notifyListeners();
      print('Discovered devices updated in BleProvider: ${_discoveredDevices.length}');
    });

    _connectedDeviceSubscription = _bleService.connectedDevice.listen((device) {
      _connectedDevice = device;
      _isConnected = device != null;
      notifyListeners();
      print('Connected device updated in BleProvider: ${device?.platformName}');
    });

    _sensorReadingSubscription = _bleService.sensorReadings.listen((reading) {
      if (onSensorReadingReceived != null) {
        onSensorReadingReceived!(reading);
      }
    });

    // Update state variables based on initial service state
    _isScanning = _bleService.isScanning;
    _isConnected = _bleService.isConnected; // This will be true if already connected on app start
    _currentSesiId = _bleService.currentSesiId; // Get initial session ID
    notifyListeners(); // Notify listeners about initial state
    print('BleProvider initialized. isConnected: $_isConnected, currentSesiId: $_currentSesiId');

  }

  // Set current session ID
  void setCurrentSesiId(int sesiId) {
    print('BleProvider: Setting currentSesiId to $sesiId');
    _currentSesiId = sesiId;
    _bleService.setCurrentSesiId(sesiId); // Pass to BleService
    notifyListeners();
  }


  // Start scanning for BLE devices
  Future<void> startScan() async {
    print('BleProvider: Calling startScan...');
    await _bleService.startScan();
    _isScanning = true; // Update state immediately
    notifyListeners();
    print('BleProvider: startScan initiated.');
  }

  // Stop scanning
  Future<void> stopScan() async {
    print('BleProvider: Calling stopScan...');
    await _bleService.stopScan();
    _isScanning = false; // Update state immediately
    notifyListeners();
    print('BleProvider: stopScan initiated.');
  }

  // Connect to a device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    print('BleProvider: Calling connectToDevice: ${device.platformName}');
    // Stop scanning before connecting
    if (_isScanning) {
      await stopScan();
    }
    _connectingDevices.add(device.id.id);
    notifyListeners();
    try {
      final result = await _bleService.connectToDevice(device);
      // State update handled by the stream listener from BleService
      print('BleProvider: connectToDevice result: $result');
      return result;
    } finally {
      _connectingDevices.remove(device.id.id);
      notifyListeners();
    }
  }

  // Check if a specific device is connecting
  bool isConnecting(BluetoothDevice device) {
    return _connectingDevices.contains(device.id.id);
  }

  // Check if any device is connecting
  bool isConnectingAny() {
    return _connectingDevices.isNotEmpty;
  }

  // Disconnect from current device
  Future<void> disconnect() async {
    print('BleProvider: Calling disconnect');
    await _bleService.disconnect();
    // State update handled by the stream listener from BleService
    print('BleProvider: disconnect initiated.');
  }

  // Dispose resources
  @override
  void dispose() {
    print('BleProvider: Disposing subscriptions');
    _devicesSubscription?.cancel();
    _connectedDeviceSubscription?.cancel();
    _sensorReadingSubscription?.cancel();
    // Do NOT dispose BleService here if it's a singleton intended to live longer than the provider
    // If BleService is a true singleton managed globally, it shouldn't be disposed here.
    // BleService().dispose(); // <-- Only call this if BleService is NOT a persistent singleton
    super.dispose();
  }
}