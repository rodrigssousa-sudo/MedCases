// legal_screen.dart — Documentos legais + Consent Gate
// Todos os textos bilíngues (es / pt-BR)
// Uso: showLegalSheet(context, LegalType.terms, lang)
//      ConsentGate.showIfNeeded(context) — retorna true se já tinha consentimento

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
class ConsentGate {
  static const _kConsentKey = 'consent_v1';

  /// Retorna true se o consentimento já foi dado (não precisa mostrar modal).
  static Future<bool> hasConsented() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_kConsentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Grava o consentimento.
  static Future<void> saveConsent() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kConsentKey, true);
    } catch (_) {}
  }
}

// ── Bottom Sheet do documento legal ───────────────────────────────────────────
class _LegalSheet extends StatelessWidget {
  final LegalType type;
  final bool isEs;
  const _LegalSheet({required this.type, required this.isEs});

  String get _title {
    switch (type) {
      case LegalType.terms:
        return isEs ? 'Términos de Uso' : 'Termos de Uso';
      case LegalType.privacy:
        return isEs ? 'Política de Privacidad' : 'Política de Privacidade';
      case LegalType.disclaimer:
        return isEs ? 'Aviso Médico' : 'Aviso Médico';
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
    final bg = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final handle = dark ? const Color(0xFF48484A) : const Color(0xFFDDDDDD);
    final titleCol = dark ? const Color(0xFFE8E8EA) : const Color(0xFF07110d);
    final textCol = dark ? const Color(0xFFB0B0B8) : const Color(0xFF333344);
    final headCol = dark ? const Color(0xFFD4A96A) : const Color(0xFF075f45);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Título
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: titleCol,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textCol, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: handle),
            // Conteúdo scrollável
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: _sections.length,
                itemBuilder: (_, i) {
                  final s = _sections[i];
                  if (s.isTitle) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 6),
                      child: Text(
                        s.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: headCol,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      s.text,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textCol,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
  _LegalSection('Última atualização: Janeiro de 2025', isTitle: false),
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
  _LegalSection('Última actualización: Enero de 2025', isTitle: false),
];

// ═══════════════════════════════════════════════════════════════════════════════
// POLÍTICA DE PRIVACIDADE — Português
// ═══════════════════════════════════════════════════════════════════════════════
const _privacyPt = [
  _LegalSection('1. Dados Coletados', isTitle: true),
  _LegalSection(
    'Coletamos: nome, e-mail profissional, profissão, instituição de vínculo, '
    'preferências de idioma e tema, histórico de consultas e interações com a IA. '
    'Não coletamos dados de pacientes, CPF, dados bancários ou informações sensíveis adicionais.',
  ),
  _LegalSection('2. Finalidade do Tratamento', isTitle: true),
  _LegalSection(
    'Os dados são utilizados para: autenticação e gestão de conta, '
    'personalização da experiência educacional, melhoria dos modelos de IA, '
    'comunicações operacionais (aprovação de conta, atualizações de segurança) '
    'e cumprimento de obrigações legais.',
  ),
  _LegalSection('3. Base Legal (LGPD)', isTitle: true),
  _LegalSection(
    'O tratamento de dados ocorre com base no consentimento do titular (Art. 7º, I, LGPD) '
    'e no legítimo interesse para prestação do serviço educacional (Art. 7º, IX, LGPD).',
  ),
  _LegalSection('4. Compartilhamento', isTitle: true),
  _LegalSection(
    'Não vendemos nem compartilhamos seus dados com terceiros para fins comerciais. '
    'Podemos compartilhar com provedores de infraestrutura (Firebase/Google) '
    'sob contratos de proteção de dados compatíveis com a LGPD.',
  ),
  _LegalSection('5. Seus Direitos (LGPD)', isTitle: true),
  _LegalSection(
    'Você tem direito a: confirmar a existência de tratamento, acessar seus dados, '
    'corrigir dados incompletos ou inexatos, solicitar anonimização ou exclusão, '
    'revogar o consentimento e solicitar portabilidade. '
    'Para exercer esses direitos, entre em contato conosco.',
  ),
  _LegalSection('6. Retenção e Eliminação', isTitle: true),
  _LegalSection(
    'Dados são retidos enquanto a conta estiver ativa. Após solicitação de '
    'exclusão de conta, os dados pessoais são removidos em até 30 dias, '
    'exceto os que devem ser mantidos por obrigação legal.',
  ),
  _LegalSection('7. Segurança', isTitle: true),
  _LegalSection(
    'Utilizamos criptografia em trânsito (TLS) e em repouso, controle de acesso '
    'baseado em perfis e monitoramento de atividades para proteger seus dados.',
  ),
  _LegalSection('8. Contato', isTitle: true),
  _LegalSection(
    'Encarregado de Proteção de Dados (DPO): contato disponível pelo suporte do aplicativo. '
    'Autoridade Nacional de Proteção de Dados (ANPD): www.gov.br/anpd',
  ),
  _LegalSection('Última atualização: Janeiro de 2025', isTitle: false),
];

// ═══════════════════════════════════════════════════════════════════════════════
// POLÍTICA DE PRIVACIDADE — Español
// ═══════════════════════════════════════════════════════════════════════════════
const _privacyEs = [
  _LegalSection('1. Datos Recopilados', isTitle: true),
  _LegalSection(
    'Recopilamos: nombre, correo profesional, profesión, institución de pertenencia, '
    'preferencias de idioma y tema, historial de consultas e interacciones con la IA. '
    'No recopilamos datos de pacientes, documentos de identidad, datos bancarios '
    'ni información sensible adicional.',
  ),
  _LegalSection('2. Finalidad del Tratamiento', isTitle: true),
  _LegalSection(
    'Los datos se utilizan para: autenticación y gestión de cuenta, '
    'personalización de la experiencia educativa, mejora de los modelos de IA, '
    'comunicaciones operacionales (aprobación de cuenta, actualizaciones de seguridad) '
    'y cumplimiento de obligaciones legales.',
  ),
  _LegalSection('3. Base Legal', isTitle: true),
  _LegalSection(
    'El tratamiento de datos se realiza con base en el consentimiento del titular '
    'y en el interés legítimo para la prestación del servicio educativo.',
  ),
  _LegalSection('4. Compartición', isTitle: true),
  _LegalSection(
    'No vendemos ni compartimos sus datos con terceros con fines comerciales. '
    'Podemos compartir con proveedores de infraestructura (Firebase/Google) '
    'bajo contratos de protección de datos.',
  ),
  _LegalSection('5. Sus Derechos', isTitle: true),
  _LegalSection(
    'Tiene derecho a: confirmar la existencia de tratamiento, acceder a sus datos, '
    'corregir datos incompletos o inexactos, solicitar anonimización o eliminación, '
    'revocar el consentimiento y solicitar portabilidad.',
  ),
  _LegalSection('6. Retención y Eliminación', isTitle: true),
  _LegalSection(
    'Los datos se retienen mientras la cuenta esté activa. Tras la solicitud de '
    'eliminación de cuenta, los datos personales se eliminan en un plazo de 30 días, '
    'excepto los que deben conservarse por obligación legal.',
  ),
  _LegalSection('7. Seguridad', isTitle: true),
  _LegalSection(
    'Utilizamos cifrado en tránsito (TLS) y en reposo, control de acceso basado '
    'en perfiles y monitoreo de actividades para proteger sus datos.',
  ),
  _LegalSection('8. Contacto', isTitle: true),
  _LegalSection(
    'Responsable de Protección de Datos: disponible a través del soporte de la aplicación. '
    'Autoridad Nacional de Protección de Datos de Brasil (ANPD): www.gov.br/anpd',
  ),
  _LegalSection('Última actualización: Enero de 2025', isTitle: false),
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

  static const _kGreen = Color(0xFF075f45);
  static const _kGold  = Color(0xFFD4A96A);
  static const _kDark  = Color(0xFF07110d);

  String get _titleText => _isEs
      ? 'Antes de continuar'
      : 'Antes de continuar';

  String get _subtitleText => _isEs
      ? 'Por favor, lea y acepte los términos para acceder a MedCases Pro.'
      : 'Por favor, leia e aceite os termos para acessar o MedCases Pro.';

  String get _btnText => _isEs ? 'Continuar' : 'Continuar';

  String get _btnDisabledText => _isEs
      ? 'Marque todos os itens'
      : 'Marque todos os itens';

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.90),
      decoration: const BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Ícone + Título
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.verified_user_rounded, size: 28, color: _kGold),
                ),
                const SizedBox(height: 14),
                Text(
                  _titleText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitleText,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Checkboxes
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    onLinkTap: () => showLegalSheet(context, LegalType.terms, widget.lang),
                  ),
                  const SizedBox(height: 8),
                  _ConsentCheck(
                    value: _c2,
                    isEs: _isEs,
                    labelPt: 'Li e compreendi a ',
                    labelEs: 'He leído y entendido la ',
                    linkTextPt: 'Política de Privacidade',
                    linkTextEs: 'Política de Privacidad',
                    onChanged: (v) => setState(() => _c2 = v),
                    onLinkTap: () => showLegalSheet(context, LegalType.privacy, widget.lang),
                  ),
                  const SizedBox(height: 8),
                  _ConsentCheck(
                    value: _c3,
                    isEs: _isEs,
                    labelPt: 'Consinto com o tratamento dos meus dados conforme a LGPD',
                    labelEs: 'Consiento el tratamiento de mis datos conforme a la ley de protección de datos',
                    linkTextPt: '',
                    linkTextEs: '',
                    onChanged: (v) => setState(() => _c3 = v),
                    onLinkTap: null,
                  ),
                  const SizedBox(height: 8),
                  _ConsentCheck(
                    value: _c4,
                    isEs: _isEs,
                    labelPt: 'Declaro que sou profissional de saúde habilitado e compreendo que doses, protocolos e cálculos são ferramentas educativas de apoio. A verificação e a decisão clínica final são de minha exclusiva responsabilidade — ',
                    labelEs: 'Declaro que soy profesional de la salud habilitado y comprendo que las dosis, protocolos y cálculos son herramientas educativas de apoyo. La verificación y la decisión clínica final son de mi exclusiva responsabilidad — ',
                    linkTextPt: 'ver Aviso Médico',
                    linkTextEs: 'ver Aviso Médico',
                    onChanged: (v) => setState(() => _c4 = v),
                    onLinkTap: () => showLegalSheet(context, LegalType.disclaimer, widget.lang),
                  ),
                ],
              ),
            ),
          ),

          // Botão
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _allChecked ? _kGreen : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: _allChecked ? _kGreen : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _allChecked
                      ? () async {
                          await ConsentGate.saveConsent();
                          widget.onAccepted();
                        }
                      : null,
                  child: Center(
                    child: Text(
                      _allChecked ? _btnText : _btnDisabledText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _allChecked
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        letterSpacing: 0.2,
                      ),
                    ),
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

  static const _kGreen = Color(0xFF075f45);
  static const _kGold  = Color(0xFFD4A96A);

  @override
  Widget build(BuildContext context) {
    final label    = isEs ? labelEs    : labelPt;
    final linkText = isEs ? linkTextEs : linkTextPt;
    final hasLink  = linkText.isNotEmpty && onLinkTap != null;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value
              ? _kGreen.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: value
                ? _kGreen.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox visual
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20, height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: value ? _kGreen : Colors.transparent,
                border: Border.all(
                  color: value
                      ? _kGreen
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            // Texto com link opcional
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.45,
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
                              fontSize: 12.5,
                              color: _kGold,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: _kGold,
                              height: 1.45,
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
