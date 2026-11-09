// SPEC-008 測試設計 §2.2 IT-H2：三種降級可辨識（FR-08），以真實 git 建 fixture。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/git/git_history_port.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/history_fixture_repo.dart';

const int _t1 = 1700000100;
const int _t3 = 1700000300;

Future<FixtureRepo> _nonGitDir() async {
  final repo = await FixtureRepo.create(init: false);
  await repo.write('docs/a.md', frontmatterDoc({'id': 'A'}));
  return repo;
}

Future<FixtureRepo> _repoWithCommit() async {
  final repo = await FixtureRepo.create();
  await repo.write('docs/a.md', frontmatterDoc({'id': 'A'}));
  await repo.commitAll('first', epochSeconds: _t1);
  return repo;
}

/// 3 個 commit 的來源 repo；每個 commit 都新增帶 parent_id 的檔案。
Future<FixtureRepo> _threeCommitSource() async {
  final repo = await FixtureRepo.create();
  var seconds = _t1;
  for (final name in ['a', 'b', 'c']) {
    await repo.write(
      'docs/$name.md',
      frontmatterDoc({'id': name.toUpperCase(), 'parent_id': 'ROOT'}),
    );
    await repo.commitAll('add $name', epochSeconds: seconds);
    seconds += 100;
  }
  return repo;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final disposables = <FixtureRepo>[];
  tearDownAll(() async {
    for (final repo in disposables) {
      await repo.dispose();
    }
  });

  Future<FixtureRepo> track(Future<FixtureRepo> pending) async {
    final repo = await pending;
    disposables.add(repo);
    return repo;
  }

  Future<HistoryPipelineResult> runWithRealPath(String root) =>
      runHistoryPipeline(root, PathRestrictedRunner(realPathDirs()));

  test('H2-1 非 git 目錄：結果為非 git 專案', () async {
    final repo = await track(_nonGitDir());
    final result = await runWithRealPath(repo.path);
    expect(result.kind, GitPreflightNotWorkTree);
  });

  test('H2-2 PATH 不含 git：結果為找不到 git', () async {
    final repo = await track(_repoWithCommit());
    final emptyPath = await Directory.systemTemp.createTemp('history_nopath_');
    addTearDown(() => emptyPath.delete(recursive: true));
    final result = await runHistoryPipeline(
      repo.path,
      PathRestrictedRunner([emptyPath.path]),
    );
    expect(result.kind, GitPreflightGitNotFound);
  });

  test('H2-3 淺層 clone：完成且帶淺層資訊，邊界時間等於來源 HEAD，事件為空', () async {
    final source = await track(_threeCommitSource());
    final clone = await track(source.shallowClone(depth: 1));
    final sourceHeadTime = int.parse(
      await source.git(['log', '-1', '--format=%ct']),
    );
    final result = await runWithRealPath(clone.path);
    expect(result.kind, GitScanCompleted);
    expect(result.ready!.isShallow, isTrue);
    expect(result.commitTimes, [sourceHeadTime]);
    expect(sourceHeadTime, _t3);
    expect(result.events, isEmpty);
    // 正向對照：同一 fixture 若非淺層，邊界 commit 會產生事件，證明「事件為空」有鑑別力。
    final full = await runWithRealPath(source.path);
    expect(full.events, isNotEmpty);
  });

  test('H2-4 三種結果型別兩兩不同，且皆非讀取失敗', () async {
    final nonGit = await track(_nonGitDir());
    final noPath = await track(_repoWithCommit());
    final shallow = await track(
      (await track(_threeCommitSource())).shallowClone(),
    );
    final emptyPath = await Directory.systemTemp.createTemp('history_nopath_');
    addTearDown(() => emptyPath.delete(recursive: true));
    final results = [
      await runWithRealPath(nonGit.path),
      await runHistoryPipeline(
        noPath.path,
        PathRestrictedRunner([emptyPath.path]),
      ),
      await runWithRealPath(shallow.path),
    ];
    expect(results.map((r) => r.kind).toSet(), hasLength(3));
    expect(results.every((r) => !r.isReadFailure), isTrue);
  });

  test('H2-5 正向對照：git 版本過舊為讀取失敗（原因碼 gitVersionTooOld）', () async {
    final repo = await track(_repoWithCommit());
    final fakeDir = await Directory.systemTemp.createTemp('history_oldgit_');
    addTearDown(() => fakeDir.delete(recursive: true));
    final script = File('${fakeDir.path}/git');
    await script.writeAsString('#!/bin/sh\necho "git version 2.30.0"\n');
    await Process.run('chmod', ['+x', script.path]);
    final result = await runHistoryPipeline(
      repo.path,
      PathRestrictedRunner([fakeDir.path]),
    );
    expect(result.isReadFailure, isTrue);
    final stopped = result.open as GitOpenStopped;
    final failed = stopped.outcome as GitPreflightFailed;
    expect(failed.reason, GitFailureReason.gitVersionTooOld);
  });
}
