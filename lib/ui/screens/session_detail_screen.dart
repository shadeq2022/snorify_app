import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/models/sesi.dart';
import 'package:snorify_app/core/models/sensor_reading.dart';
import 'package:snorify_app/core/providers/session_provider.dart';
import 'package:snorify_app/core/providers/ble_provider.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  // Zoom and pan controllers
  double _minX = 0;
  double _maxX = 0;
  double minY1 = 80; // SpO2 minimum
  double maxY1 = 100; // SpO2 maximum
  double minY2 = -0.2; // Snoring minimum
  double maxY2 = 1.2; // Snoring maximum
  
  @override
  void initState() {
    super.initState();
    
    // Load session data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SessionProvider>(context, listen: false).loadSessionById(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, _) {
        final session = sessionProvider.currentSession;
        final readings = sessionProvider.currentReadings;
        
        if (session == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Session Details'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        // Update chart X range if we have readings
        if (readings.isNotEmpty && _maxX == 0) {
          final startTime = readings.first.timestamp;
          final endTime = readings.last.timestamp;
          _minX = 0;
          _maxX = (endTime - startTime) / 60 + 1; // minutes
        }
        
        return Scaffold(
          appBar: AppBar(
            title: Text(session.nama),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditSessionDialog(context, session),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteConfirmationDialog(context, session.id!),
              ),
            ],
          ),
          body: Column(
            children: [
              // Session info card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              session.nama,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              session.tanggal,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${session.waktuMulai} - ${session.waktuSelesai ?? "In Progress"}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.timelapse, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              session.durasi != null ? '${session.durasi} minutes' : 'Duration not available',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        if (session.deviceId != null) ...[  
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.bluetooth, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Device ID: ${session.deviceId}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                        if (session.catatan != null && session.catatan!.isNotEmpty) ...[  
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Notes:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 4),
                          Text(session.catatan!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              // Statistics section
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
              //   child: Card(
              //     child: Padding(
              //       padding: const EdgeInsets.all(16.0),
              //       child: _buildStatisticsSection(readings, sessionProvider.snoringPercentage),
              //     ),
              //   ),
              // ),
              
              // Charts section
              Expanded(
                child: _buildChartsSection(readings, session),
              ),
            ],
          ),
          floatingActionButton: session.waktuSelesai == null
              ? FloatingActionButton.extended(
                  onPressed: () => _endSession(context, session),
                  icon: const Icon(Icons.stop),
                  label: const Text('End Session'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildStatisticsSection(List<SensorReading> readings, double snoringPercentage) {
    if (readings.isEmpty) {
      return const Center(child: Text('No data available for this session'));
    }
    
    // Calculate SpO2 statistics
    double avgSpO2 = 0;
    int minSpO2 = 100;
    int maxSpO2 = 0;
    
    for (var reading in readings) {
      avgSpO2 += reading.spo2;
      if (reading.spo2 < minSpO2) minSpO2 = reading.spo2;
      if (reading.spo2 > maxSpO2) maxSpO2 = reading.spo2;
    }
    
    avgSpO2 = avgSpO2 / readings.length;
    
    // Calculate snoring statistics
    final snoringCount = readings.where((r) => r.status == AppConstants.statusSnore).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow('Avg SpO₂', '${avgSpO2.toStringAsFixed(1)}%'),
                  _buildStatRow('Min SpO₂', '$minSpO2%'),
                  _buildStatRow('Max SpO₂', '$maxSpO2%'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow('Snoring %', '${snoringPercentage.toStringAsFixed(1)}%'),
                  _buildStatRow('Snoring Events', snoringCount.toString()),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsSection(List<SensorReading> readings, Sesi session) {
    if (readings.isEmpty) {
      return const Center(child: Text('No data available for this session'));
    }

    // Prepare timestamp to real time conversion
    final startTime = readings.first.timestamp;
    final sessionStartDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(
  '${session.tanggal} ${session.waktuMulai}'
);
    
    // Convert timestamp to device current time for tooltip
    String timestampToTime(int timestamp) {
      final secondsFromStart = timestamp - startTime;
      final currentTime = sessionStartDateTime.add(Duration(seconds: secondsFromStart));
      return DateFormat('HH:mm:ss').format(currentTime);
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GestureDetector(
        onDoubleTap: () {
          setState(() {
            // Reset zoom
            _minX = 0;
            _maxX = (readings.last.timestamp - startTime) / 60 + 1;
          });
        },
        child: Column(
          children: [
            // SpO2 Chart
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SpO₂', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildSpO2Chart(readings, startTime, timestampToTime),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Snoring Chart
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Snoring', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildSnoringChart(readings, startTime, timestampToTime),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSpO2Chart(List<SensorReading> readings, int startTime, Function timestampToTime) {
    // Prepare data points
    final spots = <FlSpot>[];
    
    for (var reading in readings) {
      // X-axis: minutes since start, Y-axis: SpO2 value
      final timeOffset = (reading.timestamp - startTime) / 60; // Convert seconds to minutes
      spots.add(FlSpot(timeOffset.toDouble(), reading.spo2.toDouble()));
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('${value.toInt()} min'),
                );
              },
              interval: 5,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('${value.toInt()}'),
                );
              },
              interval: 5,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: _minX,
        maxX: _maxX,
        minY: minY1,
        maxY: maxY1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final minutesFromStart = touchedSpot.x;
                final secondsFromStart = (minutesFromStart * 60).toInt();
                final timestamp = startTime + secondsFromStart;
                final time = timestampToTime(timestamp);
                
                return LineTooltipItem(
                  '${touchedSpot.y.toInt()}%\n$time',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildSnoringChart(List<SensorReading> readings, int startTime, Function timestampToTime) {
    // Prepare data points
    final spots = <FlSpot>[];
    
    for (var reading in readings) {
      // X-axis: minutes since start, Y-axis: 1 for snoring, 0 for not snoring
      final timeOffset = (reading.timestamp - startTime) / 60; // Convert seconds to minutes
      final isSnoring = reading.status == AppConstants.statusSnore ? 1.0 : 0.0;
      spots.add(FlSpot(timeOffset.toDouble(), isSnoring));
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('${value.toInt()} min'),
                );
              },
              interval: 5,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                final String label;
                if (value == 0) {
                  label = 'No';
                } else if (value == 1) {
                  label = 'Yes';
                } else {
                  label = '';
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(label),
                );
              },
              interval: 1,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: _minX,
        maxX: _maxX,
        minY: minY2,
        maxY: maxY2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.orange,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.2)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.orange.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final minutesFromStart = touchedSpot.x;
                final secondsFromStart = (minutesFromStart * 60).toInt();
                final timestamp = startTime + secondsFromStart;
                final time = timestampToTime(timestamp);
                final status = touchedSpot.y > 0 ? 'Snoring' : 'Not Snoring';
                
                return LineTooltipItem(
                  '$status\n$time',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  void _showEditSessionDialog(BuildContext context, Sesi session) {
    final nameController = TextEditingController(text: session.nama);
    final notesController = TextEditingController(text: session.catatan);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Session Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateSession(context, session, nameController.text, notesController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updateSession(BuildContext context, Sesi session, String name, String? notes) async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    final updatedSession = session.copyWith(
      nama: name,
      catatan: notes?.isNotEmpty == true ? notes : null,
    );
    
    await sessionProvider.updateSession(updatedSession);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session updated successfully')),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, int sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'Are you sure you want to delete this session? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSession(context, sessionId);
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _deleteSession(BuildContext context, int sessionId) async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    await sessionProvider.deleteSession(sessionId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session deleted successfully')),
      );
      Navigator.pop(context);
    }
  }

  void _endSession(BuildContext context, Sesi session) async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    // Get current time
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm:ss');
    final endTime = timeFormat.format(now);
    
    // Calculate duration in minutes
    final startTime = DateFormat('HH:mm:ss').parse(session.waktuMulai);
    final endTimeObj = DateFormat('HH:mm:ss').parse(endTime);
    final difference = endTimeObj.difference(startTime);
    final durationMinutes = difference.inMinutes;
    
    // Update session
    final updatedSession = session.copyWith(
      waktuSelesai: endTime,
      durasi: durationMinutes,
    );
    
    await sessionProvider.updateSession(updatedSession);
    
    // Disconnect from device
    bleProvider.disconnect();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session ended successfully')),
      );
    }
  }
}