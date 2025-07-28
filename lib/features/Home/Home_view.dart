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
        // Initialize data loading when ViewModel is created
        WidgetsBinding.instance.addPostFrameCallback((_) {
          viewModel.loadCurrentUserMedications();
        });
        return viewModel;
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavBar(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Navigate to add medication page
            Navigator.pushNamed(context, AppRoutes.new_medicine);
          },
          child: Icon(Icons.add),
        ),
        body: Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return Center(child: CircularProgressIndicator());
            }
            
            if (viewModel.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${viewModel.errorMessage}'),
                    ElevatedButton(
                      onPressed: () => viewModel.refresh(),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  HeroSection(),
                  storyText(),
                  SizedBox(height: 20),
                  MedicationSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      child: Stack(
        children: [
          Clockwidget(),
          Positioned(
            right: 10,
            bottom: 10,
            child: Consumer<HomeViewModel>(
              builder: (context, viewModel, child) {
                final count = viewModel.homepageData.upcomingMedicationCount;
                return Text(
                  "you have $count medications to take\n registered",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 16,
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
  return Padding(
    padding: const EdgeInsets.all(10.0),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 17,
        ),
        children: [
          TextSpan(
            text: "Don't wait! Every reminder brings you closer to a healthier, stress-free life."
          ),
          TextSpan(
            text: " Tap the + button",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: " to start managing you medications effortlessly"
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
    return Container(
      padding: EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Medications",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Consumer<HomeViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.medications.isEmpty) {
                return _buildEmptyState(context, viewModel);
              }

              return GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: viewModel.medications.map((med) {
                  return MedicationBox(
                    medicationId: med.id,
                    medicationName: med.name,
                    medicationImageUrl: med.imageUrl,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, HomeViewModel viewModel) {
    return Container(
      height: 280,
      margin: EdgeInsets.symmetric(vertical: 20),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.medication_liquid,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 20),
              Text(
                "No medications yet",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Start tracking your medications to\nnever miss a dose again",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to add medication screen
                  Navigator.pushNamed(context, '/add-medication');
                },
                icon: Icon(Icons.add, size: 18),
                label: Text(
                  "Add Your First Medication",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
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
    required this.medicationImageUrl
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate directly to log page with medication ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LogView(medicineId: medicationId),
          ),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: Image.asset(
                  height: 30,
                  medicationImageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.medication,
                      size: 50,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
              SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: Text(
                  medicationName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}