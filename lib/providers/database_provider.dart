import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/database_repository.dart';

final databaseRepositoryProvider = Provider<DatabaseRepository>((ref) {
  throw UnimplementedError('databaseRepositoryProvider must be overridden');
});
