/// 單值狀態容器（0.6.0-W1-106）：取代 riverpod 舊版相容層的
/// `StateProvider`，以 3.x 的 [Notifier] 實作。
///
/// 通知依 `==` 過濾（3.x Notifier 語意）：寫入與現值 `==` 的值不通知監聽者。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// 持有單一值的 [Notifier]；[_create] 在 `build` 取初值，可使用 `ref.watch`。
class StateHolder<T> extends Notifier<T> {
  StateHolder(this._create);

  final T Function(Ref ref) _create;

  @override
  T build() => _create(ref);

  /// 對外公開讀寫（Notifier 預設為 protected，單值容器需供呼叫端直接寫入）。
  @override
  T get state => super.state;

  @override
  set state(T value) => super.state = value;
}

/// 建立以 [create] 為初值的單值 provider（語意等同舊 `StateProvider`）。
NotifierProvider<StateHolder<T>, T> stateHolderProvider<T>(
  T Function(Ref ref) create,
) => NotifierProvider<StateHolder<T>, T>(() => StateHolder<T>(create));

/// 以初值工廠覆寫單值 provider（沿用舊 `StateProvider.overrideWith((ref) => v)`
/// 的呼叫形狀；3.x 的 `overrideWith` 改收 Notifier 工廠，故另立此入口）。
extension StateHolderOverride<T> on NotifierProvider<StateHolder<T>, T> {
  Override overrideWithInitial(T Function(Ref ref) create) =>
      overrideWith(() => StateHolder<T>(create));
}

/// [stateHolderProvider] 的 autoDispose 版（無監聽者時釋放狀態）。
NotifierProvider<StateHolder<T>, T> autoDisposeStateHolderProvider<T>(
  T Function(Ref ref) create,
) => NotifierProvider.autoDispose<StateHolder<T>, T>(
  () => StateHolder<T>(create),
);
