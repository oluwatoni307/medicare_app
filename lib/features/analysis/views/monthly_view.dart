// lib/features/analysis/views/monthly_view.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../analysis_viewmodel.dart';

// --- Monthly View for displaying adherence trend line chart ---
class MonthlyView extends StatelessWidget {
  const MonthlyView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AnalysisViewModel>(context);

    return SingleChildScrollView(
      child: _buildContent(context, viewModel),
    );
  }

  // --- Content ---
  /// Displays loading, error, or the monthly adherence chart.
  Widget _buildContent(BuildContext context, AnalysisViewModel viewModel) {
    if (viewModel.isLoadingMonthly) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (viewModel.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              viewModel.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => viewModel.refreshData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _buildMonthlyChart(context, viewModel);
  }

  // --- Monthly Chart ---
  /// Displays a line chart of monthly adherence trends.
  Widget _buildMonthlyChart(BuildContext context, AnalysisViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: viewModel.goToPreviousMonth,
              ),
              Text(
                viewModel.currentMonthString,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: viewModel.goToNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Line chart
          SizedBox(
            height: 250, // Reduced height
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Padding(
  padding: const EdgeInsets.fromLTRB(16, 30, 16, 16), // Extra top padding
                child: viewModel.monthlyChartData.isEmpty
                    ? Center(
                        child: Text(
                          'No data available',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 25,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= viewModel.monthlyChartData.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final date = viewModel.monthlyChartData[value.toInt()].date;
                                  final day = int.parse(date.split('-').last);
                                  
                                  // Show fewer labels for cleaner look
                                  if (day % 5 == 0 || day == 1) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        day.toString(),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                reservedSize: 24,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) => Text(
                                  '${value.toInt()}%',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                reservedSize: 35,
                                interval: 25,
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                width: 1,
                              ),
                              left: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: viewModel.monthlyChartData
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                                  .toList(),
                              isCurved: true,
                              
                              curveSmoothness: 0.2,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 2.5,
                              belowBarData: BarAreaData(
                                show: true,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              ),
                              dotData: FlDotData(
                                show: true,
                                checkToShowDot: (spot, barData) {
                                  // Only show dots for data points with actual values > 0
                                  return spot.y > 0;
                                },
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 3,
                                    color: Theme.of(context).colorScheme.primary,
                                    strokeWidth: 0,
                                  );
                                },
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              // tooltipBgColor: Theme.of(context).colorScheme.inverseSurface,
                      tooltipBorderRadius: BorderRadius.circular(8.0),
                              tooltipPadding: const EdgeInsets.all(8),
                              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                                final day = viewModel.monthlyChartData[spot.x.toInt()];
                                final dayNum = day.date.split('-').last;
                                return LineTooltipItem(
                                  'Day $dayNum\n${day.value.toStringAsFixed(1)}%',
                                  TextStyle(
                                    color: Theme.of(context).colorScheme.onInverseSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Summary stats
          if (viewModel.hasMonthlyData) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryCard(
                  context,
                  'Average',
                  '${viewModel.monthlyAverageAdherence.toStringAsFixed(1)}%',
                  Icons.analytics_outlined,
                ),
                _buildSummaryCard(
                  context,
                  'Days Active',
                  '${viewModel.monthlyData.where((d) => d.hasActivity).length}',
                  Icons.calendar_today_outlined,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}