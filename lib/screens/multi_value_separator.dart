import '../l10n/app_localizations.dart';

/// 多值串接分隔符依語系選擇；只支援 zh／en（新增語系時只在此補分支）。
String multiValueSeparator(AppLocalizations l10n) =>
    l10n.localeName.startsWith('zh') ? '、' : ', '; // i18n-exempt: 語系分隔符
