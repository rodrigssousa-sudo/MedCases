import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dados das sugestões rápidas
// ─────────────────────────────────────────────────────────────────────────────
class _Suggestion {
  final String labelPt;
  final String labelEs;
  final String promptPt;
  final String promptEs;
  const _Suggestion(this.labelPt, this.labelEs, this.promptPt, this.promptEs);
}

const _suggestions = [
  _Suggestion(
      'IAM / dor torácica',
      'IAM / dolor torácico',
      'Paciente com dor torácica intensa, diaforese e irradiação para braço esquerdo. Suspeita de IAM.',
      'Paciente con dolor torácico intenso, diaforesis e irradiación al brazo izquierdo. Sospecha de IAM.'),
  _Suggestion(
      'Choque + hipotensão',
      'Choque + hipotensión',
      'Paciente em choque com hipotensão, taquicardia e pele fria.',
      'Paciente en choque con hipotensión, taquicardia y piel fría.'),
  _Suggestion(
      'Anafilaxia',
      'Anafilaxia',
      'Reação anafilática aguda após contraste. PA 80/50, broncoespasmo.',
      'Reacción anafiláctica aguda. PA 80/50, broncoespasmo.'),
  _Suggestion(
      'PCR / parada',
      'PCR / parada',
      'Parada cardiorrespiratória. Sem pulso. Monitor: fibrilação ventricular.',
      'Parada cardiorrespiratoria. Sin pulso. FV no monitor.'),
  _Suggestion(
      'TPSV / taquicardia',
      'TPSV / taquicardia',
      'Taquicardia paroxística supraventricular, QRS estreito, FC 180.',
      'Taquicardia paroxística supraventricular, QRS estrecho, FC 180.'),
  _Suggestion(
      'FA com alta resposta',
      'FA con alta respuesta',
      'Fibrilação atrial com resposta ventricular rápida, FC 145 irregular.',
      'Fibrilación auricular con respuesta ventricular rápida, FC 145 irregular.'),
  _Suggestion(
      'Crise hipertensiva',
      'Crisis hipertensiva',
      'PA 210/120 com cefaleia intensa e confusão mental.',
      'PA 210/120 con cefalea intensa y confusión mental.'),
  _Suggestion(
      'Sepse / febre',
      'Sepsis / fiebre',
      'Febre alta, hipotensão, taquicardia e suspeita de sepse.',
      'Fiebre alta, hipotensión, taquicardia y sospecha de sepsis.'),
  _Suggestion(
      'TEP / embolia',
      'TEP / embolia',
      'Embolia pulmonar com dispneia súbita, PA 85/50, SatO2 85%.',
      'Embolia pulmonar con disnea súbita, PA 85/50, SatO2 85%.'),
  _Suggestion(
      'DPOC exacerbação',
      'EPOC exacerbación',
      'DPOC com piora de dispneia, PaCO2 68, pH 7,28.',
      'EPOC con empeoramiento de disnea, PaCO2 68, pH 7,28.'),
  _Suggestion(
      'Asma grave',
      'Asma grave',
      'Crise de asma grave, silêncio auscultório, SpO2 88%.',
      'Crisis de asma grave, silencio auscultatorio, SpO2 88%.'),
  _Suggestion(
      'AVC isquêmico',
      'ACV isquémico',
      'AVC isquêmico agudo, hemiplegia direita, NIHSS 14, 1h45 de evolução.',
      'ACV isquémico agudo, hemiplejía derecha, NIHSS 14, evolución 1h45.'),
  _Suggestion(
      'Convulsão / status',
      'Convulsión / status',
      'Convulsão há 8 min sem pausa. Estado de mal epiléptico.',
      'Convulsión de 8 min sin pausa. Estado epiléptico.'),
  _Suggestion(
      'Meningite',
      'Meningitis',
      'Febre, cefaleia em trovoada, rigidez de nuca, petéquias.',
      'Fiebre, cefalea en trueno, rigidez de nuca, petequias.'),
  _Suggestion(
      'Cetoacidose / CAD',
      'Cetoacidosis / CAD',
      'Cetoacidose diabética. Glicemia 480, pH 7,18, K+ 3,2.',
      'Cetoacidosis diabética. Glucemia 480, pH 7,18, K+ 3,2.'),
  _Suggestion(
      'Hipoglicemia grave',
      'Hipoglucemia grave',
      'Hipoglicemia grave, Glasgow 8, glicemia 28 mg/dL.',
      'Hipoglucemia grave, Glasgow 8, glucemia 28 mg/dL.'),
  _Suggestion(
      'Hemorragia digestiva',
      'Hemorragia digestiva',
      'Hematêmese, Hb 7,2, instabilidade hemodinâmica.',
      'Hematemesis, Hb 7,2, inestabilidad hemodinámica.'),
  _Suggestion(
      'Insuf. cardíaca',
      'Insuf. cardíaca',
      'IC descompensada, ortopneia, SatO2 91%, crepitações bibasais.',
      'IC descompensada, ortopnea, SatO2 91%, crepitantes bibasales.'),
  _Suggestion(
      'K⁺ alto / hipercalemia',
      'K⁺ alto / hipercalemia',
      'Hipercalemia grave K+ 7,1 com ondas T apiculadas no ECG.',
      'Hipercalemia grave K+ 7,1 con ondas T picudas en ECG.'),
  _Suggestion(
      'Delirium / confusão',
      'Delirium / confusión',
      'Confusão mental aguda, agitação, rebaixamento. Idoso de 78 anos.',
      'Confusión mental aguda, agitación. Anciano de 78 años.'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Carrossel horizontal de sugestões
// ─────────────────────────────────────────────────────────────────────────────
class SuggestionCarousel extends StatelessWidget {
  final String lang;
  final bool dark;
  final void Function(String) onTap;
  const SuggestionCarousel({
    super.key,
    required this.lang,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final bg = dark ? const Color(0xFF1A1D23) : Colors.white;
    final border = dark ? const Color(0xFF2D3340) : const Color(0xFFE5E0D8);
    final chipBg = dark ? const Color(0xFF252930) : const Color(0xFFF5F3EE);
    final chipBorder = dark ? const Color(0xFF374151) : const Color(0xFFDAD5CC);
    final textCol = dark ? Colors.white70 : const Color(0xFF2D3340);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: SizedBox(
        height: 34,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _suggestions.length,
          itemBuilder: (context, i) {
            final s = _suggestions[i];
            final label = isEs ? s.labelEs : s.labelPt;
            final prompt = isEs ? s.promptEs : s.promptPt;
            return GestureDetector(
              onTap: () => onTap(prompt),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipBorder),
                ),
                child: Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textCol,
                    )),
              ),
            );
          },
        ),
      ),
    );
  }
}
