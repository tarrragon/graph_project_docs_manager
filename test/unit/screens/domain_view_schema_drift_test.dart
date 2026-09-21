// 內建型別表版本漂移偵測（0.1.0-W2-012 acceptance 3）。
//
// 承擔者與門檻（decision-trigger-binding 規則 1／2.5，非無 trigger 的
// 待觀察）：
//   門檻：schemaVersionMinorDrift（.claude/VERSION 與內嵌資產版本的
//         次版號差距）超過 kSchemaVersionDriftThreshold（現行 25）。
//   承擔者：下一位執行涉及
//         lib/screens/domain_view/domain_view_schema_version.dart 或
//         assets/schema/builtin_schema_version.json 的 IMP ticket 之
//         parsley-flutter-developer——本測試轉紅即為其入口 ticket 的
//         acceptance 訊號，不需另建監測 ticket。
//   偵測機制：下方「漂移未超過門檻」一案以真實 .claude/VERSION 驅動，
//         超過門檻時本測試轉紅、CI 卡關。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_schema_version.dart';

void main() {
  group('schemaVersionMinorDrift（純函式，固定 fixture）', () {
    test('次版號差距為正整數', () {
      expect(schemaVersionMinorDrift('2.60.1', '2.40.3'), 20);
    });

    test('次版號相同 → 差距為 0', () {
      expect(schemaVersionMinorDrift('2.40.9', '2.40.3'), 0);
    });

    test('任一版本字串不足兩段 → 無法判定，回傳 null', () {
      expect(schemaVersionMinorDrift('2', '2.40.3'), isNull);
    });

    test('任一段無法解析為整數 → 無法判定，回傳 null', () {
      expect(schemaVersionMinorDrift('2.x.1', '2.40.3'), isNull);
    });
  });

  group('isBuiltinSchemaVersionDrifted（純函式，固定 fixture）', () {
    test('差距未超過門檻 → 未漂移', () {
      expect(
        isBuiltinSchemaVersionDrifted('2.44.0', '2.40.3', threshold: 10),
        isFalse,
      );
    });

    test('差距超過門檻 → 已漂移', () {
      expect(
        isBuiltinSchemaVersionDrifted('2.60.1', '2.40.3', threshold: 10),
        isTrue,
      );
    });

    test('無法判定時視為未漂移（診斷用途，不誤報）', () {
      expect(
        isBuiltinSchemaVersionDrifted('2', '2.40.3', threshold: 10),
        isFalse,
      );
    });
  });

  group('漂移偵測門檻測試（真實 .claude/VERSION 驅動）', () {
    test('.claude/VERSION 與內嵌資產版本的差距未超過門檻', () {
      final liveVersion = File('.claude/VERSION').readAsStringSync().trim();
      final assetJson = jsonDecode(
        File(
          'assets/schema/builtin_schema_version.json',
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      final assetVersion =
          assetJson['schema_generated_at_framework_version'] as String;

      final drift = schemaVersionMinorDrift(liveVersion, assetVersion);
      expect(
        isBuiltinSchemaVersionDrifted(liveVersion, assetVersion),
        isFalse,
        reason:
            '.claude/VERSION（$liveVersion）與內嵌資產版本（$assetVersion）的'
            '次版號差距（$drift）已超過門檻（$kSchemaVersionDriftThreshold）：'
            '請同步更新 assets/schema/builtin_schema_version.json 的'
            'schema_generated_at_framework_version 欄（見本檔檔頭承擔者說明）',
      );
    });
  });
}
