// medication_list_view.dart
import 'package:flutter/material.dart';
import 'package:medicare_app/theme.dart';
import 'package:provider/provider.dart';
import '../AddMedication/AddMedication_model.dart';
import '/routes.dart';
import 'medication_list_viewmodel.dart';
import 'medicine_view.dart';

class MedicationListView extends StatelessWidget {
  const MedicationListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ChangeNotifierProvider(
      create: (_) => MedicationListViewModel(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          // backgroundColor: theme.colorScheme.primary,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: theme.colorScheme.onBackground,
            title: Text(
              'My Medications',
              style: theme.textTheme.headlineMedium,
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.primary,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: theme.colorScheme.onPrimary,
                  unselectedLabelColor: theme.colorScheme.onSurface,
                  labelStyle: theme.textTheme.labelLarge,
                  unselectedLabelStyle: theme.textTheme.labelMedium,
                  tabs: const [
                    Tab(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication, size: 18),
                          SizedBox(width: 8),
                          Text('Active'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 18),
                          SizedBox(width: 8),
                          Text('Completed'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Consumer<MedicationListViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.isLoading) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading medications...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                onRefresh: () => viewModel.refreshMedications(),
                child: TabBarView(
                  children: [
                    _buildMedicationList(context, viewModel, viewModel.activeMedications.cast<MedicationModel>(), 'No active medications yet.', true),
                    _buildMedicationList(context, viewModel, viewModel.completedMedications.cast<MedicationModel>(), 'No completed medications.', false),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationList(
    BuildContext context,
    MedicationListViewModel viewModel,
    List<MedicationModel> medications,
    String emptyMessage,
    bool isActiveTab,
  ) {
    if (medications.isEmpty) {
      return EmptyMedicationState(message: emptyMessage, isActiveTab: isActiveTab);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(7.0),
      itemCount: medications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12.0),
      itemBuilder: (context, index) {
        final medication = medications[index];
        return MedicationCard(
          medication: medication,
          viewModel: viewModel,
          isActive: isActiveTab,
        );
      },
    );
  }
}

// Empty State
class EmptyMedicationState extends StatelessWidget {
  final String message;
  final bool isActiveTab;

  const EmptyMedicationState({super.key, required this.message, required this.isActiveTab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActiveTab ? Icons.medication_liquid : Icons.check_circle_outline,
              size: 40,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isActiveTab ? 'Add your first medication to get started' : 'Completed medications will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Medication Card
class MedicationCard extends StatelessWidget {
  final MedicationModel medication;
  final MedicationListViewModel viewModel;
  final bool isActive;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.viewModel,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Subtle accent line
          Container(
            height: 3,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                // Medication type image
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Center(
                    child: Image.asset(
                      medication.imageUrl,
                      width: 32,
                      height: 32,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.medication_liquid,
                          size: 32,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(width: 16.0),

                // Medication name
                Expanded(
                  child: Text(
                    medication.medicationName ?? 'Unknown',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 16.0),

                // Actions
                MedicationActions(medication: medication, viewModel: viewModel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MedicationActions extends StatelessWidget {
  final MedicationModel medication;
  final MedicationListViewModel viewModel;

  const MedicationActions(
      {super.key, required this.medication, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Details
        OutlinedButton(
          onPressed: () => _navigateToDetails(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.4)),
            minimumSize: const Size(72, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
          ),
          child: Text(
            'Details',
            style: theme.textTheme.labelMedium
                // ?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        // Edit
        ElevatedButton(
          onPressed: () => _navigateToEdit(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary, // soft-coral
            foregroundColor: Colors.white,
            minimumSize: const Size(72, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            elevation: 0,
          ),
          child: Text(
            'Edit',
            style: TextStyle(color: Colors.blueGrey[50], fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationDetailView(medicineId: medication.id!),
      ),
    );
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.edit_medication,
      arguments: medication.id,
    ).then((_) => viewModel.refreshMedications());
  }
}