import 'package:flutter/material.dart';
import 'package:medicare_app/features/log/log_viewmodel.dart';
import 'package:provider/provider.dart';
import '/theme.dart';
import 'log_model.dart' as log;

class LogView extends StatelessWidget {
  final String medicineId;

  const LogView({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final viewModel = LogViewModel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          viewModel.initialize(medicineId: medicineId);
        });
        return viewModel;
      },
      child: Consumer<LogViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(viewModel.medicineName ?? 'Loading...'),
              backgroundColor: AppTheme.primaryBlue,
              elevation: 0,
            ),
            body: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : viewModel.hasError
                ? _buildErrorState(context, viewModel)
                : !viewModel.hasSchedules
                ? _buildEmptyState(context, viewModel)
                : _buildTimelineView(context, viewModel),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, LogViewModel viewModel) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              viewModel.errorMessage ?? 'Unknown error',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: () => viewModel.initialize(medicineId: medicineId),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingM,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, LogViewModel viewModel) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'No schedules for today',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              'There are no scheduled doses for ${viewModel.medicineName ?? "this medication"} today.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingL),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineView(BuildContext context, LogViewModel viewModel) {
    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Progress Header
          SliverToBoxAdapter(child: _buildProgressHeader(context, viewModel)),

          // Success/Error Message Banner
          if (viewModel.hasSuccess || viewModel.hasError)
            SliverToBoxAdapter(child: _buildMessageBanner(context, viewModel)),

          // Dose Cards List
          SliverPadding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final scheduleLog = viewModel.scheduleLogModels[index];
                return _buildDoseCard(context, viewModel, scheduleLog);
              }, childCount: viewModel.scheduleLogModels.length),
            ),
          ),

          // Bottom Padding
          SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingXL)),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context, LogViewModel viewModel) {
    final progressPercent = viewModel.dailyProgressPercentage;
    final isComplete = viewModel.isFullyCompleteToday;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isComplete
              ? [const Color(0xFF4CAF50), const Color(0xFF81C784)]
              : [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      viewModel.progressText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${progressPercent.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (isComplete)
                      const Icon(
                        Icons.celebration,
                        color: Colors.white,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              _buildProgressChip(
                context,
                '✅ ${viewModel.dailyTakenDoses}',
                const Color(0xFF4CAF50),
              ),
              SizedBox(width: AppTheme.spacingS),
              _buildProgressChip(
                context,
                '❌ ${viewModel.dailyMissedDoses}',
                const Color(0xFFFF9800),
              ),
              SizedBox(width: AppTheme.spacingS),
              _buildProgressChip(
                context,
                '⏳ ${viewModel.dailyNotLoggedDoses}',
                const Color(0xFF9E9E9E),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChip(BuildContext context, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBanner(BuildContext context, LogViewModel viewModel) {
    final isSuccess = viewModel.hasSuccess;
    final message = isSuccess
        ? viewModel.successMessage!
        : viewModel.errorMessage!;

    return Container(
      margin: EdgeInsets.all(AppTheme.spacingM),
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFF4CAF50).withOpacity(0.1)
            : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess ? const Color(0xFF4CAF50) : Colors.red[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? const Color(0xFF4CAF50) : Colors.red[700],
          ),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSuccess ? const Color(0xFF2E7D32) : Colors.red[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(
    BuildContext context,
    LogViewModel viewModel,
    log.ScheduleLogModelWithLog scheduleLog,
  ) {
    final statusColor = viewModel.getDoseStatusColor(scheduleLog);
    final statusIcon = viewModel.getDoseStatusIcon(scheduleLog);
    final statusText = viewModel.getDoseStatusText(scheduleLog);

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withOpacity(0.05),
            statusColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Time and Status Icon
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scheduleLog.schedule.displayName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                      ),
                      Text(
                        scheduleLog.schedule.scheduleLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: AppTheme.spacingM),

            // Status Text
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  SizedBox(width: AppTheme.spacingS),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacingM),

            // Action Buttons
            _buildActionButtons(context, viewModel, scheduleLog, statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    LogViewModel viewModel,
    log.ScheduleLogModelWithLog scheduleLog,
    Color statusColor,
  ) {
    if (scheduleLog.isTaken) {
      // Undo button for taken doses
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            viewModel.setSelectedSchedule(scheduleLog);
            await viewModel.submitLogAsNotTaken();
          },
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: statusColor,
            side: BorderSide(color: statusColor),
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacingM),
          ),
        ),
      );
    } else {
      // Mark as Taken and Mark as Missed buttons
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: viewModel.canTakeAction(scheduleLog)
                  ? () async {
                      viewModel.setSelectedSchedule(scheduleLog);
                      await viewModel.submitLogAsTaken();
                    }
                  : null,
              icon: const Icon(Icons.check),
              label: const Text('Mark Taken'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: AppTheme.spacingM),
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: viewModel.canTakeAction(scheduleLog)
                  ? () async {
                      viewModel.setSelectedSchedule(scheduleLog);
                      await viewModel.submitLogAsMissed();
                    }
                  : null,
              icon: const Icon(Icons.close),
              label: const Text('Missed'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF9800),
                side: const BorderSide(color: Color(0xFFFF9800)),
                padding: EdgeInsets.symmetric(vertical: AppTheme.spacingM),
              ),
            ),
          ),
        ],
      );
    }
  }
}
