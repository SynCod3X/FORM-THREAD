import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/profile_details_screen.dart';

void main() {
  const profile = {
    'full_name': 'Jomel Galapon',
    'email': 'jomel@example.com',
    'contact_number': '09481978066',
    'address': 'Bagong Barrio, Caloocan City',
  };

  testWidgets('profile form is readable and saves edited details on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(370, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? savedName;
    String? savedPhone;
    String? savedAddress;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileDetailsScreen(
                    profile: profile,
                    saveProfile: (name, phone, address) async {
                      savedName = name;
                      savedPhone = phone;
                      savedAddress = address;
                    },
                  ),
                ),
              ),
              child: const Text('OPEN PROFILE'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN PROFILE'));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE DETAILS'), findsOneWidget);
    expect(find.text('jomel@example.com'), findsOneWidget);
    expect(find.text('DELIVERY ADDRESS'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField).first, 'Jomel G.');
    await tester.ensureVisible(find.text('SAVE CHANGES'));
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(savedName, 'Jomel G.');
    expect(savedPhone, '09481978066');
    expect(savedAddress, 'Bagong Barrio, Caloocan City');
    expect(find.text('OPEN PROFILE'), findsOneWidget);
  });

  testWidgets('profile form requires all delivery details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileDetailsScreen(
          profile: profile,
          saveProfile: (_, _, _) async => fail('Should not save invalid form'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, ' ');
    await tester.ensureVisible(find.text('SAVE CHANGES'));
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter full name.'), findsOneWidget);
  });
}
