import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app/shell.dart';
import 'l10n/app_localizations.dart';
import 'tokens/colors.dart';
import 'workspace/workspace_repository.dart';

/// 設計稿基準尺寸（logical pixels）。
///
/// ScreenUtil 的所有換算都以此為 1:1 基準：視窗寬度 / [kDesignSize].width
/// 即為 `.w` 的縮放係數。此值刻意等同 macOS 端的預設視窗尺寸
/// （MainFlutterWindow.defaultSize），使 App 一開啟時縮放係數為 1.0，
/// 開發時所見即 1:1 設計稿。
const Size kDesignSize = Size(1280, 800);

/// 視窗尺寸下限，必須與 macOS 端 `MainFlutterWindow.minimumSize` 一致。
///
/// 桌面與行動裝置的根本差異：視窗尺寸是連續且使用者可控的，不是一組
/// 離散的機型。因此「不跑版」的驗收範圍由這個下限定義 —— 整合測試以
/// 此尺寸作為最嚴苛的 viewport。
const Size kMinWindowSize = Size(960, 640);

void main() {
  runApp(const ProviderScope(child: DocsManagerApp()));
}

class DocsManagerApp extends StatelessWidget {
  const DocsManagerApp({super.key, this.locale, this.repository});

  /// 工作資料夾的資料來源；測試可注入替身，避免碰到真實檔案系統。
  final WorkspaceRepository? repository;

  /// 強制指定語系；`null` 表示跟隨系統設定。
  ///
  /// 整合測試藉此鎖定語系來斷言字串，未來若要做「語系切換」設定頁，
  /// 也是把使用者選擇注入到這個參數。
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    // ScreenUtilInit 必須位於 MaterialApp 之上：它需要先取得 MediaQuery
    // 完成換算表初始化，底下的 widget 才能安全使用 .w / .h / .sp。
    return ScreenUtilInit(
      designSize: kDesignSize,
      // 字級取寬／高縮放的較小值，避免視窗被拉寬時字級跟著暴增。
      minTextAdapt: true,
      // 這是 Android 分割畫面專用的補償，桌面單一視窗情境下不適用。
      splitScreenMode: false,
      builder: (context, child) => MaterialApp(
        // title 是靜態字串，取不到 localizations；onGenerateTitle 會在
        // Localizations 就緒後才呼叫，才能拿到當前語系的名稱。
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.accent,
        ),
        home: child,
      ),
      child: const AppShell(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.repository});

  /// 可注入替身供測試使用；預設走真實的 platform channel。
  final WorkspaceRepository? repository;

  /// 整合測試用來確認「已抵達首頁」的錨點。
  static const Key pageKey = Key('home-page');

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WorkspaceRepository _repository =
      widget.repository ?? WorkspaceRepository();

  WorkspaceState _workspace = const WorkspaceUnset();

  @override
  void initState() {
    super.initState();
    // 啟動即嘗試還原上次的授權。失敗不阻擋 App 使用 —— 使用者只是會看到
    // 「請選擇資料夾」而非直接進入工作狀態。
    _repository.restore().then((state) {
      if (mounted) setState(() => _workspace = state);
    });
  }

  Future<void> _chooseFolder() async {
    final state = await _repository.chooseFolder();
    if (state != null && mounted) setState(() => _workspace = state);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: HomePage.pageKey,
      appBar: AppBar(
        title: Text(l10n.appTitle, style: TextStyle(fontSize: 18.sp)),
        toolbarHeight: 56.h,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WorkspaceBanner(state: _workspace, onChoose: _chooseFolder),
              SizedBox(height: 12.h),
              const _StatsRow(),
              SizedBox(height: 16.h),
              Text(
                l10n.sectionRecentDocuments,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              // Expanded 交出剩餘高度給可捲動區，是這個版型不會垂直 overflow
              // 的關鍵：Column 的固定高度子項總和永遠小於可用高度。
              const Expanded(child: _DocumentList()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顯示工作資料夾狀態，並提供選取／重選入口。
class _WorkspaceBanner extends StatelessWidget {
  const _WorkspaceBanner({required this.state, required this.onChoose});

  final WorkspaceState state;
  final VoidCallback onChoose;

  /// 整合測試用來定位這個區塊。
  static const Key bannerKey = Key('workspace-banner');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    // sealed class + switch 讓編譯器保證每個狀態都被處理過；
    // 未來新增狀態時，漏掉的分支會是編譯錯誤而非執行期驚喜。
    final (String message, Color background, String action) = switch (state) {
      WorkspaceUnset() => (
          l10n.folderAccessRationale,
          scheme.surfaceContainerHighest,
          l10n.chooseWorkspaceFolder,
        ),
      WorkspaceReady(:final path) => (
          l10n.workspaceReady(path),
          scheme.surfaceContainerHighest,
          l10n.changeWorkspaceFolder,
        ),
      WorkspaceUnavailable(:final reason) => (
          l10n.workspaceUnavailable(reason),
          scheme.errorContainer,
          l10n.chooseWorkspaceFolder,
        ),
    };

    return Container(
      key: bannerKey,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp),
            ),
          ),
          SizedBox(width: 12.w),
          FilledButton(onPressed: onChoose, child: Text(action)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <(String, String)>[
      (l10n.statInProgress, '12'),
      (l10n.statPendingReview, '5'),
      (l10n.statArchived, '38'),
    ];
    return Row(
      children: [
        for (final (label, value) in items) ...[
          // Expanded 讓三張卡片均分寬度，而非各自撐開 —— 這是 Row 水平
          // overflow 最常見的成因，也是窄螢幕上第一個爆掉的地方。
          Expanded(child: _StatCard(label: label, value: value)),
          if (label != items.last.$1) SizedBox(width: 8.w),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.sp, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList();

  @override
  Widget build(BuildContext context) {
    const docs = <String>[
      '系統架構決策紀錄',
      '資料庫遷移計畫',
      'API 介面規格 v2',
      '第三季驗收清單',
      '部署流程手冊',
    ];
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, _) => SizedBox(height: 8.h),
      itemBuilder: (context, index) => Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 20.r),
            SizedBox(width: 10.w),
            // Expanded + ellipsis：長標題在窄螢幕上收斂而非撐破 Row。
            Expanded(
              child: Text(
                docs[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
            Icon(Icons.chevron_right, size: 20.r),
          ],
        ),
      ),
    );
  }
}
