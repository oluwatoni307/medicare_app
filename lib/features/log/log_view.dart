import 'package:flutter/material.dart';
import 'package:medicare_app/features/log/log_viewmodel.dart';
import 'package:provider/provider.dart';
import '/theme.dart';
import 'log_model.dart' as log;

class LogView extends StatelessWidget {
  final String medicineId;

  const LogView({
    super.key,
    required this.medicineId,
  });

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
            backgroundColor: AppTheme.primaryBlue,
            appBar: AppBar(
              title: Text(viewModel.medicineName ?? 'Loading...'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : viewModel.hasError
                    ? _buildErrorState(context, viewModel)
                    : !viewModel.hasSchedules
                        ? _buildEmptyState(context, viewModel)
                        : _buildContent(context, viewModel),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, LogViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 32, color: AppTheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load doses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage ?? 'Something went wrong',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => viewModel.initialize(medicineId: medicineId),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, LogViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline, size: 32, color: AppTheme.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'No doses today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all set for ${viewModel.medicineName ?? "this medication"}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, LogViewModel viewModel) {
    return Column(
      children: [
        // Progress header
        _buildProgressHeader(context, viewModel),
        
        // Success/error message
        if (viewModel.hasSuccess || viewModel.hasError)
          _buildMessageBanner(context, viewModel),
        
        // Doses list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: viewModel.scheduleLogModels.length,
            itemBuilder: (context, index) {
              final scheduleLog = viewModel.scheduleLogModels[index];
              return _buildDoseCard(context, viewModel, scheduleLog);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressHeader(BuildContext context, LogViewModel viewModel) {
    final progress = viewModel.dailyProgressPercentage / 100;
    final isComplete = progress == 1.0;
    
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isComplete ? AppTheme.accent : AppTheme.primaryAction).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isComplete ? Icons.check_circle : Icons.medication,
                  color: isComplete ? AppTheme.accent : AppTheme.primaryAction,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      viewModel.progressText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: isComplete ? AppTheme.accent : AppTheme.primaryAction,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? AppTheme.accent : AppTheme.primaryAction,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBanner(BuildContext context, LogViewModel viewModel) {
    final isSuccess = viewModel.hasSuccess;
    final message = isSuccess ? viewModel.successMessage! : viewModel.errorMessage!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isSuccess
            ? AppTheme.accent.withOpacity(0.1)
            : AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? AppTheme.accent : AppTheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSuccess ? AppTheme.accent : AppTheme.error,
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
    final isTaken = scheduleLog.isTaken;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isTaken 
              ? AppTheme.accent.withOpacity(0.2)
              : AppTheme.surfaceMuted,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time and status row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scheduleLog.schedule.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scheduleLog.schedule.scheduleLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isTaken ? 'Done' : scheduleLog.isPast ? 'Pending' : 'Upcoming',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 14),
            
            // Action buttons
            if (isTaken)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    viewModel.setSelectedSchedule(scheduleLog);
                    await viewModel.submitLogAsNotTaken();
                  },
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Undo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.lightText,
                    side: BorderSide(color: AppTheme.surfaceMuted, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        viewModel.setSelectedSchedule(scheduleLog);
                        await viewModel.submitLogAsTaken();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAction,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      child: const Text('Mark Taken'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        viewModel.setSelectedSchedule(scheduleLog);
                        await viewModel.submitLogAsMissed();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.darkText,
                        side: BorderSide(color: AppTheme.surfaceMuted, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      child: const Text('Missed'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}