// Conditional re-export of `TymeDataImportService`.
//
// - Native/desktop: `tyme_data_import_service_io.dart` (real implementation
//   using `package:sqlite3`).
// - Web: `tyme_data_import_service_stub.dart` (no sqlite3 dependency; all
//   operations throw `UnsupportedError`).
//
// Callers should keep gating UI affordances with `PlatformUtils.isWeb` so the
// stub is never invoked at runtime.
export 'tyme_data_import_service_io.dart' if (dart.library.js_interop) 'tyme_data_import_service_stub.dart';
