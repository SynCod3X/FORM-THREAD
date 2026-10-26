import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/staff_support_screen.dart';

class _FakeSupportDataSource extends StaffSupportDataSource {
  final request = <String, dynamic>{
    'id': 'request-1',
    'subject': 'Where is my order?',
    'customer_email': 'customer@example.com',
    'message': 'Please help me find my order.',
    'status': 'open',
    'staff_reply': '',
  };
  bool failNextLoad = false;

  @override
  Future<List<Map<String, dynamic>>> load() async {
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('Temporary load failure');
    }
    return [Map<String, dynamic>.from(request)];
  }

  @override
  Future<void> updateStatus(String id, String status) async {
    expect(id, 'request-1');
    request['status'] = status;
  }

  @override
  Future<void> sendReply(String id, String reply) async {
    expect(id, 'request-1');
    request['staff_reply'] = reply;
    request['status'] = 'in_progress';
  }
}

void main() {
  testWidgets('staff can open support, update status, and reply', (
    tester,
  ) async {
    final dataSource = _FakeSupportDataSource();
    await tester.pumpWidget(
      MaterialApp(home: StaffSupportScreen(dataSource: dataSource)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Where is my order?'), findsOneWidget);
    expect(find.text('Status: open'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mark in progress'));
    await tester.pumpAndSettle();
    expect(find.text('Status: in progress'), findsOneWidget);

    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Your order is on its way.',
    );
    await tester.tap(find.text('SEND'));
    await tester.pumpAndSettle();
    expect(dataSource.request['staff_reply'], 'Your order is on its way.');
    expect(
      find.textContaining('Reply: Your order is on its way.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff can retry after a load failure', (tester) async {
    final dataSource = _FakeSupportDataSource()..failNextLoad = true;
    await tester.pumpWidget(
      MaterialApp(home: StaffSupportScreen(dataSource: dataSource)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load support requests.'), findsOneWidget);
    await tester.tap(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();
    expect(find.text('Where is my order?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
