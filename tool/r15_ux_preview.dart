// Local Flutter component review. No Firebase, auth, model, ledger or quota calls.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medcases/models/canonical_clinical_snapshot.dart';
import 'package:medcases/models/plantao_presentation_contract.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_session_exchange_hydrator.dart';
import 'package:medcases/services/clinical_tts_service.dart';
import 'package:medcases/screens/ai/widgets/ai_bubble.dart';
import '../test/fixtures/r15_ux_fixtures.dart';
import '../test/fixtures/r15_drug_reference_snapshots.dart';
import '../test/fixtures/r15_current_drug_preview.dart';

void main() => runApp(const _ReviewApp());

class _ReviewApp extends StatelessWidget {
  const _ReviewApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF151A21),
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF009C3B), brightness: Brightness.dark)),
      home: const _ReviewPage());
}

class _ReviewPage extends StatefulWidget {
  const _ReviewPage();
  @override
  State<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<_ReviewPage> {
  String locale = 'pt', scenario = 'A';
  double width = 760;
  bool playing = false, ready = false;
  String receipt =
      'Nenhuma consulta à IA. Fixture técnica; não é homologação médica.';
  final tts = ClinicalTtsService();
  final createdAt = DateTime.now();
  @override
  void initState() {
    super.initState();
    tts.initialize().then((_) {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    tts.dispose();
    super.dispose();
  }

  Future<void> _play(String text) async {
    if (playing) {
      await tts.stop();
      if (mounted) {
        setState(() => playing = false);
      }
      return;
    }
    setState(() {
      playing = true;
      receipt = 'TTS: reprodução iniciada no navegador.';
    });
    try {
      await tts.speak(text, languageCode: locale);
      final available = await tts.enumerateVoices();
      final voices = available
          .where((v) => v.locale.toLowerCase().startsWith(locale))
          .map((v) => v.name)
          .join(', ');
      if (mounted) {
        setState(() {
          playing = false;
          receipt =
              'TTS concluído • voz: ${tts.selectedVoice?.name ?? 'padrão do idioma'} • ritmo natural. Vozes disponíveis: ${voices.isEmpty ? 'nenhuma voz deste idioma informada pelo navegador' : voices}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          playing = false;
          receipt = 'TTS: falha real; não aprovado.';
        });
      }
    }
  }

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        setState(() => receipt =
            'Cópia integral confirmada: ${utf8.encode(text).length} bytes.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => receipt = 'Falha de cópia; não aprovado.');
      }
    }
  }

  CanonicalClinicalSnapshot get snapshot {
    if (['C', 'D', 'F', 'G'].contains(scenario)) {
      String raw = r15DrugReferenceSnapshots[locale]!;
      if (scenario == 'F') {
        raw = r15CurrentDrugPreview['noradrenalina/$locale']['documentJson']
            as String;
      } else if (scenario == 'G') {
        final document = jsonDecode(r15CurrentDrugPreview['ceftriaxona/$locale']
            ['documentJson'] as String) as Map<String, dynamic>;
        document['lookupField'] =
            locale == 'pt' ? 'contraindicacoes' : 'contraindicaciones';
        raw = jsonEncode(document);
      }
      final hash = PlantaoPresentationContract.textHash(raw);
      final drug = CanonicalClinicalSnapshot.fromDrugReference(raw, hash);
      if (scenario == 'D') {
        return AiSessionExchangeHydrator.hydrate(
            sessionId: 'LOCAL_PREVIEW',
            exchanges: [
              {
                'requestId': 'LOCAL_ONLY',
                'mode': 'plantao',
                'locale': locale,
                'userInput': 'Paracetamol',
                'provenance': 'CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION',
                'assistantOutput': drug.blocks(locale).join(),
                'drugReference': {'documentJson': raw, 'payloadSha256': hash}
              }
            ]).single.referenceDocument!;
      }
      return drug;
    }
    return r15ProtocolSnapshot(locale, executive: scenario == 'A');
  }

  @override
  Widget build(BuildContext context) {
    final source = snapshot;
    final full = scenario == 'E'
        ? (locale == 'pt'
            ? '# Estudo local\n\nExplicação didática de demonstração; sem consulta à IA ou orientação clínica.\n\n## Referências\n\n- [Fonte técnica](https://example.org/study)'
            : '# Estudio local\n\nExplicación didáctica de demostración; sin consulta a la IA ni orientación clínica.\n\n## Referencias\n\n- [Fuente técnica](https://example.org/study)')
        : source.blocks(locale).join();
    return Scaffold(
        appBar: AppBar(title: const Text('MedCases · revisão local Flutter')),
        body: SingleChildScrollView(
            child: Center(
                child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width),
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'AMBIENTE LOCAL · LEITURA REVISÃO C · SEM CONSULTAS PRODUTIVAS',
                                  style: TextStyle(
                                      color: Color(0xFF009C3B),
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, children: [
                                for (final code in ['pt', 'es'])
                                  ChoiceChip(
                                      label: Text(code.toUpperCase()),
                                      selected: locale == code,
                                      onSelected: (_) =>
                                          setState(() => locale = code)),
                                for (final entry in {
                                  'A': 'A · EXECUTIVE sintético',
                                  'B': 'B · FULL sintético',
                                  'C': 'C · Paracetamol',
                                  'D': 'D · Histórico local',
                                  'E': 'E · Estudo local',
                                  'F': 'F · Noradrenalina',
                                  'G': 'G · Contraindicações'
                                }.entries)
                                  ChoiceChip(
                                      label: Text(entry.value),
                                      selected: scenario == entry.key,
                                      onSelected: (_) => setState(() {
                                            scenario = entry.key;
                                            receipt =
                                                'Revisão local da fonte; sem geração ou cobrança.';
                                          }))
                              ]),
                              Wrap(spacing: 8, children: [
                                for (final e in {
                                  320.0: '320 px',
                                  375.0: '375 px',
                                  768.0: '768 px',
                                  1200.0: '1200 px'
                                }.entries)
                                  TextButton(
                                      onPressed: () =>
                                          setState(() => width = e.key),
                                      child: Text(e.value))
                              ]),
                              Text(
                                  ['C', 'D', 'F', 'G'].contains(scenario)
                                      ? 'Fonte publicada 79b73f4: bytes PT/ES conferidos. Prévia local; sessão MCC1 real ainda não comprovada.'
                                      : 'Fixture de contrato; aprovação sintética, não utilizável clinicamente.',
                                  style: const TextStyle(fontSize: 12)),
                              Text(receipt,
                                  key: const ValueKey('review_receipt'),
                                  style: const TextStyle(fontSize: 12)),
                              TextButton.icon(
                                icon: const Icon(Icons.record_voice_over),
                                label: Text(locale == 'pt'
                                    ? 'Ouvir demonstração natural'
                                    : 'Escuchar demostración natural'),
                                onPressed: () => _play(locale == 'pt'
                                    ? '## Leitura de demonstração\n\nOlá. Esta é uma demonstração da leitura em voz alta do MedCases. A proposta é ouvir o texto com clareza, sem pressa e sem interrupções desnecessárias.\n\n## Pausas e compreensão\n\nCada frase deve ser lida de forma contínua. A pontuação indica as pausas: uma pausa breve nas vírgulas, e uma pausa mais clara ao terminar cada ideia.\n\n## Finalização\n\nVocê pode interromper a leitura a qualquer momento. Este exemplo não contém orientações clínicas.'
                                    : '## Demostración de lectura\n\nHola. Esta es una demostración de la lectura en voz alta de MedCases. El objetivo es escuchar el texto con claridad, sin prisa y sin interrupciones innecesarias.\n\n## Pausas y comprensión\n\nCada frase debe leerse de forma continua. La puntuación indica las pausas: una pausa breve en las comas, y una pausa más clara al terminar cada idea.\n\n## Finalización\n\nPuede detener la lectura en cualquier momento. Este ejemplo no contiene indicaciones clínicas.'),
                              ),
                              const Divider(),
                              if (scenario == 'E')
                                AiBubble(
                                  text: full,
                                  dark: true,
                                  lang: locale,
                                  studyMode: true,
                                  createdAt: createdAt,
                                  ttsReady: ready,
                                  ttsPlaying: playing,
                                  onTts: () => _play(full),
                                  onCopy: () => _copy(full),
                                )
                              else ...[
                                if (['C', 'D', 'F', 'G'].contains(scenario))
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Text(scenario == 'F'
                                          ? 'Pergunta / Pregunta: Noradrenalina'
                                          : scenario == 'G'
                                              ? (locale == 'pt'
                                                  ? 'Pergunta: Contraindicações da ceftriaxona'
                                                  : 'Pregunta: Contraindicaciones de ceftriaxona')
                                              : 'Pergunta / Pregunta: Paracetamol')),
                                GuardiaClinicalResponseView(
                                    key: ValueKey('$locale-$scenario'),
                                    createdAt: createdAt,
                                    rawText: full,
                                    referenceDocument: source,
                                    userText: switch (scenario) {
                                      'C' || 'D' => 'Paracetamol',
                                      'F' => 'Noradrenalina',
                                      'G' => locale == 'pt'
                                          ? 'Contraindicações da ceftriaxona'
                                          : 'Contraindicaciones de ceftriaxona',
                                      _ => '',
                                    },
                                    preserveReferenceText: true,
                                    dark: true,
                                    languageCode: locale,
                                    ttsReady: ready,
                                    ttsPlaying: playing,
                                    onTts: () => _play(full),
                                    onCopy: () => _copy(full)),
                              ],
                            ]))))));
  }
}
