enum AppThemeStyle { vault, stratum, cipher }

extension AppThemeStyleX on AppThemeStyle {
  String get persistKey {
    switch (this) {
      case AppThemeStyle.vault:
        return 'vault';
      case AppThemeStyle.stratum:
        return 'stratum';
      case AppThemeStyle.cipher:
        return 'cipher';
    }
  }

  static AppThemeStyle fromKey(String? key) {
    switch (key) {
      case 'stratum':
        return AppThemeStyle.stratum;
      case 'cipher':
        return AppThemeStyle.cipher;
      default:
        return AppThemeStyle.vault;
    }
  }
}
