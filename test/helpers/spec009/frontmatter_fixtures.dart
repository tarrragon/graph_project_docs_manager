import 'dart:convert';
import 'dart:typed_data';

/// 需求：[SPEC-009-test-design §1.6] 文件位元組樣本。
///
/// 只收錄已有測試使用的樣本；其餘樣本（doc_uc_mention、doc_nonutf8）由使用
/// 它們的票補入。
const String docPlainText =
    '---\n'
    'id: PROP-900\n'
    'title:   "原標題"\n'
    'status:  draft\n'
    'priority: P1\n'
    'target_version: "1.0.0"\n'
    'created: 2026-11-01\n'
    'updated: 2026-11-02\n'
    '# note\n'
    'version: 1.0\n'
    '---\n'
    '內文第一段\n'
    '\n'
    '內文第二段';

/// `doc_plain` 不含 `updated` 的版本。
final String docNoUpdatedText = docPlainText.replaceFirst(
  'updated: 2026-11-02\n',
  '',
);

/// `doc_plain` 的 CRLF 版本。
final String docCrlfText = docPlainText.replaceAll('\n', '\r\n');

/// 錨點與別名：`title` 帶 anchor，`subtitle` 以 alias 引用。
const String docAnchorText =
    '---\n'
    'id: PROP-901\n'
    'title: &t "x"\n'
    'subtitle: *t\n'
    'updated: 2026-11-02\n'
    '---\n'
    '內文';

/// block scalar 的兩個變體（literal `|` 與 folded `>`）。
const String docBlockLiteralText =
    '---\n'
    'id: PROP-902\n'
    'title: |\n'
    '  第一行\n'
    'updated: 2026-11-02\n'
    '---\n'
    '內文';
const String docBlockFoldedText =
    '---\n'
    'id: PROP-902\n'
    'title: >\n'
    '  第一行\n'
    'updated: 2026-11-02\n'
    '---\n'
    '內文';

/// 兩個不在 `docs/app-use-cases.md` 白名單、彼此不同的 UC 編號
/// （test-design §1.4）。
/// 字面值以串接寫出，避免被 UC 引用掃描判為使用。
const String unregisteredUc =
    'U'
    'C-901';
const String unregisteredUc2 =
    'U'
    'C-902';

/// `doc uc verify` 的違規輸出樣本：首行為總數，其後逐行
/// `<路徑>:<行號>:<UC 編號>`（2026-11-10 以真實 CLI 實測形式）。
String ucViolationOutput(String uc, int count, {int firstLine = 4}) {
  final lines = [
    for (var i = 0; i < count; i++)
      'docs/spec/x/SPEC-900.md:${firstLine + i}:$uc',
  ];
  return '發現 $count 處違規 UC 編號:\n${lines.join('\n')}\n';
}

/// `doc validate` 的失敗輸出樣本（2026-11-12 以真實 CLI 對缺欄位的 EVT 取得）：
/// 首行為標題，其後逐行 `  - <問題>`。
const String docValidateFailureBase =
    '驗證失敗: EVT-X-001 缺少以下項目\n'
    '  - 缺少必填欄位: category\n'
    '  - 必填欄位值不可為空: canonical_name\n';

Uint8List fixtureBytes(String text) => Uint8List.fromList(utf8.encode(text));
