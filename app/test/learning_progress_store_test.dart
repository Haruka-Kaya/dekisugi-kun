import 'package:dekisugi/services/session_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/learning_progress_store_contract.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runLearningProgressStoreContract('Memory', () async => MemorySessionStore());
  runLearningProgressStoreContract(
    'SQLite',
    () => SqfliteSessionStore.open(path: inMemoryDatabasePath),
  );
}
