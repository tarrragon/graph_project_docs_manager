/// 偏好設定面板（SPEC-003 §3.8、SPEC-001 §9）。
///
/// 主視窗內的面板（不是獨立視窗）：⌘, 開啟，只承載「開啟原始檔使用的編輯器」
/// 一項。開啟時對 [editorTable] 各編輯器查一次 handler，只列查得者；偵測
/// 完成前不渲染選項。點選即關閉面板：與持久化值不同則寫入並以
/// SnackBar 提示成敗，相同則只關閉（SPEC-003 §3.8）。
///
/// 已持久化的編輯器本次查無 handler：選取標示落在「系統預設（不定位）」，
/// 持久化值不改寫，直到使用者點選（SPEC-001 §9〈預設值與持久化〉）。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../../components/attention_level.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import '../../services/macos_preferences_channel.dart';
import '../../state/state_holder.dart';
import '../../tokens/tokens.dart';
import '../../workspace/editor_preference.dart';
import 'preferences_log_event.dart';

/// 面板開合；`true` 時由組裝根掛載 [PreferencesPanel]。
final preferencesOpenProvider = stateHolderProvider<bool>((ref) => false);

/// 開啟時的偵測結果：持久化值與查得 handler 的編輯器。
class _PreferencesSnapshot {
  const _PreferencesSnapshot({required this.storedId, required this.available});

  final String storedId;
  final List<EditorSpec> available;

  /// 選取標示：持久化值不在選項中時落在系統預設。
  String get selectedId {
    final listed = available.any((spec) => spec.id == storedId);
    return listed ? storedId : systemEditorId;
  }
}

class PreferencesPanel extends ConsumerStatefulWidget {
  const PreferencesPanel({super.key});

  @override
  ConsumerState<PreferencesPanel> createState() => _PreferencesPanelState();
}

class _PreferencesPanelState extends ConsumerState<PreferencesPanel> {
  _PreferencesSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  /// 每次開啟偵測一次；偵測為唯讀查詢，不啟動任何編輯器。
  Future<void> _detect() async {
    final probe = ref.read(editorHandlerProbeProvider);
    final storedId = await ref.read(editorPreferenceStoreProvider).read();
    final available = <EditorSpec>[
      for (final spec in editorTable)
        if (await probe.hasHandler(spec.scheme)) spec,
    ];
    ref.read(preferencesLogSinkProvider)(
      PreferencesLogEvent.editorsDetected,
      LogFields({
        PreferencesLogKeys.availableCount: LogValue.integer(available.length),
      }),
      level: LogLevel.debug,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = _PreferencesSnapshot(
        storedId: storedId,
        available: available,
      );
    });
  }

  /// 點選即關閉（SPEC-003 §3.8）：與持久化值比對，不同才寫入並依成敗提示，
  /// 相同只關閉。提示在關閉前送出——SnackBar 掛在主視窗的 ScaffoldMessenger，
  /// 面板卸載後仍續存。
  Future<void> _choose(String editorId, String label) async {
    final snapshot = _snapshot;
    if (snapshot == null || editorId == snapshot.storedId) {
      _close();
      return;
    }
    final l10n = AppLocalizations.of(context);
    // await 前取得 notifier：寫入期間面板可能因 Esc 卸載，之後不可再用 ref。
    final openHolder = ref.read(preferencesOpenProvider.notifier);
    final log = ref.read(preferencesLogSinkProvider);
    final saved = await ref.read(editorPreferenceStoreProvider).write(editorId);
    if (saved) {
      log(PreferencesLogEvent.editorSaved, LogFields.empty);
    } else {
      log(
        PreferencesLogEvent.editorSaveFailed,
        LogFields.empty,
        level: LogLevel.warning,
        source: ErrorSource.platformIo,
      );
    }
    if (mounted) {
      AppSnackBar.show(
        context,
        message: saved
            ? l10n.preferencesEditorAppliedMessage(label)
            : l10n.preferencesEditorSaveFailedMessage,
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
    }
    openHolder.state = false;
  }

  void _close() {
    ref.read(preferencesOpenProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = _snapshot;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: FocusScope(
        autofocus: true,
        // 高度取與寬度同值的 token：Panel.scrollable 需有界高度，選項最多
        // 五項（系統預設加四個編輯器），此高度容得下，超出時可捲動。
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          height: LayoutSize.overlayWidth,
          child: Panel.scrollable(
            key: _stateKey(snapshot),
            scrollKey: const Key('scroll-preferences-editors'),
            footer: AppButton(
              label: l10n.cellDetailCloseAction,
              onPressed: _close,
              variant: AppButtonVariant.text,
              autofocus: true,
              testKey: const Key('action-preferences-close'),
            ),
            children: [
              AppText.singleLine(
                l10n.preferencesTitle,
                variant: AppTextVariant.subtitle,
              ),
              if (snapshot != null) ..._optionRows(l10n, snapshot),
            ],
          ),
        ),
      ),
    );
  }

  Key _stateKey(_PreferencesSnapshot? snapshot) {
    if (snapshot == null) return const Key('state-preferences-loading');
    return snapshot.available.isEmpty
        ? const Key('state-preferences-no-editors')
        : const Key('state-preferences-editors');
  }

  List<Widget> _optionRows(
    AppLocalizations l10n,
    _PreferencesSnapshot snapshot,
  ) {
    final selectedId = snapshot.selectedId;
    return [
      _option(
        editorId: systemEditorId,
        label: l10n.preferencesEditorSystemOption,
        selectedId: selectedId,
      ),
      for (final spec in snapshot.available)
        _option(editorId: spec.id, label: spec.name, selectedId: selectedId),
      if (snapshot.available.isEmpty)
        AppText.multiLine(
          l10n.preferencesNoEditorsExplanation,
          maxLines: null,
          secondary: true,
        ),
    ];
  }

  Widget _option({
    required String editorId,
    required String label,
    required String selectedId,
  }) {
    return ListRow.option(
      primary: AppText.singleLine(label),
      onTap: () => _choose(editorId, label),
      testKey: Key('option-preferences-editor-$editorId'),
      isSelected: editorId == selectedId,
    );
  }
}
