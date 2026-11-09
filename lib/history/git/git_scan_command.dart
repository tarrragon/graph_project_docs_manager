/// SPEC-008 FR-01 規則 1、3 的 git 呼叫組裝（純函式，無 I/O）。
library;

import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';

/// 所有 git 呼叫的固定環境：語系無關（FR-01 規則 1）。
const Map<String, String> historyGitEnvironment = {'LC_ALL': 'C'};

/// FR-02 規則 1 的標頭格式：U+001E 開頭，欄位以 U+0000 分隔。
const String historyLogHeaderFormat = '%x1e%H%x00%P%x00%ct%x00%an%x00%s';

/// 最低支援的 git 主版本與次版本。
const int minGitMajor = 2;
const int minGitMinor = 31;

// i18n-exempt: git 輸出解析樣式，非使用者可見字串
final RegExp _majorMinorPattern = RegExp(r'git version (\d+)\.(\d+)');

// i18n-exempt: git 輸出解析樣式，非使用者可見字串
final RegExp _fullVersionPattern = RegExp(r'git version (\d+(?:\.\d+)*)');

GitInvocation _invocation(String root, List<String> rest) => GitInvocation(
  arguments: ['-C', root, ...rest],
  environment: historyGitEnvironment,
);

GitInvocation gitVersionInvocation(String root) =>
    _invocation(root, ['--version']);

GitInvocation gitWorkTreeInvocation(String root) => _invocation(root, [
  'rev-parse',
  '--is-inside-work-tree',
  '--is-shallow-repository',
]);

GitInvocation gitHeadInvocation(String root) =>
    _invocation(root, ['rev-parse', '--verify', '-q', 'HEAD']);

GitInvocation gitMainlineInvocation(String root) =>
    _invocation(root, ['rev-list', '--first-parent', 'HEAD']);

GitInvocation gitTagsInvocation(String root) => _invocation(root, [
  'for-each-ref',
  '--format=%(refname:short)%00%(objectname)%00%(*objectname)',
  'refs/tags',
]);

/// 掃描指令（FR-01 規則 3）。
GitInvocation gitScanInvocation(String root) => _invocation(root, [
  '-c',
  'core.quotePath=false',
  'log',
  '-p',
  '--reverse',
  '--first-parent',
  '--diff-merges=first-parent',
  '--no-renames',
  '--no-color',
  '--no-ext-diff',
  '--no-textconv',
  '--no-show-signature',
  '--src-prefix=a/',
  '--dst-prefix=b/',
  '--relative',
  '--format=$historyLogHeaderFormat',
  '--',
  'docs/',
]);

/// 版本字串是否達到最低要求；無法解析回傳 null。
bool? isSupportedGitVersion(String versionOutput) {
  final match = _majorMinorPattern.firstMatch(versionOutput);
  if (match == null) return null;
  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  if (major != minGitMajor) return major > minGitMajor;
  return minor >= minGitMinor;
}

/// 取出版本號文字（例 `2.39.3`），無法解析回傳空字串。
String gitVersionNumber(String versionOutput) =>
    _fullVersionPattern.firstMatch(versionOutput)?.group(1) ?? '';
