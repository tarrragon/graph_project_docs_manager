import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('autoDisposeStateHolderProvider.overrideWithInitial', () {
    final provider = autoDisposeStateHolderProvider<int>((ref) => 0);

    test('覆寫值生效、寫入生效、釋放後重讀回覆寫初值', () async {
      final container = ProviderContainer(
        overrides: [provider.overrideWithInitial((ref) => 7)],
      );
      addTearDown(container.dispose);

      var sub = container.listen(provider, (_, _) {});
      expect(sub.read(), 7);

      container.read(provider.notifier).state = 9;
      expect(container.read(provider), 9);

      sub.close();
      await Future<void>.delayed(Duration.zero);

      sub = container.listen(provider, (_, _) {});
      expect(sub.read(), 7);
      sub.close();
    });

    test('對照組：未覆寫讀到宣告初值，釋放後仍為宣告初值', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var sub = container.listen(provider, (_, _) {});
      expect(sub.read(), 0);
      container.read(provider.notifier).state = 5;
      sub.close();
      await Future<void>.delayed(Duration.zero);

      sub = container.listen(provider, (_, _) {});
      expect(sub.read(), 0);
      sub.close();
    });
  });
}
