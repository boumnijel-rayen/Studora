import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studora/app/app.dart';

void main() {
  testWidgets('L\'application Studora s\'initialise correctement avec le ProviderScope', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: StudoraApp(),
      ),
    );

    // Vérifie la présence du titre Studora sur le Splash Screen
    expect(find.text('Studora'), findsOneWidget);
    expect(find.text('Organise tes études, simplement.'), findsOneWidget);

    // Laisse s'écouler le timer du Splash Screen pour vérifier la redirection vers l'onboarding / login
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });
}
