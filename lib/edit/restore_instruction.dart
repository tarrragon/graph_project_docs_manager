/// 需求：[SPEC-009 FR-02] 取回說明：有快照（W ≠ H）為
/// `git cat-file -p <sha> > <路徑>`；無快照（W = H）為
/// `git checkout HEAD -- <路徑>`。路徑為工作區相對路徑。
///
/// 兩者是使用者貼進終端機的 git 指令字面，不隨語系變動。
String restoreInstruction({
  required String relativePath,
  String? snapshotSha,
}) => snapshotSha == null
    ? 'git checkout HEAD -- $relativePath' // i18n-exempt
    : 'git cat-file -p $snapshotSha > $relativePath'; // i18n-exempt
