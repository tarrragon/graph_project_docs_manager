// SPEC-009 測試設計 §1.5：fixture repo 建構器。以真實 git 在暫存目錄建 repo，
// 變體 R0～R10（本檔先收錄閘門、快照、唯讀降級所需的變體）。
import 'dart:io';
import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/edit_git_port.dart';

import '../../test/helpers/spec009/frontmatter_fixtures.dart';

const String editTargetRelative = 'docs/spec/x/SPEC-900.md';
const String _otherRelative = 'docs/spec/x/SPEC-901.md';

/// 記錄每次 git 呼叫後轉給真實 port 的包裝。
class RecordingEditGitPort implements EditGitPort {
  RecordingEditGitPort(this.inner);

  final EditGitPort inner;
  final List<EditGitInvocation> calls = [];

  @override
  Future<EditGitCall> start(EditGitInvocation invocation) {
    calls.add(invocation);
    return inner.start(invocation);
  }
}

/// 以真實 git 建在暫存目錄的 repo。
class EditFixtureRepo {
  EditFixtureRepo._(this.base, this.repoRoot, this.workspaceRoot);

  final Directory base;

  /// repo 根（非 git 變體為純目錄）。
  final String repoRoot;

  /// 工作區根（R3 為 repo 的子目錄，其餘等於 [repoRoot]）。
  final String workspaceRoot;

  /// 隔離使用者 git 設定、固定作者（§1.5 共同設定）。
  Map<String, String> get gitEnv => {
    'GIT_CONFIG_GLOBAL': '/dev/null',
    'GIT_CONFIG_NOSYSTEM': '1',
    'HOME': base.path,
    'GIT_AUTHOR_NAME': 'Fixture',
    'GIT_AUTHOR_EMAIL': 'fixture@example.invalid',
    'GIT_COMMITTER_NAME': 'Fixture',
    'GIT_COMMITTER_EMAIL': 'fixture@example.invalid',
    'LC_ALL': 'C',
  };

  String get targetPath => '$workspaceRoot/$editTargetRelative';

  /// 帶測試 fixture 隔離環境的真實 git port；[extraEnvironment] 供語系案使用。
  IoEditGitPort gitPort({
    Map<String, String> extraEnvironment = const {},
    String executable = 'git',
  }) => IoEditGitPort(
    executable: executable,
    baseEnvironment: {...gitEnv, ...extraEnvironment},
  );

  static Future<EditFixtureRepo> _create({bool init = true}) async {
    final base = await Directory.systemTemp.createTemp('edit_fixture_');
    final root = await base.resolveSymbolicLinks();
    final repo = EditFixtureRepo._(Directory(root), root, root);
    if (init) await repo._initRepo(repo.repoRoot);
    return repo;
  }

  Future<void> _initRepo(String where) async {
    await git(['init', '-q', '-b', 'main'], cwd: where);
    await git(['config', 'user.name', 'Fixture'], cwd: where);
    await git(['config', 'user.email', 'fixture@example.invalid'], cwd: where);
    await git(['config', 'commit.gpgsign', 'false'], cwd: where);
    await git(['config', 'core.autocrlf', 'false'], cwd: where);
  }

  Future<String> git(List<String> args, {String? cwd}) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: cwd ?? repoRoot,
      environment: gitEnv,
    );
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} 失敗：${result.stderr}');
    }
    return result.stdout as String;
  }

  /// 以位元組執行 git 並回傳 stdout 位元組。
  Future<Uint8List> gitBytes(List<String> args) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: repoRoot,
      environment: gitEnv,
      stdoutEncoding: null,
    );
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} 失敗：${result.stderr}');
    }
    return Uint8List.fromList(result.stdout as List<int>);
  }

  void write(String relative, List<int> bytes, {String? under}) {
    final file = File('${under ?? workspaceRoot}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }

  Uint8List read(String relative) =>
      File('$workspaceRoot/$relative').readAsBytesSync();

  Future<void> commitAll(String message) async {
    await git(['add', '-A']);
    await git(['commit', '-q', '-m', message]);
  }

  /// 把目標檔的 `title` 值改成 [value]（不 commit）。
  void modifyTitle(String value, {String? under}) {
    final file = File('${under ?? workspaceRoot}/$editTargetRelative');
    file.writeAsStringSync(
      file.readAsStringSync().replaceFirst('"原標題"', '"$value"'),
    );
  }

  void dispose() => base.deleteSync(recursive: true);

  /// R0 乾淨：W = H。
  static Future<EditFixtureRepo> r0() async {
    final repo = await _create();
    repo.write(editTargetRelative, fixtureBytes(docPlainText));
    await repo.commitAll('base');
    return repo;
  }

  /// R1 已追蹤且已改：W ≠ H。
  static Future<EditFixtureRepo> r1() async {
    final repo = await r0();
    repo.modifyTitle('已改標題');
    return repo;
  }

  /// R2 未追蹤檔：另有 SPEC-901，不 `git add`。
  static Future<EditFixtureRepo> r2() async {
    final repo = await r0();
    repo.write(_otherRelative, fixtureBytes(docPlainText));
    return repo;
  }

  /// R3 子目錄工作區：repo 根為 `repo/`，工作區根為 `repo/proj/`，並在 repo
  /// 根 commit 一份 title 不同的對照檔。
  static Future<EditFixtureRepo> r3() async {
    final base = await Directory.systemTemp.createTemp('edit_fixture_');
    final real = await base.resolveSymbolicLinks();
    final repoRoot = '$real/repo';
    final repo = EditFixtureRepo._(Directory(real), repoRoot, '$repoRoot/proj');
    Directory(repoRoot).createSync();
    await repo._initRepo(repoRoot);
    repo.write(editTargetRelative, fixtureBytes(docPlainText));
    repo.write(
      editTargetRelative,
      fixtureBytes(docPlainText.replaceFirst('"原標題"', '"對照檔標題"')),
      under: repoRoot,
    );
    await repo.commitAll('base');
    return repo;
  }

  /// R4 換行轉換：`.gitattributes` 為 `*.md text eol=crlf`，基準以 CRLF 提交，
  /// 之後改動一個值（仍為 CRLF），不 commit。
  static Future<EditFixtureRepo> r4() async {
    final repo = await _create();
    repo.write('.gitattributes', fixtureBytes('*.md text eol=crlf\n'));
    await repo._commitCrlfBase();
    return repo;
  }

  /// R4b autocrlf：不設 `.gitattributes`，改設 repo 層 `core.autocrlf true`。
  static Future<EditFixtureRepo> r4b() async {
    final repo = await _create();
    await repo.git(['config', 'core.autocrlf', 'true']);
    await repo._commitCrlfBase();
    return repo;
  }

  Future<void> _commitCrlfBase() async {
    write(editTargetRelative, fixtureBytes(docCrlfText));
    await commitAll('base');
    final file = File(targetPath);
    file.writeAsBytesSync(
      fixtureBytes(docCrlfText.replaceFirst('priority: P1', 'priority: P2')),
    );
  }

  /// R6 非 git：純目錄，含基準文件。
  static Future<EditFixtureRepo> r6() async {
    final repo = await _create(init: false);
    repo.write(editTargetRelative, fixtureBytes(docPlainText));
    return repo;
  }

  /// R8 他人狀態：R1 之上，另一檔已 staged，另有一筆 stash。
  static Future<EditFixtureRepo> r8() async {
    final repo = await _create();
    repo.write(editTargetRelative, fixtureBytes(docPlainText));
    repo.write('docs/stash_src.md', fixtureBytes('stash-base'));
    await repo.commitAll('base');
    repo.write('docs/stash_src.md', fixtureBytes('stash-changed'));
    await repo.git(['stash', 'push', '-q']);
    repo.modifyTitle('已改標題');
    repo.write('docs/other.md', fixtureBytes('staged-by-someone'));
    await repo.git(['add', 'docs/other.md']);
    return repo;
  }

  /// R9 尚無 commit：HEAD unborn。
  static Future<EditFixtureRepo> r9() async {
    final repo = await _create();
    repo.write(editTargetRelative, fixtureBytes(docPlainText));
    return repo;
  }

  /// R10 權限：R0 之上，基準文件 `chmod 0640`。
  static Future<EditFixtureRepo> r10() async {
    final repo = await r0();
    await Process.run('chmod', ['640', repo.targetPath]);
    return repo;
  }
}
