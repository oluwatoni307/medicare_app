// lib/features/analysis/views/weekly_view.dart
import 'package:flutter/material.dart';
import 'package:medicare_app/theme.dart';
import 'package:provider/provider.dart';
import '../analysis_viewmodel.dart';

// --- Modern Weekly View with Card-based Design (Simplified) ---
class WeeklyView extends StatefulWidget {
  const WeeklyView({Key? key}) : super(key: key);

  @override
  State<WeeklyView> createState() => _WeeklyViewState();
}

class _WeeklyViewState extends State<WeeklyView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    return SingleChildScrollView(
      child: _buildContent(context, viewModel),
    );
  }

  // --- Content ---
  Widget _buildContent(BuildContext context, AnalysisViewModel viewModel) {
    if (viewModel.isLoadingWeekly) {
      return _buildLoadingState(context);
    }
    if (viewModel.error != null) {
      return _buildErrorState(viewModel);
    }
    if (viewModel.weeklyInsight == null) {
        return _buildEmptyState(context);
    }
    _animationController.forward(); // Start animation for content
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _buildWeeklyDashboard(context, viewModel),
    );
  }

  // --- Loading State ---
  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAction),
            strokeWidth: 3,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Loading weekly data...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.lightText,
            ),
          ),
        ],
      ),
    );
  }

  // --- Error State ---
  Widget _buildErrorState(AnalysisViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'Oops! Something went wrong',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  viewModel.error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingL),
                ElevatedButton.icon(
                  onPressed: () => viewModel.refreshData(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Weekly Dashboard ---
  Widget _buildWeeklyDashboard(BuildContext context, AnalysisViewModel viewModel) {
    // Use data directly from the ViewModel
    final insight = viewModel.weeklyInsight!;
    final average = insight.overallAdherence;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, viewModel),
          const SizedBox(height: AppTheme.spacingL),
          _buildWeeklySummaryCard(context, viewModel, average),
          const SizedBox(height: AppTheme.spacingL),
          // Optional: Show today's medications if available
          if (viewModel.hasDailyData) ...[
            Text(
              'Today’s Medications',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...viewModel.dailyTiles.map((tile) {
              return Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Icon(
                    tile.status == 'taken' ? Icons.check_circle : Icons.warning,
                    color: tile.status == 'taken' ? Colors.green : Colors.orange,
                  ),
                  title: Text(tile.name),
                  subtitle: Text(tile.time),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: tile.status == 'taken'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: Text(
                      tile.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tile.status == 'taken' ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader(BuildContext context, AnalysisViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.primaryAction.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(
              Icons.calendar_view_week_rounded,
              color: AppTheme.primaryAction,
              size: 28,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Adherence',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  viewModel.currentWeekString,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Weekly Summary Card (Styled Like Medication Card) ---
  Widget _buildWeeklySummaryCard(BuildContext context, AnalysisViewModel viewModel, double average) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Row ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: _getAdherenceColor(average).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: _getAdherenceColor(average),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Adherence',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        _getAdherenceMessage(average),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.lightText,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: _getAdherenceColor(average).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Text(
                    '${average.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getAdherenceColor(average),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingL),

            // --- Progress Bar ---
            Text(
              'This Week’s Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            LinearProgressIndicator(
              value: average / 100,
              backgroundColor: Colors.grey.shade200,
              color: _getAdherenceColor(average),
              minHeight: 12,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              '${average.toStringAsFixed(1)}% of scheduled doses taken',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightText,
                  ),
            ),
          ],
        ),
      ),
    );
  }


  // --- Empty State ---
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.medication_outlined,
                  size: 64,
                  color: AppTheme.lightText,
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'No Data Available',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'No medication data found for this week.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Methods ---
  Color _getAdherenceColor(double percentage) {
    if (percentage >= 80) return AppTheme.primaryAction;
    if (percentage >= 50) return AppTheme.secondary;
    return const Color(0xFFDC2626); // Red
  }

  String _getAdherenceMessage(double percentage) {
    if (percentage >= 80) return 'Excellent adherence! Keep it up!';
    if (percentage >= 50) return 'Good progress, room for improvement';
    return 'Needs attention to improve adherence';
  }
}