/// 節點詳情編輯模式的狀態持有者（SPEC-001 §6〈編輯模式〉；SPEC-003 §3.6、
/// §4 #58–#60）。
///
/// 把 Edit domain 的 `WriteResult`、`ValidationStatus` 映射為 `FieldBlock`
/// 自有型別（元件不 import domain）。寫入結果只經欄位提示格與橫幅呈現，
/// 不向暫態提示通道發請求（SPEC-003 §2.14 列 23–25）。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/components/field_block.dart';
import 'package:graph_project_docs_manager/components/field_list.dart'
    show FieldListReloadResult;
import 'package:graph_project_docs_manager/corpus/frontmatter_classifier.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import 'field_input_mapping.dart';
import 'node_detail_providers.dart';
import 'node_detail_state.dart';

/// 編輯模式狀態；`null` 為不在編輯模式。
final NotifierProvider<NodeDetailEditNotifier, NodeDetailEditState?>
nodeDetailEditProvider =
    NotifierProvider<NodeDetailEditNotifier, NodeDetailEditState?>(
      NodeDetailEditNotifier.new,
    );

/// 開始編輯讀取失敗的節點 id（`badge-nodeDetail-edit-read-failed`）；無則 null。
final nodeDetailEditReadFailedProvider = stateHolderProvider<String?>(
  (ref) => null,
);

/// 完成後、下一輪掃描完成前，meta 列以受理值顯示的欄位（節點 id → 欄位 → 值）。
final nodeDetailAcceptedValuesProvider =
    stateHolderProvider<Map<String, Map<String, String>>>((ref) => const {});

/// 工作區相對路徑對應的編輯欄位鍵（FR-09 表列序）。
List<String> editableFieldKeysFor(String nodeType) => [
  for (final key in editableInOneZeroFields())
    if (key.startsWith('$nodeType.')) key.substring(nodeType.length + 1),
];

/// 編輯模式的 [Notifier]。
class NodeDetailEditNotifier extends Notifier<NodeDetailEditState?> {
  StreamSubscription<WriteObservation>? _observations;
  String? _lastWrittenField;

  @override
  NodeDetailEditState? build() {
    ref.onDispose(() => _observations?.cancel());
    // 看衍生後的狀態：點關聯換節點與判定順序 1–4 命中（專案未就緒、圖不可用、
    // 節點不在圖上）都使編輯目標不再成立。
    ref.listen<NodeDetailState>(
      nodeDetailEffectiveStateProvider,
      _onNodeChanged,
    );
    ref.listen<ScanRoundResult?>(lastCompletedRoundProvider, _onRoundChanged);
    ref.listen<ReturnEvent?>(returnEventProvider, _onReturn);
    ref.listen<WorkspaceState>(currentWorkspaceStateProvider, (_, _) {
      _exit();
    });
    return null;
  }

  /// 點關聯換節點、節點消失、狀態離開正常：退出模式（草稿捨棄）。
  void _onNodeChanged(NodeDetailState? _, NodeDetailState next) {
    final editing = state;
    if (editing == null) return;
    if (next is! NodeDetailReady || next.nodeId != editing.nodeId) _exit();
  }

  /// 返回（`consumeReturnTo`）自節點詳情觸發時退出模式；rail 切換與其他
  /// 畫面的返回保留模式（以 [returnEventProvider] 判斷，不看 returnTo 值）。
  void _onReturn(ReturnEvent? _, ReturnEvent? event) {
    if (state != null && event?.from == AppDestination.nodeDetail) _exit();
  }

  /// 輪次完成即 EVT-CORPUS-001 的送達點：編輯中時重讀比較 M（SPEC-009
  /// FR-06）；不同或 notFound 轉預警，已預警／阻擋不變。同時清除受理值。
  void _onRoundChanged(ScanRoundResult? _, ScanRoundResult? next) {
    ref.read(nodeDetailAcceptedValuesProvider.notifier).state = const {};
    final editing = state;
    if (editing == null || editing.phase != NodeDetailEditPhase.editing) return;
    unawaited(_recheckAgainstDisk(editing));
  }

  Future<void> _recheckAgainstDisk(NodeDetailEditState editing) async {
    final bytes = await _readDisk(editing.path);
    final now = state;
    if (now == null || !identical(now.session, editing.session)) return;
    if (now.phase != NodeDetailEditPhase.editing) return;
    if (bytes != null && _same(bytes, now.session.baseline)) return;
    state = now.copyWith(phase: NodeDetailEditPhase.warning);
  }

  Future<Uint8List?> _readDisk(WorkspaceRelativePath path) async {
    try {
      return await ref.read(editFilePortProvider).read(path.absolute);
    } on EditFileException {
      return null;
    }
  }

  void _exit() {
    _observations?.cancel();
    _observations = null;
    _lastWrittenField = null;
    state = null;
  }

  /// 開始編輯（SPEC-003 §3.6〈編輯欄位〉）。
  Future<NodeDetailEditBeginResult> begin({
    required String nodeId,
    required String nodeType,
    required String relativePath,
  }) async {
    final workspace = await ref.read(editWorkspaceProvider.future);
    final root = ref.read(currentWorkspaceStateProvider);
    final path = root is WorkspaceReady
        ? WorkspaceRelativePath.from(root.path, relativePath)
        : null;
    if (workspace == null || path == null) {
      return NodeDetailEditBeginResult.unavailable;
    }
    return _beginWith(workspace, path, nodeId, nodeType);
  }

  Future<NodeDetailEditBeginResult> _beginWith(
    EditWorkspace workspace,
    WorkspaceRelativePath path,
    String nodeId,
    String nodeType,
  ) async {
    final result = await workspace.beginEditing(path);
    switch (result) {
      case EditingReadOnly():
        return NodeDetailEditBeginResult.unavailable;
      case EditingReadFailed():
        return await _probe(path) == _Probe.notFound
            ? NodeDetailEditBeginResult.missing
            : NodeDetailEditBeginResult.readFailed;
      case EditingStarted(:final session):
        _start(session, path, nodeId, nodeType);
        return NodeDetailEditBeginResult.started;
    }
  }

  void _start(
    EditSession session,
    WorkspaceRelativePath path,
    String nodeId,
    String nodeType,
  ) {
    _observations?.cancel();
    _lastWrittenField = null;
    _observations = session.observations.listen(_onObservation);
    state = NodeDetailEditState(
      nodeId: nodeId,
      nodeType: nodeType,
      session: session,
      path: path,
      fieldKeys: editableFieldKeysFor(nodeType),
      values: _valuesOf(session.baseline),
    );
  }

  /// 送出（SPEC-003 §3.6〈欄位送出〉）：沒有其他寫入進行中、非阻擋才發出。
  Future<void> submit(String field, String draft) async {
    final editing = state;
    if (editing == null || editing.writeInProgress) return;
    if (editing.phase == NodeDetailEditPhase.blocked) return;
    final decision = decideSubmit(
      editing.nodeType,
      field,
      draft,
      ref.read(fieldDomainSourceProvider),
    );
    switch (decision) {
      case FieldSubmitNotEditable():
        return;
      case FieldSubmitBlocked():
        state = editing.copyWith(
          requiredEmpty: {...editing.requiredEmpty, field},
        );
      case FieldSubmitWrite(:final value):
        await _write(editing, field, value);
    }
  }

  Future<void> _write(
    NodeDetailEditState editing,
    String field,
    String? value,
  ) async {
    state = editing.copyWith(
      writingField: field,
      requiredEmpty: {...editing.requiredEmpty}..remove(field),
      writeStates: {
        ...editing.writeStates,
        field: const FieldWriteState.writing(),
      },
    );
    final result = await editing.session.writeField(
      field: field,
      newValue: value,
    );
    final now = state;
    if (now == null || !identical(now.session, editing.session)) return;
    _lastWrittenField = result is Written ? field : _lastWrittenField;
    state = _afterWrite(now, field, value, result);
  }

  NodeDetailEditState _afterWrite(
    NodeDetailEditState now,
    String field,
    String? value,
    WriteResult result,
  ) {
    final settled = now.copyWith(clearWriting: true);
    final states = {...now.writeStates};
    switch (result) {
      case Written(:final snapshotSha):
        states[field] = FieldWriteState.written(
          validation: FieldValidation.running,
          hasSnapshot: snapshotSha != null,
        );
        return settled.copyWith(
          phase: NodeDetailEditPhase.editing,
          values: {...now.values, field: value ?? ''},
          writeStates: states,
        );
      case Blocked(:final reason):
        states[field] = FieldWriteState.blocked(_blockedReason(reason));
        return settled.copyWith(
          phase: reason == BlockedReason.externallyModified
              ? NodeDetailEditPhase.blocked
              : null,
          writeStates: states,
        );
      case IoFailed():
        states[field] = const FieldWriteState.ioFailed();
        return settled.copyWith(writeStates: states);
    }
  }

  FieldBlockedReason _blockedReason(BlockedReason reason) => switch (reason) {
    BlockedReason.externallyModified => FieldBlockedReason.externallyModified,
    BlockedReason.snapshotFailed => FieldBlockedReason.snapshotFailed,
    BlockedReason.rewriteNotIsolated => FieldBlockedReason.rewriteNotIsolated,
  };

  void _onObservation(WriteObservation observation) {
    final editing = state;
    final field = _lastWrittenField;
    if (observation is! ValidationObserved || editing == null) return;
    final previous = field == null ? null : editing.writeStates[field];
    if (field == null || previous == null || !previous.isWritten) return;
    state = editing.copyWith(
      writeStates: {
        ...editing.writeStates,
        field: _mapValidation(observation.status, previous.hasSnapshot),
      },
    );
  }

  FieldWriteState _mapValidation(ValidationStatus status, bool hasSnapshot) =>
      switch (status) {
        ValidationRunning() => FieldWriteState.written(
          validation: FieldValidation.running,
          hasSnapshot: hasSnapshot,
        ),
        ValidationPassed() => FieldWriteState.written(
          validation: FieldValidation.passed,
          hasSnapshot: hasSnapshot,
        ),
        ValidationFailed(:final newIssueCount) => FieldWriteState.written(
          validation: FieldValidation.failed,
          newIssueCount: newIssueCount,
          hasSnapshot: hasSnapshot,
        ),
        ValidationUnavailable(:final reason) => FieldWriteState.written(
          validation: FieldValidation.unavailable,
          unavailableReason: _unavailableReason(reason),
          hasSnapshot: hasSnapshot,
        ),
      };

  /// `baselineNotReady` 在元件契約無對應原因，歸入無法判讀輸出。
  FieldValidationUnavailableReason _unavailableReason(
    UnavailableReason reason,
  ) => switch (reason) {
    UnavailableReason.executableMissing =>
      FieldValidationUnavailableReason.executableMissing,
    UnavailableReason.unexpectedExitCode =>
      FieldValidationUnavailableReason.unexpectedExitCode,
    UnavailableReason.timedOut => FieldValidationUnavailableReason.timedOut,
    UnavailableReason.unparsableOutput || UnavailableReason.baselineNotReady =>
      FieldValidationUnavailableReason.unparsableOutput,
  };

  /// 欄位草稿是否與目前值不同的轉換通知。
  ///
  /// 輸入元件可能在 build 階段（`didUpdateWidget`）回報，故延後到 build 之後
  /// 寫入狀態（Riverpod 禁止 build 期間修改 provider）。
  void setDirty(String field, bool dirty) {
    scheduleMicrotask(() {
      if (ref.mounted) _applyDirty(field, dirty);
    });
  }

  void _applyDirty(String field, bool dirty) {
    final editing = state;
    if (editing == null || editing.dirty.contains(field) == dirty) return;
    final next = {...editing.dirty};
    dirty ? next.add(field) : next.remove(field);
    state = editing.copyWith(dirty: next);
  }

  /// 完成：草稿捨棄、回正常；受理值暫供 meta 列顯示。
  void done() {
    final editing = state;
    if (editing == null || editing.writeInProgress) return;
    final accepted = {
      for (final key in const ['title', 'status'])
        if (editing.writeStates[key]?.isWritten ?? false)
          key: editing.values[key] ?? '',
    };
    if (accepted.isNotEmpty) {
      final holder = ref.read(nodeDetailAcceptedValuesProvider.notifier);
      holder.state = {...holder.state, editing.nodeId: accepted};
    }
    _exit();
  }

  /// 放棄並重讀（SPEC-009 FR-06）：成功回編輯中並顯示磁碟上的值；notFound
  /// 轉原始檔已消失；其他失敗維持原狀態。
  Future<FieldListReloadResult> discardAndReload({
    required String lastKnownPath,
  }) async {
    final editing = state;
    if (editing == null || editing.writeInProgress) {
      return FieldListReloadResult.failed;
    }
    final probe = await _probe(editing.path);
    if (probe == _Probe.notFound) {
      _exit();
      ref.read(nodeDetailStateProvider.notifier).state = NodeDetailMissing(
        nodeId: editing.nodeId,
        lastKnownPath: lastKnownPath,
      );
      return FieldListReloadResult.notFound;
    }
    final failure = await editing.session.discardAndReload();
    final now = state;
    if (now == null || !identical(now.session, editing.session)) {
      return FieldListReloadResult.failed;
    }
    if (probe == _Probe.failed || failure != null) {
      return FieldListReloadResult.failed;
    }
    _lastWrittenField = null;
    state = now.copyWith(
      phase: NodeDetailEditPhase.editing,
      values: _valuesOf(now.session.baseline),
      writeStates: const {},
      requiredEmpty: const {},
      dirty: const {},
      generation: now.generation + 1,
    );
    return FieldListReloadResult.success;
  }

  Future<_Probe> _probe(WorkspaceRelativePath path) async {
    try {
      await ref.read(editFilePortProvider).read(path.absolute);
      return _Probe.readable;
    } on EditFileException catch (error) {
      return error.notFound ? _Probe.notFound : _Probe.failed;
    }
  }
}

enum _Probe { readable, notFound, failed }

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// frontmatter 各鍵的字串值（`null` 為空字串）；解析失敗為空表。
Map<String, String> _valuesOf(Uint8List bytes) {
  final outcome = classifyFrontmatter(bytes);
  if (outcome is! Available) return const {};
  return {
    for (final entry in outcome.frontmatter.entries)
      entry.key: entry.value == null ? '' : '${entry.value}',
  };
}
