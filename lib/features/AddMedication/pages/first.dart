import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../AddMedication_viewmodel.dart';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _initializeControllers(MedicationViewModel viewModel) {
    if (!_controllersInitialized && !viewModel.isLoading) {
      _nameController.text = viewModel.medication.medicationName ?? '';
      _dosageController.text = viewModel.medication.dosage ?? '';
      _controllersInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MedicationViewModel>(
      builder: (context, viewModel, child) {
        // Initialize controllers with existing data when not loading
        _initializeControllers(viewModel);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Medication name", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                onChanged: viewModel.updateMedicationName,
                decoration: const InputDecoration(
                  hintText: 'Paracetamol',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Dosage", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _dosageController,
                onChanged: viewModel.updateDosage,
                decoration: const InputDecoration(
                  hintText: '10mg',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Medication type", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
              ),
              const SizedBox(height: 5),
              MedicineTypesWidget(
                selectedType: viewModel.medication.type,
                onTypeSelected: viewModel.updateMedicationType,
              ),
            ],
          ),
        );
      },
    );
  }
}

class MedicineTypesWidget extends StatelessWidget {
  final Function(String)? onTypeSelected;
  final String? selectedType;

  const MedicineTypesWidget({
    Key? key, 
    this.onTypeSelected, 
    this.selectedType
  }) : super(key: key);

  final List<String> medicineTypes = const [
    'tablet', 'capsule', 'syrup', 'injection', 
    'topical', 'sachet', 'inhaler', 'drop',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: medicineTypes.length,
      itemBuilder: (context, index) {
        final type = medicineTypes[index];
        final isSelected = selectedType == type;

        return GestureDetector(
          onTap: () => onTypeSelected?.call(type),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade100 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'images/types/$type.png',
                  width: 35,
                  height: 35,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.broken_image, size: 35),
                ),
                const SizedBox(height: 5),
                Text(
                  type[0].toUpperCase() + type.substring(1),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.blue.shade700 : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}