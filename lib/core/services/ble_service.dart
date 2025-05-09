import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/models/sensor_reading.dart';


class BleService with ChangeNotifier {
  // Singleton pattern
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // ESP32C3 BLE Service and Characteristic UUIDs
  // Service UUID yang terdeteksi di nRFConnect:
  static const String esp32ServiceUuid = "12345678-1234-5678-1234-56789abcdef0";
  // Characteristic UUID untuk Notifikasi:
  static const String esp32CharacteristicUuid = "87654321-4321-8765-4321-123456789abc";
  // MAC Address ESP32 yang terdeteksi: 64:E8:33:87:53:4E


  // Stream controllers
  final StreamController<List<BluetoothDevice>> _devicesController =
      StreamController<List<BluetoothDevice>>.broadcast();
  final StreamController<BluetoothDevice?> _connectedDeviceController =
      StreamController<BluetoothDevice?>.broadcast();
  final StreamController<SensorReading> _sensorReadingController =
      StreamController<SensorReading>.broadcast();

  // Streams
  Stream<List<BluetoothDevice>> get devices => _devicesController.stream;
  Stream<BluetoothDevice?> get connectedDevice => _connectedDeviceController.stream;
  Stream<SensorReading> get sensorReadings => _sensorReadingController.stream;

  // State variables
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothDevice? _currentDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  int _currentSesiId = -1; // Default invalid session ID

  // Getters
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  BluetoothDevice? get currentDevice => _currentDevice;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  int get currentSesiId => _currentSesiId;

  // Set current session ID
  void setCurrentSesiId(int sesiId) {
    print('BleService: Setting currentSesiId to $sesiId');
    _currentSesiId = sesiId;
    notifyListeners();
  }

  // Initialize BLE service
  Future<void> initialize() async {
    print('BleService: Initializing...');
    // Request permissions
    await _requestPermissions();

    // Check if adapter is available and on
    if (!await FlutterBluePlus.isSupported) {
      print("BleService: BLE not supported by this device");
      // Handle this case, maybe show an error to the user
      return;
    }

    // Wait for the adapter to be powered on
    print("BleService: Waiting for Bluetooth adapter to be on...");
    await FlutterBluePlus.adapterState
        .map((state) {
          print('BleService: Adapter state changed to: $state');
          return state == BluetoothAdapterState.on;
        })
        .firstWhere((isOn) => isOn);
    print("BleService: Bluetooth adapter is on.");


    // Check initial connection state
    List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
    if (connectedDevices.isNotEmpty) {
      // Optional: Try to find the specific device if multiple are connected
      _currentDevice = connectedDevices.first; // Assuming the first one is ours
      _isConnected = true;
      _connectedDeviceController.add(_currentDevice);
      print('BleService: Found already connected device: ${_currentDevice?.platformName}');
      // Re-discover services and set up notifications if needed on app restart
      _discoverServices();
      notifyListeners();
    } else {
        print('BleService: No devices already connected.');
      }


    // Listen to connection state changes of the *current* device
    // This listener is better set up per device after connection
    // A global listener on adapterState mainly tells us if BT is on/off

    print('BleService: Initialization complete.');
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    print('BleService: Requesting permissions...');
    // Request location permission (required for BLE scanning on Android)
    var locationStatus = await Permission.location.request();
    print('BleService: Location permission status: $locationStatus');

    // Request Bluetooth permissions (newer Android versions)
    var bluetoothScanStatus = await Permission.bluetoothScan.request();
    print('BleService: Bluetooth Scan permission status: $bluetoothScanStatus');
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    print('BleService: Bluetooth Connect permission status: $bluetoothConnectStatus');
    var bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.request(); // Useful if you were acting as server too
     print('BleService: Bluetooth Advertise permission status: $bluetoothAdvertiseStatus');


    // Check if necessary permissions are granted
    if (!locationStatus.isGranted || !bluetoothScanStatus.isGranted || !bluetoothConnectStatus.isGranted) {
      print('BleService: Necessary BLE permissions not granted!');
      // You might want to inform the user or open app settings
    } else {
        print('BleService: All necessary BLE permissions granted.');
      }
  }

  // Helper function to log all scan results before filtering
  void _logScanResults(List<ScanResult> results) {
      print('--- Raw Scan Results ---');
      if (results.isEmpty) {
          print('No devices found during this scan result batch.');
      } else {
          for (ScanResult result in results) {
              print('Device Found:');
              print('- Platform Name: ${result.device.platformName}');
              print('- Device ID: ${result.device.remoteId}');
              print('- RSSI: ${result.rssi}');
              print('- Advertised Name: ${result.advertisementData.localName}');
              print('- Advertised Services: ${result.advertisementData.serviceUuids}');
              print('- Manufacturer Data: ${result.advertisementData.manufacturerData}');
              print('- Service Data: ${result.advertisementData.serviceData}');
              print('- TX Power Level: ${result.advertisementData.txPowerLevel}');
              print('- Connectable: ${result.advertisementData.connectable}');
              
              // Check if this is our target ESP32 device
              bool nameMatches = true;
              bool serviceMatches = result.advertisementData.serviceUuids.contains(AppConstants.esp32ServiceUuid.toLowerCase());
              print('- Name Matches ("ESP32"): $nameMatches');
              print('- Service Matches: $serviceMatches');
              print('- Is Target Device: ${nameMatches || serviceMatches}');
              print('---');
          }
      }
      print('--- End Raw Scan Results ---');
  }


  // Start scanning for BLE devices
  Future<void> startScan() async {
    print('BleService: Starting scan...');
    if (_isScanning) {
        print('BleService: Scan is already running.');
        return;
      }

    // Check if adapter is on before scanning
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
         print('BleService: Cannot start scan, Bluetooth adapter is off.');
         // Optionally notify UI or handle error
         return;
    }


    // Check if location services are enabled
    if (!await Permission.location.serviceStatus.isEnabled) {
        print('BleService: Location services are not enabled. Prompting user to enable them.');
        // Optionally, prompt the user to enable location services
        return;
    }


    // Clear previous results
    _discoveredDevices = [];
    _devicesController.add(_discoveredDevices);

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: AppConstants.scanDuration),
      // Removed: allowDuplicates: false, // This parameter is not available
    );

    _isScanning = true;
    notifyListeners(); // Notify UI that scanning has started

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) async {
      // Log all raw scan results first
      _logScanResults(results);

      // Store all devices without filtering
      _discoveredDevices = results
          .map((result) => result.device)
          .toList();
      
      // Log all discovered devices
      for (BluetoothDevice device in _discoveredDevices) {
        print('BleService: Discovered device - Name: ${device.platformName}, MAC: ${device.remoteId}');
      }

      // Print devices found
      print('BleService: Devices found: ${_discoveredDevices.length}');
      for (BluetoothDevice device in _discoveredDevices) {
        print('BleService: Device: ${device.platformName} (${device.remoteId})');
      }

      // Update stream
      _devicesController.add(_discoveredDevices);
      notifyListeners(); // Notify UI about updated device list
    }).onDone(() {
        // This is called when the scan times out or is stopped manually
        print('BleService: Scan finished.');
        _isScanning = false;
        notifyListeners();
    });
  }

  // Stop scanning
  Future<void> stopScan() async {
    print('BleService: Stopping scan...');
    await FlutterBluePlus.stopScan();
    // State update happens in the onDone callback of the scanResults listen
  }

  // Connect to a device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    print('BleService: Attempting to connect to ${device.platformName}');
    try {
      // Listen for the specific device's connection state changes
      StreamSubscription<BluetoothConnectionState>? connectionStateSubscription;
      connectionStateSubscription = device.connectionState.listen((state) async {
          print('BleService: Device ${device.platformName} connection state: $state');
          if (state == BluetoothConnectionState.disconnected) {
              // Handle disconnection
              print('BleService: Device ${device.platformName} disconnected.');
              _currentDevice = null;
              _isConnected = false;
              _connectedDeviceController.add(null);
              notifyListeners();
              await connectionStateSubscription?.cancel(); // Cancel listener after disconnect
          } else if (state == BluetoothConnectionState.connected) {
              // Handle successful connection
              print('BleService: Device ${device.platformName} connected successfully.');
              _currentDevice = device;
              _isConnected = true;
              _connectedDeviceController.add(_currentDevice);
              notifyListeners();
               // Discover services after successful connection
              _discoverServices(); // Moved service discovery here
          }
      });


      await device.connect(); // This call completes when the connection is established
      print('BleService: connect() method finished.');

      return true; // Connection process initiated successfully
    } catch (e) {
      print('BleService: Error connecting to device: $e');
      // Clean up state if connection failed
      _currentDevice = null;
      _isConnected = false;
      _connectedDeviceController.add(null);
      notifyListeners();
      return false;
    }
  }

  // Disconnect from current device
  Future<void> disconnect() async {
    print('BleService: Attempting to disconnect from ${_currentDevice?.platformName}');
    if (_currentDevice != null) {
      try {
        await _currentDevice!.disconnect();
        print('BleService: disconnect() method finished.');
        // State update happens in the connectionState listener
      } catch (e) {
        print('BleService: Error during disconnection: $e');
        // Even if error, try to update state to disconnected
        _currentDevice = null;
        _isConnected = false;
        _connectedDeviceController.add(null);
        notifyListeners();
      }
    } else {
        print('BleService: No device currently connected to disconnect.');
      }
  }

  // Discover services and set up notifications
  Future<void> _discoverServices() async {
    if (_currentDevice == null) {
      print('BleService: Cannot discover services, no device connected.');
      return;
    }

    try {
      print('BleService: Discovering services for device: ${_currentDevice!.platformName}');
      List<BluetoothService> services = await _currentDevice!.discoverServices();
      print('BleService: Found ${services.length} services');

      bool foundTargetCharacteristic = false;

      for (BluetoothService service in services) {
        print('BleService: Discovered Service UUID: ${service.uuid.toString().toLowerCase()}');

        // Check if this is our target Service UUID (matching the ESP32 Server Service UUID)
        if (service.uuid.toString().toLowerCase() == esp32ServiceUuid.toLowerCase()) {
          print('BleService: Found target ESP32C3 service.');

          // Look for the sensor data characteristic within this service
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            print('BleService: Discovered Characteristic UUID: ${characteristic.uuid.toString().toLowerCase()}, Properties: ${characteristic.properties}');

            // Check if this is our target Characteristic UUID
            if (characteristic.uuid.toString().toLowerCase() == esp32CharacteristicUuid.toLowerCase()) {
              print('BleService: Found target ESP32C3 characteristic.');

              // Subscribe to notifications if the characteristic supports it
              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);
                print('BleService: Subscribed to notifications for target characteristic.');

                // Listen to value changes on this characteristic
                characteristic.value.listen((value) {
                  if (value.isNotEmpty && _currentSesiId != -1) {
                    // Parse the data
                    _handleSensorData(value);
                  } else if (value.isEmpty) {
                         print('BleService: Received empty data from characteristic.');
                  } else if (_currentSesiId == -1) {
                         print('BleService: Received data but currentSesiId is -1. Data: ${String.fromCharCodes(value)}');
                  }
                });
                foundTargetCharacteristic = true; // Found and subscribed
                break; // Stop looking for characteristic in this service
              } else {
                  print('BleService: Target characteristic does NOT support notify.');
              }
            }
          }
          // If we found the service, we can potentially break here if we only care about the specific service
          // break;
        }
      }

      // Optional: Fallback if the exact service/characteristic wasn't found
      if (!foundTargetCharacteristic) {
        print('BleService: Target service or characteristic not found. Trying generic approach for notify characteristic.');
        // This generic fallback is less reliable but might work if UUIDs aren't matched exactly
        for (BluetoothService service in services) {
          try {
            for (BluetoothCharacteristic characteristic in service.characteristics) {
              if (characteristic.properties.notify) {
                print('BleService: Found generic characteristic with notify: ${characteristic.uuid.toString().toLowerCase()}');
                await characteristic.setNotifyValue(true);
                print('BleService: Subscribed to notifications for generic characteristic.');
                characteristic.value.listen(
                  (value) {
                    if (value.isNotEmpty && _currentSesiId != -1) {
                      _handleSensorData(value);
                    }
                  },
                  onError: (error) {
                    print('BleService: Error receiving notification on generic characteristic: $error');
                  }
                );
                // Note: This generic approach will subscribe to *all* notify characteristics found.
                // If you only expect data from one, this might be fine.
                // If you found *any* notify characteristic, you might consider `foundTargetCharacteristic = true;` here
                // and potentially break out of these loops if one is sufficient.
              }
            }
          } catch (e) {
            print('BleService: Error setting up notifications for a generic service: $e');
            continue;
          }
        }
      }

    } catch (e) {
      print('BleService: Error discovering services: $e');
      // Rethrow or handle appropriately
      throw Exception('Failed to discover BLE services: $e');
    }
  }

  // Handle sensor data received from BLE
  void _handleSensorData(List<int> data) {
    try {
      // Convert bytes to string
      String jsonString = utf8.decode(data); // Use utf8.decode for potentially non-ASCII chars
      print('BleService: Received raw data: $data'); // Log raw bytes too
      print('BleService: Received data as string: $jsonString');

      // Parse JSON
      Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // Validate required fields
      if (!jsonData.containsKey(AppConstants.keyStatus) ||
          !jsonData.containsKey(AppConstants.keyTimestamp) ||
          !jsonData.containsKey(AppConstants.keySpo2)) {
        print('BleService: Invalid data format: missing required fields in JSON: $jsonString');
        return;
      }

      // Create sensor reading object
      // Ensure _currentSesiId is valid before creating reading
      if (_currentSesiId != -1) {
             SensorReading reading = SensorReading.fromEsp32c3Json(jsonData, _currentSesiId);
             print('BleService: Created sensor reading: SesiId=${reading.sesiId}, SpO2=${reading.spo2}, Status=${reading.status}, Timestamp=${reading.timestamp}');

             // Add to stream
             _sensorReadingController.add(reading);
         } else {
              print('BleService: Received data but _currentSesiId is invalid (-1). Cannot create SensorReading.');
         }

    } catch (e) {
      print('BleService: Error processing sensor data: $e, Data: ${String.fromCharCodes(data)}');
    }
  }

  // Dispose resources
  // Note: For a true singleton BleService, this dispose method might not be called
  // unless the entire app is shutting down BLE operations specifically.
  @override
  void dispose() {
    print('BleService: Disposing controllers');
    // It's generally safe to close StreamControllers when done
    _devicesController.close();
    _connectedDeviceController.close();
    _sensorReadingController.close();

    // Note: FlutterBluePlus itself doesn't typically need explicit dispose calls
    // in the same way as controllers, it's more globally managed.

    super.dispose(); // Call ChangeNotifier dispose
  }
}