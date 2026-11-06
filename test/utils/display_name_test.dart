import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/utils/display_name.dart';

void main() {
  test('blank stored names fall through to the translated fallback', () {
    expect(firstNonBlank(['', null, '  '], fallback: 'Person'), 'Person');
    expect(firstNonBlank(['', 'Ali'], fallback: 'Person'), 'Ali');
    expect(firstNonBlank(['Mona', 'Ali'], fallback: 'Person'), 'Mona');
  });
}
