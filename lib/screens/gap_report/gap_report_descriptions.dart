/// 破洞項目說明與分節標籤的 l10n 查表（SPEC-004 §4.0.6〈1.80 提案〉）。
///
/// [GapDescriptionKind] 與 ARB key 一對一；清單類佔位符（paths／targets／
/// bundles／types）依語系以「、」／", " 連接。
library;

import 'package:graph_project_docs_manager/graph/path_declaration_state.dart';
import 'package:graph_project_docs_manager/graph/project_path_declaration.dart';

import '../../l10n/app_localizations.dart';
import 'gap_report_models.dart';
import 'gap_report_projection.dart';

/// 分節 category id → 語系化標籤；未知 id 原樣回傳。
String gapCategoryLabel(AppLocalizations l10n, String categoryId) =>
    switch (categoryId) {
      gapCategoryIdParseFailure => l10n.gapCategoryParseFailure,
      gapCategoryIdFlowBlockMalformed => l10n.gapCategoryFlowBlockMalformed,
      gapCategoryIdNonDomainPathsMalformed =>
        l10n.gapCategoryNonDomainPathsMalformed,
      gapCategoryIdGraphDefect => l10n.gapCategoryGraphDefect,
      gapCategoryIdGraphDefectFlow => l10n.gapCategoryGraphDefectFlow,
      gapCategoryIdOrphanEvent => l10n.gapCategoryOrphanEvent,
      gapCategoryIdEventDeclarationMismatch =>
        l10n.gapCategoryEventDeclarationMismatch,
      _ => categoryId,
    };

/// 項目說明文字（無說明的項目回傳 `null`）。
String? gapItemDescriptionText(AppLocalizations l10n, GapItemDescription? d) {
  if (d == null) return null;
  final a = d.args;
  return switch (d.kind) {
    GapDescriptionKind.parseNoFrontmatter => l10n.gapParseNoFrontmatter,
    GapDescriptionKind.parseFrontmatterUnclosed =>
      l10n.gapParseFrontmatterUnclosed,
    GapDescriptionKind.parseFrontmatterNotMap => l10n.gapParseFrontmatterNotMap,
    GapDescriptionKind.parseYamlInvalid => l10n.gapParseYamlInvalid,
    GapDescriptionKind.parseUnreadableEncoding =>
      l10n.gapParseUnreadableEncoding,
    GapDescriptionKind.parseUnreadablePermission =>
      l10n.gapParseUnreadablePermission,
    GapDescriptionKind.parseUnreadableMissing => l10n.gapParseUnreadableMissing,
    GapDescriptionKind.flowBlockMalformed => l10n.gapFlowBlockMalformed,
    GapDescriptionKind.nonDomainPathsYamlInvalid =>
      l10n.gapNonDomainPathsYamlInvalid,
    GapDescriptionKind.nonDomainPathsKeyMissing =>
      l10n.gapNonDomainPathsKeyMissing(a['key']! as String),
    GapDescriptionKind.nonDomainPathsNotList => l10n.gapNonDomainPathsNotList(
      a['key']! as String,
    ),
    GapDescriptionKind.nonDomainPathsNonStringElements =>
      l10n.gapNonDomainPathsNonStringElements(a['count']! as int),
    GapDescriptionKind.danglingRefTargetMissing =>
      l10n.gapDanglingRefTargetMissing(
        a['field']! as String,
        a['value']! as String,
      ),
    GapDescriptionKind.danglingRefTargetDuplicated =>
      l10n.gapDanglingRefTargetDuplicated(
        a['field']! as String,
        a['value']! as String,
      ),
    GapDescriptionKind.malformedRefInvalidShape =>
      l10n.gapMalformedRefInvalidShape(
        a['field']! as String,
        a['value']! as String,
      ),
    GapDescriptionKind.malformedRefPatternMismatch =>
      l10n.gapMalformedRefPatternMismatch(
        a['field']! as String,
        a['value']! as String,
      ),
    GapDescriptionKind.malformedRefSelfReference =>
      l10n.gapMalformedRefSelfReference(a['field']! as String),
    GapDescriptionKind.duplicateId => l10n.gapDuplicateId(
      a['id']! as String,
      a['count']! as int,
      _join(l10n, a['paths']! as List<String>),
    ),
    GapDescriptionKind.multiSource => l10n.gapMultiSource(
      a['edgeType']! as String,
      _join(l10n, a['targets']! as List<String>),
    ),
    GapDescriptionKind.flowRefUnresolved => l10n.gapFlowRefUnresolved(
      a['stepId']! as String,
      a['field']! as String,
      a['value']! as String,
    ),
    GapDescriptionKind.flowStepIdDuplicated => l10n.gapFlowStepIdDuplicated(
      a['stepId']! as String,
    ),
    GapDescriptionKind.traversesUndeclared => l10n.gapTraversesUndeclared(
      a['stepId']! as String,
      a['value']! as String,
    ),
    GapDescriptionKind.traversesMissing => l10n.gapTraversesMissing(
      a['stepId']! as String,
    ),
    GapDescriptionKind.flowEventUnresolved => l10n.gapFlowEventUnresolved(
      a['stepId']! as String,
      a['field']! as String,
      a['value']! as String,
    ),
    GapDescriptionKind.domainDeclaredTwice => l10n.gapDomainDeclaredTwice(
      a['domain']! as String,
      _join(l10n, a['bundles']! as List<String>),
    ),
    GapDescriptionKind.orphanEventEmittedNotConsumed =>
      l10n.gapOrphanEventEmittedNotConsumed,
    GapDescriptionKind.orphanEventConsumedNotEmitted =>
      l10n.gapOrphanEventConsumedNotEmitted,
    GapDescriptionKind.eventConsumerUnmatched => l10n.gapEventConsumerUnmatched(
      a['domain']! as String,
    ),
    GapDescriptionKind.eventProducerUnmatched => l10n.gapEventProducerUnmatched(
      a['domain']! as String,
    ),
  };
}

/// 歸屬型別不明的附註（`ambiguousTypes` 為空時回傳 `null`）。
String? gapAmbiguousTypesText(AppLocalizations l10n, List<String> types) =>
    types.isEmpty ? null : l10n.gapParseTypeAmbiguous(_join(l10n, types));

/// 需求：[SPEC-001 §5〈專案層級宣告狀態一行〉、SPEC-004 §4.0.6] 宣告狀態行
/// 文字；兩側皆完整宣告（無缺口）回傳 `null`。
///
/// 整體未宣告只顯示 `pathDeclarationNoneLine`（不含路徑數）；部分缺口的
/// `{detail}` 由 domain 側與非 domain 側片段以語系連接符號連接，格式錯誤
/// 與缺席是不同片段。
String? pathDeclarationLineText(
  AppLocalizations l10n,
  ProjectPathDeclaration? declaration,
) {
  if (declaration == null || !declaration.hasGap) return null;
  if (declaration.overallUndeclared) return l10n.pathDeclarationNoneLine;
  final fragments = <String>[
    if (declaration.totalBundleCount == 0)
      l10n.pathDeclarationNoBundles
    else if (!declaration.isBundleSideComplete)
      l10n.pathDeclarationBundlesPartial(
        declaration.declaredBundleCount,
        declaration.totalBundleCount,
      ),
    ?switch (declaration.nonDomainSide) {
      NonDomainSideState.absent => l10n.pathDeclarationNonDomainMissing,
      NonDomainSideState.malformed => l10n.pathDeclarationNonDomainMalformed,
      NonDomainSideState.declared => null,
    },
  ];
  return l10n.pathDeclarationIncompleteLine(
    _join(l10n, fragments),
    declaration.affectedPathCount ?? 0,
  );
}

/// 連接符號依語系選擇；只支援 zh／en（新增語系時須在此補分支）。
String _join(AppLocalizations l10n, List<String> values) => values.join(
  l10n.localeName.startsWith('zh') ? '、' : ', ',
); // i18n-exempt: 語系分隔符
