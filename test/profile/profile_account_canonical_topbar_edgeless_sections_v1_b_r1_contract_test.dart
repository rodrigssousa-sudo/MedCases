import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();
  });

  String slice(String startToken, String endToken) {
    final start = source.indexOf(startToken);
    final end = source.indexOf(endToken, start + startToken.length);
    expect(start, greaterThanOrEqualTo(0), reason: 'Missing $startToken');
    expect(end, greaterThan(start), reason: 'Missing $endToken');
    return source.substring(start, end);
  }

  group('Profile account canonical UI R1', () {
    test('profile marker and canonical dark palette exist', () {
      expect(
        source,
        contains(
          'MEDCASES_PROFILE_ACCOUNT_CANONICAL_TOPBAR_EDGELESS_SECTIONS_V1_B_R1',
        ),
      );
      final state = slice(
        'class _ProfileAccountScreenState extends State<ProfileAccountScreen>',
        'class _ProfileAccountTopBar extends StatelessWidget',
      );
      expect(state, contains('_pageDark = Color(0xFF0F1116)'));
      expect(state, contains('_surfaceDark = Color(0xFF181D25)'));
      expect(state, contains('top: false'));
    });

    test('topbar matches canonical MedCases geometry and glass', () {
      final topbar = slice(
        'class _ProfileAccountTopBar extends StatelessWidget',
        'class _ProfileAccountSection extends StatelessWidget',
      );
      expect(topbar, contains('ImageFilter.blur(sigmaX: 14, sigmaY: 14)'));
      expect(topbar, contains('height: topPad + 48'));
      expect(topbar, contains('withValues(alpha: 0.70)'));
      expect(topbar, contains('Color(0xFF252930)'));
      expect(topbar, contains('FontWeight.w900'));
      expect(topbar, contains('letterSpacing: 1.2'));
      expect(topbar, contains('width: 0.7'));
      expect(topbar, contains('width: 36'));
      expect(topbar, contains('height: 36'));
      expect(topbar, contains('Icons.arrow_back_ios_new_rounded'));
      expect(topbar, contains('TextAlign.center'));
    });

    test('section owner is edgeless', () {
      final section = slice(
        'class _ProfileAccountSection extends StatelessWidget',
        'class _ProfileAccountField extends StatelessWidget',
      );
      expect(
          section, isNot(contains('borderRadius: BorderRadius.circular(12)')));
      expect(section, isNot(contains('Border.all(color: border')));
      expect(section, contains('height: 0.7'));
      expect(section, contains('...children'));
    });

    test('avatar hero outer frame is removed', () {
      final state = slice(
        'class _ProfileAccountScreenState extends State<ProfileAccountScreen>',
        'class _ProfileAccountTopBar extends StatelessWidget',
      );
      final start = state.indexOf('Widget _avatarCard()');
      final end = state.indexOf('Widget _accountCard()', start);
      final fallbackEnd = state.indexOf('Widget _securityCard()', start);
      final stop = end > start ? end : fallbackEnd;
      expect(start, greaterThanOrEqualTo(0));
      expect(stop, greaterThan(start));
      final avatar = state.substring(start, stop);
      expect(
        avatar,
        contains('padding: const EdgeInsets.fromLTRB(2, 14, 2, 18)'),
      );
    });

    test('fields use subtle resting border and focused accent', () {
      final field = slice(
        'class _ProfileAccountField extends StatelessWidget',
        'class _ProfileAccountButton extends StatelessWidget',
      );
      expect(field, contains('fill ='));
      expect(field, contains('Color(0xFF181D25)'));
      expect(field, contains('borderSide: BorderSide.none'));
      expect(field, contains('border.withValues(alpha: 0.42)'));
      expect(field, contains('width: 0.55'));
      expect(field, contains('Color(0xFF10B981)'));
    });

    test('photo actions are ghost actions without card outlines', () {
      final action = slice(
        'class _ProfilePhotoAction extends StatelessWidget',
        'class _ProfilePasswordToggle extends StatelessWidget',
      );
      expect(action, contains('TextButton.icon('));
      expect(action, isNot(contains('Border.all(')));
    });

    test('profile functional wiring is preserved', () {
      expect(source, contains('_saveProfile'));
      expect(source, contains('_changePassword'));
      expect(source, contains('_pickCropAvatar'));
      expect(source, contains('_removeAvatar'));
      expect(source, contains('p.updateProfile('));
      expect(source, contains('AuthService.changePassword'));
    });

    test('drawer R3 marker remains present', () {
      expect(
        source,
        contains(
          'MEDCASES_DRAWER_COMPACT_20_PERCENT_VISUAL_DENSITY_V1_B_R3',
        ),
      );
    });
  });
}
