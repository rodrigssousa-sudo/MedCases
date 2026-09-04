// legal_screen.dart — Documentos legais + Consent Gate
// Todos os textos bilíngues (es / pt-BR)
// Uso: showLegalSheet(context, LegalType.terms, lang)
//      ConsentGate.showIfNeeded(context) — retorna true se já tinha consentimento
//
// Conformidade: Apple App Store Review Guidelines Section 5.1 (Privacy)
//               Google Play Developer Policy — Personal and Sensitive Information
//               LGPD (Lei 13.709/2018) Art. 7º, I e IX
//               IEC 62304 (Medical device software lifecycle) — auditabilidade

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Tipos de documento ─────────────────────────────────────────────────────────
enum LegalType { terms, privacy, disclaimer }

// ── Função pública — abre o bottom sheet ──────────────────────────────────────
Future<void> showLegalSheet(
  BuildContext context,
  LegalType type,
  String lang,
) async {
  final bool isEs = lang == 'es';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LegalSheet(type: type, isEs: isEs),
  );
}

// ── Consent Gate — lógica estática ────────────────────────────────────────────
/// Versão atual dos termos — incrementar a cada alteração material nos documentos legais.
/// Apple Section 5.1: usuário deve re-consentir após mudanças significativas.
const _kTermsVersion = 'v2.1-2026-remote-audio';

class ConsentGate {
  // v2: chave incrementada para forçar re-consentimento após atualização dos termos.
  static const _kConsentKey = 'consent_v3';
  static const _kConsentTimestamp = 'consent_timestamp'; // ISO-8601 UTC
  static const _kConsentVersion =
      'consent_terms_ver'; // versão dos termos aceitos
  static const _kConsentLang = 'consent_lang'; // idioma no momento do aceite

  /// Retorna true se o consentimento já foi dado (não precisa mostrar modal).
  static Future<bool> hasConsented() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_kConsentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Grava o consentimento com metadados de auditoria completos.
  /// Persistência: flag booleana + timestamp ISO-8601 UTC + versão dos termos + idioma.
  /// Conformidade LGPD Art. 7º I: registro comprobatório do consentimento informado.
  static Future<void> saveConsent({required String lang}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().toIso8601String();
      await Future.wait([
        p.setBool(_kConsentKey, true),
        p.setString(_kConsentTimestamp, now),
        p.setString(_kConsentVersion, _kTermsVersion),
        p.setString(_kConsentLang, lang),
      ]);
    } catch (_) {}
  }

  /// Metadados de auditoria do consentimento (suporte / compliance).
  static Future<Map<String, String?>> auditInfo() async {
    try {
      final p = await SharedPreferences.getInstance();
      return {
        'timestamp': p.getString(_kConsentTimestamp),
        'version': p.getString(_kConsentVersion),
        'lang': p.getString(_kConsentLang),
      };
    } catch (_) {
      return {};
    }
  }
}

// ── Bottom Sheet do documento legal ───────────────────────────────────────────
// MEDCASES_LEGAL_ABOUT_SUPPORT_VISUAL_V2_B_R2
class _LegalSheet extends StatelessWidget {
  const _LegalSheet({
    required this.type,
    required this.isEs,
  });

  final LegalType type;
  final bool isEs;

  static const _accent = Color(0xFF0D6B57);

  String get _title {
    switch (type) {
      case LegalType.terms:
        return isEs ? 'Términos de Uso' : 'Termos de Uso';
      case LegalType.privacy:
        return isEs ? 'Política de Privacidad' : 'Política de Privacidade';
      case LegalType.disclaimer:
        return 'Aviso Médico';
    }
  }

  String get _eyebrow {
    switch (type) {
      case LegalType.terms:
        return isEs ? 'INFORMACIÓN LEGAL' : 'INFORMAÇÃO LEGAL';
      case LegalType.privacy:
        return isEs ? 'PRIVACIDAD Y DATOS' : 'PRIVACIDADE E DADOS';
      case LegalType.disclaimer:
        return isEs ? 'USO RESPONSABLE' : 'USO RESPONSÁVEL';
    }
  }

  IconData get _icon {
    switch (type) {
      case LegalType.terms:
        return Icons.description_outlined;
      case LegalType.privacy:
        return Icons.shield_outlined;
      case LegalType.disclaimer:
        return Icons.medical_information_outlined;
    }
  }

  List<_LegalSection> get _sections {
    switch (type) {
      case LegalType.terms:
        return isEs ? _termsEs : _termsPt;
      case LegalType.privacy:
        return isEs ? _privacyEs : _privacyPt;
      case LegalType.disclaimer:
        return isEs ? _disclaimerEs : _disclaimerPt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final surfaceSoft =
        dark ? const Color(0xFF20242B) : const Color(0xFFF7F9FB);
    final text = dark ? const Color(0xFFF7F8FA) : const Color(0xFF18202A);
    final muted = dark ? const Color(0xFFAAB3BF) : const Color(0xFF66717E);
    final line = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: background,
            child: Column(
              children: [
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surface.withValues(
                          alpha: dark ? 0.88 : 0.92,
                        ),
                        border: Border(
                          bottom: BorderSide(color: line, width: 0.7),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 9),
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: muted.withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 11),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(
                                      alpha: dark ? 0.18 : 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_icon, size: 18, color: _accent),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _eyebrow,
                                        style: const TextStyle(
                                          color: _accent,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _title,
                                        style: TextStyle(
                                          color: text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: IconButton(
                                    tooltip: isEs ? 'Cerrar' : 'Fechar',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: muted,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 32),
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      if (section.isTitle) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 2 : 18,
                            bottom: 7,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  section.text,
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: line, width: 0.65),
                        ),
                        child: Text(
                          section.text,
                          style: TextStyle(
                            color: muted,
                            fontSize: 12.8,
                            height: 1.55,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 9, 16, 11),
                  decoration: BoxDecoration(
                    color: surfaceSoft,
                    border: Border(
                      top: BorderSide(color: line, width: 0.7),
                    ),
                  ),
                  child: Text(
                    isEs
                        ? 'MedCases Pro · Documento informativo dentro de la aplicación'
                        : 'MedCases Pro · Documento informativo dentro do aplicativo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Modelo de seção ────────────────────────────────────────────────────────────
class _LegalSection {
  final String text;
  final bool isTitle;
  const _LegalSection(this.text, {this.isTitle = false});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERMOS DE USO — Português
// ═══════════════════════════════════════════════════════════════════════════════
const _termsPt = [
  _LegalSection('1. Aceitação dos Termos', isTitle: true),
  _LegalSection(
    'Ao acessar o MedCases Pro, você concorda com estes Termos de Uso. '
    'Se não concordar com qualquer disposição, não utilize o aplicativo.',
  ),
  _LegalSection('2. Natureza da Plataforma', isTitle: true),
  _LegalSection(
    'O MedCases Pro é uma plataforma educacional e de suporte à decisão clínica '
    'destinada exclusivamente a profissionais e estudantes da área de saúde. '
    'Não constitui dispositivo médico, nem substitui julgamento clínico individual.',
  ),
  _LegalSection('3. Uso Permitido', isTitle: true),
  _LegalSection(
    'Você pode utilizar o conteúdo para fins educacionais, consulta de protocolos '
    'e apoio ao raciocínio clínico. É vedada a distribuição, reprodução ou '
    'comercialização do conteúdo sem autorização expressa.',
  ),
  _LegalSection('4. Responsabilidade Clínica', isTitle: true),
  _LegalSection(
    'As informações disponibilizadas são baseadas em diretrizes e evidências '
    'científicas atualizadas, porém não substituem a avaliação médica individualizada. '
    'O profissional de saúde é integralmente responsável pelas decisões clínicas tomadas.',
  ),
  _LegalSection('5. Conta de Usuário', isTitle: true),
  _LegalSection(
    'Você é responsável pela confidencialidade de suas credenciais de acesso. '
    'Contas são pessoais e intransferíveis. Atividades suspeitas devem ser '
    'reportadas imediatamente.',
  ),
  _LegalSection('6. Modificações', isTitle: true),
  _LegalSection(
    'Reservamo-nos o direito de modificar estes Termos a qualquer momento. '
    'O uso contínuo da plataforma após alterações implica aceitação dos novos termos.',
  ),
  _LegalSection('7. Lei Aplicável', isTitle: true),
  _LegalSection(
    'Estes Termos são regidos pela legislação brasileira. Eventuais disputas '
    'serão resolvidas no foro da comarca competente.',
  ),
  _LegalSection('Última atualização: Junho de 2026 | Versão v2.0-2026',
      isTitle: false),
];

// ═══════════════════════════════════════════════════════════════════════════════
// TERMOS DE USO — Español
// ═══════════════════════════════════════════════════════════════════════════════
const _termsEs = [
  _LegalSection('1. Aceptación de los Términos', isTitle: true),
  _LegalSection(
    'Al acceder a MedCases Pro, usted acepta estos Términos de Uso. '
    'Si no está de acuerdo con alguna disposición, no utilice la aplicación.',
  ),
  _LegalSection('2. Naturaleza de la Plataforma', isTitle: true),
  _LegalSection(
    'MedCases Pro es una plataforma educativa y de apoyo a la decisión clínica, '
    'destinada exclusivamente a profesionales y estudiantes del área de salud. '
    'No constituye un dispositivo médico ni reemplaza el juicio clínico individual.',
  ),
  _LegalSection('3. Uso Permitido', isTitle: true),
  _LegalSection(
    'Puede utilizar el contenido con fines educativos, consulta de protocolos '
    'y apoyo al razonamiento clínico. Se prohíbe la distribución, reproducción o '
    'comercialización del contenido sin autorización expresa.',
  ),
  _LegalSection('4. Responsabilidad Clínica', isTitle: true),
  _LegalSection(
    'La información disponible se basa en directrices y evidencias científicas '
    'actualizadas, pero no reemplaza la evaluación médica individualizada. '
    'El profesional de salud es completamente responsable de las decisiones clínicas tomadas.',
  ),
  _LegalSection('5. Cuenta de Usuario', isTitle: true),
  _LegalSection(
    'Usted es responsable de la confidencialidad de sus credenciales de acceso. '
    'Las cuentas son personales e intransferibles. Las actividades sospechosas deben '
    'reportarse de inmediato.',
  ),
  _LegalSection('6. Modificaciones', isTitle: true),
  _LegalSection(
    'Nos reservamos el derecho de modificar estos Términos en cualquier momento. '
    'El uso continuo de la plataforma después de los cambios implica la aceptación '
    'de los nuevos términos.',
  ),
  _LegalSection('7. Ley Aplicable', isTitle: true),
  _LegalSection(
    'Estos Términos se rigen por la legislación brasileña. Las disputas se '
    'resolverán en el foro jurisdiccional competente.',
  ),
  _LegalSection('Última actualización: Junio de 2026 | Versión v2.0-2026',
      isTitle: false),
];

// ═══════════════════════════════════════════════════════════════════════════════
// POLÍTICA DE PRIVACIDADE — Português
// ═══════════════════════════════════════════════════════════════════════════════
const _privacyPt = [
  _LegalSection('1. Dados Coletados', isTitle: true),
  _LegalSection(
    'Coletamos dados da conta e do uso do serviço, como nome, e-mail profissional, '
    'profissão, instituição de vínculo, preferências de idioma e tema e histórico '
    'de interações com a IA. O MedCases Pro não exige identificadores de pacientes '
    'como dados cadastrais da conta. Entretanto, campos livres, documentos e '
    'gravações clínicas inseridos pelo profissional podem conter informações de saúde.',
  ),
  _LegalSection('2. Finalidade do Tratamento', isTitle: true),
  _LegalSection(
    'Os dados são utilizados para autenticação e gestão de conta, personalização '
    'da experiência, execução de recursos solicitados pelo usuário, suporte à '
    'transcrição e organização de conteúdo clínico, segurança e cumprimento de '
    'obrigações legais.',
  ),
  _LegalSection('3. Base Legal (LGPD)', isTitle: true),
  _LegalSection(
    'O tratamento ocorre com base no consentimento do titular quando aplicável '
    '(Art. 7º, I, LGPD), no legítimo interesse para prestação e segurança do '
    'serviço (Art. 7º, IX, LGPD) e nas demais bases legais aplicáveis.',
  ),
  _LegalSection('4. Compartilhamento', isTitle: true),
  _LegalSection(
    'Não vendemos dados pessoais nem os compartilhamos para publicidade. '
    'Podemos utilizar provedores de infraestrutura, autenticação e processamento '
    'sob obrigações de proteção de dados. Quando a transcrição remota de áudio '
    'for disponibilizada e o profissional der consentimento específico, segmentos '
    'selecionados poderão ser transmitidos de forma criptografada em trânsito pelo '
    'backend do MedCases Pro a um provedor externo de IA/transcrição exclusivamente '
    'para atender à solicitação de transcrição.',
  ),
  _LegalSection('5. Transcrição remota de áudio', isTitle: true),
  _LegalSection(
    'A transcrição remota é opcional e separada do ditado padrão. A documentação '
    'pública atual do provedor informa que o endpoint /v1/audio/transcriptions não '
    'mantém conteúdo do cliente em retenção de monitoramento de abuso nem em estado '
    'de aplicação. Essa verificação é específica do endpoint e não significa que a '
    'organização do MedCases Pro esteja provisionada com Zero Data Retention. '
    'O backend do MedCases Pro continua projetado para usar somente uma cópia '
    'temporária durante a requisição e eliminá-la após o processamento.',
  ),
  _LegalSection('6. Consentimento e Revogação', isTitle: true),
  _LegalSection(
    'O consentimento para transcrição remota de áudio será específico, opcional, '
    'registrado separadamente e desativado por padrão. O profissional poderá '
    'revogar o consentimento específico a qualquer momento; a revogação impede '
    'novas transmissões remotas de áudio. O consentimento geral para uso do '
    'aplicativo não autoriza automaticamente a transmissão remota de áudio.',
  ),
  _LegalSection('7. Retenção e Eliminação', isTitle: true),
  _LegalSection(
    'Dados da conta são retidos enquanto necessário para a prestação do serviço '
    'e conforme obrigações legais. O áudio clínico temporário no dispositivo segue '
    'um ciclo próprio de revisão: permanece sob controle do app até a revisão do '
    'usuário e, após a confirmação, é excluído por padrão, preservando apenas a '
    'transcrição ou os materiais derivados escolhidos. Cópias temporárias no '
    'backend do MedCases Pro não devem ser persistidas de forma durável.',
  ),
  _LegalSection('8. Segurança', isTitle: true),
  _LegalSection(
    'Utilizamos criptografia em trânsito, proteção de dados sensíveis em repouso, '
    'controle de acesso e mecanismos de redução de persistência desnecessária. '
    'Credenciais padrão de provedores de IA não são incorporadas ao aplicativo.',
  ),
  _LegalSection('9. Seus Direitos e Contato', isTitle: true),
  _LegalSection(
    'Você pode acessar, corrigir ou solicitar exclusão de dados aplicáveis, '
    'revogar consentimentos e solicitar informações sobre o tratamento. '
    'Encarregado de Proteção de Dados (DPO): contato disponível pelo suporte do '
    'aplicativo. ANPD: www.gov.br/anpd',
  ),
  _LegalSection(
    'Última atualização: Agosto de 2026 | Versão v2.1-2026-remote-audio',
    isTitle: false,
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// POLÍTICA DE PRIVACIDADE — Español
// ═══════════════════════════════════════════════════════════════════════════════
const _privacyEs = [
  _LegalSection('1. Datos Recopilados', isTitle: true),
  _LegalSection(
    'Recopilamos datos de la cuenta y del uso del servicio, como nombre, correo '
    'profesional, profesión, institución, preferencias de idioma y tema e historial '
    'de interacciones con la IA. MedCases Pro no exige identificadores de pacientes '
    'como datos de registro de la cuenta. Sin embargo, los campos libres, documentos '
    'y grabaciones clínicas incorporados por el profesional pueden contener '
    'información de salud.',
  ),
  _LegalSection('2. Finalidad del Tratamiento', isTitle: true),
  _LegalSection(
    'Los datos se utilizan para autenticación y gestión de cuenta, personalización '
    'de la experiencia, ejecución de funciones solicitadas por el usuario, soporte '
    'a la transcripción y organización de contenido clínico, seguridad y '
    'cumplimiento de obligaciones legales.',
  ),
  _LegalSection('3. Base Legal', isTitle: true),
  _LegalSection(
    'El tratamiento se realiza con base en el consentimiento cuando corresponda, '
    'el interés legítimo para la prestación y seguridad del servicio y las demás '
    'bases legales aplicables.',
  ),
  _LegalSection('4. Compartición', isTitle: true),
  _LegalSection(
    'No vendemos datos personales ni los compartimos para publicidad. Podemos '
    'utilizar proveedores de infraestructura, autenticación y procesamiento bajo '
    'obligaciones de protección de datos. Cuando la transcripción remota de audio '
    'esté disponible y el profesional otorgue un consentimiento específico, los '
    'segmentos seleccionados podrán transmitirse cifrados en tránsito a través del '
    'backend de MedCases Pro a un proveedor externo de IA/transcripción '
    'exclusivamente para atender la solicitud de transcripción.',
  ),
  _LegalSection('5. Transcripción remota de audio', isTitle: true),
  _LegalSection(
    'La transcripción remota es opcional y separada del dictado estándar. La '
    'documentación pública actual del proveedor indica que el endpoint '
    '/v1/audio/transcriptions no conserva contenido del cliente en retención de '
    'monitoreo de abuso ni en estado de aplicación. Esta verificación es específica '
    'del endpoint y no significa que la organización de MedCases Pro tenga '
    'provisionado Zero Data Retention. El backend de MedCases Pro continúa diseñado '
    'para utilizar únicamente una copia temporal durante la solicitud y eliminarla '
    'después del procesamiento.',
  ),
  _LegalSection('6. Consentimiento y Revocación', isTitle: true),
  _LegalSection(
    'El consentimiento para la transcripción remota de audio será específico, '
    'opcional, registrado por separado y desactivado por defecto. El profesional '
    'podrá revocar el consentimiento específico en cualquier momento; la revocación '
    'impide nuevas transmisiones remotas de audio. El consentimiento general para '
    'usar la aplicación no autoriza automáticamente la transmisión remota de audio.',
  ),
  _LegalSection('7. Retención y Eliminación', isTitle: true),
  _LegalSection(
    'Los datos de la cuenta se conservan mientras sea necesario para prestar el '
    'servicio y conforme a las obligaciones legales. El audio clínico temporal en '
    'el dispositivo sigue un ciclo de revisión: permanece bajo control de la app '
    'hasta la revisión del usuario y, tras su confirmación, se elimina por defecto, '
    'conservando únicamente la transcripción o los materiales derivados elegidos. '
    'Las copias temporales en el backend de MedCases Pro no deben persistirse de '
    'forma duradera.',
  ),
  _LegalSection('8. Seguridad', isTitle: true),
  _LegalSection(
    'Utilizamos cifrado en tránsito, protección de datos sensibles en reposo, '
    'control de acceso y mecanismos para reducir la persistencia innecesaria. '
    'Las credenciales estándar de proveedores de IA no se incorporan a la app.',
  ),
  _LegalSection('9. Sus Derechos y Contacto', isTitle: true),
  _LegalSection(
    'Puede acceder, corregir o solicitar la eliminación de los datos aplicables, '
    'revocar consentimientos y solicitar información sobre el tratamiento. '
    'Responsable de Protección de Datos: disponible a través del soporte de la '
    'aplicación. ANPD: www.gov.br/anpd',
  ),
  _LegalSection(
    'Última actualización: Agosto de 2026 | Versión v2.1-2026-remote-audio',
    isTitle: false,
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// AVISO MÉDICO — Português
// ═══════════════════════════════════════════════════════════════════════════════
const _disclaimerPt = [
  _LegalSection('Natureza Educacional', isTitle: true),
  _LegalSection(
    'O MedCases Pro é uma plataforma educacional e de suporte à decisão clínica. '
    'Todo o conteúdo — incluindo casos clínicos, protocolos, calculadoras, '
    'informações sobre fármacos e respostas da IA — tem fins exclusivamente educacionais.',
  ),
  _LegalSection('Não é um Dispositivo Médico', isTitle: true),
  _LegalSection(
    'Esta plataforma NÃO é um dispositivo médico regulamentado e NÃO foi aprovada '
    'por agências regulatórias (ANVISA, FDA ou equivalentes) para uso diagnóstico '
    'ou terapêutico. Não deve ser utilizada como substituto de avaliação clínica profissional.',
  ),
  _LegalSection('Responsabilidade do Profissional', isTitle: true),
  _LegalSection(
    'O profissional de saúde é o único responsável pelas decisões clínicas tomadas '
    'com base em qualquer informação consultada nesta plataforma. '
    'Cada paciente apresenta características individuais que requerem avaliação personalizada.',
  ),
  _LegalSection('Limitações da IA', isTitle: true),
  _LegalSection(
    'As respostas geradas pela inteligência artificial podem conter imprecisões, '
    'omissões ou erros. Sempre verifique as informações em fontes primárias '
    'e diretrizes institucionais atualizadas antes de qualquer aplicação clínica.',
  ),
  _LegalSection('Atualização de Conteúdo', isTitle: true),
  _LegalSection(
    'Embora nos esforcemos para manter o conteúdo atualizado com as evidências '
    'científicas mais recentes, a medicina é dinâmica. Protocolos e diretrizes '
    'podem ser atualizados. Consulte sempre as fontes originais.',
  ),
  _LegalSection('Uso em Emergências', isTitle: true),
  _LegalSection(
    'Em situações de emergência, siga os protocolos institucionais estabelecidos '
    'e os guidelines oficiais. Esta plataforma NÃO substitui treinamentos de '
    'emergência (ACLS, BLS, PALS) nem protocolos hospitalares vigentes.',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// AVISO MÉDICO — Español
// ═══════════════════════════════════════════════════════════════════════════════
const _disclaimerEs = [
  _LegalSection('Naturaleza Educativa', isTitle: true),
  _LegalSection(
    'MedCases Pro es una plataforma educativa y de apoyo a la decisión clínica. '
    'Todo el contenido —incluidos casos clínicos, protocolos, calculadoras, '
    'información sobre fármacos y respuestas de la IA— tiene fines exclusivamente educativos.',
  ),
  _LegalSection('No es un Dispositivo Médico', isTitle: true),
  _LegalSection(
    'Esta plataforma NO es un dispositivo médico regulado y NO ha sido aprobada '
    'por agencias regulatorias (ANVISA, FDA o equivalentes) para uso diagnóstico '
    'o terapéutico. No debe utilizarse como sustituto de la evaluación clínica profesional.',
  ),
  _LegalSection('Responsabilidad del Profesional', isTitle: true),
  _LegalSection(
    'El profesional de salud es el único responsable de las decisiones clínicas '
    'tomadas con base en cualquier información consultada en esta plataforma. '
    'Cada paciente presenta características individuales que requieren evaluación personalizada.',
  ),
  _LegalSection('Limitaciones de la IA', isTitle: true),
  _LegalSection(
    'Las respuestas generadas por la inteligencia artificial pueden contener '
    'inexactitudes, omisiones o errores. Siempre verifique la información en '
    'fuentes primarias y directrices institucionales actualizadas antes de cualquier aplicación clínica.',
  ),
  _LegalSection('Actualización de Contenido', isTitle: true),
  _LegalSection(
    'Aunque nos esforzamos por mantener el contenido actualizado con las evidencias '
    'científicas más recientes, la medicina es dinámica. Protocolos y directrices '
    'pueden cambiar. Consulte siempre las fuentes originales.',
  ),
  _LegalSection('Uso en Emergencias', isTitle: true),
  _LegalSection(
    'En situaciones de emergencia, siga los protocolos institucionales establecidos '
    'y las guías oficiales. Esta plataforma NO reemplaza los entrenamientos de '
    'emergencia (ACLS, BLS, PALS) ni los protocolos hospitalarios vigentes.',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Consent Modal — 4 checkboxes obrigatórios
// ═══════════════════════════════════════════════════════════════════════════════
class ConsentModal extends StatefulWidget {
  final String lang;
  final VoidCallback onAccepted;
  const ConsentModal({super.key, required this.lang, required this.onAccepted});

  @override
  State<ConsentModal> createState() => _ConsentModalState();
}

class _ConsentModalState extends State<ConsentModal> {
  bool _c1 = false; // Termos de Uso
  bool _c2 = false; // Política de Privacidade
  bool _c3 = false; // LGPD
  bool _c4 = false; // Aviso Médico

  bool get _isEs => widget.lang == 'es';
  bool get _allChecked => _c1 && _c2 && _c3 && _c4;

  // MEDCASES_CONSENT_FLAT_DIRECT_SURFACE_V1_B_R0_R1
  // MEDCASES_AUTH_CONSENT_MODAL_UI_V2_B_R1
  static const _kAccent = Color(0xFF0D6B57);
  static const _kLink = Color(0xFF0D6B57);
  static const _kDark = Color(0xFF1A1D23);
  static const _kDivider = Color(0xFF374151);
  static const _kTextSecondary = Color(0xFF94A3B8);
  static const _kTextMuted = Color(0xFF7C8797);

  String get _titleText => _isEs ? 'Antes de continuar' : 'Antes de continuar';

  String get _subtitleText => _isEs
      ? 'Por favor, lea y acepte los términos para acceder a MedCases Pro.'
      : 'Por favor, leia e aceite os termos para acessar o MedCases Pro.';

  String get _btnText => _isEs ? 'Continuar' : 'Continuar';

  String get _btnDisabledText =>
      _isEs ? 'Marque todos los elementos' : 'Marque todos os itens';

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    Widget divider() => const Divider(
          height: 1,
          thickness: 0.7,
          color: _kDivider,
        );

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.90),
      decoration: const BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Column(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 30,
                  color: _kLink,
                ),
                const SizedBox(height: 14),
                Text(
                  _titleText,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 7),
                Text(
                  _subtitleText,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _kTextSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  _ConsentCheck(
                    value: _c1,
                    isEs: _isEs,
                    labelPt: 'Li e aceito os ',
                    labelEs: 'He leído y acepto los ',
                    linkTextPt: 'Termos de Uso',
                    linkTextEs: 'Términos de Uso',
                    onChanged: (v) => setState(() => _c1 = v),
                    onLinkTap: () =>
                        showLegalSheet(context, LegalType.terms, widget.lang),
                  ),
                  divider(),
                  _ConsentCheck(
                    value: _c2,
                    isEs: _isEs,
                    labelPt: 'Li e compreendi a ',
                    labelEs: 'He leído y entendido la ',
                    linkTextPt: 'Política de Privacidade',
                    linkTextEs: 'Política de Privacidad',
                    onChanged: (v) => setState(() => _c2 = v),
                    onLinkTap: () =>
                        showLegalSheet(context, LegalType.privacy, widget.lang),
                  ),
                  divider(),
                  _ConsentCheck(
                    value: _c3,
                    isEs: _isEs,
                    labelPt:
                        'Consinto com o tratamento dos meus dados conforme a LGPD',
                    labelEs:
                        'Consiento el tratamiento de mis datos conforme a la ley de protección de datos',
                    linkTextPt: '',
                    linkTextEs: '',
                    onChanged: (v) => setState(() => _c3 = v),
                    onLinkTap: null,
                  ),
                  divider(),
                  _ConsentCheck(
                    value: _c4,
                    isEs: _isEs,
                    labelPt:
                        'Declaro que sou profissional de saúde habilitado e compreendo que doses, protocolos e cálculos são ferramentas educativas de apoio. A verificação e a decisão clínica final são de minha exclusiva responsabilidade — ',
                    labelEs:
                        'Declaro que soy profesional de la salud habilitado y comprendo que las dosis, protocolos y cálculos son herramientas educativas de apoyo. La verificación y la decisión clínica final son de mi exclusiva responsabilidad — ',
                    linkTextPt: 'ver Aviso Médico',
                    linkTextEs: 'ver Aviso Médico',
                    onChanged: (v) => setState(() => _c4 = v),
                    onLinkTap: () => showLegalSheet(
                        context, LegalType.disclaimer, widget.lang),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              18,
              22,
              MediaQuery.of(context).viewInsets.bottom + 28,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _allChecked
                    ? () async {
                        await ConsentGate.saveConsent(lang: widget.lang);
                        widget.onAccepted();
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF252930),
                  disabledForegroundColor: _kTextMuted,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _allChecked ? _btnText : _btnDisabledText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Checkbox de consentimento individual ──────────────────────────────────────
class _ConsentCheck extends StatelessWidget {
  final bool value;
  final bool isEs;
  final String labelPt;
  final String labelEs;
  final String linkTextPt;
  final String linkTextEs;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onLinkTap;

  const _ConsentCheck({
    required this.value,
    required this.isEs,
    required this.labelPt,
    required this.labelEs,
    required this.linkTextPt,
    required this.linkTextEs,
    required this.onChanged,
    required this.onLinkTap,
  });

  static const _kAccent = Color(0xFF0D6B57);
  static const _kLink = Color(0xFF0D6B57);
  static const _kTextPrimary = Color(0xFFF1F5F9);
  static const _kCheckboxIdle = Color(0xFF7C8797);

  @override
  Widget build(BuildContext context) {
    final label = isEs ? labelEs : labelPt;
    final linkText = isEs ? linkTextEs : linkTextPt;
    final hasLink = linkText.isNotEmpty && onLinkTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: value ? _kAccent : Colors.transparent,
                border: Border.all(
                  color: value ? _kAccent : _kCheckboxIdle,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kTextPrimary,
                    height: 1.48,
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    TextSpan(text: label),
                    if (hasLink)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: onLinkTap,
                          child: Text(
                            linkText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _kLink,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: _kLink,
                              decorationThickness: 1,
                              height: 1.48,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
