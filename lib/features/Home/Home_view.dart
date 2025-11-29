import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/navBar.dart';
import '/widgets/clock_widget.dart';
import 'Home_viewmodel.dart';
import '/routes.dart';
import '/features/log/log_view.dart';
import '/theme.dart';
import 'Home_model.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (context) {
        final viewModel = HomeViewModel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          viewModel.loadCurrentUserMedications();
        });
        return viewModel;
      },
      child: Scaffold(
        bottomNavigationBar: const BottomNavBar(),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.new_medicine),
          child: const Icon(Icons.add),
        ),
        body: Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${viewModel.errorMessage}'),
                    ElevatedButton(
                      onPressed: viewModel.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                // Hero Section
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(height: 10),
                      HeroSection(),
                      storyText(),
                      SizedBox(height: 20),
                    ],
                  ),
                ),

                // Today's Summary Card (conditional)
                if (viewModel.showSummary)
                  SliverToBoxAdapter(
                    child: TodaysSummaryCard(summary: viewModel.todaysSummary!),
                  ),

                // Medications Grid
                Consumer<HomeViewModel>(
                  builder: (_, viewModel, __) {
                    if (viewModel.medications.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _buildEmptyState(context, viewModel),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      sliver: SliverGrid.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 0.95,
                        children: viewModel.medications.map((med) {
                          return MedicationBox(medication: med);
                        }).toList(),
                      ),
                    );
                  },
                ),

                // Bottom Padding
                SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, HomeViewModel viewModel) {
    // Check if has meds but no doses today
    final hasSummary = viewModel.todaysSummary != null;
    final noDosesToday = hasSummary && viewModel.todaysSummary!.totalDoses == 0;

    if (noDosesToday) {
      // Has medications but no doses scheduled today
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Card(
          elevation: 1,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available,
                    size: 48,
                    color: AppTheme.accent,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'All set for today',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                Text(
                  'No doses scheduled for today.\nEnjoy your day!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightText,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // No medications at all
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Card(
        elevation: 1,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.medication_liquid,
                  size: 48,
                  color: AppTheme.lightText,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'No medications yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 8),
              Text(
                'Start tracking your medications to\nnever miss a dose again',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightText,
                    ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/new_medicine'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Your First Medication',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Hero Section
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        children: [
          const Clockwidget(),
          Positioned(
            right: 10,
            bottom: 10,
            child: Consumer<HomeViewModel>(
              builder: (context, viewModel, _) {
                final count = viewModel.homepageData.upcomingMedicationCount;
                final medicationText = count == 1 ? 'medication' : 'medications';
                return Text(
                  '$count active $medicationText',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Story Text
Widget storyText() {
  return Padding(
    padding: EdgeInsets.all(10.0),
    child: RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 17, color: Colors.black),
        children: [
          TextSpan(
            text: "Don't wait! Every reminder brings you closer to a healthier, stress-free life. ",
          ),
          TextSpan(
            text: "Tap the + button",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          TextSpan(
            text: " to start managing your medications effortlessly.",
          ),
        ],
      ),
    ),
  );
}

// Today's Summary Card
class TodaysSummaryCard extends StatelessWidget {
  final TodaysSummary summary;

  const TodaysSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Progress',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.darkText,
                        ),
                  ),
                  Text(
                    '${summary.overallPercent.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.primaryAction,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              
              SizedBox(height: AppTheme.spacingXS),
              
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHover,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (summary.overallPercent / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryAction, AppTheme.accent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: AppTheme.spacingS),
              
              // Doses Text
              Text(
                '${summary.takenDoses} of ${summary.totalDoses} doses',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightText,
                    ),
              ),
              
              // Next Dose Info (if available)
              if (summary.nextDoseInfo != null) ...[
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Next: ${summary.nextDoseInfo}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightText,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Medication Box with Status Badge
class MedicationBox extends StatelessWidget {
  final MedicationInfo medication;

  const MedicationBox({
    super.key,
    required this.medication,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: medication.cardOpacity,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LogView(medicineId: medication.id),
            ),
          );
        },
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Stack(
            children: [
              // Main Content
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      medication.imageUrl,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.medication,
                        size: 36,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      medication.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Status Badge (top-right)
              Positioned(
                top: 6,
                right: 6,
                child: _buildStatusBadge(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final badgeText = medication.displayBadge;
    
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: medication.badgeBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: medication.badgeBorderColor,
          width: 1,
        ),
      ),
      child: Center(
        child: badgeText != null
            ? Text(
                badgeText,
                style: TextStyle(
                  fontSize: badgeText == '✓' || badgeText == '—' ? 12 : 10,
                  fontWeight: FontWeight.w500,
                  color: medication.badgeColor,
                ),
              )
            : Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: medication.badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}