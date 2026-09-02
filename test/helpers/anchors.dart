/// 測試錨點組 Key 輔助（SPEC-003 §2.9 命名規範）。
///
/// SPEC-003 §4 的 31 列與各元件的測試點都以 `<類別>-<screen>-<名>` 字串
/// 定位 widget。字串拼法散落各測試檔會讓「拼錯一個字母」變成靜默的
/// `find` 落空；本檔把拼法集中，測試只寫 `Anchor.state(Screen.domain, 'loading')`，
/// 拼法錯誤在編譯期（screen 是列舉）或單一處（類別前綴）被抓到。
///
/// `<screen>` 一律取 `AppDestination.name`（camelCase），浮層取 `switcher`，
/// 與既有 `nav-item-` / `nav-page-` 同源（SPEC-003 §2.9）。
///
/// 本檔只組 Key，不宣告任何錨點「應存在」——存在與否由各畫面票的
/// 斷言決定。回傳型別是 [Key]（`ValueKey<String>`），與 lib 內
/// `Key('...')` 字面值相等，`find.byKey` 可直接匹配。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';

/// 錨點的 `<screen>` 段：六個 [AppDestination] 加上浮層。
///
/// 不直接用 [AppDestination] 是因為浮層（SPEC-003 §3.7）不在其中，
/// 而 §4 第 27–29 列需要為它組 `state-switcher-*`。
enum Screen {
  domain(AppDestination.domain),
  ucFlow(AppDestination.ucFlow),
  traceability(AppDestination.traceability),
  tickets(AppDestination.tickets),
  gaps(AppDestination.gaps),
  nodeDetail(AppDestination.nodeDetail),

  /// 專案切換浮層（覆蓋層，非 `AppDestination`）。
  switcher(null);

  const Screen(this.destination);

  /// 對應的導覽項；浮層為 `null`。
  final AppDestination? destination;

  /// 錨點字串中的 `<screen>` 段。
  String get segment => destination?.name ?? 'switcher';

  /// 由 [AppDestination] 反查。
  static Screen of(AppDestination destination) =>
      values.firstWhere((s) => s.destination == destination);
}

/// 依 SPEC-003 §2.9 九類格式組 [Key]。
///
/// 各方法的 `<名>` 段照規格原文傳入（kebab-case，如 `'schema-incompatible'`、
/// `'cancel-load'`），本檔不做大小寫轉換——轉換會讓錨點字串與規格表
/// 對不上，規格表才是斷言對象。
abstract final class Anchor {
  /// 側欄專案名按鈕（既有錨點，`AppShell.projectSwitcherEntryKey`）。
  static const Key projectSwitcherEntry = Key('project-switcher-entry');

  /// `nav-item-<destination>`。
  static Key navItem(AppDestination destination) =>
      Key('nav-item-${destination.name}');

  /// `nav-page-<destination>`（與 `AppDestination.pageKey` 同值）。
  static Key navPage(AppDestination destination) => destination.pageKey;

  /// 狀態根節點 `state-<screen>-<state>`。
  static Key state(Screen screen, String state) =>
      _key('state', screen, state);

  /// 動作 `action-<screen>-<action>`。
  static Key action(Screen screen, String action) =>
      _key('action', screen, action);

  /// 換頁控制 `mode-<screen>-<mode>`。
  static Key mode(Screen screen, String mode) => _key('mode', screen, mode);

  /// 捲動容器 `scroll-<screen>-<area>`。
  static Key scroll(Screen screen, String area) =>
      _key('scroll', screen, area);

  /// 拖曳畫布 `drag-<screen>-<area>`。
  static Key drag(Screen screen, String area) => _key('drag', screen, area);

  /// 徽章 `badge-<screen>-<kind>`。
  static Key badge(Screen screen, String kind) =>
      _key('badge', screen, kind);

  /// 面板 `panel-<screen>-<kind>`。
  static Key panel(Screen screen, String kind) =>
      _key('panel', screen, kind);

  /// 卡片 `card-<screen>-<name>`。§2.9 表未列此類，但 §4 第 11、12、17、
  /// 24、28 列以 `card-<screen>-*` 作跳轉觸發錨點，故一併提供。
  static Key card(Screen screen, String name) => _key('card', screen, name);

  /// 矩陣格 `cell-<screen>-<name>`（§4 第 31 列）。
  static Key cell(Screen screen, String name) => _key('cell', screen, name);

  static Key _key(String kind, Screen screen, String name) =>
      Key('$kind-${screen.segment}-$name');
}

/// [Anchor] 的 [Finder] 版本：`AnchorFinder.state(...)` 等同
/// `find.byKey(Anchor.state(...))`，省去每個斷言重複包一層。
abstract final class AnchorFinder {
  static Finder get projectSwitcherEntry =>
      find.byKey(Anchor.projectSwitcherEntry);
  static Finder navItem(AppDestination d) => find.byKey(Anchor.navItem(d));
  static Finder navPage(AppDestination d) => find.byKey(Anchor.navPage(d));
  static Finder state(Screen s, String n) => find.byKey(Anchor.state(s, n));
  static Finder action(Screen s, String n) => find.byKey(Anchor.action(s, n));
  static Finder mode(Screen s, String n) => find.byKey(Anchor.mode(s, n));
  static Finder scroll(Screen s, String n) => find.byKey(Anchor.scroll(s, n));
  static Finder drag(Screen s, String n) => find.byKey(Anchor.drag(s, n));
  static Finder badge(Screen s, String n) => find.byKey(Anchor.badge(s, n));
  static Finder panel(Screen s, String n) => find.byKey(Anchor.panel(s, n));
  static Finder card(Screen s, String n) => find.byKey(Anchor.card(s, n));
  static Finder cell(Screen s, String n) => find.byKey(Anchor.cell(s, n));
}
