import 'package:flutter_test/flutter_test.dart';
import 'package:untitled4/services/invoice_numbering_service.dart';

void main() {
  final service = InvoiceNumberingService();

  group('buildPrefix (D3, D5)', () {
    test('regular user uses the "A" marker', () {
      expect(service.buildPrefix(7, 3, 2), 'A732');
    });

    test('admin (UID 0) uses the "AD" marker', () {
      expect(service.buildPrefix(0, 1, 1), 'AD011');
    });

    test('prefix differs per branch for the same user', () {
      expect(service.buildPrefix(7, 3, 2), isNot(equals(service.buildPrefix(7, 5, 2))));
    });

    test('prefix differs per department for the same user and branch', () {
      expect(service.buildPrefix(7, 3, 2), isNot(equals(service.buildPrefix(7, 3, 4))));
    });
  });
}
