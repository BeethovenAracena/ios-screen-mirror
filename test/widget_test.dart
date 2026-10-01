import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ios_screen_cast/main.dart';
import 'package:ios_screen_cast/services/streaming_server.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final server = StreamingServer();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: server,
        child: const ScreenMirrorApp(),
      ),
    );

    expect(find.text('iOS Screen Mirror'), findsOneWidget);
  });
}
