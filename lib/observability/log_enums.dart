/// SPEC-010 FR-01 / FR-02 / FR-03 / FR-06：記錄等級、錯誤來源與建構失敗替代值。
library;

/// 記錄等級；[devLogLevel] 為轉呼 developer.log 的數值（FR-06）。
enum LogLevel {
  debug('debug', 500),
  info('info', 800),
  warning('warning', 900),
  error('error', 1000);

  const LogLevel(this.wireName, this.devLogLevel);

  final String wireName;
  final int devLogLevel;
}

/// 錯誤來源分類（FR-02），[wireName] 為信封 `error_source` 的值。
enum ErrorSource {
  platformIo('platform_io'),
  externalProcess('external_process'),
  parse('parse'),
  gateBlocked('gate_blocked'),
  internal('internal');

  const ErrorSource(this.wireName);

  final String wireName;
}

/// 工作區外位置的替代值（FR-03）。
enum LogLocation { appSupport, executable, system, other }

/// 識別不合法的替代值（FR-03）。
enum LogIdentityRejected { fieldNameRejected, nodeIdRejected }
