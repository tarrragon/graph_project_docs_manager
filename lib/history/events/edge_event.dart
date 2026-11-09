// SPEC-008 FR-04 規則 3：邊事件值物件。
import 'package:graph_project_docs_manager/history/events/edge_key.dart';

enum EdgeEventType { added, removed }

class EdgeEvent {
  const EdgeEvent({
    required this.type,
    required this.key,
    required this.declarersBefore,
    required this.declarersAfter,
    required this.commitId,
    required this.committedAtSeconds,
    required this.author,
    required this.subject,
    required this.isTicketCreation,
  });

  final EdgeEventType type;
  final EdgeKey key;

  /// 該 commit 前後的宣告者節點 ID（去重、字典序）。
  final List<String> declarersBefore;
  final List<String> declarersAfter;
  final String commitId;
  final int committedAtSeconds;
  final String author;
  final String subject;

  /// FR-05：新增事件且該 commit 新建了宣告此邊的 ticket 檔。
  final bool isTicketCreation;
}
