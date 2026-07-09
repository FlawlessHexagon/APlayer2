import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/library_scanner.dart';
import '../providers/database_provider.dart';

final libraryScannerProvider = Provider<LibraryScanner>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  return LibraryScanner(dbRepo);
});
