// 節點詳情編輯模式（SPEC-003 §3.6、§4 #58–#60；SPEC-001 §6〈編輯模式〉、
// §1 唯讀降級；SPEC-003 §2.17〈1.0 新增兩格的測試設計〉列 23、24）。
//
// 以 widget 測試走畫面：port 層（git、檔案系統）以替身覆寫，Edit domain 與
// 閘門為真實實作；寫入結果只經欄位提示格與橫幅呈現，不經暫態提示通道。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/attention_arbiter.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/components/attention_level.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_edit_notifier.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_fixtures.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_screen.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../../helpers/gap_round_fakes.dart';
import '../../../helpers/helpers.dart';
import '../../../helpers/spec009/fake_edit_file_port.dart';
import '../../../helpers/spec009/fake_edit_git_port.dart';
import '../../../helpers/spec009/fake_validator_port.dart';
import '../../../helpers/spec009/frontmatter_fixtures.dart'
    show ucViolationOutput, unregisteredUc;

const String _relative = 'docs/spec/x/SPEC-900.md';
const String _otherRelative = 'docs/spec/x/SPEC-901.md';
const String _doc =
    '---\n'
    'id: SPEC-900\n'
    'title: 原標題\n'
    'status: draft\n'
    'domain: edit\n'
    'subdomain: sub\n'
    'owner: me\n'
    '---\n'
    '內文\n';

final AppLocalizationsZh _zh = AppLocalizationsZh();

/// 計數仲裁請求的替身：轉呼叫真實仲裁器。
class _SpyArbiter extends AttentionArbiterImpl {
  final List<AttentionRequest> requests = [];

  @override
  AttentionDecision request(AttentionRequest request) {
    requests.add(request);
    return super.request(request);
  }
}

NodeDetailFixture _node(String id, String type, String path, {String? rel}) =>
    NodeDetailFixture(
      id: id,
      type: type,
      status: 'draft',
      title: '原標題',
      filePath: path,
      markdown: '內文',
      relations: rel == null
          ? const []
          : [
              NodeRelationCategory(label: 'relates', nodeIds: [rel]),
            ],
    );

class _Env {
  _Env._(
    this.dir,
    this.root,
    this.files,
    this.git,
    this.arbiter,
    this.overrides,
  );

  final Directory dir;
  final String root;
  final FakeEditFilePort files;
  final FakeEditGitPort git;
  final _SpyArbiter arbiter;
  final List<Override> overrides;

  String get abs => WorkspaceRelativePath.from(root, _relative)!.absolute;

  Uint8List get target => files.files[abs]!;
  String get targetText => utf8.decode(target);

  void setDisk(String text) =>
      files.files[abs] = Uint8List.fromList(utf8.encode(text));

  static _Env create({
    FakeEditGitPort? git,
    String doc = _doc,
    String nodeType = 'SPEC',
    TypeTable? typeTable,
    FakeValidatorPort? validator,
  }) {
    final dir = Directory.systemTemp.createTempSync('node_detail_edit_');
    final root = dir.resolveSymbolicLinksSync();
    Directory('$root/docs/spec/x').createSync(recursive: true);
    final files = FakeEditFilePort();
    final bytes = Uint8List.fromList(utf8.encode(doc));
    files.files[WorkspaceRelativePath.from(root, _relative)!.absolute] = bytes;
    final fakeGit = git ?? FakeEditGitPort.repo(head: bytes);
    final arbiter = _SpyArbiter();
    final overrides = <Override>[
      nodeDetailNodesProvider.overrideWithValue({
        'SPEC-900': _node('SPEC-900', nodeType, _relative, rel: 'SPEC-901'),
        'SPEC-901': _node('SPEC-901', 'SPEC', _otherRelative),
      }),
      nodeDetailStateProvider.overrideWithInitial(
        (ref) => const NodeDetailReady(nodeId: 'SPEC-900'),
      ),
      currentWorkspaceStateProvider.overrideWithInitial(
        (ref) => WorkspaceReady(root),
      ),
      editGitPortProvider.overrideWithValue(fakeGit),
      editFilePortProvider.overrideWithValue(files),
      // 預設驗證永不完成（提示格停在驗證中）；不讓測試啟動真實 doc 子行程。
      editValidatorPortProvider.overrideWithValue(
        validator ??
            FakeValidatorPort(
              validate: const [ValidatorHang()],
              ucVerify: const [ValidatorHang()],
            ),
      ),
      attentionArbiterProvider.overrideWithValue(arbiter),
      scanRoundProvider.overrideWith(
        () => FakeScanRound(
          produce: () => fakeRound(typeTable: typeTable),
          initial: fakeRound(typeTable: typeTable),
        ),
      ),
    ];
    addTearDown(() => dir.deleteSync(recursive: true));
    return _Env._(dir, root, files, fakeGit, arbiter, overrides);
  }
}

Future<ProviderContainer> _pump(WidgetTester tester, _Env env) => pumpHarness(
  tester,
  child: const NodeDetailScreen(),
  overrides: env.overrides,
  size: WindowSize.design,
);

/// 假時鐘推進，讓 domain 的非同步鏈（讀檔、閘門、寫入）跑完。
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _enterEditing(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('action-nodeDetail-edit')));
  await _flush(tester);
}

Finder _anchor(String key) => find.byKey(Key(key));

/// testKey 落在 AppButton 內部的按鈕上，向上取 AppButton 本身。
AppButton _button(String key, WidgetTester tester) => tester.widget<AppButton>(
  find.ancestor(of: _anchor(key), matching: find.byType(AppButton)),
);

Finder _inputOf(String field) => find.descendant(
  of: _anchor('input-nodeDetail-field-$field'),
  matching: find.byType(EditableText),
);

Future<void> _submit(WidgetTester tester, String field, String text) async {
  await tester.enterText(_inputOf(field), text);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await _flush(tester);
}

Finder _hint(String field, String text) => find.descendant(
  of: _anchor('card-nodeDetail-field-$field'),
  matching: find.text(text),
);

/// 讓 git 子行程的 5 秒逾時計時器走完，避免殘留計時器。
Future<void> _drainTimers(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 40));

void main() {
  group('進入編輯（SPEC-003 §3.6 編輯欄位）', () {
    testWidgets('正常態渲染編輯鈕；Ticket 不渲染', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      expect(_anchor('action-nodeDetail-edit'), findsOneWidget);
      expect(find.text(_zh.editFieldsAction), findsOneWidget);
      await _drainTimers(tester);

      final ticket = _Env.create(nodeType: 'Ticket');
      await _pump(tester, ticket);
      expect(_anchor('action-nodeDetail-edit'), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('讀取成功：state-nodeDetail-editing，FieldList 取代分隔線以上整區', (
      tester,
    ) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);

      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      expect(_anchor('state-nodeDetail-normal'), findsNothing);
      expect(_anchor('panel-nodeDetail-field-list'), findsOneWidget);
      expect(find.byType(ListRow), findsNothing);
      expect(_anchor('action-nodeDetail-edit'), findsNothing);
      for (final field in ['title', 'status', 'domain', 'subdomain', 'owner']) {
        expect(_anchor('card-nodeDetail-field-$field'), findsOneWidget);
      }
      // 分隔線以下與關聯右欄同正常。
      expect(find.byType(DocumentBody), findsOneWidget);
      expect(_anchor('card-nodeDetail-relation-SPEC-901'), findsOneWidget);
      expect(_inputOf('title').evaluate().single.widget, isA<EditableText>());
      expect(
        tester.widget<EditableText>(_inputOf('title')).controller.text,
        '原標題',
      );
      await _drainTimers(tester);
    });

    testWidgets('notFound：轉 state-nodeDetail-missing，無 SnackBar', (
      tester,
    ) async {
      final env = _Env.create();
      await _pump(tester, env);
      env.files.files.remove(env.abs);
      await _enterEditing(tester);

      expect(_anchor('state-nodeDetail-missing'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(env.arbiter.requests, isEmpty);
      await _drainTimers(tester);
    });

    testWidgets('其他讀取失敗：維持正常，按鈕下方出現說明，無 SnackBar', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      env.files.readScript[1] = const EditFileException(errorCode: 5);
      await _enterEditing(tester);

      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      expect(_anchor('badge-nodeDetail-edit-read-failed'), findsOneWidget);
      expect(find.text(_zh.nodeDetailEditReadFailedMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(env.arbiter.requests, isEmpty);
      await _drainTimers(tester);
    });
  });

  group('唯讀降級（SPEC-001 §1、§6）', () {
    testWidgets('不是 git repo：編輯入口 disabled，點擊不進入編輯', (tester) async {
      final env = _Env.create(
        git: FakeEditGitPort((args) => GitExit.text(0, 'false\n')),
      );
      final container = await _pump(tester, env);
      await _flush(tester);

      final button = _button('action-nodeDetail-edit', tester);
      expect(button.enabled, isFalse);
      expect(button.disabledReason, _zh.readonlyWorkspaceNotGitBadge);
      await tester.tap(_anchor('action-nodeDetail-edit'), warnIfMissed: false);
      await _flush(tester);
      expect(container.read(nodeDetailEditProvider), isNull);
      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('git 無法執行：同樣 disabled，原因為 git 不可用', (tester) async {
      final env = _Env.create(
        git: FakeEditGitPort((args) => const GitLaunchFail()),
      );
      await _pump(tester, env);
      await _flush(tester);

      final button = _button('action-nodeDetail-edit', tester);
      expect(button.enabled, isFalse);
      expect(button.disabledReason, _zh.readonlyWorkspaceGitMissingBadge);
      await _drainTimers(tester);
    });

    testWidgets('正向對照：可寫工作區的編輯入口 enabled', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _flush(tester);
      expect(_button('action-nodeDetail-edit', tester).enabled, isTrue);
      await _drainTimers(tester);
    });
  });

  group('欄位送出（SPEC-003 §3.6、§2.17 列 23、24）', () {
    testWidgets('written：顯示新值、驗證中、不做樂觀更新、無 SnackBar', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      await _submit(tester, 'title', '新標題');

      expect(env.targetText, contains('title: "新標題"'));
      expect(
        tester.widget<EditableText>(_inputOf('title')).controller.text,
        '新標題',
      );
      expect(_hint('title', _zh.validationRunning), findsOneWidget);
      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(env.arbiter.requests, isEmpty);
      await _drainTimers(tester);
    });

    testWidgets('驗證通過：提示格由驗證中轉為通過', (tester) async {
      final env = _Env.create(validator: FakeValidatorPort());
      await _pump(tester, env);
      await _enterEditing(tester);
      await _submit(tester, 'title', '新標題');

      expect(_hint('title', _zh.validationPassed), findsOneWidget);
      expect(_hint('title', _zh.validationRunning), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('驗證發現新問題：提示格轉為失敗並帶問題數', (tester) async {
      final env = _Env.create(
        validator: FakeValidatorPort(
          ucVerify: [
            validatorOk,
            ValidatorExit(1, ucViolationOutput(unregisteredUc, 1)),
          ],
        ),
      );
      await _pump(tester, env);
      await _enterEditing(tester);
      await _submit(tester, 'title', '新標題');

      expect(_hint('title', _zh.validationFailed(1)), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('有快照時提示格另寫見寫入清單', (tester) async {
      final env = _Env.create(git: FakeEditGitPort.repo());
      await _pump(tester, env);
      await _enterEditing(tester);
      await _submit(tester, 'title', '新標題');

      expect(
        find.descendant(
          of: _anchor('card-nodeDetail-field-title'),
          matching: find.textContaining(_zh.fieldSeeWriteLogHint),
        ),
        findsOneWidget,
      );
      await _drainTimers(tester);
    });

    testWidgets('寫入進行中：提示寫入中、全部值格鎖定、完成不可用、不可並行送出', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      final hold = Completer<Uint8List>();
      env.files.readScript[2] = hold.future;
      await tester.enterText(_inputOf('title'), '新標題');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(_hint('title', _zh.fieldWriteInProgress), findsOneWidget);
      expect(tester.widget<EditableText>(_inputOf('owner')).readOnly, isTrue);
      expect(_button('action-nodeDetail-edit-done', tester).enabled, isFalse);
      // 並行送出被擋：第二欄送出不發出寫入。
      final before = env.files.ops.length;
      await tester.tap(
        _anchor('action-nodeDetail-edit-done'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      expect(env.files.ops.length, before);

      hold.complete(env.target);
      await _flush(tester);
      expect(_hint('title', _zh.fieldWriteInProgress), findsNothing);
      expect(tester.widget<EditableText>(_inputOf('owner')).readOnly, isFalse);
      await _drainTimers(tester);
    });

    testWidgets('列 23：通道被可棄 SnackBar 持有時 blocked(externallyModified)', (
      tester,
    ) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      AppSnackBar.show(
        tester.element(_anchor('panel-nodeDetail-field-list')),
        message: 'held',
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
      await tester.pump();
      expect(find.text('held'), findsOneWidget);

      env.setDisk(_doc.replaceFirst('原標題', '外部改的'));
      await _submit(tester, 'title', '新標題');

      expect(_anchor('state-nodeDetail-edit-blocked'), findsOneWidget);
      expect(_anchor('panel-nodeDetail-edit-banner'), findsOneWidget);
      expect(_anchor('action-nodeDetail-edit-reload'), findsOneWidget);
      expect(
        find.text(_zh.editBannerExternallyModifiedBlocked),
        findsOneWidget,
      );
      // 檔案未被寫；本次寫入沒有向仲裁器提出請求；持有中的 SnackBar 不被取代。
      expect(env.targetText, contains('外部改的'));
      expect(env.arbiter.requests, isEmpty);
      expect(find.text('held'), findsOneWidget);
      await _drainTimers(tester);
    });

    for (final failure in [
      'snapshotFailed',
      'rewriteNotIsolated',
      'ioFailed',
    ]) {
      testWidgets('列 24：$failure 維持編輯中，欄位提示格為錯誤樣式', (tester) async {
        final env = _Env.create(
          git: failure == 'snapshotFailed'
              ? FakeEditGitPort((args) {
                  return switch (FakeEditGitPort.subcommandOf(args)) {
                    'rev-parse' => GitExit.text(0, 'true\n'),
                    'show' => GitExit(128, stderr: 'not in head'),
                    _ => GitExit(1),
                  };
                })
              : null,
        );
        await _pump(tester, env);
        await _enterEditing(tester);
        if (failure == 'ioFailed') env.files.failOp('write');
        // owner 以外的缺席鍵走 rewriteNotIsolated。
        final field = failure == 'rewriteNotIsolated'
            ? 'has_functional_requirements'
            : 'title';
        await _submit(tester, field, '新值');

        final expected = switch (failure) {
          'snapshotFailed' => _zh.fieldBlockedSnapshotFailed,
          'rewriteNotIsolated' => _zh.fieldBlockedRewriteNotIsolated,
          _ => _zh.fieldIoFailed,
        };
        expect(_hint(field, expected), findsOneWidget);
        expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(env.arbiter.requests, isEmpty);
        await _drainTimers(tester);
      });
    }

    testWidgets('必填欄位送出空白：不發出寫入，提示格為 fieldRequiredEmpty', (tester) async {
      final env = _Env.create(
        typeTable: TypeTable({
          'SPEC': NodeTypeEntry(
            name: 'SPEC',
            completenessFields: const {'title'},
          ),
        }),
      );
      await _pump(tester, env);
      await _enterEditing(tester);
      final before = env.files.ops.length;
      await _submit(tester, 'title', '   ');

      expect(_hint('title', _zh.fieldRequiredEmpty), findsOneWidget);
      expect(env.files.ops.length, before);
      expect(env.targetText, contains('title: 原標題'));
      await _drainTimers(tester);
    });

    testWidgets('正向對照：非必填欄位空白寫 null', (tester) async {
      final env = _Env.create(
        typeTable: TypeTable({
          'SPEC': NodeTypeEntry(
            name: 'SPEC',
            completenessFields: const {'title'},
          ),
        }),
      );
      await _pump(tester, env);
      await _enterEditing(tester);
      await _submit(tester, 'owner', '');

      expect(env.targetText, contains('owner: null'));
      expect(_hint('owner', _zh.fieldRequiredEmpty), findsNothing);
      await _drainTimers(tester);
    });
  });

  group('草稿與焦點（SPEC-003 §3.6 欄位 Esc、失焦、Tab；SPEC-001 §6 未送出的草稿）', () {
    testWidgets('Esc：草稿還原為目前值，不發出寫入', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      final before = env.files.ops.length;
      await tester.enterText(_inputOf('title'), '草稿');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _flush(tester);

      expect(
        tester.widget<EditableText>(_inputOf('title')).controller.text,
        '原標題',
      );
      expect(env.files.ops.length, before);
      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('失焦：草稿保留不送出，提示格顯示未送出', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      final before = env.files.ops.length;
      await tester.enterText(_inputOf('title'), '草稿');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _flush(tester);

      expect(
        tester.widget<EditableText>(_inputOf('title')).controller.text,
        '草稿',
      );
      expect(_hint('title', _zh.fieldDraftUnsentHint), findsOneWidget);
      expect(env.files.ops.length, before);
      await _drainTimers(tester);
    });

    testWidgets('Tab：進入編輯後第一個停留點為首欄，依表列序到完成鈕', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);

      bool focusedIn(Finder finder) =>
          tester.widget<EditableText>(finder).focusNode.hasFocus;
      expect(focusedIn(_inputOf('title')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedIn(_inputOf('status')), isTrue);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focusedIn(_inputOf('owner')), isTrue);
      await _drainTimers(tester);
    });

    testWidgets('完成：未送出的草稿捨棄，回 state-nodeDetail-normal', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      await tester.enterText(_inputOf('title'), '草稿');
      await tester.pump();
      await tester.tap(_anchor('action-nodeDetail-edit-done'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      expect(container.read(nodeDetailEditProvider), isNull);
      expect(env.targetText, contains('title: 原標題'));
      await _drainTimers(tester);
    });

    testWidgets('完成：meta 列以最近一次 written 的值顯示', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      await _submit(tester, 'title', '新標題');
      await tester.tap(_anchor('action-nodeDetail-edit-done'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      expect(find.text('新標題'), findsOneWidget);
      expect(find.text('原標題'), findsNothing);
      await _drainTimers(tester);
    });
  });

  group('外部已改與放棄並重讀（#58–#60）', () {
    testWidgets('輪次完成且磁碟內容與 M 不同：轉預警，草稿保留', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      await tester.enterText(_inputOf('title'), '草稿');
      await tester.pump();

      env.setDisk(_doc.replaceFirst('me', 'someone'));
      _completeRound(container, env);
      await _flush(tester);

      expect(_anchor('state-nodeDetail-edit-warning'), findsOneWidget);
      expect(_anchor('panel-nodeDetail-edit-banner'), findsOneWidget);
      expect(
        find.text(_zh.editBannerExternallyModifiedWarning),
        findsOneWidget,
      );
      expect(_anchor('action-nodeDetail-edit-reload'), findsOneWidget);
      expect(
        tester.widget<EditableText>(_inputOf('title')).controller.text,
        '草稿',
      );
      expect(find.byType(SnackBar), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('輪次完成但內容與 M 相同：狀態不變（正向對照）', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      _completeRound(container, env);
      await _flush(tester);

      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      expect(_anchor('panel-nodeDetail-edit-banner'), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('重讀得 notFound 同樣轉預警', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      env.files.files.remove(env.abs);
      _completeRound(container, env);
      await _flush(tester);

      expect(_anchor('state-nodeDetail-edit-warning'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('預警下 written → 回編輯中', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      // 先造成預警：磁碟內容與 M 不同。
      env.setDisk(_doc.replaceFirst('me', 'x'));
      _completeRound(container, env);
      await _flush(tester);
      expect(_anchor('state-nodeDetail-edit-warning'), findsOneWidget);

      // 磁碟內容回到 M：送出得 written，回編輯中。
      env.setDisk(_doc);
      await _submit(tester, 'title', '新標題');
      expect(_anchor('state-nodeDetail-edit-warning'), findsNothing);
      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('阻擋下欄位不可送出；放棄並重讀成功 → 編輯中，顯示磁碟上的值', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      env.setDisk(_doc.replaceFirst('原標題', '外部改的'));
      await _submit(tester, 'title', '新標題');
      expect(_anchor('state-nodeDetail-edit-blocked'), findsOneWidget);
      // 阻擋時全部值格 disabled（不可送出）。
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: _anchor('input-nodeDetail-field-title'),
                matching: find.byType(TextField),
              ),
            )
            .enabled,
        isFalse,
      );

      await tester.tap(_anchor('action-nodeDetail-edit-reload'));
      await _flush(tester);
      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      expect(
        tester.widget<EditableText>(_inputOf('title')).controller.text,
        '外部改的',
      );
      expect(_anchor('panel-nodeDetail-edit-banner'), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('放棄並重讀：notFound → state-nodeDetail-missing', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      env.setDisk(_doc.replaceFirst('原標題', '外部改的'));
      await _submit(tester, 'title', '新標題');
      env.files.files.remove(env.abs);
      await tester.tap(_anchor('action-nodeDetail-edit-reload'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-missing'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('放棄並重讀：其他讀取失敗 → 維持原狀態，橫幅改讀取失敗說明', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      env.setDisk(_doc.replaceFirst('原標題', '外部改的'));
      await _submit(tester, 'title', '新標題');
      env.files.resetCounters();
      env.files.readScript[2] = const EditFileException(errorCode: 5);
      await tester.tap(_anchor('action-nodeDetail-edit-reload'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-edit-blocked'), findsOneWidget);
      expect(find.text(_zh.editBannerReloadFailed), findsOneWidget);
      await _drainTimers(tester);
    });
  });

  group('預警與阻擋的轉換（#59、#60；§3.6 放棄並重讀、生命週期）', () {
    Future<ProviderContainer> toWarning(WidgetTester tester, _Env env) async {
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      env.setDisk(_doc.replaceFirst('me', 'someone'));
      _completeRound(container, env);
      await _flush(tester);
      expect(_anchor('state-nodeDetail-edit-warning'), findsOneWidget);
      return container;
    }

    Future<void> toBlocked(WidgetTester tester, _Env env) async {
      await _pump(tester, env);
      await _enterEditing(tester);
      env.setDisk(_doc.replaceFirst('原標題', '外部改的'));
      await _submit(tester, 'title', '新標題');
      expect(_anchor('state-nodeDetail-edit-blocked'), findsOneWidget);
    }

    testWidgets('#59 預警：放棄並重讀成功 → 編輯中，草稿捨棄、顯示磁碟值、橫幅消失', (tester) async {
      final env = _Env.create();
      await toWarning(tester, env);
      await tester.enterText(_inputOf('title'), '草稿');
      await tester.pump();
      await tester.tap(_anchor('action-nodeDetail-edit-reload'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      expect(_anchor('panel-nodeDetail-edit-banner'), findsNothing);
      expect(
        tester.widget<EditableText>(_inputOf('title')).controller.text,
        '原標題',
      );
      expect(
        tester.widget<EditableText>(_inputOf('owner')).controller.text,
        'someone',
      );
      await _drainTimers(tester);
    });

    testWidgets('#59 預警：放棄並重讀得 notFound → state-nodeDetail-missing', (
      tester,
    ) async {
      final env = _Env.create();
      await toWarning(tester, env);
      env.files.files.remove(env.abs);
      await tester.tap(_anchor('action-nodeDetail-edit-reload'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-missing'), findsOneWidget);
      expect(_anchor('state-nodeDetail-edit-warning'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('#59 預警：送出得 blocked(externallyModified) → 阻擋', (tester) async {
      final env = _Env.create();
      await toWarning(tester, env);
      // 磁碟內容仍與 M 不同：閘門判 externallyModified。
      await _submit(tester, 'title', '新標題');

      expect(_anchor('state-nodeDetail-edit-blocked'), findsOneWidget);
      expect(
        find.text(_zh.editBannerExternallyModifiedBlocked),
        findsOneWidget,
      );
      expect(env.targetText, contains('someone'));
      await _drainTimers(tester);
    });

    testWidgets('#59 預警：完成 → state-nodeDetail-normal', (tester) async {
      final env = _Env.create();
      final container = await toWarning(tester, env);
      await tester.tap(_anchor('action-nodeDetail-edit-done'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      expect(container.read(nodeDetailEditProvider), isNull);
      await _drainTimers(tester);
    });

    testWidgets('#60 阻擋：完成 → state-nodeDetail-normal', (tester) async {
      final env = _Env.create();
      await toBlocked(tester, env);
      await tester.tap(_anchor('action-nodeDetail-edit-done'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('#60 阻擋：點關聯退出編輯模式並替換為該節點', (tester) async {
      final env = _Env.create();
      await toBlocked(tester, env);
      await tester.tap(_anchor('card-nodeDetail-relation-SPEC-901'));
      await _flush(tester);

      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      expect(_anchor('state-nodeDetail-edit-blocked'), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('放棄並重讀：重跑 baseline（驗證器再次被呼叫）', (tester) async {
      final validator = FakeValidatorPort(
        validate: const [ValidatorHang(), ValidatorHang()],
        ucVerify: const [ValidatorHang(), ValidatorHang()],
      );
      final env = _Env.create(validator: validator);
      await toWarning(tester, env);
      final before = validator.calls.length;
      await tester.tap(_anchor('action-nodeDetail-edit-reload'));
      await _flush(tester);

      expect(validator.calls.length, greaterThan(before));
      await _drainTimers(tester);
    });

    testWidgets('放棄並重讀：讀取失敗後橫幅為 negative，再按一次可成功', (tester) async {
      final env = _Env.create();
      await _pump(tester, env);
      await _enterEditing(tester);
      env.setDisk(_doc.replaceFirst('原標題', '外部改的'));
      await _submit(tester, 'title', '新標題');
      env.files.resetCounters();
      env.files.readScript[2] = const EditFileException(errorCode: 5);
      await tester.tap(_anchor('action-nodeDetail-edit-reload'));
      await _flush(tester);

      final banner = tester.widget<NoticeBanner>(find.byType(NoticeBanner));
      expect(banner.variant, NoticeBannerVariant.negative);
      expect(_button('action-nodeDetail-edit-reload', tester).enabled, isTrue);

      env.files.readScript.clear();
      await tester.tap(_anchor('action-nodeDetail-edit-reload'));
      await _flush(tester);
      expect(_anchor('state-nodeDetail-editing'), findsOneWidget);
      expect(_anchor('panel-nodeDetail-edit-banner'), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('已預警再收一輪：狀態維持預警', (tester) async {
      final env = _Env.create();
      final container = await toWarning(tester, env);
      _completeRound(container, env);
      await _flush(tester);

      expect(_anchor('state-nodeDetail-edit-warning'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('已阻擋再收一輪：狀態維持阻擋', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      env.setDisk(_doc.replaceFirst('原標題', '外部改的'));
      await _submit(tester, 'title', '新標題');
      _completeRound(container, env);
      await _flush(tester);

      expect(_anchor('state-nodeDetail-edit-blocked'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('切到其他導覽項期間收到輪次：回來時為預警', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      navigateTo(container.read, AppDestination.traceability, NavIntent.rail);
      await _flush(tester);
      env.setDisk(_doc.replaceFirst('me', 'someone'));
      _completeRound(container, env);
      await _flush(tester);
      navigateTo(container.read, AppDestination.nodeDetail, NavIntent.rail);
      await _flush(tester);

      expect(_anchor('state-nodeDetail-edit-warning'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('X-7：預警出現時不請求焦點，不搶走編輯中欄位的焦點', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      await tester.tap(_inputOf('owner'));
      await tester.pump();
      final focusBefore = FocusManager.instance.primaryFocus;
      expect(focusBefore, isNotNull);
      env.arbiter.requests.clear();

      env.setDisk(_doc.replaceFirst('原標題', '外部改的'));
      _completeRound(container, env);
      await _flush(tester);

      expect(_anchor('state-nodeDetail-edit-warning'), findsOneWidget);
      expect(env.arbiter.requests, isEmpty);
      expect(FocusManager.instance.primaryFocus, same(focusBefore));
      await _drainTimers(tester);
    });

    testWidgets('預警不出現 SnackBar，持有中的可棄 SnackBar 不被取代', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      AppSnackBar.show(
        tester.element(_anchor('panel-nodeDetail-field-list')),
        message: 'held',
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
      await tester.pump();
      env.arbiter.requests.clear();

      env.setDisk(_doc.replaceFirst('me', 'someone'));
      _completeRound(container, env);
      await _flush(tester);

      expect(_anchor('state-nodeDetail-edit-warning'), findsOneWidget);
      expect(env.arbiter.requests, isEmpty);
      expect(find.text('held'), findsOneWidget);
      await _drainTimers(tester);
    });
  });

  group('退出與保留（#58 返回與導覽）', () {
    testWidgets('點關聯：退出編輯模式並替換為該節點', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      await tester.tap(_anchor('card-nodeDetail-relation-SPEC-901'));
      await _flush(tester);

      expect(container.read(nodeDetailEditProvider), isNull);
      expect(_anchor('state-nodeDetail-normal'), findsOneWidget);
      expect(_anchor('state-nodeDetail-editing'), findsNothing);
      await _drainTimers(tester);
    });

    testWidgets('生命週期：圖不可用（判定順序 2 命中）退出編輯模式', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      final fake = container.read(scanRoundProvider.notifier) as FakeScanRound;
      fake.completeExternally(
        fakeRound(
          graphUnavailable:
              EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
        ),
      );
      await _flush(tester);

      expect(container.read(nodeDetailEditProvider), isNull);
      expect(_anchor('state-nodeDetail-graph-unavailable'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('生命週期：切換專案退出編輯模式', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      container.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/ws/other');
      await _flush(tester);

      expect(container.read(nodeDetailEditProvider), isNull);
      await _drainTimers(tester);
    });

    // 已重現為紅燈。返回與 rail 兩者都先清 returnTo 再切目的地，僅憑 provider
    // 值無法區分；修法需動 lib/app/router.dart（導覽模型，禁改檔），見票面
    // NeedsContext。
    testWidgets('rail 切到的目的地等於 returnTo：模式保留，不當作返回', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);
      navigateTo(container.read, AppDestination.domain, NavIntent.jump);
      navigateTo(container.read, AppDestination.nodeDetail, NavIntent.jump);
      // returnTo = domain；rail 直接切到 domain（與返回同終態）。
      navigateTo(container.read, AppDestination.domain, NavIntent.rail);
      await _flush(tester);

      expect(container.read(nodeDetailEditProvider), isNotNull);
      await _drainTimers(tester);
    });

    testWidgets('返回：退出編輯模式；rail 切換：模式保留', (tester) async {
      final env = _Env.create();
      final container = await _pump(tester, env);
      await _enterEditing(tester);

      navigateTo(container.read, AppDestination.traceability, NavIntent.rail);
      await _flush(tester);
      expect(container.read(nodeDetailEditProvider), isNotNull);

      navigateTo(container.read, AppDestination.nodeDetail, NavIntent.rail);
      navigateTo(container.read, AppDestination.domain, NavIntent.jump);
      navigateTo(container.read, AppDestination.nodeDetail, NavIntent.jump);
      await _flush(tester);
      expect(container.read(nodeDetailEditProvider), isNotNull);
      consumeReturnTo(container.read);
      await _flush(tester);
      expect(container.read(nodeDetailEditProvider), isNull);
      await _drainTimers(tester);
    });
  });
}

/// 以輪次完成模擬 EVT-CORPUS-001 的送達。
void _completeRound(ProviderContainer container, _Env env) {
  final fake = container.read(scanRoundProvider.notifier) as FakeScanRound;
  fake.completeExternally(fakeRound());
}
