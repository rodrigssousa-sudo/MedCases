import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/server_usage_authority.dart';
import 'package:medcases/services/audio/recording_start_failure.dart';
void main() {
  for (final code in ['TRANSCRIPTION_LIMIT_REACHED','RATE_LIMITED','CONCURRENT_RESERVATION_LIMIT','MONTHLY_USAGE_LIMIT','TECHNICAL_RECORDING_LIMIT']) {
    test('429 preserves $code', () async {
      final authority=ServerUsageAuthority(uid:()=> 'synthetic',token:() async=>'synthetic',
        client:MockClient((_)async=>http.Response(jsonEncode({'code':code}),429)));
      await expectLater(authority.reserve('synthetic',{'kinds':['recording']}),throwsA(isA<StateError>().having((e)=>e.message,'reason',code)));
    });
  }
  test('untyped proxy 429 is rate limit, not monthly quota', () async {
    final authority=ServerUsageAuthority(uid:()=> 'synthetic',token:() async=>'synthetic',client:MockClient((_)async=>http.Response('Too many requests',429)));
    await expectLater(authority.reserve('synthetic',{'kinds':['recording']}),throwsA(isA<StateError>().having((e)=>e.message,'reason','RATE_LIMITED')));
  });
  test('PT ES distinguish rate and transcription', () {
    for(final es in [false,true]) {
      final rate=RecordingStartFailure.from(StateError('RATE_LIMITED'),'usage').message(isEs:es);
      final quota=RecordingStartFailure.from(StateError('TRANSCRIPTION_LIMIT_REACHED'),'usage').message(isEs:es);
      expect(rate,isNot(quota));expect(quota,contains(es?'transcripción':'transcrição'));
    }
  });
}
