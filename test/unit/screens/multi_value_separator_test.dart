// 多值串接分隔符共用函式（zh「、」、en「, 」；0.6.0-W1-127）。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/screens/multi_value_separator.dart';

void main() {
  test('zh 回頓號', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(multiValueSeparator(l10n), '、');
  });

  test('en 回逗號加空格', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(multiValueSeparator(l10n), ', ');
  });
}
