// lib/features/analysis/views/monthly_view.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../analysis_viewmodel.dart';

/// Monthly View with elegant motivational card, green chart, proper date labels
class MonthlyView extends StatelessWidget {
  const MonthlyView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AnalysisViewModel>(context);

    return SingleChildScrollView(child: _buildContent(context, viewModel));
  }

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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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

  Widget _buildMonthlyChart(BuildContext context, AnalysisViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ELEGANT MOTIVATIONAL CARD
          _buildMotivationalHeader(context),
          const SizedBox(height: 24),

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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: viewModel.goToNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Title
          Text(
            'Daily Medication Adherence',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Line chart
          SizedBox(
            height: 280,
            child: Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: viewModel.monthlyChartData.isEmpty
                    ? _buildEmptyState(context)
                    : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: (_getDaysInMonth(viewModel.currentMonth) - 1)
                              .toDouble(),
                          minY: 0,
                          maxY: 100,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 25,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.15),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final day = value.toInt() + 1;
                                  final daysInMonth = _getDaysInMonth(
                                    viewModel.currentMonth,
                                  );

                                  if (day == 1 ||
                                      day == 7 ||
                                      day == 14 ||
                                      day == 21 ||
                                      day == 28 ||
                                      day == daysInMonth) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '$day',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontSize: 12,
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
                                getTitlesWidget: (value, meta) {
                                  if (value % 25 == 0) {
                                    return Text(
                                      '${value.toInt()}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                reservedSize: 42,
                                interval: 25,
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _buildMonthlySpots(viewModel),
                              isCurved: true,
                              curveSmoothness: 0.25,
                              color: const Color(0xFF66BB6A),
                              barWidth: 3,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF66BB6A).withOpacity(0.3),
                                    const Color(0xFF66BB6A).withOpacity(0.05),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              dotData: FlDotData(
                                show: true,
                                checkToShowDot: (spot, barData) => spot.y > 0,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 3,
                                    color: const Color(0xFF66BB6A),
                                    strokeWidth: 1.5,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (touchedSpot) =>
                                  Theme.of(context).colorScheme.inverseSurface,
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              getTooltipItems: (touchedSpots) =>
                                  touchedSpots.map((spot) {
                                    final day = spot.x.toInt() + 1;
                                    final month = _getMonthAbbreviation(
                                      viewModel.currentMonth.month,
                                    );

                                    return LineTooltipItem(
                                      '$month $day\n${spot.y.toStringAsFixed(1)}%',
                                      TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onInverseSurface,
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
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'Average Adherence',
                    '${viewModel.monthlyAverageAdherence.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    _getAdherenceColor(
                      viewModel.monthlyAverageAdherence,
                      context,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'Days Tracked',
                    '${_countActiveDays(viewModel)}',
                    Icons.calendar_today,
                    const Color(0xFF66BB6A),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ELEGANT MOTIVATIONAL HEADER CARD
  Widget _buildMotivationalHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF66BB6A).withOpacity(0.15),
            const Color(0xFF81C784).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF66BB6A).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF66BB6A).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFF66BB6A),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay on track with your health goals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your monthly dashboard highlights how well you stay consistent and informed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No medication data yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your medications to see\nyour adherence trends here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countActiveDays(AnalysisViewModel viewModel) {
    return viewModel.monthlyData.where((d) => d.hasActivity).length;
  }

  Color _getAdherenceColor(double percentage, BuildContext context) {
    if (percentage >= 80) return const Color(0xFF66BB6A);
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  int _getDaysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  List<FlSpot> _buildMonthlySpots(AnalysisViewModel viewModel) {
    final spots = <FlSpot>[];

    for (final dataPoint in viewModel.monthlyChartData) {
      try {
        final date = DateTime.parse(dataPoint.date);
        final dayOfMonth = date.day;
        spots.add(FlSpot((dayOfMonth - 1).toDouble(), dataPoint.value));
      } catch (e) {
        debugPrint('Error parsing date: ${dataPoint.date}');
      }
    }

    return spots;
  }
}
