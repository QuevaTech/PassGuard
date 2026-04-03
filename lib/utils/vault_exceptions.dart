/// Typed exceptions for PassGuard Vault — replace brittle string matching.
abstract class VaultException implements Exception {
  final String message;
  const VaultException(this.message);
  @override
  String toString() => message;
}

class VaultVersionUnsupportedException extends VaultException {
  const VaultVersionUnsupportedException()
      : super('vault_version_unsupported');
}

class CsvFormatUnsupportedException extends VaultException {
  const CsvFormatUnsupportedException() : super('csv_format_unsupported');
}

class VaultCorruptedException extends VaultException {
  const VaultCorruptedException() : super('vault_corrupted');
}

class WrongMasterPasswordException extends VaultException {
  const WrongMasterPasswordException() : super('wrong_master_password');
}

class VaultNotFoundException extends VaultException {
  const VaultNotFoundException() : super('vault_not_found');
}

class EntryNotFoundException extends VaultException {
  const EntryNotFoundException() : super('entry_not_found');
}

class ImportFileTooLargeException extends VaultException {
  const ImportFileTooLargeException() : super('import_file_too_large');
}
