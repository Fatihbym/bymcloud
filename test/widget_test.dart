import 'package:flutter_test/flutter_test.dart';
import 'package:bymcloud/main.dart';
import 'package:bymcloud/services/deep_link_service.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(deepLinkService: DeepLinkService()));

    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
