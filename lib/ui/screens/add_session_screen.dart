import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/models/sesi.dart';
import 'package:snorify_app/core/providers/ble_provider.dart';
import 'package:snorify_app/core/providers/session_provider.dart';
import 'package:snorify_app/ui/screens/session_detail_screen.dart';

class AddSessionScreen extends StatefulWidget {
  const AddSessionScreen({super.key});

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isScanning = false;
  BluetoothDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    // Initialize BLE provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BleProvider>(context, listen: false).initialize();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _startScan() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);

    // Check if Bluetooth is enabled
    bool isBluetoothOn = await FlutterBluePlus.isOn;
    if (!isBluetoothOn) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Bluetooth is Off'),
              content: const Text('Turn on Bluetooth to scan for devices?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Turn On'),
                  onPressed: () async {
                    try {
                      await FlutterBluePlus.turnOn();
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to turn on Bluetooth. Please enable it manually.',
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
    });

    bleProvider.startScan();

    // Auto-stop scan after duration
    Future.delayed(Duration(seconds: AppConstants.scanDuration), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        bleProvider.stopScan();
      }
    });
  }

  void _stopScan() {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    setState(() {
      _isScanning = false;
    });
    bleProvider.stopScan();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);

    final result = await bleProvider.connectToDevice(device);

    if (mounted) {
      setState(() {
        _selectedDevice = device;
      });

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name}'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to device')),
        );
      }
    }
  }

  Future<void> _createSession() async {
    if (_formKey.currentState!.validate()) {
      final sessionProvider = Provider.of<SessionProvider>(
        context,
        listen: false,
      );
      final bleProvider = Provider.of<BleProvider>(context, listen: false);

      // Get current date and time
      final now = DateTime.now();
      final dateFormat = DateFormat('yyyy-MM-dd');
      final timeFormat = DateFormat('HH:mm:ss');

      // Create session
      final sesi = Sesi(
        nama: _nameController.text,
        tanggal: dateFormat.format(now),
        waktuMulai: timeFormat.format(now),
        deviceId: _selectedDevice?.id.id,
        catatan:
            _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // Save to database
      final sesiId = await sessionProvider.createSession(sesi);

      // Set current session ID for BLE service
      bleProvider.setCurrentSesiId(sesiId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session created successfully')),
        );

        // Navigate to session detail screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SessionDetailScreen(sessionId: sesiId),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, _) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Session',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Session name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Session Name',
                          hintText: 'Enter a name for this session',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a session name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'Add any notes about this session',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Device selection section
                      const Text(
                        'Connect to Device',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Selected device
                      if (_selectedDevice != null) ...[
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.bluetooth_connected),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedDevice!.name.isNotEmpty
                                            ? _selectedDevice!.name
                                            : 'Unknown Device',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(_selectedDevice!.id.id),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    bleProvider.disconnect();
                                    setState(() {
                                      _selectedDevice = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Scan button
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? _stopScan : _startScan,
                            icon: Icon(
                              _isScanning
                                  ? Icons.stop
                                  : Icons.bluetooth_searching,
                            ),
                            label: Text(
                              _isScanning ? 'Stop Scan' : 'Scan for Devices',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Device list
                      if (_isScanning ||
                          bleProvider.discoveredDevices.isNotEmpty) ...[
                        const Text(
                          'Available Devices',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Loading indicator during scanning
                        if (_isScanning) ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ],

                        // Device list
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: bleProvider.discoveredDevices.length,
                            itemBuilder: (context, index) {
                              final device =
                                  bleProvider.discoveredDevices[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                child: ListTile(
                                  leading: const Icon(Icons.bluetooth),
                                  title: Text(
                                    device.name.isNotEmpty
                                        ? device.name
                                        : 'Unknown Device',
                                  ),
                                  subtitle: Text(device.id.id),
                                  trailing:
                                      bleProvider.isConnecting(device)
                                          ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Icon(Icons.chevron_right),
                                  onTap:
                                      bleProvider.isConnecting(device) ||
                                              !device.name
                                                  .toLowerCase()
                                                  .contains('esp32')
                                          ? null
                                          : () => _connectToDevice(device),
                                  enabled: device.name.toLowerCase().contains(
                                    'esp32',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Create session button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed:
                              (_selectedDevice != null &&
                                      !bleProvider.isConnectingAny())
                                  ? _createSession
                                  : null,
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Create Session'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
