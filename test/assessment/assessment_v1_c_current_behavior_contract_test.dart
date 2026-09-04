import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readSource(String path) {
  return File(path).readAsStringSync();
}

int countMatches(String source, RegExp pattern) {
  return pattern.allMatches(source).length;
}

List<String> dartFilesContaining(
  String root,
  String needle, {
  String? excludedPath,
}) {
  final matches = <String>[];

  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (excludedPath != null && entity.path == excludedPath) {
      continue;
    }

    final source = entity.readAsStringSync();
    if (source.contains(needle)) {
      matches.add(entity.path);
    }
  }

  matches.sort();
  return matches;
}

void main() {
  late String assessment;
  late String migrationAssessment;
  late String home;
  late String homeV2;
  late String modulesView;
  late String provider;
  late String soapSection;

  setUpAll(() {
    assessment = readSource('lib/screens/avaliacao_screen.dart');
    migrationAssessment = readSource(
      'lib/home_v2/migration_avaliacao_reference.dart',
    );
    home = readSource('lib/screens/home_screen.dart');
    homeV2 = readSource('lib/home_v2/home_screen_v2.dart');
    modulesView = readSource(
      'lib/home_v2/components/home_v2_modules_view.dart',
    );
    provider = readSource('lib/providers/app_provider.dart');
    soapSection = readSource(
      'lib/screens/internacion/components/soap/soap_section.dart',
    );
  });

  group('Avaliação V1-C — comportamento produtivo atual', () {
    test('owner canônico e cadeia Home V2 permanecem únicos', () {
      expect(
        countMatches(
          assessment,
          RegExp(
            r'^\s*class\s+AvaliacaoScreen\s+extends\s+'
            r'StatefulWidget\s*\{',
            multiLine: true,
          ),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(
            r'^\s*class\s+_AvaliacaoScreenState\s+extends\s+'
            r'State\s*<\s*AvaliacaoScreen\s*>\s*\{',
            multiLine: true,
          ),
        ),
        1,
      );
      expect(
        countMatches(
          homeV2,
          RegExp(r'\bHomeAssessmentNotesTimerCard\s*\('),
        ),
        1,
      );
      expect(
        home,
        contains("import 'avaliacao_screen.dart';"),
      );
      expect(
        countMatches(
          home,
          RegExp(
            r'pageBuilder\s*:\s*\([^)]*\)\s*=>\s*'
            r'const\s+AvaliacaoScreen\s*\(',
          ),
        ),
        1,
      );
      expect(
        countMatches(
          modulesView,
          RegExp(r'\bfinal\s+VoidCallback\s+onAssessment\s*;'),
        ),
        1,
      );
      expect(
        countMatches(
          modulesView,
          RegExp(r'\bonTap\s*:\s*onAssessment\b'),
        ),
        1,
      );
    });

    test('navegação usa nove seções e não abas Flutter', () {
      final dataPrefix = assessment.substring(
        0,
        assessment.indexOf('class AvaliacaoScreen'),
      );

      final sectionTotalRefs = countMatches(
        dataPrefix,
        RegExp(r'\b_Section\s*\('),
      );
      final sectionConstructorDeclarations = countMatches(
        dataPrefix,
        RegExp(
          r'^\s*(?:const\s+)?_Section\s*\(\s*\{',
          multiLine: true,
        ),
      );
      final questionTotalRefs = countMatches(
        dataPrefix,
        RegExp(r'\b_Question\s*\('),
      );
      final questionConstructorDeclarations = countMatches(
        dataPrefix,
        RegExp(
          r'^\s*(?:const\s+)?_Question\s*\(\s*\{',
          multiLine: true,
        ),
      );

      expect(sectionTotalRefs, 10);
      expect(sectionConstructorDeclarations, 1);
      expect(
        sectionTotalRefs - sectionConstructorDeclarations,
        9,
      );
      expect(questionTotalRefs, 58);
      expect(questionConstructorDeclarations, 1);
      expect(
        questionTotalRefs - questionConstructorDeclarations,
        57,
      );
      expect(
        countMatches(assessment, RegExp(r'\bTabBar\s*\(')),
        0,
      );
      expect(
        countMatches(assessment, RegExp(r'\bTabBarView\s*\(')),
        0,
      );
      expect(
        countMatches(assessment, RegExp(r'\bTabController\b')),
        0,
      );
      expect(
        countMatches(assessment, RegExp(r'\bPageController\b')),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(r'\bPageView(?:\.builder)?\s*\('),
        ),
        1,
      );
      expect(
        countMatches(assessment, RegExp(r'\b_SectionNav\s*\(')),
        2,
      );
    });

    test('as nove seções PT e ES permanecem disponíveis', () {
      const portuguese = <String>[
        'Geral',
        'Sinais Vitais',
        'Cabeça e Pescoço',
        'Cardiovascular',
        'Respiratório',
        'Abdome',
        'Neurológico',
        'Membros',
        'Outros',
      ];
      const spanish = <String>[
        'General',
        'Signos Vitales',
        'Cabeza y Cuello',
        'Cardiovascular',
        'Respiratorio',
        'Abdomen',
        'Neurológico',
        'Extremidades',
        'Otros',
      ];

      for (final label in portuguese) {
        expect(
          assessment,
          contains("'$label'"),
          reason: 'Seção PT ausente: $label',
        );
      }
      for (final label in spanish) {
        expect(
          assessment,
          contains("'$label'"),
          reason: 'Seção ES ausente: $label',
        );
      }
    });

    test('os 57 IDs clínicos permanecem no contrato', () {
      const questionIds = <String>[
        'estado_geral',
        'consciencia',
        'coloracao',
        'hidratacao',
        'acianose',
        'aicterica',
        'afebril',
        'edema',
        'estado_nutricional',
        'mobilidade',
        'pa',
        'fc',
        'fr',
        'temp',
        'spo2',
        'dextro',
        'peso',
        'altura',
        'cranio',
        'olhos',
        'mucosas',
        'pescoco',
        'tireoide',
        'meningismo',
        'ritmo',
        'bulhas',
        'sopro',
        'pulso',
        'tec',
        'ictus',
        'torax',
        'mv',
        'ruidos',
        'percussao',
        'dispneia_tipo',
        'inspecao_abd',
        'rha',
        'palpacao',
        'visceras',
        'sinal_peritonio',
        'ascite',
        'glasgow',
        'orientacao',
        'forca',
        'marcha',
        'reflexos',
        'fala',
        'nc',
        'mmss',
        'mmii',
        'varizes',
        'dvt',
        'pele',
        'coluna',
        'linfonodos',
        'retal',
        'observacoes',
      ];

      expect(questionIds.length, 57);

      for (final id in questionIds) {
        expect(
          assessment,
          contains("id: '$id'"),
          reason: 'ID clínico ausente: $id',
        );
      }
    });

    test('estado e ações atuais permanecem caracterizados', () {
      expect(
        assessment,
        contains('final bool _detailed = true;'),
      );
      expect(
        countMatches(
          assessment,
          RegExp(r'\bint\s+_sectionIdx\s*=\s*0\s*;'),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(r'\bTextEditingController\b'),
        ),
        6,
      );
      expect(
        countMatches(assessment, RegExp(r'\bsetState\s*\(')),
        3,
      );

      for (final method in <String>[
        '_compileResult',
        '_saveToHistory',
        '_copyText',
        '_clearAll',
        '_goTo',
        '_confirmBack',
      ]) {
        expect(
          assessment,
          contains('$method('),
          reason: 'Método ausente: $method',
        );
      }

      expect(
        assessment,
        contains('Clipboard.setData'),
      );
      expect(
        assessment,
        contains('showDialog'),
      );
    });

    test('História Clínica continua sendo o owner da persistência', () {
      expect(
        assessment.contains('FirestoreService.'),
        isFalse,
      );
      expect(
        assessment.contains('FirebaseFirestore'),
        isFalse,
      );
      expect(
        countMatches(
          assessment,
          RegExp(
            r'\b[A-Za-z_]\w*\s*\.\s*saveHistory\s*\(',
          ),
        ),
        1,
      );
      expect(
        countMatches(
          provider,
          RegExp(
            r'^\s*(?:Future<[^>]+>|Future<void>|void)\s+'
            r'saveHistory\s*\(',
            multiLine: true,
          ),
        ),
        1,
      );
      expect(
        provider,
        contains('FirestoreService.saveHistoryTyped'),
      );
      expect(
        provider,
        contains('_saveHistoriesLocal('),
      );
    });

    test('migration permanece cópia inativa do owner produtivo', () {
      expect(migrationAssessment, assessment);

      final callers = dartFilesContaining(
        'lib',
        'migration_avaliacao_reference.dart',
        excludedPath:
            'lib/home_v2/migration_avaliacao_reference.dart',
      );

      expect(callers, isEmpty);
    });

    test('AssessmentCard permanece stub visual desconectado', () {
      final callers = dartFilesContaining(
        'lib',
        'AssessmentCard(',
        excludedPath:
            'lib/home_v2/components/cards/assessment_card.dart',
      );

      expect(callers, isEmpty);
    });

    test('SOAP Evaluación permanece domínio separado de Internação', () {
      expect(
        soapSection,
        contains('SoapEvaluacion('),
      );
      expect(
        assessment.contains('SoapEvaluacion('),
        isFalse,
      );
      expect(
        assessment.contains('EvaluacionData'),
        isFalse,
      );
    });

    test('resultado usa conteúdo das seções sem persistência paralela', () {
      expect(
        countMatches(
          assessment,
          RegExp(
            r'\bString\s+_compileResult\s*\(\s*'
            r'bool\s+isEs\s*\)',
          ),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(r'\b_compileResult\s*\(\s*isEs\s*\)'),
        ),
        2,
      );
      expect(
        countMatches(
          assessment,
          RegExp(
            r'\bvoid\s+_saveToHistory\s*\(\s*'
            r'BuildContext\s+ctx\s*,\s*AppProvider\s+p\s*\)',
          ),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(
            r'\b_saveToHistory\s*\(\s*context\s*,\s*p\s*\)',
          ),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(
            r'\bvoid\s+_clearAll\s*\(\s*'
            r'BuildContext\s+ctx\s*,\s*AppProvider\s+p\s*\)',
          ),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(r'\b_clearAll\s*\(\s*context\s*,\s*p\s*\)'),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(
            r'\bvoid\s+_confirmBack\s*\(\s*'
            r'BuildContext\s+ctx\s*,\s*AppProvider\s+p\s*\)',
          ),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(r'\b_confirmBack\s*\(\s*context\s*,\s*p\s*\)'),
        ),
        1,
      );
      expect(
        countMatches(
          assessment,
          RegExp(r'\bSharedPreferences\b'),
        ),
        0,
      );
      expect(
        countMatches(
          assessment,
          RegExp(r'\bStreamSubscription\b'),
        ),
        0,
      );
    });
  });
}
