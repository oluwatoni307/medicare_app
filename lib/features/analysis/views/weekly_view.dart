// lib/features/analysis/views/weekly_view.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:medicare_app/theme.dart';
import 'package:provider/provider.dart';
import '../analysis_viewmodel.dart';
import '../analysis_model.dart';

class WeeklyView extends StatefulWidget {
  const WeeklyView({Key? key}) : super(key: key);

  @override
  State<WeeklyView> createState() => _WeeklyViewState();
}

class _WeeklyViewState extends State<WeeklyView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AnalysisViewModel>(context);
    return _buildContent(context, viewModel);
  }

  Widget _buildContent(BuildContext context, AnalysisViewModel viewModel) {
    // DEBUG: Print weekly data to console
    print('WeeklyView - weeklyAdherenceData: ${viewModel.weeklyAdherenceData}');
    print('WeeklyView - hasWeeklyData: ${viewModel.hasWeeklyData}');
    print('WeeklyView - weeklyInsight: ${viewModel.weeklyInsight}');
    
    if (viewModel.isLoadingWeekly) {
      return _buildLoadingState(context);
    }
    
    if (viewModel.error != null) {
      return _buildErrorState(context, viewModel);
    }

    _animationController.forward();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, viewModel),
            _buildMedicationTable(context, viewModel),
            _buildBarChart(context, viewModel),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // FIXED: Better helper methods that work with actual available data
  List<String> _getEstimatedMedications(AnalysisViewModel viewModel) {
    // Get medications from today's data as an estimate
    // In a real implementation, this would come from the service
    final todayTiles = viewModel.dailyTiles;
    final medicationNames = <String>{};
    
    for (final tile in todayTiles) {
      medicationNames.add(tile.name);
    }
    

    
    return medicationNames.toList();
  }

  List<String?> _getEstimatedMedicationAdherence(String medName, AnalysisViewModel viewModel) {
    // FIXED: Use actual weekly data with correct service keys
    final serviceKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']; // Match service format
    final adherence = <String?>[];
    
    for (int i = 0; i < 7; i++) {
      final dayKey = serviceKeys[i]; // Use lowercase keys that match service
      final dayPercentage = viewModel.weeklyAdherenceData[dayKey];
      
      // Handle null/missing data properly
      if (dayPercentage == null) {
        adherence.add(null); // No data available
      } else if (dayPercentage >= 80) {
        adherence.add('taken');
      } else if (dayPercentage >= 50) {
        adherence.add('missed');
      } else if (dayPercentage > 0) {
        adherence.add('not_logged');
      } else {
        adherence.add(null); // No scheduled doses
      }
    }
    
    return adherence;
  }

  Color _getMedicationColor(int index) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'taken':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'not_logged':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'taken':
        return Icons.check;
      case 'missed':
        return Icons.close;
      case 'not_logged':
        return Icons.remove;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAction),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading weekly insights...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AnalysisViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.refreshData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AnalysisViewModel viewModel) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4A90E2),
            const Color(0xFF357ABD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Week Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: viewModel.goToPreviousWeek,
                    icon: Icon(Icons.chevron_left, color: Colors.white, size: 28),
                  ),
                  Text(
                    viewModel.currentWeekString,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: viewModel.goToNextWeek,
                    icon: Icon(Icons.chevron_right, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationTable(BuildContext context, AnalysisViewModel viewModel) {
    // FIXED: Match service data format (lowercase)
    final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final serviceKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']; // Service uses lowercase
    
    // FIXED: Use improved helper method
    final medications = _getEstimatedMedications(viewModel);
    
    // FIXED: Better empty state handling
    if (medications.isEmpty || viewModel.weeklyAdherenceData.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.medication_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No medication data available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Weekly medication details are not available yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Individual Medication Adherence',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    'Med',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                ...daysOfWeek.map((day) => Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )),
              ],
            ),
          ),
          // Medication Rows
          ...medications.asMap().entries.map((entry) {
            final index = entry.key;
            final medName = entry.value;
            final medColor = _getMedicationColor(index);
            final adherence = _getEstimatedMedicationAdherence(medName, viewModel);
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: index < medications.length - 1 
                    ? BorderSide(color: Colors.grey.shade200)
                    : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: medColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.medication,
                            size: 16,
                            color: medColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            medName.length > 8 ? '${medName.substring(0, 8)}...' : medName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...adherence.asMap().entries.map((dayEntry) {
                    final status = dayEntry.value; // 'taken', 'missed', 'not_logged', or null
                    return Expanded(
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getStatusIcon(status),
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          // FIXED: Add disclaimer about estimated data
          if (medications.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: Individual medication data is estimated based on daily adherence.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, AnalysisViewModel viewModel) {
    // FIXED: Use correct day names and service keys
    const daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const serviceKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']; // Service uses lowercase
    
    // FIXED: Use actual weekly adherence data properly
    final weeklyData = viewModel.weeklyAdherenceData;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Relative Medication Adherence',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100, // FIXED: Use actual percentage range
                  minY: 0,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < daysOfWeek.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                daysOfWeek[value.toInt()],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 32,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        reservedSize: 28,
                        interval: 20, // FIXED: Use proper interval for 0-100 range
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20, // FIXED: Match left titles interval
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                      left: BorderSide(color: Colors.grey.shade400, width: 1),
                    ),
                  ),
                  barGroups: daysOfWeek.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dayKey = serviceKeys[index]; // Use service key format
                    final value = weeklyData[dayKey] ?? 0.0; // FIXED: Use actual percentage
                    
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: value >= 50.0 ? Colors.green : Colors.red, // FIXED: 50% threshold for percentage
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2),
                            topRight: Radius.circular(2),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(8.0),
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = daysOfWeek[group.x];
                        final percentage = rod.toY.toInt(); // FIXED: Display actual percentage
                        return BarTooltipItem(
                          '$day: $percentage%',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}