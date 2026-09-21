import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/widgets/public_landing/landing_message.dart';

void main() {
  test('accepts only known versioned JSON intents and supported languages', () {
    expect(landingLoginLanguage(jsonEncode({'type':'medcases:login:v1','language':'pt-BR'})), 'pt');
    expect(landingLoginLanguage(jsonEncode({'type':'medcases:login:v1','language':'es'})), 'es');
    for (final data in [null, 'login', '{}', '{', jsonEncode({'type':'login','language':'es'}), jsonEncode({'type':'medcases:login:v1','language':'en'}), {'type':'medcases:login:v1','language':'es'}]) {
      expect(landingLoginLanguage(data), isNull);
    }
  });
}
