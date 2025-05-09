import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';

import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/models/sesi.dart';
import 'package:snorify_app/core/models/sensor_reading.dart';
import 'package:snorify_app/core/providers/session_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedSessionIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize session data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SessionProvider>(context, listen: false).initialize();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, _) {
        final sessions = sessionProvider.sessions;
        
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistics',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Session selector
                  if (sessions.isNotEmpty) ...[  
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Select Session',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedSessionIndex < sessions.length ? _selectedSessionIndex : 0,
                      items: List.generate(sessions.length, (index) {
                        final session = sessions[index];
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text('${session.nama} (${session.tanggal})'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSessionIndex = value;
                          });
                          sessionProvider.loadSessionById(sessions[value].id!);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'SpO₂ Data'),
                        Tab(text: 'Snoring Analysis'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // SpO₂ Tab
                          _buildSpO2Tab(sessionProvider),
                          
                          // Snoring Tab
                          _buildSnoringTab(sessionProvider),
                        ],
                      ),
                    ),
                    
                    // Export and share buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _generateAndPrintPDF(sessionProvider, sessions[_selectedSessionIndex]),
                          icon: const Icon(Icons.print),
                          label: const Text('Export PDF'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _shareReport(sessionProvider, sessions[_selectedSessionIndex]),
                          icon: const Icon(Icons.share),
                          label: const Text('Share Report'),
                        ),
                      ],
                    ),
                  ] else ...[  
                    const Expanded(
                      child: Center(
                        child: Text('No sessions available. Create a session to view statistics.'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpO2Tab(SessionProvider sessionProvider) {
    final readings = sessionProvider.currentReadings;
    
    if (readings.isEmpty) {
      return const Center(child: Text('No SpO₂ data available for this session'));
    }
    
    // Calculate statistics
    final avgSpO2 = sessionProvider.averageSpO2;
    int minSpO2 = 100;
    int maxSpO2 = 0;
    int belowNormalCount = 0;
    
    for (var reading in readings) {
      if (reading.spo2 < minSpO2) minSpO2 = reading.spo2;
      if (reading.spo2 > maxSpO2) maxSpO2 = reading.spo2;
      if (reading.spo2 < AppConstants.spo2Normal) belowNormalCount++;
    }
    
    final belowNormalPercentage = readings.isNotEmpty 
        ? (belowNormalCount / readings.length * 100).toStringAsFixed(1) 
        : '0.0';
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SpO₂ statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SpO₂ Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildStatRow('Average SpO₂', '${avgSpO2.toStringAsFixed(1)}%'),
                  _buildStatRow('Minimum SpO₂', '$minSpO2%'),
                  _buildStatRow('Maximum SpO₂', '$maxSpO2%'),
                  _buildStatRow('Below Normal', '$belowNormalPercentage% of time'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // SpO₂ chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SpO₂ Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildSpO2Chart(readings),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnoringTab(SessionProvider sessionProvider) {
    final readings = sessionProvider.currentReadings;
    
    if (readings.isEmpty) {
      return const Center(child: Text('No snoring data available for this session'));
    }
    
    // Calculate statistics
    final snoringPercentage = sessionProvider.snoringPercentage;
    final snoringCount = readings.where((r) => r.status == AppConstants.statusSnore).length;
    final totalDuration = sessionProvider.currentSession?.durasi ?? 0;
    final snoringMinutes = totalDuration > 0 
        ? (totalDuration * snoringPercentage / 100).round() 
        : 0;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Snoring statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Snoring Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildStatRow('Snoring Percentage', '${snoringPercentage.toStringAsFixed(1)}%'),
                  _buildStatRow('Snoring Events', snoringCount.toString()),
                  _buildStatRow('Estimated Snoring Time', '$snoringMinutes minutes'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Snoring distribution chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Snoring Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildSnoringPieChart(snoringPercentage),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // SpO₂ vs Snoring correlation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SpO₂ vs Snoring Correlation', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildCorrelationChart(readings),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildSpO2Chart(List<SensorReading> readings) {
    if (readings.isEmpty) return const Center(child: Text('No data available'));
    
    // Prepare data points
    final spots = <FlSpot>[];
    final startTime = readings.first.timestamp;
    
    for (var i = 0; i < readings.length; i++) {
      final reading = readings[i];
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('${value.toInt()}%'),
                );
              },
              interval: 5,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (readings.last.timestamp - startTime) / 60 + 1,
        minY: 80, // SpO2 minimum
        maxY: 100, // SpO2 maximum
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueAccent,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                return LineTooltipItem(
                  'SpO₂: ${touchedSpot.y.toInt()}%\n${touchedSpot.x.toInt()} min',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSnoringPieChart(double snoringPercentage) {
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            color: Colors.orange,
            value: snoringPercentage,
            title: '${snoringPercentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            color: Colors.green,
            value: 100 - snoringPercentage,
            title: '${(100 - snoringPercentage).toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationChart(List<SensorReading> readings) {
    if (readings.isEmpty) return const Center(child: Text('No data available'));
    
    // Group readings by snoring status
    final snoringReadings = readings.where((r) => r.status == AppConstants.statusSnore).toList();
    final nonSnoringReadings = readings.where((r) => r.status == AppConstants.statusNoSnore).toList();
    
    // Calculate average SpO2 for each group
    final avgSnoringSpO2 = snoringReadings.isNotEmpty 
        ? snoringReadings.map((r) => r.spo2).reduce((a, b) => a + b) / snoringReadings.length 
        : 0.0;
    final avgNonSnoringSpO2 = nonSnoringReadings.isNotEmpty 
        ? nonSnoringReadings.map((r) => r.spo2).reduce((a, b) => a + b) / nonSnoringReadings.length 
        : 0.0;
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        minY: 80,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueAccent,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${groupIndex == 0 ? 'Non-Snoring' : 'Snoring'}\nAvg SpO₂: ${rod.toY.toStringAsFixed(1)}%',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    value == 0 ? 'Non-Snoring' : 'Snoring',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('${value.toInt()}%'),
                );
              },
              interval: 5,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: avgNonSnoringSpO2,
                color: Colors.green,
                width: 12,
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: avgSnoringSpO2,
                color: Colors.orange,
                width: 12,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintPDF(SessionProvider sessionProvider, Sesi session) async {
    final pdf = pw.Document();
    
    // Add content to PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(level: 0, text: 'Snorify Sleep Report'),
              pw.SizedBox(height: 20),
              
              // Session info
              pw.Text('Session: ${session.nama}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: ${session.tanggal}'),
              pw.Text('Time: ${session.waktuMulai} - ${session.waktuSelesai ?? "In Progress"}'),
              pw.Text('Duration: ${session.durasi ?? "N/A"} minutes'),
              if (session.catatan != null && session.catatan!.isNotEmpty)
                pw.Text('Notes: ${session.catatan}'),
              pw.SizedBox(height: 20),
              
              // SpO2 Statistics
              pw.Text('SpO₂ Statistics', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Average SpO₂')),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${sessionProvider.averageSpO2.toStringAsFixed(1)}%')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Snoring Percentage')),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${sessionProvider.snoringPercentage.toStringAsFixed(1)}%')),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Summary
              pw.Paragraph(text: 'This report was generated by Snorify App on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}.'),
            ],
          );
        },
      ),
    );
    
    // Print or save PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _shareReport(SessionProvider sessionProvider, Sesi session) async {
    // Generate PDF file
    final pdf = pw.Document();
    
    // Add content to PDF (same as print function)
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(level: 0, text: 'Snorify Sleep Report'),
              pw.SizedBox(height: 20),
              
              // Session info
              pw.Text('Session: ${session.nama}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: ${session.tanggal}'),
              pw.Text('Time: ${session.waktuMulai} - ${session.waktuSelesai ?? "In Progress"}'),
              pw.Text('Duration: ${session.durasi ?? "N/A"} minutes'),
              if (session.catatan != null && session.catatan!.isNotEmpty)
                pw.Text('Notes: ${session.catatan}'),
              pw.SizedBox(height: 20),
              
              // SpO2 Statistics
              pw.Text('SpO₂ Statistics', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Average SpO₂')),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${sessionProvider.averageSpO2.toStringAsFixed(1)}%')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Snoring Percentage')),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${sessionProvider.snoringPercentage.toStringAsFixed(1)}%')),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Summary
              pw.Paragraph(text: 'This report was generated by Snorify App on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}.'),
            ],
          );
        },
      ),
    );
    
    // Save PDF to temporary file
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/snorify_report_${session.id}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    // Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Snorify Sleep Report - ${session.nama}',
    );
  }
}