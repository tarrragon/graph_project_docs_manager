// 重現 test/fixtures/corpus/ 的抽取邏輯：從語料來源專案的 docs/proposals、
// docs/spec（含各 domain 的 domain-map.md）、docs/usecases、
// docs/proposals-tracking.yaml 複製節點檔，明確排除 docs/work-logs/。
//
// 用法：
//   dart run tool/snapshot_corpus.dart <source_repo_path> <dest_dir_name>
//
// 範例：
//   dart run tool/snapshot_corpus.dart ~/project/screen_clock screen_clock
//
// 本工具只做「節點檔」抽取（PROP / SPEC / UC 三個節點目錄），不涉及
// Ticket 節點（docs/work-logs/）——ticket 規模的處置屬另一議題，見
// test/fixtures/corpus/README.md「已知落差」段與本專案工作日誌對應
// Ticket 的 Solution 章節。
import 'dart:io';

/// 節點檔來源相對路徑清單（相對於來源專案的 docs/ 目錄）。
const List<String> _nodeDirs = ['proposals', 'spec', 'usecases'];

/// docs 目錄下需一併複製的單一節點索引檔。
const List<String> _nodeFiles = ['proposals-tracking.yaml'];

const String _usage =
    'Usage: dart run tool/snapshot_corpus.dart <source_repo_path> <dest_dir_name>'; // i18n-exempt: CLI 開發工具的 usage 訊息，非 app UI

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  final sourceDocsDir = Directory('${args[0]}/docs');
  final destDir = Directory('test/fixtures/corpus/${args[1]}/docs');

  if (!sourceDocsDir.existsSync()) {
    stderr.writeln(
      '來源 docs 目錄不存在：${sourceDocsDir.path}', // i18n-exempt: CLI 開發工具的錯誤訊息，非 app UI
    );
    exitCode = 66;
    return;
  }

  await destDir.create(recursive: true);
  await _copyNodeDirs(sourceDocsDir, destDir);
  await _copyNodeFiles(sourceDocsDir, destDir);

  stdout.writeln(
    '抽取完成：${destDir.path}', // i18n-exempt: CLI 開發工具的完成訊息，非 app UI
  );
}

/// 複製 proposals/spec/usecases 三個節點目錄，逐一保留目錄結構。
Future<void> _copyNodeDirs(Directory sourceDocsDir, Directory destDir) async {
  for (final name in _nodeDirs) {
    final source = Directory('${sourceDocsDir.path}/$name');
    if (!source.existsSync()) continue;
    await _copyDirectoryRecursive(source, Directory('${destDir.path}/$name'));
  }
}

/// 複製 docs/ 下單一節點索引檔（如 proposals-tracking.yaml）。
Future<void> _copyNodeFiles(Directory sourceDocsDir, Directory destDir) async {
  for (final name in _nodeFiles) {
    final source = File('${sourceDocsDir.path}/$name');
    if (!source.existsSync()) continue;
    await source.copy('${destDir.path}/$name');
  }
}

/// 遞迴複製目錄，明確排除 work-logs（防止呼叫端誤傳含 work-logs 的路徑）。
Future<void> _copyDirectoryRecursive(Directory source, Directory dest) async {
  await dest.create(recursive: true);
  await for (final entity in source.list(recursive: false)) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (name == 'work-logs') continue;
    if (entity is Directory) {
      await _copyDirectoryRecursive(entity, Directory('${dest.path}/$name'));
    } else if (entity is File) {
      await entity.copy('${dest.path}/$name');
    }
  }
}
