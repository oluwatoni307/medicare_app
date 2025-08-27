import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/AddMedication_viewmodel.dart';
import 'pages/first.dart';
import 'pages/second.dart';

class MedicationView extends StatelessWidget {
  const MedicationView({super.key});

  @override
  Widget build(BuildContext context) {
    // Extract the medicationId from route arguments
    final String? medicationId = ModalRoute.of(context)?.settings.arguments as String?;
    
    print('MedicationView: Received medicationId = $medicationId'); // Debug print
    
    return ChangeNotifierProvider(
      create: (_) => MedicationViewModel(medicationId: medicationId),
      child: Consumer<MedicationViewModel>(
        builder: (context, viewModel, child) {
          print('MedicationView: isEditMode = ${viewModel.isEditMode}'); // Debug print
          
          // Show loading indicator while loading existing medication
          if (viewModel.isLoading) {
            return Scaffold(
              appBar: AppBar(title: const Text('Loading...')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final PageController pageController = PageController(
            initialPage: viewModel.currentPage,
          );

          void updatePage(int newPage) {
            pageController.animateToPage(
              newPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(
                viewModel.isEditMode ? 'Edit Medication' : 'Add Medication',
              ),
            ),
            body: Column(
              children: [
                LinearProgressIndicator(value: viewModel.progress),
                Expanded(
                  child: PageView(
                    controller: pageController,
                    onPageChanged: (page) {
                      viewModel.setCurrentPage(page);
                    },
                    children: [const FirstPage(), const SecondPage()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      viewModel.currentPage > 0
                          ? ElevatedButton(
                              onPressed: () {
                                final newPage = viewModel.currentPage - 1;
                                viewModel.setCurrentPage(newPage);
                                updatePage(newPage);
                              },
                              child: const Text('Previous'),
                            )
                          : const SizedBox(),
                      viewModel.currentPage < viewModel.totalPages - 1
                          ? ElevatedButton(
                              onPressed: () {
                                final newPage = viewModel.currentPage + 1;
                                viewModel.setCurrentPage(newPage);
                                updatePage(newPage);
                              },
                              child: const Text('Next'),
                            )
                          : ElevatedButton(
                              onPressed: () async {
                                // Show loading dialog
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                final validationErrors = viewModel.validateMedication();

                                // Hide loading dialog
                                Navigator.of(context).pop();
                                
                                if (validationErrors.isNotEmpty) {
                                  // Show each error in its own snackbar
                                  for (int i = 0; i < validationErrors.length; i++) {
                                    Future.delayed(
                                      Duration(milliseconds: i * 500),
                                      () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(validationErrors[i]),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                  return; // Don't proceed with saving
                                }
                                
                                bool saved = await viewModel.saveMedication();

                                if (saved) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        viewModel.isEditMode
                                            ? 'Medication Updated'
                                            : 'Medication Saved',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                  if (viewModel.isEditMode) {
                                    // Just pop back - no refresh needed for edits
                                    Navigator.of(context).pop();
                                  } else {
                                    // Navigate to home route - will show fresh data with new medication
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      '/',
                                      (route) => false,
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to save medication'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                viewModel.isEditMode ? 'Update' : 'Save',
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}