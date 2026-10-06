// legal_screen.dart — Documentos legais + Consent Gate
// Todos os textos bilíngues (es / pt-BR)
// Uso: showLegalSheet(context, LegalType.terms, lang)
//      ConsentGate.showIfNeeded(context) — retorna true se já tinha consentimento
//
// Conformidade: Apple App Store Review Guidelines Section 5.1 (Privacy)
//               Google Play Developer Policy — Personal and Sensitive Information
//               LGPD (Lei 13.709/2018) Art. 7º, I e IX
//               Referências jurídicas não equivalem a certificação do produto.

import 'dart:ui';
import '../widgets/legal_links.dart';

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
                MedCasesLegalLinks(isEs: isEs, compact: true),
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
  _LegalSection("Aceitação e licença", isTitle: true),
  _LegalSection(
      "Ao usar o MedCases Pro, você aceita estes termos. Se não concordar, interrompa o uso. É concedida uma licença limitada, pessoal e não transferível para acessar as funcionalidades disponíveis, conforme os termos da loja e direitos legais aplicáveis. O serviço é destinado a estudantes e profissionais da saúde com capacidade para contratar."),
  _LegalSection("Conta e uso permitido", isTitle: true),
  _LegalSection(
      "Proteja suas credenciais, mantenha dados de cadastro corretos e reporte acesso indevido. Não contorne controles de acesso, explore vulnerabilidades, distribua malware, use conta alheia ou copie e comercialize conteúdo protegido sem autorização. O uso para estudo e consulta profissional permanece sujeito à conferência independente."),
  _LegalSection("Conteúdo e propriedade intelectual", isTitle: true),
  _LegalSection(
      "A licença de uso não transfere direitos sobre software, marca ou conteúdo MedCases. Materiais e links de terceiros pertencem aos respectivos titulares e possuem seus próprios termos. Você mantém os direitos sobre o conteúdo que fornece e autoriza o processamento necessário às funções que solicitar."),
  _LegalSection("IA e responsabilidade profissional", isTitle: true),
  _LegalSection(
      "Respostas automatizadas e transcrições podem conter erros, omissões ou informação desatualizada. O conteúdo é educacional e informacional, não substitui avaliação individual, diagnóstico, prescrição, protocolos locais ou decisão profissional. Confira cálculos, unidades, doses, formulações, contraindicações e referências antes de qualquer uso clínico. Consulte /medical-disclaimer."),
  _LegalSection("Dados enviados", isTitle: true),
  _LegalSection(
      "Insira somente dados necessários e sobre os quais tenha autorização ou outra base aplicável. Não use o serviço para expor dados de pacientes ou terceiros indevidamente. Áudio e transcrição seguem as escolhas e avisos de processamento do app e a política em /privacy."),
  _LegalSection("Assinaturas", isTitle: true),
  _LegalSection(
      "Premium Monthly e Premium Yearly, quando oferecidos, são assinaturas com renovação automática. O preço, período, recursos incluídos e eventual teste são exibidos antes da compra na loja correspondente. Gerenciamento, cancelamento e reembolso seguem Apple ou Google Play e a legislação aplicável. Restauração está disponível no fluxo de compra; consulte /subscriptions. Excluir a conta não cancela a assinatura."),
  _LegalSection("Disponibilidade e encerramento", isTitle: true),
  _LegalSection(
      "Manutenção e falhas podem interromper o serviço. Contas podem ser suspensas por abuso ou violação destes termos, observados os direitos aplicáveis. Você pode encerrar o uso e solicitar exclusão. Não garantimos disponibilidade contínua, exatidão absoluta ou resultados clínicos específicos."),
  _LegalSection("Responsabilidade e direitos preservados", isTitle: true),
  _LegalSection(
      "Nos limites permitidos pela lei, não respondemos por uso indevido, decisões independentes ou falhas de serviços de terceiros fora de nosso controle. Não se excluem garantias obrigatórias, direitos do consumidor ou responsabilidade que não possa ser limitada. Não se cria obrigação de indenização que contrarie esses direitos."),
  _LegalSection("Licenciante e contato", isTitle: true),
  _LegalSection(
      "MedCases Pro LTDA, representada por Bruno Rodrigues de Sousa. Avenida República Argentina, 2613, Foz do Iguaçu — PR, CEP 85852-018, Brasil. medcasespro@gmail.com · +55 45 98808-1338."),
  _LegalSection("Lei aplicável e foro", isTitle: true),
  _LegalSection(
      "Estes Termos e esta Licença são regidos pelas leis da República Federativa do Brasil, observadas as normas imperativas aplicáveis ao usuário. Ressalvadas as hipóteses em que a legislação aplicável determine competência diversa ou assegure ao usuário o direito de demandar em outro foro, fica eleito o foro da Comarca de São Paulo, Estado de São Paulo, Brasil, para dirimir controvérsias decorrentes destes Termos."),
  _LegalSection("2026-10-03 | 2026.10.R2"),
];

// ═══════════════════════════════════════════════════════════════════════════════
// TERMOS DE USO — Español
// ═══════════════════════════════════════════════════════════════════════════════
const _termsEs = [
  _LegalSection("Aceptación y licencia", isTitle: true),
  _LegalSection(
      "Al utilizar MedCases Pro acepta estos términos; si no está de acuerdo, deje de usarlo. Se concede una licencia limitada, personal e intransferible para acceder a las funciones disponibles, conforme a la tienda y los derechos legales aplicables. El servicio se dirige a estudiantes y profesionales sanitarios con capacidad para contratar."),
  _LegalSection("Cuenta y uso permitido", isTitle: true),
  _LegalSection(
      "Proteja credenciales, mantenga datos correctos y reporte acceso indebido. No eluda controles, explote vulnerabilidades, distribuya malware, use cuentas ajenas ni copie y comercialice contenido protegido sin autorización. El estudio y la consulta profesional requieren verificación independiente."),
  _LegalSection("Contenido y propiedad intelectual", isTitle: true),
  _LegalSection(
      "La licencia no transfiere derechos sobre software, marca ni contenido MedCases. Los materiales y enlaces de terceros pertenecen a sus titulares y tienen sus propios términos. Conserva sus derechos sobre el contenido aportado y autoriza el procesamiento necesario para las funciones solicitadas."),
  _LegalSection("IA y responsabilidad profesional", isTitle: true),
  _LegalSection(
      "Respuestas automatizadas y transcripciones pueden contener errores, omisiones o información desactualizada. El contenido es educativo e informativo; no sustituye evaluación individual, diagnóstico, prescripción, protocolos locales ni decisión profesional. Verifique cálculos, unidades, dosis, formulaciones, contraindicaciones y referencias antes del uso clínico. Consulte /medical-disclaimer."),
  _LegalSection("Datos enviados", isTitle: true),
  _LegalSection(
      "Aporte solo datos necesarios y para los que disponga de autorización u otra base aplicable. No exponga indebidamente información de pacientes o terceros. El audio y la transcripción siguen las opciones y avisos del app y la política en /privacy."),
  _LegalSection("Suscripciones", isTitle: true),
  _LegalSection(
      "Premium Monthly y Premium Yearly, cuando se ofrezcan, se renuevan automáticamente. Precio, período, recursos y eventual prueba se muestran antes de comprar en la tienda correspondiente. Gestión, cancelación y reembolso siguen Apple o Google Play y la normativa aplicable. La restauración está disponible en el flujo de compra; consulte /subscriptions. Eliminar la cuenta no cancela la suscripción."),
  _LegalSection("Disponibilidad y finalización", isTitle: true),
  _LegalSection(
      "El mantenimiento y los fallos pueden interrumpir el servicio. Se pueden suspender cuentas por abuso o incumplimiento, respetando derechos aplicables. Puede dejar de usarlo y solicitar eliminación. No garantizamos disponibilidad continua, exactitud absoluta ni resultados clínicos concretos."),
  _LegalSection("Responsabilidad y derechos preservados", isTitle: true),
  _LegalSection(
      "En los límites legales, no respondemos por uso indebido, decisiones independientes ni fallos ajenos fuera de nuestro control. No se excluyen garantías obligatorias, derechos del consumidor ni responsabilidad no limitable. No se impone indemnización contraria a esos derechos."),
  _LegalSection("Licenciante y contacto", isTitle: true),
  _LegalSection(
      "MedCases Pro LTDA, representada por Bruno Rodrigues de Sousa. Avenida República Argentina, 2613, Foz do Iguaçu — PR, CEP 85852-018, Brasil. medcasespro@gmail.com · +55 45 98808-1338."),
  _LegalSection("Ley aplicable y jurisdicción", isTitle: true),
  _LegalSection(
      "Estos Términos y esta Licencia se rigen por las leyes de la República Federativa de Brasil, respetando las normas imperativas aplicables al usuario. Salvo cuando la ley determine otra competencia o reconozca al usuario el derecho de acudir a otro foro, se elige el foro de la Comarca de São Paulo, Estado de São Paulo, Brasil, para las controversias derivadas de estos Términos."),
  _LegalSection("2026-10-03 | 2026.10.R2"),
];

// ═══════════════════════════════════════════════════════════════════════════════
// POLÍTICA DE PRIVACIDADE — Português
// ═══════════════════════════════════════════════════════════════════════════════
const _privacyPt = [
  _LegalSection("Serviço e alcance", isTitle: true),
  _LegalSection(
      "Esta política descreve o tratamento de dados no MedCases Pro e em medcasespro.com. Controlador e responsável: MedCases Pro LTDA, representada por Bruno Rodrigues de Sousa. Avenida República Argentina, 2613, Foz do Iguaçu — PR, CEP 85852-018, Brasil. medcasespro@gmail.com · +55 45 98808-1338."),
  _LegalSection("Dados fornecidos", isTitle: true),
  _LegalSection(
      "Podemos tratar nome, e-mail, profissão, instituição, identificador da conta, idioma, preferências, solicitações de suporte e dados necessários à autenticação. Ferramentas e IA recebem as perguntas, textos, documentos ou histórias clínicas que você inserir. Evite identificadores de pacientes e forneça dados de terceiros apenas quando houver autorização ou outra base aplicável."),
  _LegalSection("Áudio e transcrições", isTitle: true),
  _LegalSection(
      "O áudio gravado ou importado pode permanecer no dispositivo e, quando você solicitar transcrição remota, ser enviado ao serviço e ao provedor usado naquela operação. São tratados também a transcrição e os materiais derivados solicitados. Áudio e campos livres podem conter dados de saúde; forneça somente o necessário. O consentimento específico de áudio remoto pode ser revogado no fluxo do aplicativo, impedindo novos envios autorizados por esse consentimento."),
  _LegalSection("Dados técnicos e registros", isTitle: true),
  _LegalSection(
      "Identificadores do dispositivo e de notificações, versão do app, idioma, registros de tentativas, duração, uso e falhas são tratados para funcionamento, contabilização, suporte, segurança e prevenção de abuso. A aplicação usa armazenamento local e sessões de autenticação. Não se presume anonimato de informações vinculadas à sua conta."),
  _LegalSection("Finalidades", isTitle: true),
  _LegalSection(
      "Tratamos dados para autenticar, disponibilizar ferramentas solicitadas, transcrever, gerar materiais, salvar conteúdos escolhidos, administrar assinaturas, controlar uso, responder suporte e investigar falhas. Dados agregados ou operacionais podem ajudar a avaliar o funcionamento do produto. Solicitações opcionais e comunicações seguem as escolhas disponíveis no app."),
  _LegalSection("Serviços envolvidos", isTitle: true),
  _LegalSection(
      "A arquitetura contém Firebase/Google para autenticação, banco, armazenamento e notificações; Google Sign-In para acesso escolhido pelo usuário; Apple e Google Play para distribuição e compras; RevenueCat para validação e sincronização de assinaturas; DigitalOcean para hospedagem e gateway; OpenAI e serviços Google Gemini em rotas de IA/transcrição. O serviço efetivamente utilizado depende da função e configuração. Dados necessários à tarefa são encaminhados ao serviço correspondente, não a todos os fornecedores em todas as operações. Pagamentos são processados pela loja, sem coleta dos dados completos do cartão pelo app."),
  _LegalSection("Armazenamento, transferências e retenção", isTitle: true),
  _LegalSection(
      "Os dados pessoais são mantidos pelo período necessário para fornecer o serviço, cumprir obrigações legais, resolver disputas, prevenir abuso e atender às finalidades descritas nesta Política. Os períodos específicos podem variar conforme o tipo de dado e a finalidade do tratamento. Dados podem estar no dispositivo, backend e fornecedores, inclusive em outros países. Não prometemos retenção zero ou exclusão instantânea. Não há prazo global de retenção aprovado."),
  _LegalSection("Segurança", isTitle: true),
  _LegalSection(
      "O projeto usa HTTPS, autenticação e controles de acesso. Esses mecanismos reduzem riscos, mas não garantem segurança absoluta. Esta política não afirma criptografia ponta a ponta nem certificação HIPAA, GDPR, LGPD, SOC 2 ou ISO. Não compartilhe senhas ou chaves no suporte."),
  _LegalSection("Direitos, exclusão e contato", isTitle: true),
  _LegalSection(
      "Você pode solicitar informações, acesso, correção e exclusão pelo contato medcasespro@gmail.com, sujeito à verificação da titularidade e às regras aplicáveis. Consulte /data-deletion para o fluxo no app e solicitações complementares. Cancelar uma assinatura é uma operação separada. Informe apenas dados necessários para localizar a conta, nunca prontuários completos."),
  _LegalSection("Público e atualizações", isTitle: true),
  _LegalSection(
      "O produto é destinado a estudantes e profissionais da saúde, não a serviços dirigidos a crianças. Mudanças relevantes serão refletidas nesta página com data e versão; não há ampliação automática de autorização para uso de dados por simples alteração de texto."),
  _LegalSection("2026-10-03 | 2026.10.R2"),
];

// ═══════════════════════════════════════════════════════════════════════════════
// POLÍTICA DE PRIVACIDADE — Español
// ═══════════════════════════════════════════════════════════════════════════════
const _privacyEs = [
  _LegalSection("Servicio y alcance", isTitle: true),
  _LegalSection(
      "Esta política describe el tratamiento de datos en MedCases Pro y medcasespro.com. Responsable del tratamiento: MedCases Pro LTDA, representada por Bruno Rodrigues de Sousa. Avenida República Argentina, 2613, Foz do Iguaçu — PR, CEP 85852-018, Brasil. medcasespro@gmail.com · +55 45 98808-1338."),
  _LegalSection("Datos aportados", isTitle: true),
  _LegalSection(
      "Podemos tratar nombre, correo, profesión, institución, identificador de cuenta, idioma, preferencias, solicitudes de soporte y datos de autenticación. Las herramientas e IA reciben las preguntas, textos, documentos e historias clínicas que usted introduzca. Evite identificadores de pacientes; aporte datos de terceros solo con autorización u otra base aplicable."),
  _LegalSection("Audio y transcripciones", isTitle: true),
  _LegalSection(
      "El audio grabado o importado puede permanecer en el dispositivo y, al solicitar transcripción remota, enviarse al servicio y proveedor de esa operación. También se procesan la transcripción y los materiales derivados solicitados. El audio y los campos libres pueden contener información de salud; aporte solo lo necesario. El consentimiento específico de audio remoto puede revocarse en el flujo de la aplicación, impidiendo nuevos envíos amparados en ese consentimiento."),
  _LegalSection("Datos técnicos y registros", isTitle: true),
  _LegalSection(
      "Se tratan identificadores del dispositivo y de notificaciones, versión, idioma, intentos, duración, uso y fallos para funcionamiento, contabilización, soporte, seguridad y prevención de abuso. La aplicación utiliza almacenamiento local y sesiones de autenticación. No se presume anonimato de datos asociados a su cuenta."),
  _LegalSection("Finalidades", isTitle: true),
  _LegalSection(
      "Tratamos datos para autenticar, proporcionar herramientas solicitadas, transcribir, generar materiales, guardar contenidos elegidos, administrar suscripciones, contabilizar uso, responder soporte e investigar fallos. Los datos agregados u operativos pueden ayudar a evaluar el funcionamiento. Las solicitudes opcionales y comunicaciones siguen las opciones disponibles en la aplicación."),
  _LegalSection("Servicios involucrados", isTitle: true),
  _LegalSection(
      "La arquitectura contiene Firebase/Google para autenticación, base de datos, almacenamiento y notificaciones; Google Sign-In para acceso elegido; Apple y Google Play para distribución y compras; RevenueCat para validación y sincronización de suscripciones; DigitalOcean para alojamiento y gateway; OpenAI y servicios Google Gemini en rutas de IA/transcripción. El servicio utilizado depende de la función y configuración. Solo se envían los datos necesarios al servicio correspondiente, no a todos los proveedores en cada operación. La tienda procesa pagos; la aplicación no recoge los datos completos de la tarjeta."),
  _LegalSection("Almacenamiento, transferencias y conservación", isTitle: true),
  _LegalSection(
      "Los datos personales se mantienen durante el período necesario para prestar el servicio, cumplir obligaciones legales, resolver disputas, prevenir abuso y atender las finalidades de esta Política. Los períodos pueden variar según el tipo de dato y su finalidad. Pueden almacenarse en el dispositivo, backend y proveedores, incluso en otros países. No prometemos conservación cero ni eliminación instantánea. No existe un plazo global aprobado."),
  _LegalSection("Seguridad", isTitle: true),
  _LegalSection(
      "El proyecto utiliza HTTPS, autenticación y controles de acceso. Reducen riesgos, sin garantizar seguridad absoluta. Esta política no afirma cifrado de extremo a extremo ni certificación HIPAA, GDPR, LGPD, SOC 2 o ISO. No comparta contraseñas ni claves con soporte."),
  _LegalSection("Derechos, eliminación y contacto", isTitle: true),
  _LegalSection(
      "Puede solicitar información, acceso, corrección y eliminación mediante medcasespro@gmail.com, sujeto a verificación de titularidad y normas aplicables. Consulte /data-deletion para el flujo y solicitudes adicionales. Cancelar una suscripción es una operación distinta. Aporte solo datos necesarios para localizar la cuenta, nunca historias clínicas completas."),
  _LegalSection("Público y cambios", isTitle: true),
  _LegalSection(
      "El producto se dirige a estudiantes y profesionales sanitarios, no a servicios dirigidos a niños. Los cambios relevantes se reflejarán con fecha y versión; una modificación del texto no amplía automáticamente la autorización para utilizar datos."),
  _LegalSection("2026-10-03 | 2026.10.R2"),
];

// ═══════════════════════════════════════════════════════════════════════════════
// AVISO MÉDICO — Português
// ═══════════════════════════════════════════════════════════════════════════════
const _disclaimerPt = [
  _LegalSection("Apoio educacional", isTitle: true),
  _LegalSection(
      "MedCases Pro é ferramenta de apoio educacional e informacional para estudantes e profissionais da saúde. Não é serviço de emergência nem substitui avaliação individual, prescrição, decisão profissional ou protocolos institucionais."),
  _LegalSection("Verificação", isTitle: true),
  _LegalSection(
      "Conteúdo e sistemas automatizados podem apresentar limitações, erros, omissões ou informações incompletas. Confira fontes, indicações, unidades, dose, via, formulação e contexto clínico antes do uso. A responsabilidade pelas decisões permanece com o profissional. Calculadoras não validam por si só a adequação de uma conduta."),
  _LegalSection("Emergências", isTitle: true),
  _LegalSection(
      "Em emergência, procure o sistema assistencial apropriado da sua região. Não espere uma resposta do aplicativo para buscar atendimento urgente."),
  _LegalSection("2026-10-03 | 2026.10.R2"),
];

// ═══════════════════════════════════════════════════════════════════════════════
// AVISO MÉDICO — Español
// ═══════════════════════════════════════════════════════════════════════════════
const _disclaimerEs = [
  _LegalSection("Apoyo educativo", isTitle: true),
  _LegalSection(
      "MedCases Pro es una herramienta educativa e informativa para estudiantes y profesionales sanitarios. No es un servicio de emergencias ni sustituye evaluación individual, prescripción, decisión profesional o protocolos institucionales."),
  _LegalSection("Verificación", isTitle: true),
  _LegalSection(
      "Los contenidos y sistemas automatizados pueden presentar limitaciones, errores, omisiones o información incompleta. Verifique fuentes, indicaciones, unidades, dosis, vía, formulación y contexto antes de usar. El profesional conserva la responsabilidad por sus decisiones. Una calculadora no valida por sí sola la adecuación de una conducta."),
  _LegalSection("Emergencias", isTitle: true),
  _LegalSection(
      "En una emergencia, acuda al sistema asistencial apropiado de su región. No espere una respuesta de la aplicación para buscar atención urgente."),
  _LegalSection("2026-10-03 | 2026.10.R2"),
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
