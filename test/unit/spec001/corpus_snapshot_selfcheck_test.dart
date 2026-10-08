import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// 需求：SPEC-001-test-design §1.2 / 0.5.0-W1-114.6
/// 自我驗證凍結快照：只斷言可由檔案直接數出的值；不含載入器、不建圖。
const _root = 'test/fixtures/spec001/corpus_snapshot';

class _Counts {
  _Counts(this.bundles, this.ucs);
  final int bundles;
  final int ucs;
}

List<File> _filesUnder(Directory dir, bool Function(String) match) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => match(f.path))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

List<File> _domainMaps(Directory c) =>
    _filesUnder(c, (p) => p.endsWith('domain-map.md'));

List<File> _ucs(Directory c) => _filesUnder(
  c,
  (p) => p.contains('/docs/usecases/') && p.endsWith('.md'),
);

_Counts _count(Directory c) =>
    _Counts(_domainMaps(c).length, _ucs(c).length);

YamlMap _frontmatter(File f) {
  final lines = f.readAsStringSync().split('\n');
  final end = lines.indexOf('---', 1);
  return loadYaml(lines.sublist(1, end).join('\n')) as YamlMap;
}

List<YamlMap> _flowSteps(File f) {
  final lines = f.readAsStringSync().split('\n');
  final body = lines.sublist(1, lines.lastIndexOf('```'));
  final doc = loadYaml(body.join('\n')) as YamlMap;
  return (doc['flow'] as YamlList).cast<YamlMap>().toList();
}

void main() {
  final own = Directory('$_root/graph_project_docs_manager');
  final bal = Directory('$_root/flutter_balance');

  group('凍結快照自我驗證', () {
    test('本專案：DomainBundle 8、UC 6', () {
      final c = _count(own);
      expect(c.bundles, 8);
      expect(c.ucs, 6);
    });

    test('flutter_balance：DomainBundle 1（balance-sheet）、無 bundle_dependency', () {
      final maps = _domainMaps(bal);
      expect(maps, hasLength(1));
      final fm = _frontmatter(maps.single);
      expect(fm['domain'], 'balance-sheet');
      expect(fm.containsKey('depends_on_bundles'), isFalse);
      expect(fm.containsKey('path_patterns'), isFalse);
    });

    test('flutter_balance：UC 1、UC-01 九步、四分支步皆帶 return_to、無 traverses', () {
      final ucs = _ucs(bal);
      expect(ucs, hasLength(1));
      final steps = _flowSteps(ucs.single);
      expect(steps, hasLength(9));
      final branches = steps.where((s) => s['branch_from'] != null);
      expect(branches, hasLength(4));
      expect(branches.every((s) => s['return_to'] != null), isTrue);
      expect(steps.any((s) => s.containsKey('traverses')), isFalse);
    });

    test('flutter_balance：無非 domain 清單', () {
      final text = _filesUnder(bal, (p) => p.endsWith('domain-map.md'))
          .single
          .readAsStringSync();
      expect(text.contains('path_patterns'), isFalse);
      expect(text.contains('non_domain'), isFalse);
    });

    test('每份語料皆含 MANIFEST 與型別表', () {
      for (final c in [own, bal]) {
        expect(File('${c.path}/MANIFEST.md').existsSync(), isTrue);
        expect(
          File(
            '${c.path}/.claude/skills/doc/doc_system/core/tracking_schema.json',
          ).existsSync(),
          isTrue,
        );
      }
    });

    test('E2：刪去一個 UC 的暫時副本，UC 計數翻紅', () {
      final tmp = Directory.systemTemp.createTempSync('corpus_e2_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      for (final f in own.listSync(recursive: true).whereType<File>()) {
        final rel = f.path.substring(own.path.length + 1);
        final dest = File('${tmp.path}/$rel')..createSync(recursive: true);
        dest.writeAsBytesSync(f.readAsBytesSync());
      }
      expect(_count(tmp).ucs, 6, reason: '副本未刪前應與快照一致');
      _ucs(tmp).first.deleteSync();
      expect(_count(tmp).ucs, isNot(6));
      expect(_count(tmp).ucs, 5);
    });
  });
}
