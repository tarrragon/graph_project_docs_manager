/// SPEC-007 FR-10 UC flow 子圖的資料型別（不可變）。
///
/// FlowStep 不進主圖：子圖的步驟不是輕節點，子圖內的連線不進 EVT-GRAPH-001
/// 的邊集合。本檔只放資料型別，不依賴事件模組；建構見
/// `flow_subgraph_builder.dart`，查詢見 `flow_query.dart`。
library;

/// 只有此節點型別的 rawNode 附掛 flow 步驟（型別表節點型別名）。
const flowSourceTypeName = 'UC';

/// FlowStep 欄位名（缺陷負載的「欄位」值）。
class FlowFields {
  FlowFields._();

  static const id = 'id';
  static const name = 'name';
  static const next = 'next';
  static const emits = 'emits';
  static const consumes = 'consumes';
  static const traverses = 'traverses';
  static const branchFrom = 'branch_from';
  static const returnTo = 'return_to';
}

/// 一個參照（`branch_from`／`return_to`／分支步 `next`）。
///
/// [targetIndex] 為被指向步驟在 [FlowSubgraph.steps] 的位置；null 即未解析。
class FlowReference {
  const FlowReference({
    required this.field,
    required this.rawValue,
    required this.targetIndex,
  });

  final String field;
  final Object? rawValue;
  final int? targetIndex;

  bool get isResolved => targetIndex != null;
}

/// 空值：null、空字串、空清單／空 Map（規格 FR-10 的「非空」；空集合視為空）。
bool _isEmptyRef(Object? value) =>
    value == null ||
    value == '' ||
    (value is Iterable && value.isEmpty) ||
    (value is Map && value.isEmpty);

/// 步驟 `id` 與參照值的比對鍵：非空值一律轉成字串（FR-10 用戶裁決 S1，
/// 與上游 `doc validate` 的 `str()` 正規化一致）；空值回傳 null。
String? flowKeyOf(Object? value) => _isEmptyRef(value) ? null : '$value';

/// 遞迴凍結 Map／List，使子圖不與 RawNode 共用可變參照。
Object? _freeze(Object? value) => switch (value) {
  final Map<dynamic, dynamic> m => Map<String, dynamic>.unmodifiable({
    for (final e in m.entries) '${e.key}': _freeze(e.value),
  }),
  final List<dynamic> l => List<dynamic>.unmodifiable(l.map(_freeze)),
  _ => value,
};

/// 子圖中的一步；屬性皆為 flow 區塊原值的唯讀副本，參照在建構時解析完成。
class FlowStepNode {
  FlowStepNode({
    required this.index,
    required Map<String, dynamic> step,
    required Map<String, List<int>> idIndex,
  }) : step = _freeze(step)! as Map<String, dynamic>,
       isMainline = _isEmptyRef(step[FlowFields.branchFrom]),
       branchFrom = _resolveIf(
         !_isEmptyRef(step[FlowFields.branchFrom]),
         FlowFields.branchFrom,
         step,
         idIndex,
       ),
       returnTo = _resolveIf(true, FlowFields.returnTo, step, idIndex),
       nextRef = _resolveIf(
         !_isEmptyRef(step[FlowFields.branchFrom]),
         FlowFields.next,
         step,
         idIndex,
       );

  /// 在步驟清單中的位置。
  final int index;
  final Map<String, dynamic> step;
  final bool isMainline;

  /// 非空 `branch_from` 的解析結果；主線步驟為 null。
  final FlowReference? branchFrom;

  /// 非空 `return_to` 的解析結果。
  final FlowReference? returnTo;

  /// 分支步非空 `next` 的解析結果；主線步驟恆為 null（主線 `next` 不解析）。
  final FlowReference? nextRef;

  /// 此步驟三個參照中的全部（依 branch_from、return_to、next 順序）。
  List<FlowReference> get references => [?branchFrom, ?returnTo, ?nextRef];

  Object? get id => step[FlowFields.id];
  Object? get name => step[FlowFields.name];
  Object? get next => step[FlowFields.next];
  Object? get emits => step[FlowFields.emits];
  Object? get consumes => step[FlowFields.consumes];
  Object? get traverses => step[FlowFields.traverses];
}

/// 參照只在同 UC 範圍解析；目標 id 缺席或重複皆為未解析。
FlowReference? _resolveIf(
  bool applies,
  String field,
  Map<String, dynamic> step,
  Map<String, List<int>> idIndex,
) {
  final raw = step[field];
  if (!applies || _isEmptyRef(raw)) return null;
  final hits = idIndex[flowKeyOf(raw)];
  final target = hits != null && hits.length == 1 ? hits.single : null;
  return FlowReference(field: field, rawValue: raw, targetIndex: target);
}

/// 一個 UC 的 flow 子圖。
class FlowSubgraph {
  FlowSubgraph({required this.ucId, required List<FlowStepNode> steps})
    : steps = List.unmodifiable(steps);

  final String ucId;

  /// 全部步驟，依清單順序。
  final List<FlowStepNode> steps;

  /// 參照指向的步驟；未解析回傳 null。
  FlowStepNode? targetOf(FlowReference ref) {
    final i = ref.targetIndex;
    return i == null ? null : steps[i];
  }

  /// 主線：`branch_from` 為空者，依清單順序。
  List<FlowStepNode> get mainline => [
    for (final s in steps)
      if (s.isMainline) s,
  ];

  /// 分支：`branch_from` 非空者，依清單順序。
  List<FlowStepNode> get branches => [
    for (final s in steps)
      if (!s.isMainline) s,
  ];

  /// 回指：`return_to` 非空者，依清單順序。
  List<FlowStepNode> get returns => [
    for (final s in steps)
      if (s.returnTo != null) s,
  ];
}
