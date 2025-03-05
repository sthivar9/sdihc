import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:sdihc/widgets/monthlySummaryCard.dart';
import 'package:sdihc/widgets/selling_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' show min, max;

class SalesChartPage extends StatefulWidget {
  const SalesChartPage({super.key});

  @override
  State<SalesChartPage> createState() => _SalesChartPageState();
}

class _SalesChartPageState extends State<SalesChartPage> {
  final _supabase = Supabase.instance.client;
  List<FlSpot> _spots = [];
  bool _isLoading = true;
  double _minY = 0;
  double _maxY = 0;
  DateTime _minX = DateTime.now();
  DateTime _maxX = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      final String? userId = user?.id;

      if (userId == null) {
        print('User not logged in');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not logged in')),
        );
        return;
      }

      print('Current user ID: $userId');

      // Fetch the user's class_id from the profiles table
      final profileResponse = await _supabase
          .from('profiles')
          .select('class_id')
          .eq('user_id', userId)
          .single();

      if (profileResponse == null) {
        print('Error fetching profile data');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not fetch profile data')),
        );
        return;
      }

      final String userClassId = profileResponse['class_id'];
      print('User class ID: $userClassId');

      // Calculate date range for the last 7 days
      final DateTime endDate = DateTime.now();
      final DateTime startDate = endDate
          .subtract(const Duration(days: 6)); // 6 days ago + today = 7 days

      // Set time to start of day for start date and end of day for end date
      final DateTime startOfDay =
          DateTime(startDate.year, startDate.month, startDate.day);
      final DateTime endOfDay =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      final String formattedStart = startOfDay.toIso8601String();
      final String formattedEnd = endOfDay.toIso8601String();

      print('Querying for dates between $formattedStart and $formattedEnd');

      // Fetch sales data for the user's class_id
      final response = await _supabase
          .from('sales')
          .select('date, amount, class_id')
          .eq('class_id', userClassId)
          .gte('date', formattedStart)
          .lte('date', formattedEnd)
          .order('date');

      if (response == null) {
        print('Error fetching sales data');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not fetch sales data')),
        );
        return;
      }

      print('Sales data response: $response');

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(response);

      if (data.isEmpty) {
        print('No sales data available for the user\'s class ID');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sales data available')),
          );
        }
      } else {
        print('Fetched ${data.length} records');

        // Process data to generate FlSpots
        _spots = [];
        // Create a map to store daily totals
        Map<String, double> dailyTotals = {};

        // Initialize all 7 days with 0 values
        for (int i = 0; i <= 6; i++) {
          String date =
              startDate.add(Duration(days: i)).toIso8601String().split('T')[0];
          dailyTotals[date] = 0.0;
        }

        // Sum up amounts for each day
        for (var sale in data) {
          String date = DateTime.parse(sale['date'].toString())
              .toIso8601String()
              .split('T')[0];
          double amount = (sale['amount'] as num).toDouble();
          dailyTotals[date] = (dailyTotals[date] ?? 0) + amount;
        }

        // Convert daily totals to FlSpots
        _spots = dailyTotals.entries.map((entry) {
          final date = DateTime.parse(entry.key);
          return FlSpot(date.millisecondsSinceEpoch.toDouble(), entry.value);
        }).toList();

        // Sort spots by date
        _spots.sort((a, b) => a.x.compareTo(b.x));

        // Calculate chart bounds if spots are available
        if (_spots.isNotEmpty) {
          _minX = startOfDay;
          _maxX = endOfDay;
          _minY = _spots.map((spot) => spot.y).reduce(min);
          _maxY = _spots.map((spot) => spot.y).reduce(max);
        }
      }
    } catch (e, stackTrace) {
      print('Error in _fetchData: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.maxFinite,
          height: double.maxFinite,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              Color.fromRGBO(25, 17, 58, 1),
              Color.fromRGBO(58, 49, 92, 1)
            ], begin: Alignment.bottomCenter, end: Alignment.topCenter),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Text(
                    "   Trends",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  MonthlyFinancialSummary(),
                  Past7DaysSellingPriceChart(),
                  AspectRatio(
                    aspectRatio: 2,
                    child: Container(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _spots.isEmpty
                              ? const Center(child: Text('No data available'))
                              : Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: LineChart(
                                    LineChartData(
                                      minX: _minX.millisecondsSinceEpoch
                                          .toDouble(),
                                      maxX: _maxX.millisecondsSinceEpoch
                                          .toDouble(),
                                      minY: _minY * 0.9,
                                      maxY: _maxY * 1.1,
                                      gridData: const FlGridData(show: true),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                value.toStringAsFixed(2),
                                                style: const TextStyle(
                                                    fontSize: 10),
                                              );
                                            },
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 30,
                                            interval: 24 *
                                                60 *
                                                60 *
                                                1000, // 1 day interval
                                            getTitlesWidget: (value, meta) {
                                              final date = DateTime
                                                  .fromMillisecondsSinceEpoch(
                                                      value.toInt());
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.all(4.0),
                                                child: Text(
                                                  DateFormat('MM/dd')
                                                      .format(date),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                      ),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: _spots,
                                          isCurved: true,
                                          color: Color.fromRGBO(72, 50, 174, 1),
                                          barWidth: 3,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                              show: true,
                                              color: Colors.blueAccent),
                                        ),
                                      ],
                                    ),
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
  }
}
