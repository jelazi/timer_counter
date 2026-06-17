// Web stub for `TymeDataImportService`.
//
// The real implementation lives in `tyme_data_import_service_io.dart` and
// depends on the `sqlite3` package, which in turn requires `dart:ffi` and
// therefore cannot compile for the web. This stub keeps the same public
// surface so that `tyme_data_import_service.dart`'s conditional re-export
// produces a working symbol on the web build. All operations throw at
// runtime because Tyme `.data` (SQLite) import has no meaningful web
// equivalent.

import '../../data/repositories/category_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import 'tyme_import_service.dart';

class TymeDataImportService {
  TymeDataImportService({
    required TimeEntryRepository timeEntryRepository,
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required CategoryRepository categoryRepository,
  });

  Future<ImportResult> importFromTymeData(String filePath, ImportMode mode) async {
    throw UnsupportedError('Importing Tyme .data files is not supported on web.');
  }
}
