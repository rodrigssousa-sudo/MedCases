import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String range(String source, String startSignature, String endSignature) {
  final start = source.indexOf(startSignature);
  expect(start, greaterThanOrEqualTo(0), reason: startSignature);
  final end = source.indexOf(endSignature, start + startSignature.length);
  expect(end, greaterThan(start), reason: endSignature);
  return source.substring(start, end);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('Profile Account UI V2 B R1', () {
    test('profile state keeps behavior and adopts canonical palette', () {
      final owner = range(
        main,
        'class _ProfileAccountScreenState',
        'class _ProfileAccountTopBar',
      );

      for (final token in <String>[
        'MEDCASES_PROFILE_ACCOUNT_UI_V2_B_R1',
        'static const _green = Color(0xFF0D6B57);',
        'static const _pageLight = Color(0xFFECF0F4);',
        'static const _borderLight = Color(0xFFE2E7EC);',
        'Future<void> _saveProfile() async',
        'await p.updateProfile(',
        'Future<void> _pickCropAvatar() async',
        'ImageCropper().cropImage(',
        'Future<void> _removeAvatar() async',
        'Future<void> _changePassword() async',
        'AuthService.changePassword(',
        "title: isEs ? 'Perfil y cuenta' : 'Perfil e conta'",
      ]) {
        expect(owner, contains(token), reason: token);
      }
    });

    test('topbar is canonical 48px true liquid glass', () {
      final owner = range(
        main,
        'class _ProfileAccountTopBar',
        'class _ProfileAccountSection',
      );

      for (final token in <String>[
        'BackdropFilter(',
        'ImageFilter.blur(sigmaX: 16, sigmaY: 16)',
        'height: 48',
        'Color(0xE6FFFFFF)',
        'Color(0xE6252930)',
        'Color(0xFFE2E7EC)',
        'Color(0xFF374151)',
        'onTap: onBack',
        'textAlign: TextAlign.center',
      ]) {
        expect(owner, contains(token), reason: token);
      }
    });

    test('sections use clean premium hierarchy', () {
      final owner = range(
        main,
        'class _ProfileAccountSection',
        'class _ProfileAccountField',
      );

      for (final token in <String>[
        'Color(0xFFFFFFFF)',
        'Color(0xFFE2E7EC)',
        'Color(0xFF252930)',
        'Color(0xFF374151)',
        'Color(0xFF18202A)',
        'Color(0xFF66717E)',
        'BorderRadius.circular(12)',
        'width: double.infinity',
        'fontWeight: FontWeight.w800',
      ]) {
        expect(owner, contains(token), reason: token);
      }
    });

    test('photo actions use MedCases accent and preserve destructive state',
        () {
      final owner = range(
        main,
        'class _ProfilePhotoAction',
        'class _ProfilePasswordToggle',
      );

      expect(owner, contains('Color(0xFF0D6B57)'));
      expect(owner, contains('Color(0xFFB91C1C)'));
      expect(owner, contains('Color(0xFFE2E7EC)'));
      expect(owner, contains('required this.onTap'));
      expect(owner, contains('this.destructive = false'));
    });

    test('productive route and account data contracts remain wired', () {
      for (final token in <String>[
        'ProfileAccountScreen(p: p)',
        'displayName: name',
        'profession:',
        'institution:',
        "label: isEs ? 'Correo de la cuenta' : 'E-mail da conta'",
      ]) {
        expect(main, contains(token), reason: token);
      }
    });
  });
}
