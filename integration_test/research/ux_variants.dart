/// 實機字型截圖產生器的共用件：變體介面、fixture 狀態、替身（0.5.0-W1-466.2）。
///
/// 本檔不帶 `_test` 後綴，原因同 `integration_test/domain_view_v050.dart`：
/// macOS 上一次 `flutter test` 只能啟動一次 app，`integration_test/` 下的第二個
/// `_test.dart` 必定啟動失敗。
///
/// 變體只能在測試／研究入口內覆寫（AC 5：不改 lib/）。第一批只有 [kOriginalVariant]；
/// 第二批（AC 4）依 466 已提交的變體目錄在此新增 [UxVariant]，同一題的原設計與
/// 壞版本共用 [UxFixture]，因此可互動元件數的差異只會來自變體本身。
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/components/design_overrides.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_fixtures.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_fixtures.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_providers.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_state.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/main.dart' show kDesignSize;
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../test/helpers/spec001/corpus_snapshot.dart';

/// 擷取尺寸（logical px）。DPR 固定為 [kCaptureDpr]，輸出像素即 1280x800。
const Size kCaptureLogicalSize = Size(1280, 800);
const double kCaptureDpr = 1.0;

/// 一個可被擷取的設計版本。
///
/// [overrides] 與 [wrapApp] 是變體注入點：前者覆寫 Provider 狀態，後者在 App
/// 外層包裝版面／Theme 覆寫。原設計兩者皆為空操作。
class UxVariant {
  const UxVariant({
    required this.id,
    this.overrides = const [],
    this.wrapApp = _identity,
    this.destination,
    this.locales,
    this.question,
    this.answerKey,
  });

  final String id;
  final List<Override> overrides;
  final Widget Function(Widget app) wrapApp;

  /// 非 null 時只擷取該畫面（成對變體專用）；null 沿用全部畫面。
  final AppDestination? destination;

  /// 非 null 時只擷取這些語系；null 沿用全部語系。
  final List<Locale>? locales;

  /// 成對變體的任務式問句與正解元件 key（0.5.0-W1-466.4，供凍結目錄使用）。
  final String? question;
  final String? answerKey;

  /// 成對變體（有指定畫面）才在擷取後評估 466.1 三準則。
  bool get checksGuidelines => destination != null;
}

Widget _identity(Widget app) => app;

/// 第一批唯一的版本：未經覆寫的原設計。
const UxVariant kOriginalVariant = UxVariant(id: 'original');

/// 長標題變體（0.5.0-W1-505）：以真實元件直接組出三處超長文字，不經畫面資料。
///
/// ticket_list 的 SplitRow 左格是 l10n 字串、清單資料為固定假資料，overrides
/// 無法注入長文字，故由 [wrapApp] 以同一套 ScreenUtil／l10n／Theme 外殼承載
/// 真實的 SplitRow.footer、AppTableRow.ticket、ListRow.item，內容區寬度取
/// 1280 減側欄 172。每處各一筆中文無空白長字串與一筆英文長字串。
const UxVariant kLongTitleVariant = UxVariant(
  id: 'long_title',
  wrapApp: _longTitleHarness,
);

const String _zhLong =
    '這是一段沒有任何空白的超長中文標題用來測試固定列高下的呈現方式是換行還是溢出還是被裁切掉了'
    '而且還要更長一些以確保超過任何合理的欄寬上限所以再接續一整段沒有空白的文字'
    '直到寬度遠遠超過一千一百邏輯像素為止這樣每一處元件都會碰到自己的邊界';
const String _enLong =
    'This is an extremely long English title that keeps going well beyond any reasonable column '
    'width so that we can observe wrapping overflow or clipping behavior in a fixed height row';

Widget _longTitleHarness(Widget _) => ScreenUtilInit(
  designSize: kDesignSize,
  minTextAdapt: true,
  splitScreenMode: false,
  builder: (context, child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    debugShowCheckedModeBanner: false,
    home: child,
  ),
  child: Scaffold(
    body: Align(
      alignment: Alignment.topRight,
      child: SizedBox(
        width: 1280 - 172,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final text in const [_zhLong, _enLong]) ...[
              SplitRow.footer(
                leading: AppText.singleLine(text),
                trailing: const AppText.singleLine('trailing'),
              ),
              AppTableRow.ticket(
                id: const AppText.singleLine(
                  '0.5.0-W1-505',
                  variant: AppTextVariant.mono,
                ),
                title: AppText.singleLine(text),
                status: const Badge.status(label: 'in_progress'),
                priority: const AppText.singleLine(
                  'P3',
                  variant: AppTextVariant.caption,
                ),
                blockedBy: const AppText.singleLine(
                  '—',
                  variant: AppTextVariant.mono,
                ),
                onTap: () {},
                testKey: Key('long-ticket-${text.length}'),
              ),
              ListRow.item(
                primary: AppText.singleLine(text),
                onTap: () {},
                testKey: Key('long-list-${text.length}'),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    ),
  ),
);

/// 同一份 fixture 狀態：凍結快照實體化出的真實工作區 + 固定語系。
class UxFixture {
  UxFixture({required this.snapshot, required this.locale});

  final String snapshot;
  final Locale locale;
  Directory? _workspace;

  Directory get workspace => _workspace!;

  Future<void> materialize() async {
    _workspace = await materializeSnapshotWorkspace(snapshot);
  }

  Future<void> dispose() async {
    await _workspace?.delete(recursive: true);
    _workspace = null;
  }
}

/// 組出固定 fixture 狀態所需的 Provider 覆寫（版本訊號探測就緒）。
Future<List<Override>> fixtureOverrides() async {
  final container = ProviderContainer();
  try {
    final version = await container.read(builtinSchemaVersionProvider.future);
    return [
      frameworkSignalProbeProvider.overrideWithValue(_ReadyProbe(version)),
    ];
  } finally {
    container.dispose();
  }
}

class _ReadyProbe implements FrameworkSignalProbePort {
  const _ReadyProbe(this._version);
  final String _version;

  @override
  Future<String?> readVersion(String workspacePath) async => _version;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async => true;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async => _version;
}

/// 回傳固定工作區狀態的 repository 替身（不碰 UserDefaults）。
class UxStubRepository implements WorkspaceRepository {
  UxStubRepository(this._state);
  final WorkspaceState _state;

  @override
  Future<WorkspaceState> restore() async => _state;

  @override
  Future<ChooseFolderResult> chooseFolder() async =>
      ChooseFolderSelected(_state);

  @override
  Future<ChooseFolderResult> openPath(String path) async =>
      ChooseFolderSelected(_state);

  @override
  Future<List<RecentProject>> loadRecentProjects() async => const [];

  @override
  Future<bool> addRecentProject(String path) async => true;
}

// ---------------------------------------------------------------------------
// 0.5.0-W1-466.4：成對變體（原設計 / 壞版本），壞版本以 DesignOverrides 注入。
// 同一列的兩個版本共用同一組 overrides（狀態前提），差別只在 wrapApp。
// ---------------------------------------------------------------------------

/// 一列成對變體。
class UxPair {
  UxPair({
    required this.code,
    required AppDestination destination,
    required List<Override> overrides,
    required String question,
    required this.answerKey,
    required Widget Function(Widget app) inject,
  }) : original = UxVariant(
         id: '${code}_orig',
         overrides: overrides,
         destination: destination,
         locales: const [Locale('zh')],
         question: question,
         answerKey: answerKey,
       ),
       broken = UxVariant(
         id: '${code}_bad',
         overrides: overrides,
         wrapApp: inject,
         destination: destination,
         locales: const [Locale('zh')],
         question: question,
         answerKey: answerKey,
       );

  final String code;
  final String answerKey;
  final UxVariant original;
  final UxVariant broken;
}

const FilterDropdownColorOverride _filterFlat = FilterDropdownColorOverride(
  background: AppColors.surfaceBase,
  border: AppColors.surfaceBase,
  activeBorder: AppColors.surfaceBase,
);

/// 固定破洞狀態：兩個類別（2 項、4 項）。真實快照掃描有 8 與 13 項，內容超出
/// 1280x800 視口，B 類加大間距會把項目擠出視口而使 N 不相等（466.4 查核調整 1）。
class _FixedGap extends GapReportNotifier {
  @override
  GapReportState build() => const GapReportFound([
    GapReportCategory(
      id: 'graph-defect',
      items: [
        GapReportItem(id: 'g1', filePath: 'docs/spec/corpus/domain-map.md'),
        GapReportItem(id: 'g2', filePath: 'docs/spec/graph/domain-map.md'),
      ],
    ),
    GapReportCategory(
      id: 'graph-defect-flow',
      items: [
        GapReportItem(id: 'f1', filePath: 'docs/usecases/UC-01.md'),
        GapReportItem(id: 'f2', filePath: 'docs/usecases/UC-02.md'),
        GapReportItem(id: 'f3', filePath: 'docs/usecases/UC-03.md'),
        GapReportItem(id: 'f4', filePath: 'docs/usecases/UC-04.md'),
      ],
    ),
  ]);
}

final List<Override> _gapsFixed = [gapReportProvider.overrideWith(_FixedGap.new)];

final List<Override> _traceExpanded = [
  expandedTraceNodesProvider.overrideWith((ref) => {'PROP-001', 'SPEC-001'}),
];
final List<Override> _traceBroken = [
  traceabilityStateProvider.overrideWith(
    (ref) => const TraceabilityBroken(TraceabilityFixtures.broken),
  ),
];
final List<Override> _ticketsList = [
  ticketListStateProvider.overrideWith(
    (ref) => const TicketsReady(tickets: TicketListFixtures.all),
  ),
];
final List<Override> _ticketsTopic = [
  ticketListStateProvider.overrideWith(
    (ref) => const TicketsReady(
      tickets: TicketListFixtures.all,
      mode: TicketListMode.topic,
      expandedTopics: {'shell', 'fixture', 'screens', 'unassigned'},
    ),
  ),
];

/// 九列成對變體；注入值見 466 〈變體目錄修訂稿〉與 466.4 Solution。
/// 代碼省略 C' 的撇號（T-C 即 T-C'），避免目錄名含撇號。
final List<UxPair> kUxPairs = [
  UxPair(
    code: 'T-A',
    destination: AppDestination.traceability,
    overrides: const [],
    question: '想看這些需求往下拆出的工作單，要按哪個位置？',
    answerKey: 'action-traceability-goto-tickets',
    inject: (app) => DesignOverrides(
      buttonColors: const {
        AppButtonVariant.text: ButtonColorOverride(
          foreground: AppColors.textSecondary,
        ),
      },
      child: app,
    ),
  ),
  UxPair(
    code: 'T-B',
    destination: AppDestination.traceability,
    overrides: _traceExpanded,
    question: '哪一個項目緊接在最上層需求的下一層？',
    answerKey: 'card-traceability-SPEC-001',
    inject: (app) => DesignOverrides(treeIndent: 0, child: app),
  ),
  UxPair(
    code: 'T-C',
    destination: AppDestination.traceability,
    overrides: _traceBroken,
    question: '這棵樹裡一共有幾處往下接不到後續的地方？',
    answerKey: 'badge-traceability-broken-<id> x3',
    inject: (app) => DesignOverrides(
      issueMarkerColor: AppColors.textSecondary,
      child: app,
    ),
  ),
  UxPair(
    code: 'G-A',
    destination: AppDestination.gaps,
    overrides: _gapsFixed,
    question: '想讓這頁照最新的內容再查核一遍，要按哪個位置？',
    answerKey: 'action-gaps-rescan',
    inject: (app) => DesignOverrides(
      buttonColors: const {
        AppButtonVariant.secondary: ButtonColorOverride(
          foreground: AppColors.textSecondary,
          border: AppColors.surfaceBase,
        ),
      },
      child: app,
    ),
  ),
  UxPair(
    code: 'G-B',
    destination: AppDestination.gaps,
    overrides: _gapsFixed,
    question: '由上往下數，第二個分組底下共列了幾條？',
    answerKey: 'state-gaps-section-<第二類> 下的 card-gaps-*',
    inject: (app) => DesignOverrides(sectionItemGap: Space.sm, child: app),
  ),
  UxPair(
    code: 'G-C',
    destination: AppDestination.gaps,
    overrides: _gapsFixed,
    question: '要把整個分組收起來，要按哪個位置？',
    answerKey: 'expander-gaps-<category.id>',
    inject: (app) => DesignOverrides(
      expanderIconExpanded: Icons.open_in_new,
      expanderIconCollapsed: Icons.open_in_new,
      child: app,
    ),
  ),
  UxPair(
    code: 'K-A',
    destination: AppDestination.tickets,
    overrides: _ticketsList,
    question: '只想留下還沒動工的那幾張，要按哪個位置？',
    answerKey: 'action-tickets-filter-status',
    inject: (app) =>
        DesignOverrides(filterDropdownColors: _filterFlat, child: app),
  ),
  UxPair(
    code: 'K-B',
    destination: AppDestination.tickets,
    overrides: _ticketsTopic,
    question: '單號 0.1.0-W2-006 那一張排在哪一組底下？',
    answerKey: 'state-tickets-topic-section-screens',
    inject: (app) => DesignOverrides(sectionItemGap: Space.sm, child: app),
  ),
  UxPair(
    code: 'K-C',
    destination: AppDestination.tickets,
    overrides: _ticketsList,
    question: '這一頁裡有幾張單子的內容讀不出來？',
    answerKey: 'badge-tickets-corrupted',
    inject: (app) => DesignOverrides(
      issueMarkerColor: AppColors.textSecondary,
      child: app,
    ),
  ),
];
