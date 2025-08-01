import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/navBar.dart';
import '/widgets/clock_widget.dart';
import 'Home_viewmodel.dart';
import '/routes.dart';
import '/features/log/log_view.dart';

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

            // --------------  NEW SCROLLABLE LAYOUT  --------------
            return CustomScrollView(
              slivers: [
                // 1. Sticky “header” (Hero + storyText)
                SliverToBoxAdapter(
                  child: Column(
                    children:  [
                      SizedBox(height: 7),
                      HeroSection(),
                      storyText(),
                      SizedBox(height: 20),
                    ],
                  ),
                ),

                // 2. Medications (grid or empty-state)
                Consumer<HomeViewModel>(
                  builder: (_, viewModel, __) {
                    if (viewModel.medications.isEmpty) {
                      // Empty-state card
                      return SliverToBoxAdapter(
                        child: MedicationSection()._buildEmptyState(
                          context,
                          viewModel,
                        ),
                      );
                    }

                    // Real grid
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      sliver: SliverGrid.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                        childAspectRatio: 1.2, // wider cells
                        children: viewModel.medications.map((med) {
                          return MedicationBox(
                            medicationId: med.id,
                            medicationName: med.name,
                            medicationImageUrl: med.imageUrl,
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),

                // 3. Extra padding so FAB never covers last row
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
}

// ---------- Everything below is *unchanged* ----------
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
                return Text(
                  'You have $count medications to take\nregistered',
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

Widget storyText() {
  return  Padding(
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

class MedicationSection extends StatelessWidget {
  const MedicationSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Nothing here anymore – logic moved into the CustomScrollView
    return const SizedBox.shrink();
  }

  // keep the empty-state builder public so the Sliver can use it
  Widget _buildEmptyState(BuildContext context, HomeViewModel viewModel) {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.medication_liquid,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No medications yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start tracking your medications to\nnever miss a dose again',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/new_medicine'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Your First Medication',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MedicationBox extends StatelessWidget {
  final String medicationId;
  final String medicationName;
  final String medicationImageUrl;

  const MedicationBox({
    super.key,
    required this.medicationId,
    required this.medicationName,
    required this.medicationImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LogView(medicineId: medicationId),
          ),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                medicationImageUrl,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.medication, size: 36, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                medicationName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}