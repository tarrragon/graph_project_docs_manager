/// 需求：[SPEC-006 FR-04、D5；EVT-CORPUS-003〈lostFields 的算法〉；契約 K3]
library;

/// 計算 `lostFields`：型別的完整性集合減去實際寫出的鍵。
///
/// 純函式，不讀檔案或型別表，輸入即為 EVT-CORPUS-003〈lostFields 的算法〉
/// 描述的三個判斷依據：
/// - [completenessFields]：該節點型別在 `tracking_schema.json` 的完整性
///   集合；`null` 代表型別表沒有這個鍵（W1-079 之前的 JSON），視同無集合
/// - [writtenFields]：實際寫出的鍵與值。**「已寫出」依鍵是否存在於此
///   map 判斷，不依值是否為真**——值為 `null` 或空清單（`[]`）的鍵仍算
///   已寫出，代表明確沒有，不列入 `lostFields`（C6-2 鑑別；若改用真值
///   判斷會把這類鍵誤報為缺漏）
/// - [isTied]：路徑對型別查詢是否平手（`schemaAmbiguous`）
///
/// 以下情況一律回傳空清單：型別沒有完整性集合、路徑對型別平手、型別表
/// 取不到完整性集合。
List<String> lostFields({
  required Set<String>? completenessFields,
  required Map<String, Object?> writtenFields,
  required bool isTied,
}) {
  if (isTied || completenessFields == null || completenessFields.isEmpty) {
    return const <String>[];
  }

  return completenessFields
      .where((key) => !writtenFields.containsKey(key))
      .toList();
}
