import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PROFILE_ACCOUNT_HUB_PREMIUM_V1_B_R0', () {
    late String main;
    late String pubspec;
    late String manifest;
    late String web;

    setUpAll(() {
      main = File('lib/main.dart').readAsStringSync();
      pubspec = File('pubspec.yaml').readAsStringSync();
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      web = File('web/index.html').readAsStringSync();
    });

    test('Editar abre owner full-screen', () {
      expect(
          main, contains('class ProfileAccountScreen extends StatefulWidget'));
      expect(main, contains('MaterialPageRoute<void>('));
      expect(main, contains('ProfileAccountScreen(p: p)'));
      expect(main, isNot(contains('_ProfileEditSheet(p: p)')));
    });

    test('dados profissionais usam owner existente', () {
      expect(main, contains('await p.updateProfile('));
      expect(main, contains('displayName: name'));
      expect(main, contains('profession: _professionCtrl.text.trim()'));
      expect(main, contains('institution: _institutionCtrl.text.trim()'));
    });

    test('foto é recortada 1:1 antes de persistir', () {
      expect(main, contains('ImageCropper().cropImage('));
      expect(main, contains('CropAspectRatio(ratioX: 1, ratioY: 1)'));
      expect(main, contains('CropAspectRatioPreset.square'));
      expect(main, contains('lockAspectRatio: true'));
      expect(main, contains('aspectRatioLockEnabled: true'));
      expect(main, contains('medcases_profile_avatar_'));
      expect(main, contains('prefs.setString(_avatarPrefsKey, encoded)'));
    });

    test('visual canônico e PT/ES', () {
      for (final token in [
        'Color(0xFF10B981)',
        'Color(0xFF1A1D23)',
        'Color(0xFF252930)',
        'Color(0xFF374151)',
        'Color(0xFFECF1F3)',
        'height: 48',
        'BorderRadius.circular(8)',
        "'Perfil y cuenta'",
        "'Perfil e conta'",
        "'Profesión'",
        "'Profissão'",
        "'Institución'",
        "'Instituição'",
        "'Seguridad'",
        "'Segurança'",
      ]) {
        expect(main, contains(token), reason: token);
      }
    });

    test('image_cropper está integrado nas três plataformas', () {
      expect(pubspec, contains('image_cropper: ^12.2.1'));
      expect(manifest, contains('com.yalantis.ucrop.UCropActivity'));
      expect(web, contains('cropperjs/1.6.2/cropper.css'));
      expect(web, contains('cropperjs/1.6.2/cropper.min.js'));
    });
  });
}
