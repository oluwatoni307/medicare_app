import 'package:flutter/material.dart';
// --- Import the feature's private models correctly ---
// --- Import the ViewModel ---
import 'package:medicare_app/features/log/log_viewmodel.dart';
// --- Import Provider ---
import 'package:provider/provider.dart';
// --- Import Theme (assuming AppTheme is defined somewhere) ---
import '/theme.dart';
import 'log_model.dart' as log; // Make sure this path is correct

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
            appBar: AppBar(
              title: Text(viewModel.medicineName != null ? 'Log ${viewModel.medicineName}' : 'Loading...'),
              backgroundColor: AppTheme.primaryBlue,
              titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            body: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : viewModel.hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            SizedBox(height: AppTheme.spacingS),
                            Text(
                              viewModel.errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                            SizedBox(height: AppTheme.spacingM),
                            ElevatedButton(
                              onPressed: () => viewModel.initialize(medicineId: medicineId),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : !viewModel.hasSchedules
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 60,
                                  color: AppTheme.lightText, // Assuming AppTheme.lightText is defined
                                ),
                                SizedBox(height: AppTheme.spacingS),
                                Text(
                                  'No schedules available for ${viewModel.medicineName ?? "this medication"}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.lightText, // Assuming AppTheme.lightText is defined
                                      ),
                                ),
                                SizedBox(height: AppTheme.spacingM),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Back'),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.all(AppTheme.spacingM), // Assuming AppTheme.spacingM is defined
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Schedule',
                                  style: Theme.of(context).textTheme.headlineMedium, // Check if headlineMedium exists
                                ),
                                SizedBox(height: AppTheme.spacingS),
                                // --- FIXED: Correctly reference ScheduleLogModelWithLog ---
                                DropdownButton<log.ScheduleLogModelWithLog?>(
                                  value: viewModel.selectedSchedule,
                                  hint: const Text('Choose a schedule'),
                                  isExpanded: true,
                                  items: viewModel.scheduleLogModels.map((scheduleLog) {
                                    return DropdownMenuItem<log.ScheduleLogModelWithLog?>(
                                      value: scheduleLog,
                                      child: Text(
                                        viewModel.formatScheduleForDisplay(scheduleLog),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) => viewModel.setSelectedSchedule(value),
                                ),
                                SizedBox(height: AppTheme.spacingM),
                                Text(
                                  'Status',
                                  style: Theme.of(context).textTheme.headlineMedium, // Check if headlineMedium exists
                                ),
                                SizedBox(height: AppTheme.spacingS),
                                // --- CHANGED: Logic for action buttons ---
                                // Option 1: Single button that changes action based on state
                                Center(
                                  child: SizedBox(
                                    width: double.infinity, // Make button full width
                                    child: ElevatedButton(
                                      onPressed: viewModel.canSubmit && !viewModel.isLoading
                                          ? () async {
                                              // Determine action based on current state of selected schedule
                                              if (viewModel.selectedSchedule!.isTaken) {
                                                // If taken, "Submit" reverts it
                                                await viewModel.submitLogAsNotTaken();
                                              } else {
                                                // If not taken, "Submit" marks it as taken
                                                await viewModel.submitLogAsTaken();
                                              }
                                              // Optionally pop if successful, or let user see success message
                                              // if (viewModel.hasSuccess) {
                                              //   Navigator.pop(context); // Or maybe just show success and let them log another
                                              // }
                                            }
                                          : null,
                                      // --- CHANGED: Button text changes based on state ---
                                      child: Text(
                                        viewModel.selectedSchedule?.isTaken == true
                                            ? 'Revert to Not Taken'
                                            : 'Mark as Taken',
                                      ),
                                      // --- END CHANGE ---
                                    ),
                                  ),
                                ),
                                // --- END CHANGE ---
                                SizedBox(height: AppTheme.spacingS),
                                Text(
                                  viewModel.getStatusText(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.lightText, // Assuming AppTheme.lightText is defined
                                      ),
                                ),
                                SizedBox(height: AppTheme.spacingL),
                                if (viewModel.hasSuccess)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: AppTheme.spacingS),
                                    child: Text(
                                      viewModel.successMessage!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppTheme.primaryAction, // Assuming AppTheme.primaryAction is defined
                                          ),
                                    ),
                                  ),
                                // --- REMOVED: Old "Submit Log" button ---
                                // --- ADDED: Optional "Missed" Button (explicit action) ---
                                // If you want a separate button to explicitly mark as missed (different from "not taken"):
                                // Center(
                                //   child: SizedBox(
                                //     width: double.infinity,
                                //     child: OutlinedButton(
                                //       onPressed: viewModel.canSubmit && !viewModel.isLoading
                                //           ? () async {
                                //               await viewModel.submitLogAsMissed();
                                //             }
                                //           : null,
                                //       child: const Text('Mark as Missed'),
                                //     ),
                                //   ),
                                // ),
                                // --- END ADDITION ---
                              ],
                            ),
                          ),
          );
        },
      ),
    );
  }
}