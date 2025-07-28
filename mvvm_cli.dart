import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) return _help();

  switch (args[0]) {
    case 'init':
      _initStructure();
      break;
    case 'add-feature':
      if (args.length < 2) {
        print('Please provide a feature name.');
      } else {
        _addFeature(args[1]);
      }
      break;
    default:
      _help();
  }
}

void _help() {
  print('''
MVVM CLI for Flutter

Usage:
  dart run mvvm_cli.dart init
  dart run mvvm_cli.dart add-feature <name>
''');
}

void _initStructure() {
  final structure = {
    'lib/core': 'Shared logic like services, constants, utils, themes.',
    'lib/core/services': 'Global services like API, etc.',
    'lib/core/utils': 'Helper functions, formatters, etc.',
    'lib/shared_widgets': 'Reusable UI widgets.',
    'lib/features': 'Screens grouped by feature/module.',
  };

  for (var entry in structure.entries) {
    final _ = Directory(entry.key)..createSync(recursive: true);
    File('${entry.key}/README.txt')
      ..createSync()
      ..writeAsStringSync('Folder: ${entry.key}\n\n${entry.value}');
  }

  File('lib/MVVM_PROJECT_GUIDE.txt').writeAsStringSync('''
MVVM GUIDE

To add a new feature:
dart run mvvm_cli.dart add-feature feature_name
''');

  print('MVVM structure initialized.');
}

void _addFeature(String name) {
  final path = 'lib/features/$name';
  final dir = Directory(path);
  if (dir.existsSync()) {
    print('Feature "$name" already exists.');
    return;
  }

  dir.createSync(recursive: true);
  File('$path/README.txt').writeAsStringSync('''
$path

Feature module "$name" containing:
- ${name}_model.dart
- ${name}_viewmodel.dart
- ${name}_view.dart
''');
  File('$path/${name}_model.dart').createSync();
  File('$path/${name}_viewmodel.dart').createSync();
  File('$path/${name}_view.dart').createSync();

  print('Feature "$name" added.');
}
