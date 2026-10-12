// MacosScanNotifier.show 的發送結果收斂（SPEC-003 §2.2 權限 gate「發送失敗」列）。
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/services/macos_scan_notifier.dart';
import 'package:graph_project_docs_manager/services/scan_notifier.dart';

const _channel = MethodChannel(scanNotifierChannelName);
const _notification = ScanCompleteNotification(gapCount: 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ScanNotificationDelivery> showWith(
    Future<Object?>? Function(MethodCall) handler,
  ) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
    return MacosScanNotifier(channel: _channel).show(_notification);
  }

  test('原生端正常回應：delivered', () async {
    expect(
      await showWith((_) async => null),
      ScanNotificationDelivery.delivered,
    );
  });

  test('A 內文依結果選擇：無法判定優先於破洞數（E1：同 gapCount 對照）', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final bodies = <Object?>[];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      bodies.add((call.arguments as Map)['body']);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
    final notifier = MacosScanNotifier(channel: _channel)
      ..updateLocalizedStrings(
        title: () => 't',
        foundBody: (n) => 'found$n',
        noGapsBody: () => 'none',
        undeterminableBody: () => 'undet',
      );

    await notifier.show(const ScanCompleteNotification(gapCount: 0));
    await notifier.show(
      const ScanCompleteNotification(gapCount: 0, isUndeterminable: true),
    );
    await notifier.show(const ScanCompleteNotification(gapCount: 2));

    expect(bodies, ['none', 'undet', 'found2']);
  });

  test('PlatformException：failed', () async {
    expect(
      await showWith((_) async => throw PlatformException(code: 'x')),
      ScanNotificationDelivery.failed,
    );
  });

  test('MissingPluginException（未註冊 handler）：failed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    expect(
      await MacosScanNotifier(channel: _channel).show(_notification),
      ScanNotificationDelivery.failed,
    );
  });
}
