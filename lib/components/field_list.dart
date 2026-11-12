/// FieldList（SPEC-004 4.50、5.18）。
///
/// 編輯模式的欄位區容器：頂端橫幅（0..1）+ `FieldBlock` × N（SPEC-009 FR-09
/// 表列序）+ 「完成」鈕，單欄堆疊。承載跨欄位的排列不變式：寫入進行中全部
/// 值格唯讀鎖定、「完成」與橫幅動作 disabled；外部已改阻擋時全部值格
/// disabled。鎖定由本容器下發，呼叫端不另傳。不 watch 任何狀態（SPEC-004 §2）。
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_radio_group.dart';
import 'app_text.dart';
import 'app_text_input.dart';
import 'field_block.dart';
import 'notice_banner.dart';

/// 「放棄並重讀」的結果（SPEC-004 4.49〈等待與結果〉）。
enum FieldListReloadResult {
  /// 重讀成功：橫幅消失。
  success,

  /// 讀取失敗（notFound 以外）：橫幅改 `editBannerReloadFailed`、`negative`。
  failed,

  /// 原始檔已消失：畫面轉換由頁面層承載，橫幅維持。
  notFound,
}

/// SPEC-004 4.50：編輯模式欄位區。
///
/// | slot | 說明 |
/// |------|------|
/// | [banner] | 選填；訊息與變體由呼叫端依編輯狀態決定 |
/// | [fields] | 必填，1..N，依 FR-09 表列序 |
/// | [doneButton] | 必填，`AppButton.primary` |
/// | [writeInProgress] | 必填，Edit domain 的寫入進行中旗標 |
/// | [isBlocked] | 必填，外部已改阻擋 |
/// | [onDiscardAndReload] | 選填；非 null 時由本容器驅動橫幅動作 |
/// | [testKey] | 必填，`panel-nodeDetail-field-list` |
class FieldList extends StatefulWidget {
  const FieldList({
    super.key,
    required this.fields,
    required this.doneButton,
    required this.writeInProgress,
    required this.isBlocked,
    required this.testKey,
    this.banner,
    this.onDiscardAndReload,
  }) : assert(fields.length > 0, '欄位至少一個（SPEC-004 4.50 slot 契約）');

  /// 頂端橫幅（0..1）。
  final NoticeBanner? banner;

  /// 欄位（1..N）。
  final List<FieldBlock> fields;

  /// 「完成」鈕。
  final AppButton doneButton;

  /// 寫入進行中。
  final bool writeInProgress;

  /// 外部已改阻擋。
  final bool isBlocked;

  /// 放棄並重讀；null 時橫幅動作沿用呼叫端傳入的回呼。
  final Future<FieldListReloadResult> Function()? onDiscardAndReload;

  /// 定址 key。
  final Key testKey;

  /// 橫幅動作的定址 key（SPEC-003 §2.9）。
  static const Key reloadActionKey = ValueKey('action-nodeDetail-edit-reload');

  @override
  State<FieldList> createState() => _FieldListState();
}

class _FieldListState extends State<FieldList> {
  final FocusNode _anchor = FocusNode(
    debugLabel: 'FieldList',
    canRequestFocus: false,
    skipTraversal: true,
  );
  bool _reloading = false;
  bool _bannerDismissed = false;
  bool _reloadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirstStop());
  }

  @override
  void didUpdateWidget(covariant FieldList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.banner;
    final now = widget.banner;
    if (before?.variant != now?.variant || before?.message != now?.message) {
      _bannerDismissed = false;
      _reloadFailed = false;
    }
  }

  @override
  void dispose() {
    _anchor.dispose();
    super.dispose();
  }

  /// 進入編輯模式時焦點移到 Tab 順序的第一個停留點（4.50 定位提示）。
  void _focusFirstStop() {
    if (!mounted || _anchor.context == null) return;
    final focused = FocusManager.instance.primaryFocus;
    if (focused != null && focused.context != null) {
      var inside = false;
      focused.context!.visitAncestorElements((e) {
        inside = e.widget.key == widget.testKey;
        return !inside;
      });
      if (inside) return;
    }
    _firstStop()?.requestFocus();
  }

  /// Tab 順序最前的可聚焦節點：依 `FocusTraversalOrder` 的序號取最小，
  /// 同序號取文件順序（`descendants` 為前序）。
  FocusNode? _firstStop() {
    FocusNode? best;
    double bestOrder = double.infinity;
    for (final node in _anchor.descendants) {
      final context = node.context;
      if (context == null || !node.canRequestFocus || node.skipTraversal) {
        continue;
      }
      final order = FocusTraversalOrder.maybeOf(context);
      final value = order is NumericFocusOrder ? order.order : bestOrder;
      if (value < bestOrder) {
        best = node;
        bestOrder = value;
      }
    }
    return best;
  }

  Future<void> _reload() async {
    final run = widget.onDiscardAndReload;
    if (run == null || _reloading) return;
    setState(() => _reloading = true);
    final result = await run();
    if (!mounted) return;
    setState(() {
      _reloading = false;
      _bannerDismissed = result == FieldListReloadResult.success;
      _reloadFailed = result == FieldListReloadResult.failed;
    });
    if (result == FieldListReloadResult.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirstStop());
    }
  }

  NoticeBanner? _resolveBanner(AppLocalizations l10n) {
    final base = widget.banner;
    if (base == null || _bannerDismissed) return null;
    final action = base.action;
    final locked = widget.writeInProgress || _reloading;
    return NoticeBanner(
      variant: _reloadFailed ? NoticeBannerVariant.negative : base.variant,
      message: _reloadFailed ? l10n.editBannerReloadFailed : base.message,
      testKey: base.testKey,
      action: action == null
          ? null
          : _lockedButton(
              action,
              locked,
              widget.onDiscardAndReload == null ? null : _reload,
            ),
    );
  }

  /// 以相同欄位重建 [source]，只覆寫可用性與（必要時）回呼。
  AppButton _lockedButton(
    AppButton source,
    bool locked,
    VoidCallback? onPressed,
  ) => AppButton(
    key: source.key,
    label: source.label,
    onPressed: onPressed ?? source.onPressed,
    testKey: source.testKey,
    variant: source.variant,
    leading: source.leading,
    enabled: !locked && source.enabled,
    disabledReason: source.disabledReason,
    reasonShownNearby: locked || source.reasonShownNearby,
    semanticExpanded: source.semanticExpanded,
    autofocus: source.autofocus,
  );

  /// 值格依 [FieldList.writeInProgress]、[FieldList.isBlocked] 下發鎖定；
  /// 呼叫端原本傳入的鎖定一律被覆寫。
  Widget _lockValue(Widget value) {
    final locked = widget.writeInProgress;
    final enabled = !widget.isBlocked;
    if (value is AppTextInput) {
      return _rebuildInput(value, locked, enabled);
    }
    if (value is AppRadioGroup) {
      return AppRadioGroup(
        key: value.key,
        options: value.options,
        selected: value.selected,
        onChanged: value.onChanged,
        semanticLabel: value.semanticLabel,
        enabled: enabled,
        locked: locked,
        testKey: value.testKey,
      );
    }
    return value;
  }

  AppTextInput _rebuildInput(AppTextInput v, bool locked, bool enabled) {
    return v.multiLine
        ? AppTextInput.multiLine(
            key: v.key,
            value: v.value,
            onSubmitted: v.onSubmitted,
            semanticLabel: v.semanticLabel,
            testKey: v.testKey,
            enabled: enabled,
            locked: locked,
            hasError: v.hasError,
            onDirtyChanged: v.onDirtyChanged,
          )
        : AppTextInput.singleLine(
            key: v.key,
            value: v.value,
            onSubmitted: v.onSubmitted,
            semanticLabel: v.semanticLabel,
            testKey: v.testKey,
            enabled: enabled,
            locked: locked,
            hasError: v.hasError,
            onDirtyChanged: v.onDirtyChanged,
          );
  }

  Widget _lockField(FieldBlock f) {
    // readOnly 變體的值格固定為 AppText（4.48），無輸入可鎖。
    if (f.value is AppText) return f;
    return FieldBlock.editable(
      key: f.key,
      label: f.label,
      value: _lockValue(f.value),
      testKey: f.testKey,
      supportingText: f.supportingText,
      isError: f.isError,
      writeState: f.writeState,
      isDirty: f.isDirty,
      isMultiLine: f.isMultiLine,
      requiredEmpty: f.requiredEmpty,
      outOfDomainValue: f.outOfDomainValue,
    );
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  Widget _bannerSlot(NoticeBanner? banner) {
    return AnimatedSwitcher(
      duration: Motion.transition(context),
      child: banner == null
          ? const SizedBox(
              key: ValueKey('field-list-no-banner'),
              width: double.infinity,
            )
          : Padding(
              key: const ValueKey('field-list-banner'),
              padding: EdgeInsets.only(bottom: Space.md),
              child: _ordered(0, banner),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fields = widget.fields;
    final done = _lockedButton(widget.doneButton, widget.writeInProgress, null);
    return Semantics(
      container: true,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Focus(
          focusNode: _anchor,
          child: Column(
            key: widget.testKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _bannerSlot(_resolveBanner(l10n)),
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) SizedBox(height: Space.md),
                _ordered(1.0 + i, _lockField(fields[i])),
              ],
              SizedBox(height: Space.md),
              _ordered(
                1.0 + fields.length,
                Align(alignment: AlignmentDirectional.centerStart, child: done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
