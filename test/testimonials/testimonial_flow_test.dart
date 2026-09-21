import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/models/user_model.dart';
import 'package:medcases/testimonials/testimonial_intent.dart';
import 'package:medcases/testimonials/testimonial_screen.dart';
import 'package:medcases/testimonials/testimonial_service.dart';
import 'package:medcases/widgets/public_landing/landing_message.dart';

class FakeTestimonials extends TestimonialService {
  FakeTestimonials() : super(projectId:'demo-test', token:() async => '');
  bool submitted = false;
  @override Future<TestimonialRecord?> mine(String uid) async => null;
  @override Future<void> submit({required String uid, required String name, required String profession,
    required String text, required String photo, required bool consent, TestimonialRecord? existing}) async {
      expect(consent,true); expect(photo,''); expect(uid,'owner'); submitted = true;
  }
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('testimonial intent survives login redirect, consumes once, and cancels on back', () async {
    await TestimonialIntent.request(); expect(await TestimonialIntent.consume(),true);
    expect(await TestimonialIntent.consume(),false);
    await TestimonialIntent.request(); await TestimonialIntent.clear(); expect(await TestimonialIntent.consume(),false);
    expect(landingActionLanguage('{"type":"medcases:testimonial:v1","language":"es"}','medcases:testimonial:v1'),'es');
    expect(landingLoginLanguage('{"type":"medcases:testimonial:v1","language":"es"}'),isNull);
  });
  testWidgets('ordinary user sees editor, explicit consent gates submit, and close returns to app', (tester) async {
    final service=FakeTestimonials(); var closed=false;
    await tester.pumpWidget(MaterialApp(home:TestimonialScreen(user:UserModel(uid:'owner',email:'private@example.test',
      displayName:'User',profession:'Doctor',status:UserStatus.approved,createdAt:DateTime(2026)),service:service,onClose:()=>closed=true)));
    await tester.pumpAndSettle();
    expect(find.text('Moderação'),findsNothing); expect(find.text('private@example.test'),findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);
    await tester.enterText(find.byType(TextFormField).at(2),'Minha experiência real com a plataforma.');
    await tester.ensureVisible(find.byType(CheckboxListTile)); await tester.tap(find.byType(CheckboxListTile)); await tester.pump();
    await tester.ensureVisible(find.byType(FilledButton)); await tester.tap(find.byType(FilledButton)); await tester.pumpAndSettle();
    expect(service.submitted,true); expect(find.text('Enviado para moderação.'),findsWidgets);
    await tester.tap(find.byTooltip('Voltar ao aplicativo')); expect(closed,true);
  });
}
