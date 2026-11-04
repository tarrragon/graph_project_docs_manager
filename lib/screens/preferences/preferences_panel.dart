/// 偏好設定面板（SPEC-003 §3.8、SPEC-001 §9）。
///
/// 主視窗內的面板（不是獨立視窗）：⌘, 開啟，只承載「開啟原始檔使用的編輯器」
/// 一項。開啟時對 [editorTable] 各編輯器查一次 handler，只列查得者；偵測
/// 完成前不渲染選項。選定值於點選當下持久化，不需另按儲存，也不顯示
/// SnackBar（選取標示即結果，SPEC-003 §2.13 判準 T2）。
///
/// 已持久化的編輯器本次查無 handler：選取標示落在「系統預設（不定位）」，
/// 持久化值不改寫，直到使用者點選（SPEC-001 §9〈預設值與持久化〉）。
library;

import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import '../../services/macos_preferences_channel.dart';
import '../../state/state_holder.dart';
import '../../tokens/tokens.dart';
import '../../workspace/editor_preference.dart';

const String _tag = 'PreferencesPanel';

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
  String? _chosenId;

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
    developer.log(
      '偵測完成：stored=$storedId available=${available.map((s) => s.id)}', // i18n-exempt: 開發者診斷 log
      name: _tag,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = _PreferencesSnapshot(
        storedId: storedId,
        available: available,
      );
    });
  }

  void _choose(String editorId) {
    setState(() => _chosenId = editorId);
    ref.read(editorPreferenceStoreProvider).write(editorId);
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
            children: [
              AppText.singleLine(
                l10n.preferencesTitle,
                variant: AppTextVariant.subtitle,
              ),
              if (snapshot != null) ..._optionRows(l10n, snapshot),
              AppButton(
                label: l10n.cellDetailCloseAction,
                onPressed: _close,
                variant: AppButtonVariant.text,
                testKey: const Key('action-preferences-close'),
              ),
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
    final selectedId = _chosenId ?? snapshot.selectedId;
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
      onTap: () => _choose(editorId),
      testKey: Key('option-preferences-editor-$editorId'),
      isSelected: editorId == selectedId,
    );
  }
}
