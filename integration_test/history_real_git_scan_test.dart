// SPEC-008 測試設計 §2.3 RG：真實 git 行為（FR-01、FR-08 規則 1 語系）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/history_fixture_repo.dart';

const int _t1 = 1700000100;
const int _t2 = 1700000200;
const int _t3 = 1700000300;

String _signature(List<EdgeEvent> events) => [
  for (final e in events)
    '${e.type.name}|${e.key}|${e.commitId}|${e.declarersAfter}',
].join('\n');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final disposables = <FixtureRepo>[];
  tearDownAll(() async {
    for (final repo in disposables) {
      await repo.dispose();
    }
  });

  Future<FixtureRepo> newRepo({bool init = true}) async {
    final repo = await FixtureRepo.create(init: init);
    disposables.add(repo);
    return repo;
  }

  Future<HistoryPipelineResult> scan(
    String root, {
    Map<String, String> env = const {},
  }) => runHistoryPipeline(
    root,
    PathRestrictedRunner(realPathDirs(), extraEnvironment: env),
  );

  test('RG-1 只取工作區根下的 docs/**/*.md，路徑相對於工作區根', () async {
    final repo = await newRepo();
    await repo.write(
      'notes.md',
      frontmatterDoc({'id': 'N', 'parent_id': 'NP'}),
    );
    await repo.write(
      'other/x.md',
      frontmatterDoc({'id': 'X', 'parent_id': 'XP'}),
    );
    await repo.write(
      'proj/docs/a.md',
      frontmatterDoc({'id': 'A', 'parent_id': 'AP'}),
    );
    await repo.commitAll('c1', epochSeconds: _t1);
    final result = await scan('${repo.path}/proj');
    expect(result.kind, GitScanCompleted);
    expect(result.changedPaths, ['docs/a.md']);
    expect(result.events, hasLength(1));
    final key = result.events.single.key;
    expect({key.from, key.to}, {'A', 'AP'});
  });

  test('RG-2 git mv 且內容不變：commit 2 無事件，commit 1 一筆新增', () async {
    final repo = await newRepo();
    await repo.write(
      'docs/a/x.md',
      frontmatterDoc({'id': 'X', 'parent_id': 'P'}),
    );
    final first = await repo.commitAll('c1', epochSeconds: _t1);
    await Directory('${repo.path}/docs/b').create(recursive: true);
    await repo.git(['mv', 'docs/a/x.md', 'docs/b/x.md']);
    await repo.commitAll('c2', epochSeconds: _t2);
    final result = await scan(repo.path);
    expect(result.events, hasLength(1));
    expect(result.events.single.type, EdgeEventType.added);
    expect(result.events.single.commitId, first);
  });

  test('RG-3 使用者 git 設定不影響事件清單', () async {
    final repo = await newRepo();
    await repo.write(
      'docs/a.md',
      frontmatterDoc({'id': 'A', 'parent_id': 'P1'}),
    );
    await repo.commitAll('c1', epochSeconds: _t1);
    await repo.write(
      'docs/a.md',
      frontmatterDoc({'id': 'A', 'parent_id': 'P2'}),
    );
    await repo.commitAll('c2', epochSeconds: _t2);
    final plain = await scan(repo.path);
    await repo.setConfig('diff.noprefix', 'true');
    await repo.setConfig('log.showSignature', 'true');
    await repo.setConfig('diff.mnemonicPrefix', 'true');
    final configured = await scan(repo.path);
    expect(plain.events, isNotEmpty);
    expect(_signature(configured.events), _signature(plain.events));
  });

  test('RG-4 非 git 目錄在 zh_TW 語系下仍為非 git 專案，且 git 呼叫帶 LC_ALL=C', () async {
    final dir = await newRepo(init: false);
    final runner = PathRestrictedRunner(
      realPathDirs(),
      extraEnvironment: const {
        'LANG': 'zh_TW.UTF-8',
        'LC_MESSAGES': 'zh_TW.UTF-8',
      },
    );
    final result = await runHistoryPipeline(dir.path, runner);
    expect(result.kind, GitPreflightNotWorkTree);
    expect(runner.seenEnvironments, isNotEmpty);
    expect(
      runner.seenEnvironments.every((env) => env['LC_ALL'] == 'C'),
      isTrue,
    );
  });

  test('RG-5 merge commit 的變更歸屬主線 merge commit', () async {
    final repo = await newRepo();
    await repo.write('docs/base.md', frontmatterDoc({'id': 'B'}));
    await repo.commitAll('base', epochSeconds: _t1);
    await repo.checkoutNewBranch('feat');
    await repo.write(
      'docs/r.md',
      frontmatterDoc({
        'id': 'R',
        'relatedTo': ['Z'],
      }),
    );
    await repo.commitAll('feat1', epochSeconds: _t2);
    await repo.write(
      'docs/k.md',
      frontmatterDoc({
        'id': 'K',
        'blockedBy': ['Y'],
      }),
    );
    final branchTip = await repo.commitAll('feat2', epochSeconds: _t2 + 50);
    await repo.checkout('main');
    final merge = await repo.mergeNoFf('feat', 'M', epochSeconds: _t3);
    final result = await scan(repo.path);
    expect(result.events, hasLength(2));
    expect(result.events.every((e) => e.commitId == merge), isTrue);
    expect(result.events.any((e) => e.commitId == branchTip), isFalse);
  });
}
