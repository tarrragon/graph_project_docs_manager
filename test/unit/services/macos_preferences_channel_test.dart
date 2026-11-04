// MacosPreferencesChannel：handler 查詢收斂與 ⌘, 事件（SPEC-003 §3.8）。
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/services/macos_preferences_channel.dart';

const _channel = MethodChannel(preferencesChannelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<bool> queryWith(Future<Object?>? Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(_channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
    return MacosPreferencesChannel(channel: _channel).hasHandler('vscode');
  }

  test('原生端回 true / false：照原值回傳，並帶 scheme 參數', () async {
    final seen = <Object?>[];

    final found = await queryWith((call) async {
      seen.add(call.arguments);
      return true;
    });
    final missing = await queryWith((_) async => false);

    expect(found, isTrue);
    expect(missing, isFalse);
    expect(seen.single, {'scheme': 'vscode'});
  });

  test('原生端回 null、PlatformException、未註冊：一律視為無 handler', () async {
    expect(await queryWith((_) async => null), isFalse);
    expect(
      await queryWith((_) async => throw PlatformException(code: 'X')),
      isFalse,
    );
    messenger.setMockMethodCallHandler(_channel, null);
    expect(
      await MacosPreferencesChannel(channel: _channel).hasHandler('zed'),
      isFalse,
    );
  });

  test('原生端送 openPreferences：openRequested 發出一次', () async {
    final channel = MacosPreferencesChannel(channel: _channel);
    var count = 0;
    final sub = channel.openRequested.listen((_) => count++);
    addTearDown(sub.cancel);

    await messenger.handlePlatformMessage(
      preferencesChannelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('openPreferences'),
      ),
      (_) {},
    );
    await pumpEventQueue();

    expect(count, 1);
  });
}
