import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/corpus_parsed_source.dart';
import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';

import 'fake_edit_file_port.dart';
import 'fake_edit_git_port.dart';
import 'fake_validator_port.dart';
import 'frontmatter_fixtures.dart';
import 'manual_edit_timer.dart';

const String targetRelative = 'docs/spec/x/SPEC-900.md';

/// 需求：[SPEC-009-test-design §3 G／S／R] 閘門單元測試的共用裝配：真實暫存
/// 目錄（供 [WorkspaceRelativePath] 解析）加上 fake 檔案、git port 與虛擬計時器。
class EditHarness {
  EditHarness._(this.dir, this.root, this.path, this.files, this.git);

  final Directory dir;
  final String root;
  final WorkspaceRelativePath path;
  final FakeEditFilePort files;
  final FakeEditGitPort git;
  late final ManualEditTimer timer;

  /// 工作區開啟時（探測）發出的 git 呼叫。
  late final List<EditGitInvocation> probeCalls;
  late final EditWorkspace workspace;

  /// 目標檔在記憶體檔案集合中的內容。
  Uint8List? get target => files.files[path.absolute];

  static Future<EditHarness> create({
    String? content,
    Uint8List? bytes,
    FakeEditGitPort? git,
    FieldRewriter? rewriter,
    FakeValidatorPort? validator,
    ManualEditTimer? timer,
  }) async {
    final dir = Directory.systemTemp.createTempSync('edit_gate_');
    final root = dir.resolveSymbolicLinksSync();
    Directory('$root/docs/spec/x').createSync(recursive: true);
    final path = WorkspaceRelativePath.from(root, targetRelative)!;
    final files = FakeEditFilePort()
      ..files[path.absolute] = bytes ?? fixtureBytes(content ?? docPlainText);
    final harness = EditHarness._(
      dir,
      root,
      path,
      files,
      git ??
          FakeEditGitPort.repo(
            head: bytes ?? fixtureBytes(content ?? docPlainText),
          ),
    );
    harness.timer = timer ?? ManualEditTimer();
    harness.workspace = await EditWorkspace.open(
      root: root,
      git: harness.git,
      files: files,
      timer: harness.timer.call,
      now: () => DateTime(2026, 11, 10),
      rewriter: rewriter,
      validator: validator,
    );
    harness.probeCalls = List.of(harness.git.calls);
    addTearDown(() => dir.deleteSync(recursive: true));
    return harness;
  }

  /// 開始編輯並清除計數：之後的讀取編號、操作記錄與 git 呼叫都自此起算。
  Future<EditSession> begin({CorpusParsedSource? corpusParsed}) async {
    final result = await workspace.beginEditing(
      path,
      corpusParsed: corpusParsed,
    );
    expect(result, isA<EditingStarted>());
    files.resetCounters();
    git.calls.clear();
    return (result as EditingStarted).session;
  }

  /// 目標檔同目錄中不是目標檔本身的檔案（暫存檔殘留）。
  List<String> get strayFiles => [
    for (final key in files.files.keys)
      if (key != path.absolute) key,
  ];
}

/// 修改一個位元組的複本。
Uint8List flipLastByte(Uint8List bytes) =>
    Uint8List.fromList(bytes)..[bytes.length - 1] ^= 0x01;
