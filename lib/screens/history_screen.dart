import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import '../providers/app_provider.dart';
import '../main.dart' show MainShell; // SUPER ORDEM 313: pendingTab fallback
import '../models/clinical_history_model.dart';
import '../services/firestore_service.dart';
import '../services/suggestion_service.dart';
import '../services/ai_service.dart';
import '../services/gemini_service.dart';
import '../widgets/common_widgets.dart';
import '../services/stt_helper.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../platform/web_impl.dart'
    if (dart.library.io) '../platform/web_stub.dart' as webPlatform;
import 'clinical_recorder_sheet.dart';
import '../services/clinical_recorder_service.dart' show SoapData;

// ─────────────────────────────────────────────────────────────────────────────
// i18n PT/ES para História Clínica
// Uso: _hcT(lang, 'key')   onde lang = AppProvider.lang ('pt' | 'es')
// ─────────────────────────────────────────────────────────────────────────────
const _hcStrings = <String, Map<String, String>>{
  // Header
  'tab_title':          {'pt': 'HISTÓRIA CLÍNICA',         'es': 'HISTORIA CLÍNICA'},
  'tab_subtitle':       {'pt': 'Registro clínico completo', 'es': 'Registro clínico completo'},
  'new_hc':             {'pt': 'Nova HC',                   'es': 'Nueva HC'},
  'my_hcs':             {'pt': 'Minhas HCs',                'es': 'Mis HCs'},
  'community':          {'pt': 'Comunidade',                'es': 'Comunidad'},
  'search_hint':        {'pt': 'Buscar por diagnóstico, queixa, tags...', 'es': 'Buscar por diagnóstico, queja, etiquetas...'},
  // Tabs contagem
  'my_hcs_count':       {'pt': 'minhas',                   'es': 'mis HCs'},
  'pub_count':          {'pt': 'públicas',                  'es': 'públicas'},
  // Lista
  'open':               {'pt': 'Abrir',                     'es': 'Abrir'},
  'view':               {'pt': 'Ver',                       'es': 'Ver'},
  'edit_btn':           {'pt': 'Editar',                    'es': 'Editar'},
  'delete_btn':         {'pt': 'Excluir',                   'es': 'Eliminar'},
  'public_badge':       {'pt': 'Público',                   'es': 'Público'},
  'private_badge':      {'pt': 'Privado',                   'es': 'Privado'},
  'hidden_mod':         {'pt': 'Oculta por moderador',      'es': 'Oculta por moderador'},
  'show_mod':           {'pt': 'Mostrar',                   'es': 'Mostrar'},
  'hide_mod':           {'pt': 'Ocultar',                   'es': 'Ocultar'},
  'anon':               {'pt': 'Anônimo',                   'es': 'Anónimo'},
  'years':              {'pt': 'anos',                      'es': 'años'},
  // Diálogos confirmação
  'del_title':          {'pt': 'Excluir história clínica?',             'es': '¿Eliminar historia clínica?'},
  'del_content':        {'pt': 'Esta ação não pode ser desfeita.',      'es': 'Esta acción no se puede deshacer.'},
  'cancel':             {'pt': 'Cancelar',                              'es': 'Cancelar'},
  'del_confirm':        {'pt': 'Excluir',                               'es': 'Eliminar'},
  'del_mod_title':      {'pt': 'Excluir HC da Comunidade?',             'es': '¿Eliminar HC de la Comunidad?'},
  'del_mod_content':    {'pt': 'Esta ação é permanente e remove a história clínica de todos os usuários.\n\nProceder com a exclusão?',
                          'es': 'Esta acción es permanente y elimina la historia clínica de todos los usuarios.\n\n¿Proceder con la eliminación?'},
  'del_perm':           {'pt': 'Excluir permanentemente',               'es': 'Eliminar permanentemente'},
  // Snackbar moderação
  'hc_visible':         {'pt': 'HC visível novamente',                  'es': 'HC visible nuevamente'},
  'hc_hidden':          {'pt': 'HC ocultada da comunidade',             'es': 'HC ocultada de la comunidad'},
  'hc_del_perm':        {'pt': 'HC excluída permanentemente',           'es': 'HC eliminada permanentemente'},
  // Detalhe / Visualizador
  'copy_hc':            {'pt': 'Copiar HC',                             'es': 'Copiar HC'},
  'copied':             {'pt': 'História copiada',                      'es': 'Historia copiada'},
  'pdf_hint':           {'pt': 'PDF abre janela de impressão  •  PNG salva imagem da HC', 'es': 'PDF abre ventana de impresión  •  PNG guarda imagen de la HC'},
  'export_png_ok':      {'pt': 'PNG gerado — verifique seus downloads', 'es': 'PNG generado — revise sus descargas'},
  'export_png_err':     {'pt': 'Erro ao exportar PNG:',                 'es': 'Error al exportar PNG:'},
  'back':               {'pt': 'Voltar',                                'es': 'Volver'},
  // HeroHeader
  'pront':              {'pt': 'Pront.',                                'es': 'Expte.'},
  // ── Copiar conteúdo (StringBuffer) — Esquema 11 secciones Argentina ─────
  'copy_header':        {'pt': '=== MEDCASES PRO — HISTÓRIA CLÍNICA ===',
                          'es': '══════════════════════════════════════════════════════════════════\nHISTORIA CLÍNICA — MEDCASES PRO  |  ARGENTINA\n══════════════════════════════════════════════════════════════════'},
  'copy_date':          {'pt': 'Data:',                                 'es': 'Fecha y hora de ingreso:'},
  'copy_author':        {'pt': 'Autor:',                                'es': 'Profesional:'},
  'copy_patient':       {'pt': 'Paciente:',                            'es': 'Paciente:'},
  // Sección 1
  'copy_s1':            {'pt': '\n── 1. IDENTIFICAÇÃO DO PACIENTE ──',  'es': '\n── 1. DATOS DE FILIACIÓN Y ADMINISTRATIVOS ──'},
  'copy_nombre':        {'pt': 'Iniciais:',                             'es': 'Nombre y Apellido:'},
  'copy_edad':          {'pt': 'Idade / Nascimento:',                   'es': 'Edad / Fecha de Nacimiento:'},
  'copy_sexo':          {'pt': 'Sexo:',                                 'es': 'Sexo / Género:'},
  'copy_dni':           {'pt': 'Prontuário:',                           'es': 'DNI / Pasaporte:'},
  'copy_peso_talla':    {'pt': 'Peso / Altura:',                        'es': 'Peso / Talla:'},
  'copy_obra_social':   {'pt': 'Convênio:',                             'es': 'Obra Social / Prepaga o Plan de Salud:'},
  // Sección 2
  'copy_chief':         {'pt': '\n── 2. QUEIXA PRINCIPAL ──\n',         'es': '\n── 2. MOTIVO DE CONSULTA ──\n'},
  // Sección 3
  'copy_hpi':           {'pt': '\n── 3. HISTÓRIA DA DOENÇA ATUAL ──\n', 'es': '\n── 3. ENFERMEDAD ACTUAL (EA) ──\n'},
  // Sección 4
  'copy_s4':            {'pt': '\n── 4. ANTECEDENTES PESSOAIS ──',      'es': '\n── 4. ANTECEDENTES PERSONALES ──'},
  'copy_past':          {'pt': '  Patológicos:',                        'es': '  Patológicos:'},
  'copy_allerg':        {'pt': '  Alergias:',                           'es': '  Alérgicos:'},
  'copy_meds':          {'pt': '  Medicamentos habituais:',             'es': '  Medicamentos habituales (droga, dosis, tiempo):'},
  'copy_social':        {'pt': '  Hábitos:',                            'es': '  Hábitos (tabaquismo, alcohol, actividad física):'},
  'copy_rvs':           {'pt': '  Revisão de sistemas:',                'es': '  Gineco-obstétricos (si corresponde):'},
  // Sección 5
  'copy_family':        {'pt': '\n── 5. ANTECEDENTES FAMILIARES ──\n',  'es': '\n── 5. ANTECEDENTES FAMILIARES ──\n'},
  // Sección 6
  'copy_s6':            {'pt': '\n── 6. EXAME FÍSICO ──',               'es': '\n── 6. EXAMEN FÍSICO ──'},
  'copy_vitals':        {'pt': '  Sinais vitais (PA, FC, FR, T°, SpO2, Peso, Altura, IMC):',
                          'es': '  Signos Vitales — TA, FC, FR, T°, SatO2, Peso, Talla, IMC:'},
  'copy_pe':            {'pt': '  Exame físico por sistemas:\n',         'es': '  Examen por Sistemas/Aparatos:\n'},
  // Sección 7
  'copy_lab':           {'pt': '\n── 7. EXAMES COMPLEMENTARES ──\n',    'es': '\n── 7. ESTUDIOS COMPLEMENTARIOS ──\n'},
  'copy_img':           {'pt': '  Imagem:\n',                           'es': '  Estudios de Imagen:\n'},
  // Sección 8
  'copy_work_dx':       {'pt': '\n── 8. HIPÓTESE DIAGNÓSTICA ──\n',     'es': '\n── 8. IMPRESIÓN DIAGNÓSTICA ──\n'},
  'copy_final_dx':      {'pt': 'DIAGNÓSTICO FINAL: ',                   'es': 'Diagnóstico confirmado (CIE-10): '},
  // Sección 9
  'copy_evol':          {'pt': '\n── 9. EVOLUÇÃO CLÍNICA ──\nEvolução ', 'es': '\n── 9. EVOLUCIÓN CLÍNICA ──\nRegistro '},
  // Sección 10
  'copy_treat':         {'pt': '\n── 10. CONDUTAS E INDICAÇÕES MÉDICAS ──\n', 'es': '\n── 10. INDICACIONES MÉDICAS ──\n'},
  // Sección 11
  'copy_outcome':       {'pt': '\n── 11. DESFECHO E ALTA ──\nDesfecho: ', 'es': '\n── 11. EPICRISIS / RESUMEN DE ALTA ──\nDesenlace: '},
  'copy_followup':      {'pt': 'Seguimento: ',                          'es': 'Indicaciones al alta / Seguimiento ambulatorio:\n'},
  // ── PDF sections — Esquema 11 secciones Argentina ─────────────────────
  'pdf_hc_title':       {'pt': 'História Clínica',                     'es': 'Historia Clínica'},
  'pdf_section1':       {'pt': '1. IDENTIFICAÇÃO DO PACIENTE',          'es': '1. DATOS DE FILIACIÓN Y ADMINISTRATIVOS'},
  'pdf_initials':       {'pt': 'Iniciais / Nome',                       'es': 'Nombre y Apellido'},
  'pdf_demog':          {'pt': 'Dados demográficos',                    'es': 'Edad / Fecha de Nacimiento · Sexo / Género'},
  'pdf_patient':        {'pt': 'Paciente',                              'es': 'Paciente'},
  'pdf_age_label':      {'pt': 'Idade',                                 'es': 'Edad'},
  'pdf_specialty':      {'pt': 'Especialidade',                         'es': 'Especialidad'},
  'pdf_dni':            {'pt': 'Prontuário',                            'es': 'DNI / Pasaporte'},
  'pdf_record':         {'pt': 'Nº Prontuário',                         'es': 'Nº Historia Clínica / Expediente'},
  'pdf_obra_social':    {'pt': 'Convênio / Plano de Saúde',             'es': 'Obra Social / Prepaga o Plan de Salud'},
  'pdf_ingreso':        {'pt': 'Data e hora de internação',             'es': 'Fecha y hora de ingreso'},
  'pdf_contacto':       {'pt': 'Contato (familiar/responsável)',        'es': 'Persona de contacto (familiar/tutor)'},
  'pdf_section2':       {'pt': '2. QUEIXA PRINCIPAL',                   'es': '2. MOTIVO DE CONSULTA'},
  'pdf_section3':       {'pt': '3. ENFERMIDADE ATUAL (EA)',             'es': '3. ENFERMEDAD ACTUAL (EA)'},
  'pdf_hpi':            {'pt': 'História da doença atual',              'es': 'Descripción cronológica detallada'},
  'pdf_section4':       {'pt': '4. ANTECEDENTES PESSOAIS',              'es': '4. ANTECEDENTES PERSONALES'},
  'pdf_past':           {'pt': 'Antecedentes patológicos',              'es': 'Patológicos (enfermedades, cirugías, internaciones)'},
  'pdf_allerg':         {'pt': 'Alergias',                              'es': 'Alérgicos (medicamentos, alimentos, ambientales)'},
  'pdf_meds':           {'pt': 'Medicamentos em uso',                   'es': 'Medicamentos habituales (droga, dosis, tiempo de uso)'},
  'pdf_social':         {'pt': 'Hábitos (tabagismo, etilismo, atividade física)', 'es': 'Hábitos (tabaquismo, alcohol, actividad física, dieta)'},
  'pdf_rvs':            {'pt': 'Revisão de sistemas',                   'es': 'Gineco-obstétricos (si corresponde)'},
  'pdf_section5':       {'pt': '5. ANTECEDENTES FAMILIARES',            'es': '5. ANTECEDENTES FAMILIARES'},
  'pdf_family':         {'pt': 'Antecedentes familiares',               'es': 'Enfermedades relevantes en familiares de 1ª y 2ª línea'},
  'pdf_section6':       {'pt': '6. EXAME FÍSICO',                       'es': '6. EXAMEN FÍSICO'},
  'pdf_vitals':         {'pt': 'Sinais vitais',                         'es': 'Signos Vitales — TA · FC · FR · T° · SatO2 · Peso · Talla · IMC'},
  'pdf_vitals_sub':     {'pt': 'PA, FC, FR, T°, SpO2, Peso, Altura, IMC', 'es': 'Tensión arterial (TA), Frecuencia cardíaca (FC), Frecuencia respiratoria (FR), Temperatura (T°), Saturación de oxígeno (SatO2), Peso, Talla, IMC'},
  'pdf_exam_gen':       {'pt': 'Exame geral',                           'es': 'Examen General (conciencia, piel/mucosas, TCS, ganglios)'},
  'pdf_pe':             {'pt': 'Exame físico por sistemas',             'es': 'Examen por Sistemas/Aparatos (CV · Resp · Abdomen · SN · GU · Osteoarticular)'},
  'pdf_section7':       {'pt': '7. EXAMES COMPLEMENTARES',             'es': '7. ESTUDIOS COMPLEMENTARIOS'},
  'pdf_lab':            {'pt': 'Exames laboratoriais',                  'es': 'Análisis de laboratorio'},
  'pdf_ecg':            {'pt': 'ECG / Outros (biópsia, EEG...)',        'es': 'ECG / Otros (biopsia, EEG, espirometría...)'},
  'pdf_img':            {'pt': 'Exames de imagem',                      'es': 'Estudios por imágenes'},
  'pdf_section8':       {'pt': '8. IMPRESIÓN DIAGNÓSTICA',              'es': '8. IMPRESIÓN DIAGNÓSTICA'},
  'pdf_work_dx':        {'pt': 'Hipótese principal',                    'es': 'Presunciones diagnósticas (por orden de prioridad clínica)'},
  'pdf_diff_dx':        {'pt': 'Diagnósticos diferenciais',             'es': 'Diagnósticos diferenciales / HCOP'},
  'pdf_section9':       {'pt': '9. EVOLUÇÃO CLÍNICA',                   'es': '9. EVOLUCIÓN CLÍNICA'},
  'pdf_section10':      {'pt': '10. CONDUTAS E INDICAÇÕES MÉDICAS',     'es': '10. INDICACIONES MÉDICAS'},
  'pdf_plan':           {'pt': 'Plano terapêutico',                     'es': 'Dieta · Posición · Hidratación · Medicación (droga/dosis/vía/frecuencia)'},
  'pdf_proc':           {'pt': 'Procedimentos realizados',              'es': 'Controles (signos vitales, balance hídrico) · Pedidos de estudios'},
  'pdf_section11':      {'pt': '11. DESFECHO E ALTA',                   'es': '11. EPICRISIS / RESUMEN DE ALTA'},
  'pdf_discharge':      {'pt': 'Condições de alta',                     'es': 'Diagnóstico de egreso · Condiciones de alta'},
  'pdf_followup':       {'pt': 'Seguimento / Orientações ao alta',      'es': 'Tratamiento farmacológico · Pautas de alarma · Seguimiento ambulatorio'},
  'pdf_footer':         {'pt': 'Gerado por MedCases Pro — Uso exclusivamente educacional e de apoio clínico. Não substitui avaliação médica individual presencial.',
                          'es': 'Generado por MedCases Pro — Uso exclusivamente educativo y de apoyo clínico. No sustituye la evaluación médica individual presencial.'},
  // Banner de diagnóstico
  'dx_final_label':     {'pt': 'DIAGNÓSTICO FINAL',                    'es': 'DIAGNÓSTICO FINAL'},
  'dx_working_label':   {'pt': 'HIPÓTESE DIAGNÓSTICA',                 'es': 'HIPÓTESIS DIAGNÓSTICA'},
  'dx_diff_label':      {'pt': 'DIAGNÓSTICO DIFERENCIAL',              'es': 'DIAGNÓSTICO DIFERENCIAL'},
  // PDF evolução tipos
  'evo_med':            {'pt': 'Evolução Médica',                      'es': 'Evolución Médica'},
  'evo_nurs':           {'pt': 'Nota de Enfermagem',                   'es': 'Nota de Enfermería'},
  'evo_lab':            {'pt': 'Resultado Lab',                        'es': 'Resultado Lab'},
  'evo_img':            {'pt': 'Laudo Imagem',                         'es': 'Informe Imagen'},
  'evo_proc':           {'pt': 'Procedimento',                         'es': 'Procedimiento'},
  'evo_default':        {'pt': 'Evolução',                             'es': 'Evolución'},
  // PDF outcomes
  'out_internado':      {'pt': 'Internado',                            'es': 'Hospitalizado'},
  'out_alta':           {'pt': 'Alta hospitalar',                      'es': 'Alta hospitalaria'},
  'out_obito':          {'pt': 'Óbito',                                'es': 'Fallecimiento'},
  'out_transfer':       {'pt': 'Transferência',                        'es': 'Traslado'},
  // Visualizador — seções com ícones
  'det_anamnese':       {'pt': 'ANAMNESE',                             'es': 'ANAMNESIS'},
  'det_chief':          {'pt': 'Queixa principal',                     'es': 'Motivo de consulta'},
  'det_hpi':            {'pt': 'História da doença atual',             'es': 'Enfermedad actual'},
  'det_past':           {'pt': 'Antecedentes pessoais',                'es': 'Antecedentes personales'},
  'det_family':         {'pt': 'Antecedentes familiares',              'es': 'Antecedentes familiares'},
  'det_social':         {'pt': 'História social',                      'es': 'Historia social'},
  'det_meds':           {'pt': 'Medicamentos em uso',                  'es': 'Medicación habitual'},
  'det_rvs':            {'pt': 'Revisão de sistemas',                  'es': 'Revisión de sistemas'},
  'det_exam':           {'pt': 'EXAME FÍSICO',                         'es': 'EXAMEN FÍSICO'},
  'det_vitals':         {'pt': 'Sinais vitais',                        'es': 'Signos vitales'},
  'det_pe':             {'pt': 'Exame físico',                         'es': 'Examen físico'},
  'det_labs':           {'pt': 'EXAMES COMPLEMENTARES',                'es': 'ESTUDIOS COMPLEMENTARIOS'},
  'det_lab_res':        {'pt': 'Laboratório',                          'es': 'Laboratorio'},
  'det_img':            {'pt': 'Imagem',                               'es': 'Imagen'},
  'det_other':          {'pt': 'Outros (ECG, biópsia...)',              'es': 'Otros (ECG, biopsia...)'},
  'det_treat':          {'pt': 'CONDUTA E TRATAMENTO',                 'es': 'CONDUCTA Y TRATAMIENTO'},
  'det_plan':           {'pt': 'Plano terapêutico',                    'es': 'Plan terapéutico'},
  'det_proc':           {'pt': 'Procedimentos',                        'es': 'Procedimientos'},
  'det_outcome':        {'pt': 'DESFECHO E ALTA',                      'es': 'DESENLACE Y ALTA'},
  'det_discharge':      {'pt': 'Condições de alta',                    'es': 'Condiciones de alta'},
  'det_followup':       {'pt': 'Seguimento',                           'es': 'Seguimiento'},
  // Card lista — outcomes label
  'outcome_alta':       {'pt': 'Alta',                                  'es': 'Alta'},
  'outcome_obito':      {'pt': 'Óbito',                                 'es': 'Fallecimiento'},
  'outcome_transfer':   {'pt': 'Transferência',                         'es': 'Traslado'},
  'outcome_internado':  {'pt': 'Internado',                             'es': 'Hospitalizado'},
  // Card lista — hipótese
  'card_dx':            {'pt': 'Dx:',                                   'es': 'Dx:'},
  'card_hypo':          {'pt': 'Hipótese:',                             'es': 'Hipótesis:'},
  // Estado vazio
  'empty_title':        {'pt': 'Nenhuma história clínica',              'es': 'Ninguna historia clínica'},
  'empty_sub':          {'pt': 'Crie e documente seus casos clínicos\nde forma estruturada e completa', 'es': 'Cree y documente sus casos clínicos\nde forma estructurada y completa'},
  'empty_btn':          {'pt': '+ Nova história clínica',               'es': '+ Nueva historia clínica'},
  'empty_comm_title':   {'pt': 'Nenhuma história pública',              'es': 'Ninguna historia pública'},
  'empty_comm_sub':     {'pt': 'Seja o primeiro a compartilhar!\nAnonimize e compartilhe seus casos.', 'es': '¡Sé el primero en compartir!\nAnonimiza y comparte tus casos.'},
  'community_error_title': {'pt': 'Erro ao carregar comunidade',        'es': 'Error al cargar comunidad'},
  'community_error_sub':   {'pt': 'Não foi possível buscar as histórias públicas agora.\nToque em atualizar para tentar novamente.', 'es': 'No fue posible cargar las historias públicas ahora.\nToque actualizar para reintentar.'},
  'error_details':      {'pt': 'Detalhes técnicos',                     'es': 'Detalles técnicos'},
  'refresh':            {'pt': 'Atualizar',                             'es': 'Actualizar'},
  'loading_comm':       {'pt': 'Carregando histórias da comunidade…',   'es': 'Cargando historias de la comunidad…'},
  // Editor — header
  'new_hc_title':       {'pt': 'Nova história clínica',                 'es': 'Nueva historia clínica'},
  'preview_btn':        {'pt': 'Ver',                                   'es': 'Ver'},
  'save_btn':           {'pt': 'Salvar',                                'es': 'Guardar'},
  'progress_label':     {'pt': '% preenchido',                          'es': '% completado'},
  // Editor — tabs seções
  'sec_pe':             {'pt': 'Exame Físico',                          'es': 'Examen Físico'},
  'sec_treat':          {'pt': 'Conduta',                               'es': 'Conducta'},
  'sec_evol':           {'pt': 'Evolução',                              'es': 'Evolución'},
  // Editor — seção Paciente
  'f_initials':         {'pt': 'Iniciais do paciente *',                'es': 'Iniciales del paciente *'},
  'h_initials':         {'pt': 'J.S. (preservar privacidade)',          'es': 'J.S. (preservar privacidad)'},
  'f_age':              {'pt': 'Idade',                                  'es': 'Edad'},
  'f_sex':              {'pt': 'SEXO',                                   'es': 'SEXO'},
  'sex_male':           {'pt': 'Masculino',                              'es': 'Masculino'},
  'sex_female':         {'pt': 'Feminino',                               'es': 'Femenino'},
  'f_weight':           {'pt': 'Peso (kg)',                              'es': 'Peso (kg)'},
  'f_height':           {'pt': 'Altura (cm)',                            'es': 'Talla (cm)'},
  'f_record':           {'pt': 'Nº Prontuário (opcional)',               'es': 'Nº Historia clínica (opcional)'},
  'f_category':         {'pt': 'CATEGORIA / ESPECIALIDADE',              'es': 'CATEGORÍA / ESPECIALIDAD'},
  'f_tags':             {'pt': 'Tags (ex: sepse, UTI, DM2)',             'es': 'Etiquetas (ej: sepsis, UCI, DM2)'},
  'h_tags':             {'pt': 'sepse, pneumonia, idoso',                'es': 'sepsis, neumonía, anciano'},
  'public_on':          {'pt': 'História pública — visível na Comunidade', 'es': 'Historia pública — visible en la Comunidad'},
  'public_off':         {'pt': 'História privada — somente você vê',     'es': 'Historia privada — solo tú la ves'},
  'public_hint':        {'pt': 'Toque para alternar. Dados do paciente são anonimizados (iniciais).', 'es': 'Toca para alternar. Los datos del paciente son anonimizados (iniciales).'},
  // Editor — Anamnese
  'f_chief':            {'pt': 'Queixa principal *',                     'es': 'Motivo de consulta *'},
  'h_chief':            {'pt': 'Dor torácica há 2h',                    'es': 'Dolor torácico desde hace 2h'},
  'f_hpi':              {'pt': 'História da doença atual (HDA)',         'es': 'Enfermedad actual (EA)'},
  'h_hpi':              {'pt': 'Descrever cronologia, características, fatores...', 'es': 'Describir cronología, características, factores...'},
  'f_past':             {'pt': 'Antecedentes pessoais',                  'es': 'Antecedentes personales'},
  'h_past':             {'pt': 'HAS, DM2, IAM prévio, cirurgias...',    'es': 'HTA, DM2, IAM previo, cirugías...'},
  'f_family':           {'pt': 'Antecedentes familiares',                'es': 'Antecedentes familiares'},
  'h_family':           {'pt': 'Pai: IAM aos 55 anos. Mãe: DM2...',     'es': 'Padre: IAM a los 55 años. Madre: DM2...'},
  'f_social':           {'pt': 'História social',                        'es': 'Historia social'},
  'h_social':           {'pt': 'Tabagismo, etilismo, drogas, atividade física, profissão...', 'es': 'Tabaquismo, alcohol, drogas, actividad física, ocupación...'},
  'f_meds':             {'pt': 'Medicamentos em uso',                    'es': 'Medicación habitual'},
  'h_meds':             {'pt': 'AAS 100mg/dia, metformina 850mg 2x/dia...', 'es': 'AAS 100mg/día, metformina 850mg 2v/día...'},
  'f_allerg':           {'pt': 'Alergias',                               'es': 'Alergias'},
  'h_allerg':           {'pt': 'Penicilina (urticária), dipirona (angioedema)...', 'es': 'Penicilina (urticaria), dipirona (angioedema)...'},
  'f_rvs':              {'pt': 'Revisão de sistemas',                    'es': 'Revisión de sistemas'},
  'h_rvs':              {'pt': 'Cardiovascular, respiratório, GI, neurológico...', 'es': 'Cardiovascular, respiratorio, GI, neurológico...'},
  // Editor — Exame Físico
  'f_pe':               {'pt': 'Exame físico por sistemas',              'es': 'Examen físico por sistemas'},
  'h_pe':               {'pt': 'Geral: BEG, corado, hidratado...\nCV: RCR 2T, sem sopros...\nTórax: MV+ bilateral, sem RA...\nAbdome: RHA+, indolor...', 'es': 'General: BEG, normocolor, hidratado...\nCV: RCR 2T, sin soplos...\nTórax: MV+ bilateral, sin RA...\nAbdomen: RHA+, indoloro...'},
  'f_work_dx':          {'pt': 'Hipótese diagnóstica principal',         'es': 'Hipótesis diagnóstica principal'},
  'h_work_dx':          {'pt': 'Síndrome Coronariana Aguda STEMI anterior', 'es': 'Síndrome Coronario Agudo SCAEST anterior'},
  'f_diff_dx':          {'pt': 'Diagnóstico diferencial',                'es': 'Diagnóstico diferencial'},
  'h_diff_dx':          {'pt': 'Pericardite aguda, dissecção aórtica, TEP...', 'es': 'Pericarditis aguda, disección aórtica, TEP...'},
  'f_final_dx':         {'pt': 'Diagnóstico final',                      'es': 'Diagnóstico final'},
  'h_final_dx':         {'pt': 'IAM STEMI anterior',                    'es': 'IAM SCAEST anterior'},
  // Editor — Exames
  'f_img':              {'pt': 'Exames de imagem / Outros',              'es': 'Estudios de imagen / Otros'},
  'h_img':              {'pt': 'RX tórax: sem congestão, ICT normal...\nEco: FE 48%, hipocinesia anterior...\nTC crânio: sem lesões agudas...', 'es': 'RX tórax: sin congestión, ICT normal...\nEco: FE 48%, hipocinesia anterior...\nTC cráneo: sin lesiones agudas...'},
  // Editor — Conduta
  'f_plan':             {'pt': 'Plano terapêutico / Conduta',            'es': 'Plan terapéutico / Conducta'},
  'h_plan':             {'pt': '1. AAS 300mg VO imediato\n2. Ticagrelor 180mg VO\n3. Heparina NF EV\n4. Ativar hemodinâmica (meta porta-balão < 90min)...', 'es': '1. AAS 300mg VO inmediato\n2. Ticagrelor 180mg VO\n3. Heparina no fraccionada EV\n4. Activar hemodinamia (meta puerta-balón < 90min)...'},
  'f_proc':             {'pt': 'Procedimentos realizados',               'es': 'Procedimientos realizados'},
  'h_proc':             {'pt': 'Cateterismo + angioplastia com stent em DA proximal...', 'es': 'Cateterismo + angioplastia con stent en DA proximal...'},
  // Editor — Evolução
  'evol_title':         {'pt': 'NOTAS DE EVOLUÇÃO',                      'es': 'NOTAS DE EVOLUCIÓN'},
  'evol_hint':          {'pt': 'Registre a evolução cronológica do paciente (diária, por turno, por evento).', 'es': 'Registre la evolución cronológica del paciente (diaria, por turno, por evento).'},
  'add_evol':           {'pt': 'Adicionar nota de evolução',             'es': 'Agregar nota de evolución'},
  'evol_author_hint':   {'pt': 'Dr./Enf. nome do profissional',          'es': 'Dr./Enf. nombre del profesional'},
  'evol_text_hint':     {'pt': 'Nota de evolução...',                    'es': 'Nota de evolución...'},
  // Editor — Desfecho
  'outcome_title':      {'pt': 'DESFECHO',                               'es': 'DESENLACE'},
  'f_discharge':        {'pt': 'Condições de alta',                      'es': 'Condiciones de alta'},
  'h_discharge':        {'pt': 'BEG, estável, orientado, tolerando VO...', 'es': 'BEG, estable, orientado, tolerando VO...'},
  'f_followup':         {'pt': 'Seguimento / Orientações',               'es': 'Seguimiento / Indicaciones'},
  'h_followup':         {'pt': 'Retorno em 7 dias com cardiologista. Manter AAS + ticagrelor por 12 meses...', 'es': 'Retorno en 7 días con cardiólogo. Mantener AAS + ticagrelor por 12 meses...'},
  // Outcomes labels editor
  'ol_internado':       {'pt': 'Internado',                              'es': 'Hospitalizado'},
  'ol_alta':            {'pt': 'Alta',                                   'es': 'Alta'},
  'ol_obito':           {'pt': 'Óbito',                                  'es': 'Fallec.'},
  'ol_transfer':        {'pt': 'Transferência',                          'es': 'Traslado'},
  // Ditáfone
  'dictaphone':         {'pt': 'Ditáfone inteligente',                   'es': 'Dictáfono inteligente'},
  'dictaphone_active':  {'pt': 'DITÁFONE INTELIGENTE • Gravando',        'es': 'DICTÁFONO INTELIGENTE • Grabando'},
  'dictaphone_hint':    {'pt': 'Diga "queixa", "antecedentes", "exame físico"... e o texto vai para o campo certo', 'es': 'Diga "queja", "antecedentes", "examen"... y el texto va al campo correcto'},
  'field_label':        {'pt': 'Campo: ',                                 'es': 'Campo: '},
  'dictating':          {'pt': 'Ouvindo...',                             'es': 'Escuchando...'},
  'dictate_btn':        {'pt': 'Ditar',                                  'es': 'Dictar'},
  'dict_not_supported': {'pt': 'Ditado não suportado',                   'es': 'Dictado no soportado'},
  'dict_browser_msg':   {'pt': 'Use Chrome ou Safari para o ditado.',    'es': 'Use Chrome o Safari para el dictado.'},
  // Relato Livre — modo IA
  'relato_btn':         {'pt': 'Relato Livre',                           'es': 'Relato Libre'},
  'relato_active':      {'pt': 'GRAVANDO SEU RELATO CLÍNICO...',         'es': 'GRABANDO TU RELATO CLÍNICO...'},
  'relato_hint':        {'pt': 'Fale livremente. A IA distribuirá nos campos ao final.', 'es': 'Habla libremente. La IA distribuirá en los campos al finalizar.'},
  'relato_ready':       {'pt': 'Microfone pronto. Toque para ditar.',    'es': 'Micrófono listo. Toca para dictar.'},
  'relato_processing':  {'pt': 'IA estruturando prontuário...',          'es': 'IA estructurando historia clínica...'},
  'relato_done':        {'pt': 'Prontuário preenchido pela IA!',         'es': '¡Historia clínica completada por IA!'},
  'relato_error':       {'pt': 'Erro ao processar com IA. Tente novamente.', 'es': 'Error al procesar con IA. Intenta de nuevo.'},
  'relato_no_key':      {'pt': 'Configure a chave OpenAI nas configurações para usar este recurso.', 'es': 'Configura la clave OpenAI en ajustes para usar esta función.'},
  'relato_empty':       {'pt': 'Nenhum áudio capturado. Tente novamente.', 'es': 'No se capturó audio. Intenta de nuevo.'},
  // Barra de navegação entre campos
  'nav_prev':           {'pt': 'Campo anterior',                         'es': 'Campo anterior'},
  'nav_next':           {'pt': 'Próximo campo',                          'es': 'Siguiente campo'},
  // Organizar com IA — modo texto livre
  'organizar_btn':      {'pt': 'Organizar com IA',                       'es': 'Organizar con IA'},
  'organizar_hint':     {'pt': 'Digite ou cole um texto clínico contínuo. A IA irá distribuir automaticamente nos campos da HC.', 'es': 'Escribe o pega un texto clínico continuo. La IA lo distribuirá automáticamente en los campos de la HC.'},
  'organizar_placeholder': {'pt': 'Paciente de 58 anos, HAS, DM2, queixa de dor torácica há 2h irradiando para o braço esquerdo...', 'es': 'Paciente de 58 años, HTA, DM2, queja de dolor torácico desde hace 2h irradiado al brazo izquierdo...'},
  'organizar_process':  {'pt': 'Organizar',                              'es': 'Organizar'},
  'organizar_done':     {'pt': 'HC preenchida com sucesso!',             'es': '¡HC completada con éxito!'},
  'organizar_error':    {'pt': 'Erro ao processar. Tente novamente.',    'es': 'Error al procesar. Intenta de nuevo.'},
  'organizar_empty':    {'pt': 'Digite algum texto antes de continuar.', 'es': 'Escribe algún texto antes de continuar.'},
  'organizar_title':    {'pt': 'Texto → Campos da HC',                   'es': 'Texto → Campos de la HC'},
  // STT labels de campos
  'stt_chief':          {'pt': 'Queixa principal',                       'es': 'Motivo de consulta'},
  'stt_hpi':            {'pt': 'HDA',                                    'es': 'EA'},
  'stt_past':           {'pt': 'Antecedentes pessoais',                  'es': 'Antecedentes personales'},
  'stt_family':         {'pt': 'Antecedentes familiares',                'es': 'Antecedentes familiares'},
  'stt_social':         {'pt': 'História social',                        'es': 'Historia social'},
  'stt_meds':           {'pt': 'Medicamentos',                           'es': 'Medicación'},
  'stt_allerg':         {'pt': 'Alergias',                               'es': 'Alergias'},
  'stt_rvs':            {'pt': 'Revisão de sistemas',                    'es': 'Revisión de sistemas'},
  'stt_vitals':         {'pt': 'Sinais vitais',                          'es': 'Signos vitales'},
  'stt_pe':             {'pt': 'Exame físico',                           'es': 'Examen físico'},
  'stt_work_dx':        {'pt': 'Hipótese diagnóstica',                   'es': 'Hipótesis diagnóstica'},
  'stt_treat':          {'pt': 'Conduta',                                 'es': 'Conducta'},
  // Pré-visualização
  'preview_title':      {'pt': 'PRÉ-VISUALIZAÇÃO',                       'es': 'PREVISUALIZACIÓN'},
  'prev_anamnese':      {'pt': 'ANAMNESE',                               'es': 'ANAMNESIS'},
  'prev_chief':         {'pt': 'Queixa principal',                        'es': 'Motivo de consulta'},
  'prev_hpi':           {'pt': 'História da doença atual',               'es': 'Enfermedad actual'},
  'prev_past':          {'pt': 'Antecedentes pessoais',                  'es': 'Antecedentes personales'},
  'prev_social':        {'pt': 'História social',                        'es': 'Historia social'},
  'prev_family':        {'pt': 'Antecedentes familiares',                'es': 'Antecedentes familiares'},
  'prev_meds':          {'pt': 'Medicamentos em uso',                    'es': 'Medicación habitual'},
  'prev_allerg':        {'pt': 'Alergias',                               'es': 'Alergias'},
  'prev_rvs':           {'pt': 'Revisão de sistemas',                    'es': 'Revisión de sistemas'},
  'prev_exam':          {'pt': 'EXAME FÍSICO',                           'es': 'EXAMEN FÍSICO'},
  'prev_vitals':        {'pt': 'Sinais vitais',                          'es': 'Signos vitales'},
  'prev_pe':            {'pt': 'Exame físico por sistemas',              'es': 'Examen físico por sistemas'},
  'prev_dx':            {'pt': 'DIAGNÓSTICO',                            'es': 'DIAGNÓSTICO'},
  'prev_work_dx':       {'pt': 'Hipótese diagnóstica',                   'es': 'Hipótesis diagnóstica'},
  'prev_final_dx':      {'pt': 'Diagnóstico final',                      'es': 'Diagnóstico final'},
  'prev_diff_dx':       {'pt': 'Diagnósticos diferenciais',              'es': 'Diagnósticos diferenciales'},
  'prev_labs':          {'pt': 'EXAMES COMPLEMENTARES',                  'es': 'ESTUDIOS COMPLEMENTARIOS'},
  'prev_lab':           {'pt': 'Laboratorio',                            'es': 'Laboratorio'},
  'prev_img':           {'pt': 'Imagem',                                 'es': 'Imagen'},
  'prev_other':         {'pt': 'Outros',                                 'es': 'Otros'},
  'prev_treat':         {'pt': 'CONDUTA',                                'es': 'CONDUCTA'},
  'prev_plan':          {'pt': 'Plano terapêutico',                      'es': 'Plan terapéutico'},
  'prev_proc':          {'pt': 'Procedimentos',                          'es': 'Procedimientos'},
  'prev_evol':          {'pt': 'EVOLUÇÃO',                               'es': 'EVOLUCIÓN'},
  'prev_outcome':       {'pt': 'DESFECHO',                               'es': 'DESENLACE'},
  'prev_discharge':     {'pt': 'Condições de alta',                      'es': 'Condiciones de alta'},
  'prev_followup':      {'pt': 'Seguimento',                             'es': 'Seguimiento'},
  // OCR / Lab
  'ocr_reading':        {'pt': 'Lendo imagem...',                        'es': 'Leyendo imagen...'},
  'ocr_manual':         {'pt': 'Imagem carregada — preencha os campos manualmente ou instale Tesseract.js', 'es': 'Imagen cargada — complete los campos manualmente o instale Tesseract.js'},
  'ocr_ok':             {'pt': 'Texto extraído! Revise os campos.',      'es': 'Texto extraído. Revise los campos.'},
  'ocr_err':            {'pt': 'Falha OCR:',                             'es': 'Error OCR:'},
  'ocr_btn':            {'pt': 'Foto/OCR',                               'es': 'Foto/OCR'},
  'ocr_loading':        {'pt': 'Lendo...',                               'es': 'Leyendo...'},
  'lab_filled':         {'pt': 'preenchido',                             'es': 'completado'},
  'lab_exams':          {'pt': 'EXAMES LABORATORIAIS',                   'es': 'ESTUDIOS DE LABORATORIO'},
  'lab_others_hint':    {'pt': 'Gasometria, hormônios, sorologia, culturas...', 'es': 'Gasometría, hormonas, serología, cultivos...'},
  // ── Seções do editor (tabs) ─────────────────────────────────────────────
  'sec_patient':        {'pt': 'Paciente',                                'es': 'Paciente'},
  'sec_anamnesis':      {'pt': 'Anamnese',                                'es': 'Anamnesis'},
  'sec_physical':       {'pt': 'Exame Físico',                            'es': 'Examen Físico'},
  'sec_exams':          {'pt': 'Exames',                                  'es': 'Estudios'},
  'sec_treatment':      {'pt': 'Conduta',                                 'es': 'Conducta'},
  'sec_evolution':      {'pt': 'Evolução',                                'es': 'Evolución'},
  'sec_outcome':        {'pt': 'Desfecho',                                'es': 'Desenlace'},
  // ── Desfecho labels (botões) ─────────────────────────────────────────────
  'out_transf':         {'pt': 'Transferência',                           'es': 'Transferencia'},
  // ── Labels de campos do editor ──────────────────────────────────────────
  'f_allergies':        {'pt': 'Alergias',                                'es': 'Alergias'},
  'f_cid':              {'pt': 'CID',                                     'es': 'CIE'},
  'f_diffdx':           {'pt': 'Diagnóstico diferencial',                 'es': 'Diagnóstico diferencial'},
  'f_finaldx':          {'pt': 'Diagnóstico final',                       'es': 'Diagnóstico final'},
  'f_imaging':          {'pt': 'Exames de imagem / Outros',               'es': 'Estudios de imagen / Otros'},
  'f_procedures':       {'pt': 'Procedimentos realizados',                'es': 'Procedimientos realizados'},
  'f_ros':              {'pt': 'Revisão de sistemas',                     'es': 'Revisión de sistemas'},
  'f_wdx':              {'pt': 'Hipótese diagnóstica principal',          'es': 'Hipótesis diagnóstica principal'},
  // ── Hints de campos do editor ────────────────────────────────────────────
  'h_allergies':        {'pt': 'Penicilina (urticária), dipirona (angioedema)...', 'es': 'Penicilina (urticaria), dipirona (angioedema)...'},
  'h_diffdx':           {'pt': 'Pericardite aguda, dissecção aórtica, TEP...', 'es': 'Pericarditis aguda, disección aórtica, TEP...'},
  'h_finaldx':          {'pt': 'IAM STEMI anterior',                     'es': 'IAM STEMI anterior'},
  'h_imaging':          {'pt': 'RX tórax: sem congestão... Eco: FE 48%... TC crânio: sem lesões agudas...', 'es': 'RX tórax: sin congestión... Eco: FE 48%... TC cráneo: sin lesiones agudas...'},
  'h_procedures':       {'pt': 'Cateterismo + angioplastia com stent em DA proximal...', 'es': 'Cateterismo + angioplastia con stent en DA proximal...'},
  'h_ros':              {'pt': 'Cardiovascular, respiratório, GI, neurológico...', 'es': 'Cardiovascular, respiratorio, GI, neurológico...'},
  'h_wdx':              {'pt': 'Síndrome Coronariana Aguda STEMI anterior', 'es': 'Síndrome Coronario Agudo STEMI anterior'},
  // ── Ditáfone STT labels ──────────────────────────────────────────────────
  'stt_allergies':      {'pt': 'Alergias',                                'es': 'Alergias'},
  'stt_plan':           {'pt': 'Conduta',                                 'es': 'Conducta'},
  'stt_ros':            {'pt': 'Revisão de sistemas',                     'es': 'Revisión de sistemas'},
  'stt_wdx':            {'pt': 'Hipótese diagnóstica',                    'es': 'Hipótesis diagnóstica'},
  'stt_evol_note':      {'pt': 'Nota de evolução',                       'es': 'Nota de evolución'},
  // ── ECG labels ──────────────────────────────────────────────────────────
  'ecg_ritmo':          {'pt': 'Ritmo',                                   'es': 'Ritmo'},
  'ecg_st':             {'pt': 'Alterações ST/T',                         'es': 'Alteraciones ST/T'},
  'ecg_outros':         {'pt': 'Outros Achados',                          'es': 'Otros Hallazgos'},
  // ── Lab labels ───────────────────────────────────────────────────────────
  'lab_others_title':   {'pt': 'Outros / Observações',                    'es': 'Otros / Observaciones'},
  // ── Sinais vitais ─────────────────────────────────────────────────────
  'vitals_title':       {'pt': 'Sinais Vitais',                           'es': 'Signos Vitales'},
  // ── PDF labels (seções 5-10) ─────────────────────────────────────────
  'pdf_lab_results':    {'pt': 'Exames laboratoriais',                    'es': 'Estudios de laboratorio'},
  'pdf_ecg_others':     {'pt': 'ECG / Outros (biópsia, EEG...)',          'es': 'ECG / Otros (biopsia, EEG...)'},
  'pdf_imaging_results':{'pt': 'Exames de imagem',                        'es': 'Estudios de imagen'},
  'pdf_procedures':     {'pt': 'Procedimentos realizados',                'es': 'Procedimientos realizados'},
  'pdf_out_alta':       {'pt': 'Alta hospitalar',                         'es': 'Alta hospitalaria'},
  // ── PDF evolução typeMap ─────────────────────────────────────────────
  'pdf_evo_med':        {'pt': 'Evolução Médica',                         'es': 'Evolución Médica'},
  'pdf_evo_nurse':      {'pt': 'Nota de Enfermagem',                      'es': 'Nota de Enfermería'},
  'pdf_evo_lab':        {'pt': 'Resultado Lab',                           'es': 'Resultado Lab'},
  'pdf_evo_img':        {'pt': 'Laudo Imagem',                            'es': 'Informe de Imagen'},
  'pdf_evo_proc':       {'pt': 'Procedimento',                            'es': 'Procedimiento'},
  // ── Estado vazio — histórias ──────────────────────────────────────────
  'new_history_btn':    {'pt': '+ Nova história clínica',                 'es': '+ Nuevo caso clínico'},
};

/// Retorna a string traduzida para o idioma dado.
/// Fallback: chave (nunca lança).
String _hcT(String lang, String key) {
  final map = _hcStrings[key];
  if (map == null) return key;
  return map[lang] ?? map['pt'] ?? key;
}

// Helper global — formata ISO para 'dd/mm/yyyy às hh:mm'
String _formatUploadedAt(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return 'Publicado $d/$m/${dt.year} \u00e0s $h:$min';
  } catch (_) {
    return '';
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  /// BUILD 318: Sinal estático — true enquanto o editor de história clínica
  /// está activo (nova ou edição de prontuário existente).
  /// Escutado pelo _FloatingFooter em main.dart para ocultar a dock flutuante
  /// e evitar sobreposição sobre o formulário de alta-concentração.
  /// Padrão idêntico ao AiScreen.chatKeyboardOpen.
  static final editorActive = ValueNotifier<bool>(false);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  // PERF-FIX: ValueNotifier para o texto de busca — o MedInput escuta este
  // notifier diretamente, sem propagar setState() para toda a _HistoryScreenState.
  // Cada letra digitada reduz o escopo de rebuild ao mínimo necessário.
  final _searchQuery = ValueNotifier<String>('');

  ClinicalHistoryModel? _viewing;
  ClinicalHistoryModel? _editing;
  bool _viewingPublic = false;
  // Filtro por intervalo de datas (null = sem filtro)
  DateTimeRange? _dateFilter;

  // MEMLEAK-FIX: listener nomeado em vez de lambda anônima — permite
  // removeListener() determinístico no dispose().
  void _onTabChange() {
    if (_tabCtrl.index == 1 && mounted) {
      context.read<AppProvider>().loadPublicHistories();
    }
  }

  // PERF-FIX: debounce de busca — evita rebuild por cada letra.
  // O timer é cancelado e recriado a cada keystroke; o setState() só
  // é disparado 120 ms após a última tecla, reduzindo rebuilds em ~80%.
  Timer? _searchDebounce;
  void _onSearchQueryChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // PERF-FIX: listener de busca com debounce — substitui onChanged: setState
    _searchQuery.addListener(_onSearchQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AppProvider>();
      p.loadHistories();
      // Garante que publicHistories seja carregado mesmo que o fetch do
      // setUser() já tenha terminado antes desta tela montar.
      // O Completer no provider garante que chamadas sobrepostas aguardam
      // o fetch em andamento em vez de retornar [] silenciosamente.
      p.loadPublicHistories();
    });
    // Quando o usuário muda para a aba Comunidade (índice 1), recarrega
    _tabCtrl.addListener(_onTabChange);
  }

  @override
  void dispose() {
    // MEMLEAK-FIX: remove listener nomeado antes de dispose() do controller.
    _tabCtrl.removeListener(_onTabChange);
    // BUILD 318: garante que o notifier seja resetado se a tela for destruída
    // enquanto o editor está activo (ex: hot-reload, deeplink de saída).
    if (HistoryScreen.editorActive.value) {
      HistoryScreen.editorActive.value = false;
    }
    _searchDebounce?.cancel(); // PERF-FIX: cancela timer de debounce
    _searchQuery.removeListener(_onSearchQueryChanged);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _searchQuery.dispose(); // PERF-FIX: dispõe o ValueNotifier de busca
    super.dispose();
  }

  // Abre o seletor de intervalo de datas
  Future<void> _showDateFilter() async {
    final lang = context.read<AppProvider>().lang;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateFilter,
      locale: lang == 'es' ? const Locale('es', 'ES') : const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F1116),
              onPrimary: Color(0xFFFFE8A6),
              surface: Colors.white,
              onSurface: Color(0xFF0F1116),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() => _dateFilter = picked);
    }
  }

  void _clearDateFilter() => setState(() => _dateFilter = null);

  // Aplica filtro de texto + data em uma lista de histórias
  List<ClinicalHistoryModel> _applyFilters(List<ClinicalHistoryModel> list) {
    final q = _searchQuery.value.toLowerCase();
    return list.where((h) {
      // Filtro de texto
      final textOk = q.isEmpty ||
          h.displayTitle.toLowerCase().contains(q) ||
          h.finalDiagnosis.toLowerCase().contains(q) ||
          h.workingDiagnosis.toLowerCase().contains(q) ||
          h.tags.toLowerCase().contains(q);
      if (!textOk) return false;
      // Filtro de data
      if (_dateFilter != null) {
        try {
          final dt = DateTime.parse(h.createdAt).toLocal();
          final start = DateTime(_dateFilter!.start.year, _dateFilter!.start.month, _dateFilter!.start.day);
          final end   = DateTime(_dateFilter!.end.year,   _dateFilter!.end.month,   _dateFilter!.end.day, 23, 59, 59);
          if (dt.isBefore(start) || dt.isAfter(end)) return false;
        } catch (_) {
          // Se não puder parsear a data, não filtra esse item
        }
      }
      return true;
    }).toList();
  }

  // Texto formatado do filtro ativo
  String get _dateFilterLabel {
    if (_dateFilter == null) return '';
    final s = _dateFilter!.start;
    final e = _dateFilter!.end;
    final fmt = (DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    if (s.year == e.year && s.month == e.month && s.day == e.day) return fmt(s);
    return '${fmt(s)} – ${fmt(e)}';
  }

  // BUILD 318: central setter — mantém _editing e o notifier em sincronia.
  // Todos os pontos de abertura/fecho do editor chamam este método.
  void _setEditing(ClinicalHistoryModel? model) {
    setState(() => _editing = model);
    HistoryScreen.editorActive.value = model != null;
  }

  void _startNewHistory(AppProvider p, String lang) {
    // BUILD 331+ — Intercepção com Gravador Clínico Multimodal
    // Exibe modal de seleção (gravar / digitar / blocos SOAP) antes do formulário
    ClinicalRecorderSheet.showFlowSelection(
      context,
      onManual: () => _startBlankHistory(p, lang),
      onSoapData: (soapData) {
        // Cria modelo pré-populado com dados SOAP da IA e abre o editor
        _startHistoryFromSoap(p, lang, soapData);
      },
    );
  }

  /// Cria e ativa um rascunho em branco (fluxo manual original)
  void _startBlankHistory(AppProvider p, String lang) {
    final uid = p.currentUser?.uid ?? 'local';
    final name = p.currentUser?.displayName ??
        p.currentUser?.email ??
        _hcT(lang, 'anon');
    final email = p.currentUser?.email ?? '';
    _setEditing(ClinicalHistoryModel.blank(
      authorUid: uid,
      authorName: name,
      authorEmail: email,
    ));
  }

  /// Cria modelo pré-populado com campos SOAP da IA e abre o editor
  void _startHistoryFromSoap(AppProvider p, String lang, SoapData soap) {
    final uid = p.currentUser?.uid ?? 'local';
    final name = p.currentUser?.displayName ??
        p.currentUser?.email ??
        _hcT(lang, 'anon');
    final email = p.currentUser?.email ?? '';

    // Monta ClinicalHistoryModel com campos SOAP pré-preenchidos
    // chiefComplaint + hpi ← soap.subjective
    // vitalSigns + physicalExam ← soap.objective
    // workingDiagnosis + differentialDx ← soap.assessment
    // treatmentPlan ← soap.plan
    // medications ← soap.medications
    // labResults ← soap.exams
    final model = ClinicalHistoryModel.blank(
      authorUid: uid,
      authorName: name,
      authorEmail: email,
    ).copyWith(
      chiefComplaint:    soap.subjective.isNotEmpty ? soap.subjective : null,
      hpi:              soap.subjective.isNotEmpty ? soap.subjective : null,
      vitalSigns:       soap.objective.isNotEmpty  ? soap.objective  : null,
      physicalExam:     soap.objective.isNotEmpty  ? soap.objective  : null,
      workingDiagnosis: soap.assessment.isNotEmpty ? soap.assessment : null,
      differentialDx:   soap.assessment.isNotEmpty ? soap.assessment : null,
      treatmentPlan:    soap.plan.isNotEmpty       ? soap.plan       : null,
      medications:      soap.medications.isNotEmpty? soap.medications: null,
      labResults:       soap.exams.isNotEmpty      ? soap.exams      : null,
    );

    _setEditing(model);
  }

  List<ClinicalHistoryModel> _visibleCommunityHistories(
    List<ClinicalHistoryModel> histories,
    AppProvider p,
  ) {
    if (p.canModerateContent) return histories;
    return histories.where((h) => !h.isHidden).toList();
  }

  Widget _buildTabScrollView({
    required List<Widget> slivers,
    Future<void> Function()? onRefresh,
  }) {
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );

    if (onRefresh == null) return scrollView;

    return RefreshIndicator(
      color: kGreen,
      onRefresh: onRefresh,
      child: scrollView,
    );
  }

  Widget _wrapHistoryCard({
    required MedBreakpoints bp,
    required Widget child,
  }) {
    if (!bp.isDesktop) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: child,
      ),
    );
  }

  List<Widget> _buildListSlivers({
    required MedBreakpoints bp,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          bp.isDesktop ? bp.hPadding : 0,
          0,
          bp.isDesktop ? bp.hPadding : 0,
          100,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildStateSlivers(Widget child) {
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverFillRemaining(
        hasScrollBody: false,
        child: child,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final lang = p.lang;

    // ── Modo edição ────────────────────────────────────────────────────────
    if (_editing != null) {
      return _HistoryEditor(
        initial: _editing!,
        p: p,
        onSave: (h) async {
          await p.saveHistory(h);
          if (!mounted) return;
          _setEditing(null);
        },
        onCancel: () => _setEditing(null),
      );
    }

    // ── Modo visualização ──────────────────────────────────────────────────
    if (_viewing != null) {
      return _HistoryDetail(
        history: _viewing!,
        p: p,
        readOnly: _viewingPublic,
        onBack: () => setState(() {
          _viewing = null;
          _viewingPublic = false;
        }),
        onEdit: _viewingPublic
            ? null
            : () {
                final h = _viewing!;
                setState(() => _viewing = null);
                _setEditing(h);
              },
        onDelete: _viewingPublic
            ? null
            : () async {
                await p.deleteHistory(_viewing!.id, wasPublic: _viewing!.isPublic);
                if (!mounted) return;
                setState(() => _viewing = null);
              },
      );
    }

    // ── Lista ───────────────────────────────────────────────────────────────
    final mine = _applyFilters(p.myHistories);
    final pub = _applyFilters(p.publicHistories);
    final visiblePub = _visibleCommunityHistories(pub, p);
    final bp = MedBreakpoints.of(context);
    final bg = p.darkMode ? const Color(0xFF1A1D23) : const Color(0xFFF7F8FA);

    Future<void> refreshCommunity() => p.loadPublicHistories(forceRemote: true);
    void triggerCommunityRefresh() {
      unawaited(refreshCommunity());
    }

    final mineTab = mine.isEmpty
        ? _buildTabScrollView(
            slivers: _buildStateSlivers(
              _EmptyHistoryState(
                lang: lang,
                onNew: () => _startNewHistory(p, lang),
              ),
            ),
          )
        : _buildTabScrollView(
            slivers: _buildListSlivers(
              bp: bp,
              itemCount: mine.length,
              itemBuilder: (_, i) => _wrapHistoryCard(
                bp: bp,
                child: _HistoryCard(
                  h: mine[i],
                  p: p,
                  onTap: () => setState(() {
                    _viewing = mine[i];
                    _viewingPublic = false;
                  }),
                  onEdit: () => _setEditing(mine[i]),
                  onDelete: () async {
                    final confirm = await _confirmDelete(context);
                    if (confirm) {
                      await p.deleteHistory(
                        mine[i].id,
                        wasPublic: mine[i].isPublic,
                      );
                    }
                  },
                  onTogglePublic: () => p.toggleHistoryPublic(mine[i]),
                ),
              ),
            ),
          );

    final communityTab = p.isLoadingPublic
        ? _buildTabScrollView(
            onRefresh: refreshCommunity,
            slivers: _buildStateSlivers(_CommunityLoadingState(lang: lang)),
          )
        : visiblePub.isEmpty
            ? _buildTabScrollView(
                onRefresh: refreshCommunity,
                slivers: _buildStateSlivers(
                  p.publicLoadError.trim().isNotEmpty
                      ? _CommunityErrorState(
                          lang: lang,
                          errorMessage: p.publicLoadError.trim(),
                          onRefresh: triggerCommunityRefresh,
                        )
                      : _EmptyCommunityState(
                          lang: lang,
                          onRefresh: triggerCommunityRefresh,
                        ),
                ),
              )
            : _buildTabScrollView(
                onRefresh: refreshCommunity,
                slivers: _buildListSlivers(
                  bp: bp,
                  itemCount: visiblePub.length,
                  itemBuilder: (_, i) {
                    final h = visiblePub[i];
                    final canModerate = p.canModerateContent;
                    return _wrapHistoryCard(
                      bp: bp,
                      child: _HistoryCard(
                        h: h,
                        p: p,
                        onTap: () => setState(() {
                          _viewing = h;
                          _viewingPublic = true;
                        }),
                        readOnly: true,
                        onModHide: canModerate
                            ? () async {
                                final wasHidden = h.isHidden;
                                await p.toggleHistoryHidden(h.id);
                                if (context.mounted) {
                                  _showModSnack(
                                    context,
                                    _hcT(lang, wasHidden ? 'hc_visible' : 'hc_hidden'),
                                  );
                                }
                              }
                            : null,
                        onModDelete: canModerate
                            ? () async {
                                final confirm = await _confirmModDelete(context);
                                if (!confirm) return;
                                await FirestoreService.adminDeletePublicHistory(h.id);
                                await p.loadPublicHistories(forceRemote: true);
                                if (context.mounted) {
                                  _showModSnack(
                                    context,
                                    _hcT(lang, 'hc_del_perm'),
                                    isError: true,
                                  );
                                }
                              }
                            : null,
                      ),
                    );
                  },
                ),
              );

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TOPBAR BLEED — Stack com Positioned negativo.
    //
    // CONTEXTO: MainShell._buildMobileShell() aplica Padding(top:statusBarH)
    // para as abas 3/4/5 antes do IndexedStack → topbar fica ABAIXO da
    // status bar, deixando uma falha de cor.
    //
    // SOLUÇÃO: Stack com Positioned(top: -topPad) sobe o Container do gradiente
    // para trás da status bar física. topPad via View.of() — imune ao
    // MediaQuery.removePadding do MainShell.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final double topPad = View.of(context).padding.top /
        View.of(context).devicePixelRatio;

    return ColoredBox(
      color: bg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Corpo: espaço reservado + TabRow + busca + conteúdo ──────
          Column(
            children: [
              // Reserva espaço para a topbar (fica por baixo do Positioned)
              const SizedBox(height: 56),
              // BUILD 331: Seletor triplo desacoplado — posicionado no corpo
              _HcTabRow(
                dark: p.darkMode,
                lang: lang,
                tabCtrl: _tabCtrl,
                onNew: () => _startNewHistory(p, lang),
              ),
              // ── Barra de busca ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: MedInput(
                        controller: _searchCtrl,
                        hintText: _hcT(lang, 'search_hint'),
                        // PERF-FIX: atualiza o ValueNotifier sem setState() global —
                        // apenas o ValueListenableBuilder abaixo rebuilda.
                        onChanged: (v) => _searchQuery.value = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showDateFilter,
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _dateFilter != null
                              ? AppColors.of(context).darkBtn
                              : AppColors.of(context).cardBg,
                          border: Border.all(
                            color: _dateFilter != null
                                ? AppColors.of(context).darkBtn
                                : AppColors.of(context).border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              size: 16,
                              color: _dateFilter != null
                                  ? const Color(0xFFFFE8A6)
                                  : const Color(0xFF6B7280),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_dateFilter != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.of(context).surface,
                          border: Border.all(color: AppColors.of(context).border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              size: 12,
                              color: AppColors.of(context).textPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _dateFilterLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.of(context).textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _clearDateFilter,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              // PERF-FIX: RepaintBoundary isola a TabBarView do bloco da topbar.
              // Quando o usuário digita na busca ou alterna abas, apenas esta
              // camada é redesenhada — a topbar (Positioned acima) mantém
              // seu cache de layer intacto no Impeller.
              Expanded(
                child: RepaintBoundary(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [mineTab, communityTab],
                  ),
                ),
              ),
            ],
          ),

          // ── LAYER 1: Background — sobe para trás da status bar / Dynamic Island
          // Apenas o plano de fundo é transladado negativamente. NENHUM elemento
          // interativo está aqui — garante que botões e título não sejam clicados
          // atrás do notch.
          Positioned(
            top: -topPad,
            left: 0,
            right: 0,
            height: topPad + 56,
            child: _HcTopbarBg(),
          ),
          // ── LAYER 2: Conteúdo interativo — fica em y=0, abaixo da Dynamic Island
          // Padding ergonômico: botões e título em posição segura e clicável.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 56,
            child: _HcTopbarContent(dark: p.darkMode, lang: lang),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final lang = context.read<AppProvider>().lang;
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_hcT(lang, 'del_title')),
        content: Text(_hcT(lang, 'del_content')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_hcT(lang, 'cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text(_hcT(lang, 'del_confirm'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _confirmModDelete(BuildContext context) async {
    final lang = context.read<AppProvider>().lang;
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_hcT(lang, 'del_mod_title'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F1116))),
        content: Text(
          _hcT(lang, 'del_mod_content'),
          style: const TextStyle(fontSize: 13, color: Color(0xFF444444))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_hcT(lang, 'cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(_hcT(lang, 'del_perm')),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showModSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LAYER 1 — Plano de fundo da topbar História Clínica
// Ocupa topPad+56 px, transladado top:-topPad para sangrar atrás da status bar.
// SEM conteúdo interativo — apenas decoração visual.
// ─────────────────────────────────────────────────────────────────────────────
class _HcTopbarBg extends StatelessWidget {
  const _HcTopbarBg();

  // PERF-FIX: BoxDecoration const total — o Impeller cacheia esta camada
  // e nunca a redesenha, mesmo quando a HistoryScreen recebe setState.
  static const _kDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5E2900), Color(0xFFF27405)],
    ),
    border: Border(
      bottom: BorderSide(color: Color(0xFFc2410c), width: 0.5),
    ),
    boxShadow: [
      BoxShadow(
        color: Color(0x59000000), // Colors.black.withOpacity(0.35) equivalente
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(decoration: _kDecoration);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LAYER 2 — Conteúdo interativo da topbar História Clínica
// Posicionado em top:0, height:56 — botões e título ficam ABAIXO da Dynamic
// Island em posição ergonômica e totalmente clicável. Sem translação negativa.
// ─────────────────────────────────────────────────────────────────────────────
class _HcTopbarContent extends StatelessWidget {
  final bool dark;
  final String lang;

  const _HcTopbarContent({required this.dark, required this.lang});

  @override
  Widget build(BuildContext context) {
    final title = lang == 'es' ? 'HISTORIA CLÍNICA' : 'HISTÓRIA CLÍNICA';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── CENTER: título BRANCO — contraste máximo sobre laranja ────────
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          // ── LEFT: botão de voltar — SizedBox 36×36 clicável ──────────────
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  MainShell.pendingTab.value = 0;
                }
              },
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 331 — SELETOR TRIPLO DESACOPLADO (MINHAS | PÚBLICAS | + NOVA)
// Posição: logo abaixo da Topbar, no corpo — fundo sólido nativo da aba.
// Cores adaptativas: dark → branco; light → preto.
// ─────────────────────────────────────────────────────────────────────────────
class _HcTabRow extends StatelessWidget {
  final bool dark;
  final String lang;
  final TabController tabCtrl;
  final VoidCallback onNew;

  const _HcTabRow({
    required this.dark,
    required this.lang,
    required this.tabCtrl,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = dark ? Colors.white24 : Colors.black12;
    // Cor do "+ NOVA" — ciano em qualquer modo (ação especial)
    final novaColor = dark
        ? const Color(0xFF00E5FF)
        : const Color(0xFF008CA4);

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1D23) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Row(
          children: [
            // Tab 0: MINHAS
            Expanded(
              child: _HcFlatTab(
                label: lang == 'es' ? 'MIS HCs' : 'MINHAS',
                index: 0,
                tabCtrl: tabCtrl,
                dark: dark,
              ),
            ),
            Container(width: 1, height: 14, color: dividerColor),
            // Tab 1: PÚBLICAS
            Expanded(
              child: _HcFlatTab(
                label: 'PÚBLICAS',
                index: 1,
                tabCtrl: tabCtrl,
                dark: dark,
              ),
            ),
            Container(width: 1, height: 14, color: dividerColor),
            // Tab 2: + NOVA — ação direta (não é aba real do TabBarView)
            Expanded(
              child: GestureDetector(
                onTap: onNew,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: Colors.transparent,
                  child: Text(
                    lang == 'es' ? '+ NUEVA' : '+ NOVA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: novaColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Tab flat minimalista para Historia Clínica — BUILD 331
// Cores adaptativas: dark → branco/branco60; light → preto/preto45.
// ─────────────────────────────────────────────────────────────────────────────
class _HcFlatTab extends StatefulWidget {
  final String label;
  final int index;
  final TabController tabCtrl;
  final bool dark;
  const _HcFlatTab({
    required this.label,
    required this.index,
    required this.tabCtrl,
    this.dark = true,
  });
  @override
  State<_HcFlatTab> createState() => _HcFlatTabState();
}

class _HcFlatTabState extends State<_HcFlatTab> {
  @override
  void initState() {
    super.initState();
    widget.tabCtrl.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.tabCtrl.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.tabCtrl.index == widget.index;
    // BUILD 331: dark → branco; light → preto — máxima hierarquia de leitura
    final activeColor = widget.dark ? Colors.white : const Color(0xFF0F1116);
    final inactiveColor = widget.dark
        ? Colors.white60
        : const Color(0xFF0F1116).withOpacity(0.45);
    return GestureDetector(
      onTap: () => widget.tabCtrl.animateTo(widget.index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: isActive
                ? const BorderSide(color: Color(0xFF00E5FF), width: 2.0)
                : BorderSide.none,
          ),
        ),
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? activeColor : inactiveColor,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DA LISTA
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final ClinicalHistoryModel h;
  final AppProvider p;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePublic;
  final bool readOnly;
  // Controles de moderação (admin/supervisor)
  final VoidCallback? onModHide;
  final VoidCallback? onModDelete;
  const _HistoryCard({
    required this.h, required this.p, required this.onTap,
    this.onEdit, this.onDelete, this.onTogglePublic, this.readOnly = false,
    this.onModHide, this.onModDelete,
  });

  Color get _outcomeColor {
    switch (h.outcome) {
      case 'alta': return const Color(0xFF065F46);
      case 'obito': return const Color(0xFFCC2222);
      case 'transferencia': return const Color(0xFF1E40AF);
      default: return const Color(0xFFC5A365);
    }
  }

  String _outcomeLabel(String lang) {
    switch (h.outcome) {
      case 'alta': return _hcT(lang, 'outcome_alta');
      case 'obito': return _hcT(lang, 'outcome_obito');
      case 'transferencia': return _hcT(lang, 'outcome_transfer');
      default: return _hcT(lang, 'outcome_internado');
    }
  }

  // Cor lateral do card baseada no outcome
  Color get _cardAccent {
    switch (h.outcome) {
      case 'alta':          return const Color(0xFF10B981); // verde alta
      case 'obito':         return const Color(0xFFEF4444); // vermelho
      case 'transferencia': return const Color(0xFF3B82F6); // azul
      default:              return const Color(0xFFF59E0B); // âmbar internado
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = p.lang;
    final completion = h.completionRatio;
    final accent = _cardAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1C2230) : Colors.white,
          border: Border.all(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE8EDF2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Barra colorida lateral (accent do outcome) ──────────────
              Container(
                width: 4,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  color: accent,
                ),
              ),
              // ── Conteúdo principal ───────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ── LINHA 1: categoria + data ──────────────────────────
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: accent.withOpacity(0.12),
                        ),
                        child: Text(
                          h.category,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: accent),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                        ),
                        child: Text(
                          _outcomeLabel(lang),
                          style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white60 : const Color(0xFF666666),
                          ),
                        ),
                      ),
                      if (h.isPublic) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: const Color(0xFF3B82F6).withOpacity(0.10),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.public_rounded, size: 8, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 3),
                            Text(_hcT(lang, 'public_badge'),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF3B82F6))),
                          ]),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        h.formattedDate,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : const Color(0xFFAAAAAA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 9),

                    // ── LINHA 2: Título principal ──────────────────────────
                    Text(
                      h.displayTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0D1B2A),
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // ── LINHA 3: Paciente (se houver) ─────────────────────
                    if (h.patientInitials.isNotEmpty || h.patientAge.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.person_rounded, size: 11,
                          color: isDark ? Colors.white38 : const Color(0xFFAAAAAA)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (h.patientInitials.isNotEmpty) h.patientInitials,
                              if (h.patientAge.isNotEmpty) '${h.patientAge} ${_hcT(p.lang, "years")}',
                              if (h.patientSex.isNotEmpty) h.patientSex,
                              if (h.patientWeight.isNotEmpty) '${h.patientWeight} kg',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : const Color(0xFF778899),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ]),
                    ],

                    // ── LINHA 4: Diagnóstico em destaque ──────────────────
                    if (h.finalDiagnosis.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFF065F46).withOpacity(0.08),
                          border: Border.all(color: const Color(0xFF065F46).withOpacity(0.20)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF065F46)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            'Dx: ${h.finalDiagnosis}',
                            style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                            ),
                            overflow: TextOverflow.ellipsis,
                          )),
                        ]),
                      ),
                    ] else if (h.workingDiagnosis.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF59E0B).withOpacity(0.08),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.pending_rounded, size: 13, color: Color(0xFF92400E)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            '${p.lang == "es" ? "Hip." : "Hip."}: ${h.workingDiagnosis}',
                            style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          )),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // ── LINHA 5: Progresso ────────────────────────────────
                    Row(children: [
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completion,
                          minHeight: 3,
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFEEF2F7),
                          valueColor: AlwaysStoppedAnimation(
                            completion >= 1.0
                              ? const Color(0xFF10B981)
                              : completion > 0.5
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFF59E0B),
                          ),
                        ),
                      )),
                      const SizedBox(width: 8),
                      Text(
                        '${(completion * 100).round()}%',
                        style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w900,
                          color: completion >= 1.0
                              ? const Color(0xFF10B981)
                              : isDark ? Colors.white38 : const Color(0xFFAAAAAA),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 10),

                    // ── LINHA 6: Rodapé (ações ou autor) ──────────────────
                    if (!readOnly) ...[
                      // Divisor sutil
                      Divider(
                        height: 1, thickness: 0.5,
                        color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEEF2F7),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        GestureDetector(
                          onTap: onTogglePublic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: h.isPublic
                                  ? const Color(0xFF3B82F6).withOpacity(0.10)
                                  : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F7FA)),
                              border: Border.all(
                                color: h.isPublic
                                    ? const Color(0xFF3B82F6).withOpacity(0.30)
                                    : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFDDE3ED)),
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                h.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                                size: 11,
                                color: h.isPublic ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                h.isPublic ? _hcT(p.lang, 'public_badge') : _hcT(p.lang, 'private_badge'),
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w800,
                                  color: h.isPublic ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onEdit,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kGold.withOpacity(0.10),
                            ),
                            child: const Icon(Icons.edit_rounded, size: 14, color: kGold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFEF4444).withOpacity(0.08),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.of(context).darkBtn,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Text(_hcT(p.lang, 'open'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kGoldLight)),
                          ),
                        ),
                      ]),
                    ] else ...[
                      // Banner de HC oculta
                      if (h.isHidden) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.orange.withOpacity(0.08),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.visibility_off_rounded, size: 11, color: Colors.orange),
                            const SizedBox(width: 5),
                            Text(_hcT(p.lang, 'hidden_mod'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Divisor sutil
                      Divider(
                        height: 1, thickness: 0.5,
                        color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEEF2F7),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFEEF2F7),
                          ),
                          child: Icon(Icons.person_rounded, size: 14,
                            color: isDark ? Colors.white38 : const Color(0xFFAAAAAA)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            h.authorName.isNotEmpty ? h.authorName : _hcT(p.lang, 'anon'),
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white70 : const Color(0xFF2D3748),
                            ),
                          ),
                          if (h.uploadedAt.isNotEmpty)
                            Text(
                              _formatUploadedAt(h.uploadedAt),
                              style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white30 : const Color(0xFFAAAAAA),
                              ),
                            ),
                        ])),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.of(context).darkBtn,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Text(_hcT(p.lang, 'view'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kGoldLight)),
                          ),
                        ),
                      ]),
                    ],

                    // ── Botões de moderação (admin/supervisor) ─────────────
                    if (onModHide != null || onModDelete != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        if (onModHide != null)
                          GestureDetector(
                            onTap: onModHide,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.orange.withOpacity(0.08),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(h.isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 12, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(h.isHidden ? _hcT(p.lang, 'show_mod') : _hcT(p.lang, 'hide_mod'),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange)),
                              ]),
                            ),
                          ),
                        if (onModHide != null && onModDelete != null) const SizedBox(width: 8),
                        if (onModDelete != null)
                          GestureDetector(
                            onTap: onModDelete,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.red.withOpacity(0.07),
                                border: Border.all(color: Colors.red.withOpacity(0.25)),
                              ),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.delete_forever_rounded, size: 12, color: Colors.red),
                                SizedBox(width: 4),
                                Text('Excluir', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red)),
                              ]),
                            ),
                          ),
                      ]),
                    ],

                  ]),          // ← Column children end
                ),             // ← Padding end
              ),               // ← Expanded end
            ]),                // ← Row children end (accent bar + Expanded)
          ),                   // ← IntrinsicHeight end
        ),                     // ← Container (card) end
    );                         // ← GestureDetector end
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISUALIZADOR COMPLETO
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryDetail extends StatefulWidget {
  final ClinicalHistoryModel history;
  final AppProvider p;
  final bool readOnly;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _HistoryDetail({required this.history, required this.p, required this.readOnly, required this.onBack, this.onEdit, this.onDelete});

  @override
  State<_HistoryDetail> createState() => _HistoryDetailState();
}

class _HistoryDetailState extends State<_HistoryDetail> {
  final _printKey = GlobalKey();
  bool _exporting = false;

  ClinicalHistoryModel get history => widget.history;
  AppProvider get p => widget.p;
  bool get readOnly => widget.readOnly;

  void _copy() {
    final lang = p.lang;
    final buf = StringBuffer();

    // ══ ENCABEZADO ══════════════════════════════════════════════════════════
    buf.writeln(_hcT(lang, 'copy_header'));
    buf.writeln('${_hcT(lang, 'copy_date')} ${history.formattedDate}');
    if (history.authorName.isNotEmpty) {
      buf.writeln('${_hcT(lang, 'copy_author')} ${history.authorName}'
          '${history.authorEmail.isNotEmpty ? " <${history.authorEmail}>" : ""}');
    }

    // ── 1. DATOS DE FILIACIÓN Y ADMINISTRATIVOS ──────────────────────────
    buf.writeln(_hcT(lang, 'copy_s1'));
    if (history.patientInitials.isNotEmpty)
      buf.writeln('${_hcT(lang, 'copy_nombre')} ${history.patientInitials}');
    if (history.patientAge.isNotEmpty)
      buf.writeln('${_hcT(lang, 'copy_edad')} ${history.patientAge} ${_hcT(lang, 'years')}');
    if (history.patientSex.isNotEmpty)
      buf.writeln('${_hcT(lang, 'copy_sexo')} ${history.patientSex}');
    if (history.patientRecord.isNotEmpty)
      buf.writeln('${_hcT(lang, 'copy_dni')} ${history.patientRecord}');
    if (history.patientWeight.isNotEmpty || history.patientHeight.isNotEmpty) {
      final pw = history.patientWeight.isNotEmpty ? '${history.patientWeight} kg' : '';
      final ph = history.patientHeight.isNotEmpty ? '${history.patientHeight} cm' : '';
      buf.writeln('${_hcT(lang, 'copy_peso_talla')} ${[pw, ph].where((s) => s.isNotEmpty).join(' / ')}');
    }

    // ── 2. MOTIVO DE CONSULTA ────────────────────────────────────────────
    if (history.chiefComplaint.isNotEmpty)
      buf.writeln('${_hcT(lang, 'copy_chief')}${history.chiefComplaint}');

    // ── 3. ENFERMEDAD ACTUAL (EA) ─────────────────────────────────────────
    if (history.hpi.isNotEmpty)
      buf.writeln('${_hcT(lang, 'copy_hpi')}${history.hpi}');

    // ── 4. ANTECEDENTES PERSONALES ────────────────────────────────────────
    final hasAnt4 = history.pastHistory.isNotEmpty || history.allergies.isNotEmpty ||
        history.medications.isNotEmpty || history.socialHistory.isNotEmpty ||
        history.reviewOfSystems.isNotEmpty;
    if (hasAnt4) {
      buf.writeln(_hcT(lang, 'copy_s4'));
      if (history.pastHistory.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_past')} ${history.pastHistory}');
      if (history.allergies.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_allerg')} ${history.allergies}');
      if (history.medications.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_meds')} ${history.medications}');
      if (history.socialHistory.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_social')} ${history.socialHistory}');
      if (history.reviewOfSystems.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_rvs')} ${history.reviewOfSystems}');
    }

    // ── 5. ANTECEDENTES FAMILIARES ────────────────────────────────────────
    if (history.familyHistory.isNotEmpty)
      buf.writeln('${_hcT(lang, 'copy_family')}${history.familyHistory}');

    // ── 6. EXAMEN FÍSICO ──────────────────────────────────────────────────
    if (history.vitalSigns.isNotEmpty || history.physicalExam.isNotEmpty) {
      buf.writeln(_hcT(lang, 'copy_s6'));
      if (history.vitalSigns.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_vitals')} ${history.vitalSigns}');
      if (history.physicalExam.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_pe')}${history.physicalExam}');
    }

    // ── 7. ESTUDIOS COMPLEMENTARIOS ───────────────────────────────────────
    if (history.labResults.isNotEmpty || history.imagingResults.isNotEmpty || history.otherResults.isNotEmpty) {
      buf.writeln(_hcT(lang, 'copy_lab'));
      if (history.labResults.isNotEmpty)   buf.writeln(history.labResults);
      if (history.otherResults.isNotEmpty) buf.writeln(history.otherResults);
      if (history.imagingResults.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_img')}${history.imagingResults}');
    }

    // ── 8. IMPRESIÓN DIAGNÓSTICA ──────────────────────────────────────────
    if (history.workingDiagnosis.isNotEmpty || history.differentialDx.isNotEmpty || history.finalDiagnosis.isNotEmpty) {
      buf.writeln(_hcT(lang, 'copy_work_dx'));
      if (history.workingDiagnosis.isNotEmpty) buf.writeln(history.workingDiagnosis);
      if (history.differentialDx.isNotEmpty)   buf.writeln(history.differentialDx);
      if (history.finalDiagnosis.isNotEmpty)
        buf.writeln('${_hcT(lang, 'copy_final_dx')}${history.finalDiagnosis}'
            '${history.cid.isNotEmpty ? " (CIE-10: ${history.cid})" : ""}');
    }

    // ── 9. EVOLUCIÓN CLÍNICA ──────────────────────────────────────────────
    for (final e in history.evolutions) {
      final dt = DateTime.tryParse(e.date);
      final dateStr = dt != null
          ? '${dt.day.toString().padLeft(2, "0")}/${dt.month.toString().padLeft(2, "0")}/${dt.year} ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}'
          : '';
      buf.writeln('${_hcT(lang, "copy_evol")}($dateStr — ${e.author}):\n${e.text}');
    }

    // ── 10. INDICACIONES MÉDICAS ──────────────────────────────────────────
    if (history.treatmentPlan.isNotEmpty || history.procedures.isNotEmpty) {
      buf.writeln(_hcT(lang, 'copy_treat'));
      if (history.treatmentPlan.isNotEmpty) buf.writeln(history.treatmentPlan);
      if (history.procedures.isNotEmpty)    buf.writeln(history.procedures);
    }

    // ── 11. EPICRISIS / RESUMEN DE ALTA ──────────────────────────────────
    if (history.outcome != 'internado' || history.dischargeCondition.isNotEmpty || history.followUp.isNotEmpty) {
      buf.writeln('${_hcT(lang, "copy_outcome")}${history.outcome.toUpperCase()}');
      if (history.dischargeCondition.isNotEmpty) buf.writeln(history.dischargeCondition);
      if (history.followUp.isNotEmpty)
        buf.writeln('${_hcT(lang, "copy_followup")}${history.followUp}');
    }

    buf.writeln('\n════════════════════════════════════════════════════════');
    buf.writeln('MedCases Pro — ${_hcT(lang, "pdf_footer")}');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_hcT(lang, "copied")), duration: const Duration(seconds: 1)));
  }

  // ── Exportar como PNG (web: download direto) ──────────────────────────────
  Future<void> _exportPng() async {
    setState(() => _exporting = true);
    try {
      final boundary = _printKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      _downloadBytes(bytes, '${_safeFilename()}.png', 'image/png');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_hcT(p.lang, "export_png_ok")), duration: const Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_hcT(p.lang, "export_png_err")} $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Exportar como PDF (web: janela de impressão | mobile: diálogo nativo) ─
  // Esquema oficial 11 secciones — Argentina — fondo blanco clínico puro
  Future<void> _exportPdf() async {
    final lang = p.lang;
    final buf = StringBuffer();

    // ── CSS: Fondo blanco clínico, tipografía grafito oscuro, divisores dorados finos ─
    buf.write('''<!DOCTYPE html><html lang="es"><head>
<meta charset="utf-8">
<title>Historia Clínica — MedCases Pro</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, "Segoe UI", Arial, sans-serif;
    font-size: 12.5px; color: #1a1a1a; background: #ffffff;
    padding: 36px 44px; line-height: 1.65;
  }
  /* ── Cabeçalho limpo: logo esquerda | metadados direita ── */
  .page-header {
    display: flex; align-items: flex-start; justify-content: space-between;
    padding-bottom: 12px; margin-bottom: 18px;
    border-bottom: 1.5px solid rgba(197,163,101,0.55);
  }
  .logo-block { display: flex; align-items: center; gap: 10px; }
  .logo-badge {
    width: 36px; height: 36px; border-radius: 9px;
    background: #0F2D1C; display: flex; align-items: center; justify-content: center;
    font-size: 13px; font-weight: 900; color: #FFE8A6; letter-spacing: -0.5px;
    flex-shrink: 0;
  }
  .logo-text { font-size: 15px; font-weight: 800; color: #0F2D1C; line-height: 1.2; }
  .logo-sub  { font-size: 10px; font-weight: 500; color: #6b7280; margin-top: 1px; }
  .meta-block { text-align: right; font-size: 10.5px; color: #4b5563; line-height: 1.55; }
  .meta-block .prof { font-weight: 700; color: #1a1a1a; }
  /* ── Título del caso ── */
  .case-title {
    font-size: 19px; font-weight: 800; color: #111827; margin-bottom: 4px;
  }
  .case-sub {
    font-size: 11px; color: #6b7280; margin-bottom: 20px;
    padding-bottom: 14px; border-bottom: 0.5px solid rgba(197,163,101,0.35);
  }
  /* ── Sección: título en bold compacto + divisor dorado ── */
  .section { margin-bottom: 16px; }
  .section-title {
    font-size: 9.5px; font-weight: 900; letter-spacing: 1.8px;
    color: #111827; text-transform: uppercase;
    padding-bottom: 5px; margin-bottom: 9px;
    border-bottom: 0.75px solid rgba(197,163,101,0.6);
  }
  /* ── Etiqueta de campo (gris medio) + valor (grafito oscuro) ── */
  .field-row { display: flex; gap: 16px; flex-wrap: wrap; margin-bottom: 6px; }
  .field-group { flex: 1; min-width: 180px; }
  .field-label {
    font-size: 8.5px; font-weight: 700; color: #6b7280;
    text-transform: uppercase; letter-spacing: 1px;
    margin-bottom: 1px; margin-top: 8px;
  }
  .field-value { font-size: 12.5px; color: #1a1a1a; line-height: 1.6; }
  .field-value-lg { font-size: 14px; font-weight: 700; color: #111827; line-height: 1.5; }
  /* ── Bloco alergias (vermelho discreto) ── */
  .allergy-box {
    background: #fff5f5; border-left: 3px solid #dc2626;
    padding: 8px 12px; margin: 8px 0; border-radius: 4px;
  }
  .allergy-label { font-size: 8.5px; font-weight: 900; color: #dc2626; letter-spacing: 1px; margin-bottom: 3px; }
  .allergy-text  { font-size: 12px; font-weight: 600; color: #991b1b; }
  /* ── Impresión diagnóstica (verde esmeralda discreto) ── */
  .dx-section {
    background: #f0fdf4; border-left: 3px solid #16a34a;
    padding: 10px 14px; margin-bottom: 16px; border-radius: 4px;
  }
  .dx-label { font-size: 8.5px; font-weight: 900; color: #15803d; letter-spacing: 1.4px; margin-bottom: 5px; text-transform: uppercase; }
  .dx-working { font-size: 13.5px; font-weight: 800; color: #14532d; margin-bottom: 4px; }
  .dx-diff    { font-size: 11.5px; color: #166534; margin-top: 4px; }
  .dx-final   {
    font-size: 15px; font-weight: 900; color: #0d4a24;
    margin-top: 8px; padding-top: 8px;
    border-top: 0.5px solid rgba(22,163,74,0.35);
  }
  .cie-tag { font-size: 11px; color: #15803d; font-weight: 700; margin-top: 3px; }
  /* ── Evolución: línea dorada izquierda ── */
  .evolution {
    border-left: 2.5px solid rgba(197,163,101,0.75);
    padding-left: 10px; margin-bottom: 11px;
  }
  .evo-meta { font-size: 9.5px; color: #6b7280; font-weight: 700; margin-bottom: 3px; }
  /* ── Epicrisis / Alta ── */
  .outcome-badge {
    display: inline-block; padding: 3px 10px; border-radius: 20px;
    font-size: 11px; font-weight: 800; margin-bottom: 8px;
    background: #f0fdf4; color: #15803d;
    border: 1px solid rgba(22,163,74,0.4);
  }
  /* ── Pie de página ── */
  .footer {
    margin-top: 28px; font-size: 9px; color: #9ca3af;
    text-align: center; border-top: 0.5px solid rgba(197,163,101,0.4);
    padding-top: 10px; line-height: 1.5;
  }
  @media print {
    body { padding: 18px 22px; }
    .page-header { break-inside: avoid; }
    .section { break-inside: avoid; }
  }
</style>
</head><body>
''');

    // ── Cabeçalho da página: logo [M+] à esquerda | metadados do profissional à direita ──
    buf.write('<div class="page-header">');
    buf.write('<div class="logo-block">');
    buf.write('<div class="logo-badge">M+</div>');
    buf.write('<div><div class="logo-text">MedCases Pro</div>');
    buf.write('<div class="logo-sub">Historia Clínica Oficial</div></div>');
    buf.write('</div>');
    buf.write('<div class="meta-block">');
    if (history.authorName.isNotEmpty) {
      buf.write('<div class="prof">${_esc(history.authorName)}</div>');
      if (history.authorEmail.isNotEmpty)
        buf.write('<div>${_esc(history.authorEmail)}</div>');
    }
    buf.write('<div>${history.category.isNotEmpty ? _esc(history.category) : "Clínica General"}</div>');
    buf.write('<div>${history.formattedDate}</div>');
    buf.write('</div></div>');

    // ── Título del caso ──
    buf.write('<div class="case-title">${_esc(history.displayTitle)}</div>');
    buf.write('<div class="case-sub">');
    buf.write('Historia Clínica Completa');
    if (history.tags.isNotEmpty) buf.write(' &nbsp;·&nbsp; ${_esc(history.tags)}');
    buf.write('</div>');

    // ══════════════════════════════════════════════════════════════════════
    // FUNCIÓN auxiliar: sección simple con campos
    // ══════════════════════════════════════════════════════════════════════
    void sec(String title, List<(String, String)> fields, {bool large = false}) {
      final hasContent = fields.any((f) => f.$2.isNotEmpty);
      if (!hasContent) return;
      buf.write('<div class="section"><div class="section-title">$title</div>');
      for (final f in fields) {
        if (f.$2.isEmpty) continue;
        buf.write('<div class="field-label">${f.$1}</div>');
        buf.write('<div class="${large ? "field-value-lg" : "field-value"}">${_escNl(f.$2)}</div>');
      }
      buf.write('</div>');
    }

    // ══ 1. DATOS DE FILIACIÓN Y ADMINISTRATIVOS ════════════════════════════
    final hasSec1 = history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty ||
        history.patientSex.isNotEmpty || history.patientRecord.isNotEmpty ||
        history.patientWeight.isNotEmpty || history.patientHeight.isNotEmpty;
    if (hasSec1) {
      buf.write('<div class="section"><div class="section-title">${_hcT(lang, "pdf_section1")}</div>');
      // Fila superior: Nombre | Edad+Sexo | DNI
      buf.write('<div class="field-row">');
      if (history.patientInitials.isNotEmpty) {
        buf.write('<div class="field-group">');
        buf.write('<div class="field-label">${_hcT(lang, "pdf_initials")}</div>');
        buf.write('<div class="field-value">${_esc(history.patientInitials)}</div>');
        buf.write('</div>');
      }
      if (history.patientAge.isNotEmpty || history.patientSex.isNotEmpty) {
        buf.write('<div class="field-group">');
        buf.write('<div class="field-label">${_hcT(lang, "pdf_demog")}</div>');
        buf.write('<div class="field-value">');
        if (history.patientAge.isNotEmpty) buf.write('${history.patientAge} ${_hcT(lang, "years")}');
        if (history.patientAge.isNotEmpty && history.patientSex.isNotEmpty) buf.write(' &nbsp;·&nbsp; ');
        if (history.patientSex.isNotEmpty) buf.write(_esc(history.patientSex));
        buf.write('</div></div>');
      }
      if (history.patientRecord.isNotEmpty) {
        buf.write('<div class="field-group">');
        buf.write('<div class="field-label">${_hcT(lang, "pdf_record")}</div>');
        buf.write('<div class="field-value">${_esc(history.patientRecord)}</div>');
        buf.write('</div>');
      }
      buf.write('</div>');
      // Fila inferior: Peso/Talla | Fecha ingreso
      if (history.patientWeight.isNotEmpty || history.patientHeight.isNotEmpty) {
        buf.write('<div class="field-row">');
        buf.write('<div class="field-group">');
        buf.write('<div class="field-label">Peso / Talla</div>');
        buf.write('<div class="field-value">');
        if (history.patientWeight.isNotEmpty) buf.write('${history.patientWeight} kg');
        if (history.patientWeight.isNotEmpty && history.patientHeight.isNotEmpty) buf.write(' &nbsp;·&nbsp; ');
        if (history.patientHeight.isNotEmpty) buf.write('${history.patientHeight} cm');
        buf.write('</div></div>');
        buf.write('<div class="field-group">');
        buf.write('<div class="field-label">${_hcT(lang, "pdf_ingreso")}</div>');
        buf.write('<div class="field-value">${history.formattedDate}</div>');
        buf.write('</div></div>');
      }
      buf.write('</div>');
    }

    // ══ 2. MOTIVO DE CONSULTA ══════════════════════════════════════════════
    if (history.chiefComplaint.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(lang, "pdf_section2")}</div>');
      buf.write('<div class="field-value-lg">${_escNl(history.chiefComplaint)}</div>');
      buf.write('</div>');
    }

    // ══ 3. ENFERMEDAD ACTUAL (EA) ══════════════════════════════════════════
    sec(_hcT(lang, 'pdf_section3'), [
      (_hcT(lang, 'pdf_hpi'), history.hpi),
    ]);

    // ══ 4. ANTECEDENTES PERSONALES ════════════════════════════════════════
    final hasSec4 = history.pastHistory.isNotEmpty || history.allergies.isNotEmpty ||
        history.medications.isNotEmpty || history.socialHistory.isNotEmpty ||
        history.reviewOfSystems.isNotEmpty;
    if (hasSec4) {
      buf.write('<div class="section"><div class="section-title">${_hcT(lang, "pdf_section4")}</div>');
      if (history.pastHistory.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(lang, "pdf_past")}</div>');
        buf.write('<div class="field-value">${_escNl(history.pastHistory)}</div>');
      }
      if (history.allergies.isNotEmpty) {
        buf.write('<div class="allergy-box">');
        buf.write('<div class="allergy-label">⚠ ${_hcT(lang, "pdf_allerg")}</div>');
        buf.write('<div class="allergy-text">${_esc(history.allergies)}</div>');
        buf.write('</div>');
      }
      if (history.medications.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(lang, "pdf_meds")}</div>');
        buf.write('<div class="field-value">${_escNl(history.medications)}</div>');
      }
      if (history.socialHistory.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(lang, "pdf_social")}</div>');
        buf.write('<div class="field-value">${_escNl(history.socialHistory)}</div>');
      }
      if (history.reviewOfSystems.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(lang, "pdf_rvs")}</div>');
        buf.write('<div class="field-value">${_escNl(history.reviewOfSystems)}</div>');
      }
      buf.write('</div>');
    }

    // ══ 5. ANTECEDENTES FAMILIARES ════════════════════════════════════════
    sec(_hcT(lang, 'pdf_section5'), [
      (_hcT(lang, 'pdf_family'), history.familyHistory),
    ]);

    // ══ 6. EXAMEN FÍSICO ══════════════════════════════════════════════════
    if (history.vitalSigns.isNotEmpty || history.physicalExam.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(lang, "pdf_section6")}</div>');
      if (history.vitalSigns.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(lang, "pdf_vitals")}</div>');
        buf.write('<div class="field-value" style="font-family:monospace;font-size:12px">${_escNl(history.vitalSigns)}</div>');
      }
      if (history.physicalExam.isNotEmpty) {
        buf.write('<div class="field-label" style="margin-top:10px">${_hcT(lang, "pdf_pe")}</div>');
        buf.write('<div class="field-value">${_escNl(history.physicalExam)}</div>');
      }
      buf.write('</div>');
    }

    // ══ 7. ESTUDIOS COMPLEMENTARIOS ══════════════════════════════════════
    if (history.labResults.isNotEmpty || history.imagingResults.isNotEmpty || history.otherResults.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(lang, "pdf_section7")}</div>');
      if (history.labResults.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(lang, "pdf_lab")}</div>');
        buf.write('<div class="field-value">${_escNl(history.labResults)}</div>');
      }
      if (history.otherResults.isNotEmpty) {
        buf.write('<div class="field-label" style="margin-top:8px">${_hcT(lang, "pdf_ecg")}</div>');
        buf.write('<div class="field-value">${_escNl(history.otherResults)}</div>');
      }
      if (history.imagingResults.isNotEmpty) {
        buf.write('<div class="field-label" style="margin-top:8px">${_hcT(lang, "pdf_img")}</div>');
        buf.write('<div class="field-value">${_escNl(history.imagingResults)}</div>');
      }
      buf.write('</div>');
    }

    // ══ 8. IMPRESIÓN DIAGNÓSTICA ══════════════════════════════════════════
    if (history.workingDiagnosis.isNotEmpty || history.differentialDx.isNotEmpty || history.finalDiagnosis.isNotEmpty) {
      buf.write('<div class="dx-section">');
      buf.write('<div class="dx-label">${_hcT(lang, "pdf_section8")}</div>');
      if (history.workingDiagnosis.isNotEmpty)
        buf.write('<div class="dx-working">${_esc(history.workingDiagnosis)}</div>');
      if (history.differentialDx.isNotEmpty)
        buf.write('<div class="dx-diff">${_escNl(history.differentialDx)}</div>');
      if (history.finalDiagnosis.isNotEmpty) {
        buf.write('<div class="dx-final">${_esc(history.finalDiagnosis)}</div>');
        if (history.cid.isNotEmpty)
          buf.write('<div class="cie-tag">CIE-10: ${_esc(history.cid)}</div>');
      }
      buf.write('</div>');
    }

    // ══ 9. EVOLUCIÓN CLÍNICA ═════════════════════════════════════════════
    if (history.evolutions.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(lang, "pdf_section9")}</div>');
      for (final e in history.evolutions) {
        final dt = DateTime.tryParse(e.date)?.toLocal();
        final ds = dt != null
            ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
            : '';
        final typeMap = {
          'evolution': _hcT(lang, 'evo_med'), 'nursing': _hcT(lang, 'evo_nurs'),
          'lab': _hcT(lang, 'evo_lab'), 'imaging': _hcT(lang, 'evo_img'),
          'procedure': _hcT(lang, 'evo_proc'),
        };
        buf.write('<div class="evolution">');
        buf.write('<div class="evo-meta">${typeMap[e.type] ?? _hcT(lang, "evo_default")} &nbsp;·&nbsp; $ds'
            '${e.author.isNotEmpty ? " &nbsp;·&nbsp; ${_esc(e.author)}" : ""}</div>');
        buf.write('<div class="field-value" style="margin-top:3px">${_escNl(e.text)}</div>');
        buf.write('</div>');
      }
      buf.write('</div>');
    }

    // ══ 10. INDICACIONES MÉDICAS ══════════════════════════════════════════
    if (history.treatmentPlan.isNotEmpty || history.procedures.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(lang, "pdf_section10")}</div>');
      if (history.treatmentPlan.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(lang, "pdf_plan")}</div>');
        buf.write('<div class="field-value">${_escNl(history.treatmentPlan)}</div>');
      }
      if (history.procedures.isNotEmpty) {
        buf.write('<div class="field-label" style="margin-top:8px">${_hcT(lang, "pdf_proc")}</div>');
        buf.write('<div class="field-value">${_escNl(history.procedures)}</div>');
      }
      buf.write('</div>');
    }

    // ══ 11. EPICRISIS / RESUMEN DE ALTA ══════════════════════════════════
    final outcomeLabels = {
      'internado': lang == 'es' ? 'Hospitalizado' : 'Internado',
      'alta': lang == 'es' ? 'Alta hospitalaria' : 'Alta hospitalar',
      'obito': lang == 'es' ? 'Fallecimiento' : 'Óbito',
      'transferencia': lang == 'es' ? 'Traslado' : 'Transferência',
    };
    if (history.outcome != 'internado' || history.dischargeCondition.isNotEmpty || history.followUp.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(lang, "pdf_section11")}</div>');
      buf.write('<div class="outcome-badge">${outcomeLabels[history.outcome] ?? history.outcome}</div>');
      if (history.dischargeCondition.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(lang, "pdf_discharge")}</div>');
        buf.write('<div class="field-value">${_escNl(history.dischargeCondition)}</div>');
      }
      if (history.followUp.isNotEmpty) {
        buf.write('<div class="field-label" style="margin-top:8px">${_hcT(lang, "pdf_followup")}</div>');
        buf.write('<div class="field-value">${_escNl(history.followUp)}</div>');
      }
      buf.write('</div>');
    }

    buf.write('<div class="footer">${_hcT(lang, "pdf_footer")}</div>');
    buf.write('\n</body></html>');

    final htmlStr = buf.toString();

    if (kIsWeb) {
      // Web: abre blob HTML em nova aba para impressão/PDF via browser
      webPlatform.webOpenHtmlPrint(htmlStr);
    } else {
      // Mobile (iOS / Android): usa o pacote printing para abrir diálogo nativo
      await Printing.layoutPdf(
        onLayout: (_) async {
          // Converte HTML para PDF usando o motor do pacote printing
          return Printing.convertHtml(
            format: PdfPageFormat.a4,
            html: htmlStr,
          );
        },
        name: _safeFilename(),
      );
    }
  }

  String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  String _escNl(String s) => _esc(s).replaceAll('\n', '<br>');
  String _safeFilename() => 'HC_${history.displayTitle.replaceAll(RegExp(r'[^a-zA-Z0-9\u00C0-\u024F ]'), '').trim().replaceAll(' ', '_').substring(0, history.displayTitle.length.clamp(0, 30))}_${history.formattedDate.replaceAll('/', '-')}';

  void _downloadBytes(Uint8List bytes, String filename, String mime) {
    webPlatform.webDownloadBytes(bytes, filename, mime);
  }

  @override
  Widget build(BuildContext context) {
    final bp = MedBreakpoints.of(context);
    return Stack(children: [
      // ── Conteúdo principal scrollável ──────────────────────────────────────
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ══ HEADER HERO ══════════════════════════════════════════════════════
          // Desktop: gradiente completo com decorações.
          // Mobile/tablet: compacto sem gradiente (shell AppBar já no topo).
          if (bp.isDesktop)
          _HistoryHeroHeader(
            history: history,
            readOnly: readOnly,
            onBack: widget.onBack,
            onEdit: widget.onEdit,
            lang: p.lang,
          )
          else
          _HistoryHeroHeaderCompact(
            history: history,
            readOnly: readOnly,
            onBack: widget.onBack,
            onEdit: widget.onEdit,
            lang: p.lang,
          ),
          const SizedBox(height: 14),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ══ PNG CANVAS — fondo blanco clínico puro, esquema 11 secciones ══
              RepaintBoundary(
                key: _printKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ── Cabeçalho da imagem: [M+] logo esq | metadados prof dir ─
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Logo badge
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2D1C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('M+',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                                color: Color(0xFFFFE8A6), letterSpacing: -0.5))),
                      ),
                      const SizedBox(width: 9),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('MedCases Pro',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                                color: Color(0xFF0F2D1C))),
                        Text('Historia Clínica Oficial',
                            style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (history.authorName.isNotEmpty)
                          Text(history.authorName,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: Color(0xFF1a1a1a))),
                        Text(history.category.isNotEmpty ? history.category : 'Clínica General',
                            style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                        Text(history.formattedDate,
                            style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                      ]),
                    ]),

                    // Divisor dorado fino
                    const SizedBox(height: 10),
                    Container(height: 1.5,
                        color: const Color(0xFFC5A365).withOpacity(0.55)),
                    const SizedBox(height: 10),

                    // Título do caso
                    Text(history.displayTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 12),

                    // ── Widget helper para seção com divisor dourado ────────────
                    // (definido inline via funções locais não é possível — usamos
                    //  _PngSection widgets abaixo)

                    // ── 1. DATOS DE FILIACIÓN ────────────────────────────────
                    if (history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section1'),
                        children: [
                          if (history.patientInitials.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_initials'), history.patientInitials),
                          _PngField(_hcT(p.lang, 'pdf_demog'),
                            [
                              if (history.patientAge.isNotEmpty) '${history.patientAge} ${_hcT(p.lang, 'years')}',
                              if (history.patientSex.isNotEmpty) history.patientSex,
                            ].join('  ·  ')),
                          if (history.patientRecord.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_record'), history.patientRecord),
                          if (history.patientWeight.isNotEmpty || history.patientHeight.isNotEmpty)
                            _PngField('Peso / Talla',
                              [
                                if (history.patientWeight.isNotEmpty) '${history.patientWeight} kg',
                                if (history.patientHeight.isNotEmpty) '${history.patientHeight} cm',
                              ].join('  ·  ')),
                        ],
                      ),

                    // ── 2. MOTIVO DE CONSULTA ────────────────────────────────
                    if (history.chiefComplaint.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section2'),
                        children: [_PngField('', history.chiefComplaint, large: true)],
                      ),

                    // ── 3. ENFERMEDAD ACTUAL ──────────────────────────────────
                    if (history.hpi.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section3'),
                        children: [_PngField(_hcT(p.lang, 'pdf_hpi'), history.hpi)],
                      ),

                    // ── 4. ANTECEDENTES PERSONALES ────────────────────────────
                    if (history.pastHistory.isNotEmpty || history.allergies.isNotEmpty ||
                        history.medications.isNotEmpty || history.socialHistory.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section4'),
                        children: [
                          if (history.pastHistory.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_past'), history.pastHistory),
                          if (history.allergies.isNotEmpty)
                            _PngAllergyField(history.allergies),
                          if (history.medications.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_meds'), history.medications),
                          if (history.socialHistory.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_social'), history.socialHistory),
                          if (history.reviewOfSystems.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_rvs'), history.reviewOfSystems),
                        ],
                      ),

                    // ── 5. ANTECEDENTES FAMILIARES ────────────────────────────
                    if (history.familyHistory.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section5'),
                        children: [_PngField(_hcT(p.lang, 'pdf_family'), history.familyHistory)],
                      ),

                    // ── 6. EXAMEN FÍSICO ──────────────────────────────────────
                    if (history.vitalSigns.isNotEmpty || history.physicalExam.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section6'),
                        children: [
                          if (history.vitalSigns.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_vitals'), history.vitalSigns, mono: true),
                          if (history.physicalExam.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_pe'), history.physicalExam),
                        ],
                      ),

                    // ── 7. ESTUDIOS COMPLEMENTARIOS ───────────────────────────
                    if (history.labResults.isNotEmpty || history.imagingResults.isNotEmpty || history.otherResults.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section7'),
                        children: [
                          if (history.labResults.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_lab'), history.labResults),
                          if (history.otherResults.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_ecg'), history.otherResults),
                          if (history.imagingResults.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_img'), history.imagingResults),
                        ],
                      ),

                    // ── 8. IMPRESIÓN DIAGNÓSTICA ──────────────────────────────
                    if (history.workingDiagnosis.isNotEmpty || history.differentialDx.isNotEmpty || history.finalDiagnosis.isNotEmpty)
                      _PngDxSection(
                        title: _hcT(p.lang, 'pdf_section8'),
                        working: history.workingDiagnosis,
                        differential: history.differentialDx,
                        final_: history.finalDiagnosis,
                        cid: history.cid,
                      ),

                    // ── 9. EVOLUCIÓN CLÍNICA ──────────────────────────────────
                    if (history.evolutions.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section9'),
                        children: history.evolutions.map((e) {
                          final dt = DateTime.tryParse(e.date);
                          final ds = dt != null
                              ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
                              : '';
                          return _PngEvolution(dateStr: ds, author: e.author, text: e.text);
                        }).toList(),
                      ),

                    // ── 10. INDICACIONES MÉDICAS ──────────────────────────────
                    if (history.treatmentPlan.isNotEmpty || history.procedures.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section10'),
                        children: [
                          if (history.treatmentPlan.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_plan'), history.treatmentPlan),
                          if (history.procedures.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_proc'), history.procedures),
                          if (history.drugIds.isNotEmpty) _DrugChips(history.drugIds, p),
                        ],
                      ),

                    // ── 11. EPICRISIS / RESUMEN DE ALTA ──────────────────────
                    if (history.outcome != 'internado' || history.dischargeCondition.isNotEmpty || history.followUp.isNotEmpty)
                      _PngSection(
                        title: _hcT(p.lang, 'pdf_section11'),
                        children: [
                          _PngOutcomeBadge(history.outcome, p.lang),
                          if (history.dischargeCondition.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_discharge'), history.dischargeCondition),
                          if (history.followUp.isNotEmpty)
                            _PngField(_hcT(p.lang, 'pdf_followup'), history.followUp),
                        ],
                      ),

                    // ── Pie / footer ──────────────────────────────────────────
                    const SizedBox(height: 12),
                    Container(height: 0.5,
                        color: const Color(0xFFC5A365).withOpacity(0.4)),
                    const SizedBox(height: 6),
                    Text(_hcT(p.lang, 'pdf_footer'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 8.5, color: Colors.grey[400])),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // ── Ações ──────────────────────────────────────────────────────
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: _copy,
                  child: Container(height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDark, boxShadow: [BoxShadow(color: kDark.withOpacity(0.25), blurRadius: 10, offset: const Offset(0,4))]),
                    child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.copy_rounded, size: 14, color: kGoldLight),
                      const SizedBox(width: 6),
                      Text(_hcT(p.lang, 'copy_hc'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGoldLight)),
                    ]))),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _exportPdf,
                  child: Container(
                    height: 48, width: 48,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF1E40AF), boxShadow: [BoxShadow(color: const Color(0xFF1E40AF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0,3))]),
                    child: const Center(child: Icon(Icons.picture_as_pdf_rounded, size: 20, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _exporting ? null : _exportPng,
                  child: Container(
                    height: 48, width: 48,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF065F46), boxShadow: [BoxShadow(color: const Color(0xFF065F46).withOpacity(0.3), blurRadius: 8, offset: const Offset(0,3))]),
                    child: Center(child: _exporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.image_rounded, size: 20, color: Colors.white)),
                  ),
                ),
                if (!readOnly && widget.onDelete != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(height: 48, width: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFCCCC)), color: const Color(0xFFFFF0F0)),
                      child: const Center(child: Icon(Icons.delete_rounded, size: 18, color: Color(0xFFCC2222)))),
                  ),
                ],
              ]),

              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.info_outline_rounded, size: 11, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(_hcT(p.lang, 'pdf_hint'), style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
              ]),
            ],
          )),
        ]),
      ),

      // ══ FAB INFERIOR — Editar / Nova Evolução ═══════════════════════════════
      if (!readOnly && widget.onEdit != null)
        Positioned(
          bottom: 20,
          right: 20,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // FAB principal — editar
            GestureDetector(
              onTap: widget.onEdit,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10B981), Color(0xFF0A3D2A)],
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: const Center(child: Icon(Icons.edit_rounded, size: 22, color: Color(0xFFFFE8A6))),
              ),
            ),
          ]),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER HERO — card verde escuro com gradiente
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryHeroHeader extends StatelessWidget {
  final ClinicalHistoryModel history;
  final bool readOnly;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final String lang;

  const _HistoryHeroHeader({
    required this.history,
    required this.readOnly,
    required this.onBack,
    this.onEdit,
    this.lang = 'pt',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071A10), Color(0xFF0F2D1C), Color(0xFF155131), Color(0xFF10B981)],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [BoxShadow(color: Color(0x551F6B48), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Stack(children: [
        // Ícone decorativo de fundo
        Positioned(
          right: -18, top: -18,
          child: Icon(Icons.medical_information_rounded, size: 140,
            color: Colors.white.withOpacity(0.04)),
        ),
        Positioned(
          right: 60, bottom: -10,
          child: Icon(Icons.local_hospital_rounded, size: 80,
            color: Colors.white.withOpacity(0.04)),
        ),

        // Conteúdo
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Botão voltar
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_back_ios_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(_hcT(lang, 'back'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.9))),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Categoria badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: const Color(0xFFFFE8A6).withOpacity(0.35)),
              ),
              child: Text(
                history.category.toUpperCase(),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE8A6), letterSpacing: 1.8),
              ),
            ),
            const SizedBox(height: 10),

            // Título principal
            Row(children: [
              Expanded(child: Text(
                history.displayTitle,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: Colors.white, height: 1.2, letterSpacing: -0.3),
              )),
            ]),
            const SizedBox(height: 10),

            // Autor + data
            if (history.authorName.isNotEmpty)
              Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Center(child: Icon(Icons.person_rounded, size: 12, color: Color(0xFF10B981))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    history.authorName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (history.authorEmail.isNotEmpty)
                    Text(history.authorEmail,
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w500)),
                ])),
                if (history.uploadedAt.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Text(
                      _formatUploadedAt(history.uploadedAt),
                      style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w600),
                    ),
                  ),
              ]),

            // Badges do paciente
            if (history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (history.patientInitials.isNotEmpty) _PatientBadge(
                  icon: Icons.badge_rounded, text: history.patientInitials, accent: const Color(0xFF10B981)),
                if (history.patientAge.isNotEmpty) _PatientBadge(
                  icon: Icons.cake_rounded, text: '${history.patientAge} ${_hcT(lang, 'years')}', accent: const Color(0xFF93C5FD)),
                if (history.patientSex.isNotEmpty) _PatientBadge(
                  icon: Icons.wc_rounded, text: history.patientSex, accent: const Color(0xFFF9A8D4)),
                if (history.patientWeight.isNotEmpty) _PatientBadge(
                  icon: Icons.monitor_weight_rounded, text: '${history.patientWeight} kg', accent: const Color(0xFFFBD38D)),
                if (history.patientRecord.isNotEmpty) _PatientBadge(
                  icon: Icons.folder_shared_rounded, text: '${_hcT(lang, 'pront')} ${history.patientRecord}', accent: const Color(0xFFFFE8A6)),
              ]),
            ],

            if (history.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(history.tags, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w500, letterSpacing: 0.3)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER COMPACTO — mobile/tablet (sem gradiente decorativo, shell AppBar já visível)
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryHeroHeaderCompact extends StatelessWidget {
  final ClinicalHistoryModel history;
  final bool readOnly;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final String lang;

  const _HistoryHeroHeaderCompact({
    required this.history,
    required this.readOnly,
    required this.onBack,
    this.onEdit,
    this.lang = 'pt',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071A10), Color(0xFF155131)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Linha 1: botão voltar + categoria badge + (optional) editar
        Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_back_ios_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 3),
                Text(_hcT(lang, 'back'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              history.displayTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.2),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (!readOnly && onEdit != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kGold.withOpacity(0.15),
                  border: Border.all(color: kGold.withOpacity(0.4)),
                ),
                child: const Icon(Icons.edit_rounded, size: 14, color: kGoldLight),
              ),
            ),
          ],
        ]),
        // Linha 2: badges do paciente (se houver)
        if (history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (history.patientInitials.isNotEmpty) _PatientBadge(icon: Icons.badge_rounded, text: history.patientInitials, accent: const Color(0xFF10B981)),
            if (history.patientAge.isNotEmpty) _PatientBadge(icon: Icons.cake_rounded, text: '${history.patientAge} ${_hcT(lang, 'years')}', accent: const Color(0xFF93C5FD)),
            if (history.patientSex.isNotEmpty) _PatientBadge(icon: Icons.wc_rounded, text: history.patientSex, accent: const Color(0xFFF9A8D4)),
          ]),
        ],
      ]),
    );
  }
}

// Badge colorido de dados do paciente
class _PatientBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;
  const _PatientBadge({required this.icon, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withOpacity(0.15),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: accent),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR COMPLETO (com todas as seções)
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryEditor extends StatefulWidget {
  final ClinicalHistoryModel initial;
  final AppProvider p;
  final ValueChanged<ClinicalHistoryModel> onSave;
  final VoidCallback onCancel;
  const _HistoryEditor({required this.initial, required this.p, required this.onSave, required this.onCancel});

  @override
  State<_HistoryEditor> createState() => _HistoryEditorState();
}

class _HistoryEditorState extends State<_HistoryEditor> {
  late ClinicalHistoryModel _draft;
  int _section = 0; // seção ativa do editor

  // Controllers
  late final Map<String, TextEditingController> _ctrls;

  List<(String, String)> get _sections => [
    ('', _hcT(widget.p.lang, 'sec_patient')),
    ('', _hcT(widget.p.lang, 'sec_anamnesis')),
    ('', _hcT(widget.p.lang, 'sec_physical')),
    ('', _hcT(widget.p.lang, 'sec_exams')),
    ('', _hcT(widget.p.lang, 'sec_treatment')),
    ('', _hcT(widget.p.lang, 'sec_evolution')),
    ('', _hcT(widget.p.lang, 'sec_outcome')),
  ];

  static const _categoriesPt = ['Clínica Geral', 'Cardiologia', 'Emergência', 'Pneumologia', 'Neurologia', 'Gastroenterologia', 'Endocrinologia', 'Nefrologia', 'Infectologia', 'Cirurgia', 'Pediatria', 'Ginecologia', 'Ortopedia', 'Outro'];
  static const _categoriesEs = ['Medicina General', 'Cardiología', 'Urgencias', 'Neumología', 'Neurología', 'Gastroenterología', 'Endocrinología', 'Nefrología', 'Infectología', 'Cirugía', 'Pediatría', 'Ginecología', 'Traumatología', 'Otro'];
  List<String> get _categories => widget.p.lang == 'es' ? _categoriesEs : _categoriesPt;
  static const _outcomes = ['internado', 'alta', 'obito', 'transferencia'];
  List<String> get _outcomesLabel => [
    _hcT(widget.p.lang, 'out_internado'),
    _hcT(widget.p.lang, 'out_alta'),
    _hcT(widget.p.lang, 'out_obito'),
    _hcT(widget.p.lang, 'out_transf'),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    // Inicializa FocusNodes para campos ditáveis e adiciona listeners de foco
    for (final key in _kDictableFields) {
      final fn = FocusNode();
      fn.addListener(() {
        if (fn.hasFocus && _smartDictActive && mounted) {
          setState(() => _smartCurrentField = key);
        }
      });
      _fieldFocusNodes[key] = fn;
    }
    _ctrls = {
      'patientInitials': TextEditingController(text: _draft.patientInitials),
      'patientAge': TextEditingController(text: _draft.patientAge),
      'patientWeight': TextEditingController(text: _draft.patientWeight),
      'patientHeight': TextEditingController(text: _draft.patientHeight),
      'patientRecord': TextEditingController(text: _draft.patientRecord),
      'chiefComplaint': TextEditingController(text: _draft.chiefComplaint),
      'hpi': TextEditingController(text: _draft.hpi),
      'pastHistory': TextEditingController(text: _draft.pastHistory),
      'familyHistory': TextEditingController(text: _draft.familyHistory),
      'socialHistory': TextEditingController(text: _draft.socialHistory),
      'medications': TextEditingController(text: _draft.medications),
      'allergies': TextEditingController(text: _draft.allergies),
      'reviewOfSystems': TextEditingController(text: _draft.reviewOfSystems),
      'vitalSigns': TextEditingController(text: _draft.vitalSigns),
      'physicalExam': TextEditingController(text: _draft.physicalExam),
      'workingDiagnosis': TextEditingController(text: _draft.workingDiagnosis),
      'differentialDx': TextEditingController(text: _draft.differentialDx),
      'finalDiagnosis': TextEditingController(text: _draft.finalDiagnosis),
      'cid': TextEditingController(text: _draft.cid),
      'labResults': TextEditingController(text: _draft.labResults),
      'imagingResults': TextEditingController(text: _draft.imagingResults),
      'otherResults': TextEditingController(text: _draft.otherResults),
      'treatmentPlan': TextEditingController(text: _draft.treatmentPlan),
      'procedures': TextEditingController(text: _draft.procedures),
      'dischargeCondition': TextEditingController(text: _draft.dischargeCondition),
      'followUp': TextEditingController(text: _draft.followUp),
      'tags': TextEditingController(text: _draft.tags),
    };
  }

  @override
  void dispose() {
    _sttRecog?.stop();          // Web: para WebSpeechRecognizer
    _relatoRecog?.stop();       // Web: para relato livre
    SttHelper.stop();           // Mobile: para speech_to_text nativo
    for (final c in _ctrls.values) c.dispose();
    for (final fn in _fieldFocusNodes.values) fn.dispose();
    super.dispose();
  }

  // ── STT (Speech-to-Text) — Web via dart:html | Mobile via speech_to_text ──
  String? _sttActiveKey;   // chave do campo atualmente ouvindo
  bool _sttListening = false;
  String _sttInterim = '';
  // Web: usa WebSpeechRecognizer; Mobile: usa SttHelper (speech_to_text plugin)
  webPlatform.WebSpeechRecognizer? _sttRecog;

  // ── Ditáfone inteligente global ─────────────────────────────────────────
  bool _smartDictActive = false;   // ditáfone global ativo
  String _smartCurrentField = '';  // campo ativo atual (para feedback)
  String _smartInterim = '';       // texto interim do ditáfone
  webPlatform.WebSpeechRecognizer? _smartRecog;

  // ── FocusNodes por campo ditável — rastreia campo focado pelas setas ────
  // Permite atualizar _smartCurrentField ao navegar com prev/nextFocus
  final Map<String, FocusNode> _fieldFocusNodes = {};
  static const _kDictableFields = [
    'chiefComplaint', 'hpi', 'pastHistory', 'familyHistory', 'socialHistory',
    'medications', 'allergies', 'reviewOfSystems', 'vitalSigns', 'physicalExam',
    'workingDiagnosis', 'treatmentPlan', 'procedures', 'dischargeCondition', 'followUp',
  ];

  // ── Relato Livre — captura contínua → IA estrutura nos campos ────────────
  bool   _relatoActive    = false;  // gravação de relato livre ativa
  bool   _aiProcessing    = false;  // IA processando a transcrição
  String _relatoBuffer    = '';     // buffer acumulado de texto final
  String _relatoInterim   = '';     // texto interim (exibido em tempo real)
  webPlatform.WebSpeechRecognizer? _relatoRecog; // Web recognizer do relato

  // ── Barra de controle — expandida / recolhida ────────────────────────────
  bool _micBarExpanded = false;

  // Mapa de palavras-gatilho → chave do campo
  static const _kTriggers = {
    // Queixa principal
    'queixa principal': 'chiefComplaint', 'queixa': 'chiefComplaint',
    'motivo da consulta': 'chiefComplaint', 'motivo': 'chiefComplaint',
    'chief complaint': 'chiefComplaint', 'queja principal': 'chiefComplaint',
    // HDA
    'história da doença atual': 'hpi', 'hda': 'hpi',
    'historia da doença': 'hpi', 'história atual': 'hpi',
    'historia de la enfermedad': 'hpi', 'hda atual': 'hpi',
    'doença atual': 'hpi', 'história': 'hpi',
    // Antecedentes pessoais
    'antecedentes pessoais': 'pastHistory', 'antecedentes': 'pastHistory',
    'história patológica': 'pastHistory', 'patológico': 'pastHistory',
    'antecedentes patológicos': 'pastHistory',
    'antecedentes personales': 'pastHistory',
    // Antecedentes familiares
    'antecedentes familiares': 'familyHistory', 'família': 'familyHistory',
    'historia familiar': 'familyHistory', 'familiar': 'familyHistory',
    // História social
    'história social': 'socialHistory', 'social': 'socialHistory',
    'hábitos': 'socialHistory', 'historia social': 'socialHistory',
    'tabagismo': 'socialHistory', 'etilismo': 'socialHistory',
    // Medicamentos
    'medicamentos': 'medications', 'medicações': 'medications',
    'medicação': 'medications', 'medicación': 'medications',
    'remédios': 'medications', 'uso contínuo': 'medications',
    'em uso': 'medications',
    // Alergias
    'alergias': 'allergies', 'alergia': 'allergies',
    'alergias a': 'allergies', 'hipersensibilidade': 'allergies',
    // Revisão de sistemas
    'revisão de sistemas': 'reviewOfSystems', 'revisão': 'reviewOfSystems',
    'revisión de sistemas': 'reviewOfSystems',
    'sistemas': 'reviewOfSystems',
    // Sinais vitais
    'sinais vitais': 'vitalSigns', 'vitais': 'vitalSigns',
    'pressão arterial': 'vitalSigns', 'frequência cardíaca': 'vitalSigns',
    'temperatura': 'vitalSigns', 'saturação': 'vitalSigns',
    'signos vitales': 'vitalSigns',
    // Exame físico
    'exame físico': 'physicalExam', 'exame': 'physicalExam',
    'examen físico': 'physicalExam', 'físico': 'physicalExam',
    'exame geral': 'physicalExam', 'ausculta': 'physicalExam',
    'abdome': 'physicalExam', 'tórax': 'physicalExam',
    // Hipótese / diagnóstico
    'hipótese': 'workingDiagnosis', 'hipótese diagnóstica': 'workingDiagnosis',
    'diagnóstico de trabalho': 'workingDiagnosis',
    'diagnóstico provável': 'workingDiagnosis',
    // Conduta / tratamento
    'conduta': 'treatmentPlan', 'tratamento': 'treatmentPlan',
    'plano': 'treatmentPlan', 'plan': 'treatmentPlan',
    'tratamiento': 'treatmentPlan',
  };

  // Determina o campo de destino a partir do texto transcrito
  String _detectFieldFromText(String text) {
    final lower = text.toLowerCase();
    // Busca gatilho mais longo (mais específico) primeiro
    String? bestKey;
    int bestLen = 0;
    for (final entry in _kTriggers.entries) {
      if (lower.contains(entry.key) && entry.key.length > bestLen) {
        bestKey = entry.value;
        bestLen = entry.key.length;
      }
    }
    return bestKey ?? _smartCurrentField;
  }

  // Nome legível do campo para feedback
  String _fieldLabel(String key) {
    final lang = widget.p.lang;
    final labels = {
      'chiefComplaint': _hcT(lang, 'stt_chief'),
      'hpi': _hcT(lang, 'stt_hpi'),
      'pastHistory': _hcT(lang, 'stt_past'),
      'familyHistory': _hcT(lang, 'stt_family'),
      'socialHistory': _hcT(lang, 'stt_social'),
      'medications': _hcT(lang, 'stt_meds'),
      'allergies': _hcT(lang, 'stt_allergies'),
      'reviewOfSystems': _hcT(lang, 'stt_ros'),
      'vitalSigns': _hcT(lang, 'stt_vitals'),
      'physicalExam': _hcT(lang, 'stt_pe'),
      'workingDiagnosis': _hcT(lang, 'stt_wdx'),
      'treatmentPlan': _hcT(lang, 'stt_plan'),
      'evolutionNote': _hcT(lang, 'stt_evol_note'),
    };
    return labels[key] ?? key;
  }

  /// Retorna o campo padrão inicial para cada seção com microfone ativo.
  /// Retorna null para seções sem microfone (0=Paciente, 3=Exames, 6=Desfecho).
  String? _defaultFieldForSection(int section) {
    switch (section) {
      case 1: return 'chiefComplaint';   // Anamnese
      case 2: return 'vitalSigns';       // Exame Físico
      case 4: return 'treatmentPlan';    // Conduta
      case 5: return 'evolutionNote';    // Evolução (sentinel → insere no primeiro card)
      default: return null;              // 0=Paciente, 3=Exames, 6=Desfecho → sem mic
    }
  }

  void _toggleSmartDictaphone() {
    // Esconde teclado antes de ativar — evita overlap teclado+barra
    FocusScope.of(context).unfocus();
    if (_smartDictActive) {
      _smartRecog?.stop();
      SttHelper.stop();
      if (mounted) setState(() { _smartDictActive = false; _smartInterim = ''; _smartCurrentField = ''; });
      return;
    }
    // Para STT de campo individual se estava ativo
    if (_sttListening) _stopAllStt();

    // Campo inicial baseado na seção ativa
    _smartCurrentField = _defaultFieldForSection(_section) ?? 'chiefComplaint';

    final appLang  = widget.p.lang;
    final locale   = appLang == 'es' ? 'es-ES' : 'pt-BR';

    if (kIsWeb) {
      // ── Web: Web Speech API contínua ────────────────────────────────────
      if (!webPlatform.webHasSpeechRecognition()) {
        showDialog(context: context, builder: (_) => AlertDialog(
          title: Text(widget.p.t('dictation_not_supported')),
          content: Text(widget.p.t('dictation_browser_msg')),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ));
        return;
      }
      final recog = webPlatform.WebSpeechRecognizer();
      recog.start('smart', locale,
        onResult: (transcript, isFinal) {
          if (!mounted) return;
          final detected = _detectFieldFromText(transcript);
          if (detected.isNotEmpty && detected != _smartCurrentField) {
            setState(() => _smartCurrentField = detected);
          }
          if (isFinal) {
            String clean = transcript;
            for (final trigger in _kTriggers.keys) {
              clean = clean.replaceAll(RegExp(trigger, caseSensitive: false), '');
            }
            clean = clean.trim().replaceAll(RegExp(r'^[,:\s]+'), '');
            if (clean.isNotEmpty && _smartCurrentField.isNotEmpty) {
              _insertIntoField(_smartCurrentField, clean);
            }
            if (mounted) setState(() => _smartInterim = '');
          } else {
            if (mounted) setState(() {
              _smartInterim = transcript;
              final det = _detectFieldFromText(transcript);
              if (det.isNotEmpty) _smartCurrentField = det;
            });
          }
        },
        onEnd: () {
          if (_smartDictActive && mounted) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_smartDictActive && mounted) _smartRecog?.start('smart', locale,
                onResult: (t, f) {}, onEnd: () {}, onError: (_) {});
            });
          }
        },
        onError: (code) {
          if (code != 'no-speech' && mounted) {
            setState(() { _smartDictActive = false; _smartInterim = ''; });
          }
        },
      );
      _smartRecog = recog;
    } else {
      // ── Mobile: speech_to_text — uma frase por vez, auto-reinicia ────────
      void startMobileLoop() {
        // STT-GUARD: try-catch genérico — erros nativos de áudio (AVAudioSession,
        // SFSpeechRecognizer, MicrophonePermission) não devem fechar o app.
        try {
          SttHelper.start(
            locale: locale,
            onResult: (transcript) {
              if (!mounted) return;
              // Detecta campo por palavra-gatilho
              final detected = _detectFieldFromText(transcript);
              if (detected.isNotEmpty) {
                _smartCurrentField = detected;
              }
              String clean = transcript;
              for (final trigger in _kTriggers.keys) {
                clean = clean.replaceAll(RegExp(trigger, caseSensitive: false), '');
              }
              clean = clean.trim().replaceAll(RegExp(r'^[,:\s]+'), '');
              if (clean.isNotEmpty && _smartCurrentField.isNotEmpty) {
                _insertIntoField(_smartCurrentField, clean);
              }
              if (mounted) setState(() => _smartInterim = '');
            },
            onError: (code) {
              if (!mounted) return;
              if (code == 'no_speech' || code == 'no-speech') {
                // Auto-reinicia silenciosamente
                if (_smartDictActive) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (_smartDictActive && mounted) startMobileLoop();
                  });
                }
                return;
              }
              setState(() { _smartDictActive = false; _smartInterim = ''; });
              _showSttMobileError(code);
            },
            onEnd: () {
              if (_smartDictActive && mounted) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (_smartDictActive && mounted) startMobileLoop();
                });
              }
            },
          );
        } catch (e, st) {
          debugPrint('[HistoryScreen][startMobileLoop] SttHelper.start exception: $e\n$st');
          if (mounted) setState(() { _smartDictActive = false; _smartInterim = ''; });
        }
      }
      startMobileLoop();
    }
    if (mounted) setState(() { _smartDictActive = true; _smartInterim = ''; });
  }

  // ── Relato Livre — toggle de gravação contínua ───────────────────────────
  void _toggleRelatoLivre() {
    // Esconde teclado antes de ativar — evita overlap teclado+barra
    FocusScope.of(context).unfocus();
    if (_relatoActive) {
      // Parar gravação e processar com IA
      _relatoRecog?.stop();
      SttHelper.stop();
      final captured = _relatoBuffer.trim();
      if (mounted) setState(() { _relatoActive = false; _relatoInterim = ''; });
      if (captured.isEmpty) {
        _showRelatoSnack(_hcT(widget.p.lang, 'relato_empty'));
        return;
      }
      _processRelatoWithAI(captured);
      return;
    }

    // Para outros STTs se ativos
    if (_sttListening) _stopAllStt();
    if (_smartDictActive) {
      _smartRecog?.stop();
      SttHelper.stop();
      if (mounted) setState(() { _smartDictActive = false; _smartInterim = ''; _smartCurrentField = ''; });
    }

    _relatoBuffer = '';
    final locale  = widget.p.lang == 'es' ? 'es-ES' : 'pt-BR';

    if (kIsWeb) {
      if (!webPlatform.webHasSpeechRecognition()) {
        showDialog(context: context, builder: (_) => AlertDialog(
          title: Text(_hcT(widget.p.lang, 'dict_not_supported')),
          content: Text(_hcT(widget.p.lang, 'dict_browser_msg')),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ));
        return;
      }
      final recog = webPlatform.WebSpeechRecognizer();
      recog.start('relato', locale,
        onResult: (transcript, isFinal) {
          if (!mounted) return;
          if (isFinal) {
            _relatoBuffer += (_relatoBuffer.isEmpty ? '' : ' ') + transcript.trim();
            if (mounted) setState(() => _relatoInterim = '');
          } else {
            if (mounted) setState(() => _relatoInterim = transcript);
          }
        },
        onEnd: () {
          // Auto-reinicia enquanto relato estiver ativo
          if (_relatoActive && mounted) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_relatoActive && mounted) _relatoRecog?.start('relato', locale,
                onResult: (t, f) {}, onEnd: () {}, onError: (_) {});
            });
          }
        },
        onError: (code) {
          if (code != 'no-speech' && mounted) {
            setState(() { _relatoActive = false; _relatoInterim = ''; });
          }
        },
      );
      _relatoRecog = recog;
    } else {
      // Mobile: captura em loop, acumulando buffer
      void startLoop() {
        // STT-GUARD: try-catch genérico — erros nativos de áudio não devem
        // fechar o app silenciosamente durante o relato livre clínico.
        try {
          SttHelper.start(
            locale: locale,
            onResult: (transcript) {
              if (!mounted || !_relatoActive) return;
              _relatoBuffer += (_relatoBuffer.isEmpty ? '' : ' ') + transcript.trim();
              if (mounted) setState(() => _relatoInterim = '');
            },
            onError: (code) {
              if (!mounted) return;
              if (code == 'no_speech' || code == 'no-speech') {
                if (_relatoActive) Future.delayed(const Duration(milliseconds: 300), startLoop);
                return;
              }
              setState(() { _relatoActive = false; _relatoInterim = ''; });
            },
            onEnd: () {
              if (_relatoActive && mounted) {
                Future.delayed(const Duration(milliseconds: 300), startLoop);
              }
            },
          );
        } catch (e, st) {
          debugPrint('[HistoryScreen][startLoop] SttHelper.start exception: $e\n$st');
          if (mounted) setState(() { _relatoActive = false; _relatoInterim = ''; });
        }
      }
      startLoop();
    }
    if (mounted) setState(() { _relatoActive = true; _relatoInterim = ''; });
  }

  // ── Envia transcrição bruta para IA estruturar nos campos do prontuário ──
  Future<void> _processRelatoWithAI(String rawText) async {
    final apiKey = widget.p.openAiKey;
    if (apiKey.isEmpty) {
      _showRelatoSnack(_hcT(widget.p.lang, 'relato_no_key'));
      return;
    }
    if (mounted) setState(() => _aiProcessing = true);

    const systemPrompt =
        'Você é um assistente de inteligência artificial médica especializado em '
        'estruturação de prontuários.\n'
        'Receba o texto bruto de uma transcrição médica ditada e distribua as '
        'informações de forma inteligente nos campos correspondentes.\n\n'
        'Retorne RIGOROSAMENTE apenas um objeto JSON (sem formatação markdown ```json) '
        'com a seguinte estrutura:\n'
        '{\n'
        '  "motivo_consulta": "Se extraído, o motivo da consulta. Caso contrário, string vazia.",\n'
        '  "anamnese": "Histórico do paciente, sintomas, evolução. Caso contrário, string vazia.",\n'
        '  "exame_fisico": "Sinais vitais, dados do exame clínico. Caso contrário, string vazia.",\n'
        '  "conduta": "Condutas, medicações prescritas e próximos passos. Caso contrário, string vazia."\n'
        '}';

    final result = await AiService.chat(
      apiKey:     apiKey,
      systemPrompt: systemPrompt,
      userMessage: 'Texto Transcrito:\n$rawText',
      maxTokens:  800,
    );

    if (!mounted) return;
    setState(() => _aiProcessing = false);

    if (result.isError) {
      _showRelatoSnack(_hcT(widget.p.lang, 'relato_error'));
      return;
    }

    try {
      // Limpa possíveis backticks de markdown caso o modelo não obedeça
      final clean = result.text
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> data = jsonDecode(clean) as Map<String, dynamic>;

      void _fill(String ctrlKey, String jsonKey) {
        final val = (data[jsonKey] ?? '').toString().trim();
        if (val.isEmpty) return;
        final ctrl = _ctrls[ctrlKey];
        if (ctrl == null) return;
        // Append inteligente: não duplica conteúdo já existente
        final existing = ctrl.text.trim();
        ctrl.text = existing.isEmpty ? val : '$existing\n$val';
        ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: ctrl.text.length));
      }

      _fill('chiefComplaint', 'motivo_consulta');
      _fill('hpi',            'anamnese');
      _fill('physicalExam',   'exame_fisico');
      _fill('treatmentPlan',  'conduta');

      _showRelatoSnack(_hcT(widget.p.lang, 'relato_done'), success: true);
    } catch (_) {
      _showRelatoSnack(_hcT(widget.p.lang, 'relato_error'));
    }
  }

  // ── Abre o sheet "Organizar com IA" ────────────────────────────────────────
  void _showOrganizarIASheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrganizarIASheet(
        lang: widget.p.lang,
        apiKey: widget.p.openAiKey,
        onFill: _applyOrganizarResult,
      ),
    );
  }

  /// Recebe o mapa resultado do OrganizarIA e preenche os controllers.
  void _applyOrganizarResult(Map<String, String> data) {
    void _fill(String ctrlKey, String? val) {
      if (val == null || val.trim().isEmpty) return;
      final ctrl = _ctrls[ctrlKey];
      if (ctrl == null) return;
      final existing = ctrl.text.trim();
      ctrl.text = existing.isEmpty ? val.trim() : '$existing\n${val.trim()}';
      ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
    }
    _fill('chiefComplaint',   data['motivo_consulta']);
    _fill('hpi',              data['anamnese']);
    _fill('pastHistory',      data['antecedentes']);
    _fill('medications',      data['medicamentos']);
    _fill('allergies',        data['alergias']);
    _fill('vitalSigns',       data['sinais_vitais']);
    _fill('physicalExam',     data['exame_fisico']);
    _fill('workingDiagnosis', data['hipotese_diagnostica']);
    _fill('treatmentPlan',    data['conduta']);
    _fill('labResults',       data['exames']);
    _showRelatoSnack(_hcT(widget.p.lang, 'organizar_done'), success: true);
  }

  void _showRelatoSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          size: 18, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFB91C1C),
      duration: Duration(seconds: success ? 3 : 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
    ));
  }

  void _showPreview() {
    // Sincroniza draft com controllers antes de exibir
    final snap = _draft.copyWith(
      chiefComplaint: _ctrls['chiefComplaint']!.text.trim(),
      hpi: _ctrls['hpi']!.text.trim(),
      pastHistory: _ctrls['pastHistory']!.text.trim(),
      familyHistory: _ctrls['familyHistory']!.text.trim(),
      socialHistory: _ctrls['socialHistory']!.text.trim(),
      medications: _ctrls['medications']!.text.trim(),
      allergies: _ctrls['allergies']!.text.trim(),
      reviewOfSystems: _ctrls['reviewOfSystems']!.text.trim(),
      vitalSigns: _ctrls['vitalSigns']!.text.trim(),
      physicalExam: _ctrls['physicalExam']!.text.trim(),
      workingDiagnosis: _ctrls['workingDiagnosis']!.text.trim(),
      differentialDx: _ctrls['differentialDx']!.text.trim(),
      finalDiagnosis: _ctrls['finalDiagnosis']!.text.trim(),
      cid: _ctrls['cid']!.text.trim(),
      labResults: _ctrls['labResults']!.text.trim(),
      imagingResults: _ctrls['imagingResults']!.text.trim(),
      otherResults: _ctrls['otherResults']!.text.trim(),
      treatmentPlan: _ctrls['treatmentPlan']!.text.trim(),
      procedures: _ctrls['procedures']!.text.trim(),
      dischargeCondition: _ctrls['dischargeCondition']!.text.trim(),
      followUp: _ctrls['followUp']!.text.trim(),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistoryPreviewSheet(history: snap, lang: widget.p.lang),
    );
  }

  void _startStt(String key) {
    // Toggle: parar se já está ouvindo este campo
    if (_sttListening && _sttActiveKey == key) {
      _stopAllStt();
      return;
    }
    // Se estava ouvindo outro campo, parar antes
    if (_sttListening) _stopAllStt();

    final appLang = widget.p.lang;
    final locale  = appLang == 'es' ? 'es-ES' : 'pt-BR';

    if (kIsWeb) {
      // ── Web: usa Web Speech API via dart:html ────────────────────────────
      if (!webPlatform.webHasSpeechRecognition()) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(widget.p.t('dictation_not_supported')),
            content: Text(widget.p.t('dictation_browser_msg')),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        return;
      }
      final recog = webPlatform.WebSpeechRecognizer();
      recog.start(key, locale,
        onResult: (transcript, isFinal) {
          if (isFinal) {
            _insertIntoField(key, transcript);
            if (mounted) setState(() => _sttInterim = '');
          } else {
            if (mounted) setState(() => _sttInterim = transcript);
          }
        },
        onEnd: () {
          if (mounted) setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
        },
        onError: (_) {
          if (mounted) setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
        },
      );
      _sttRecog = recog;
    } else {
      // ── Mobile (iOS / Android): usa speech_to_text nativo ───────────────
      // STT-GUARD: erros nativos de AVAudioSession / SFSpeechRecognizer
      // não devem propagar e fechar o app silenciosamente.
      try {
        SttHelper.start(
          locale: locale,
          onResult: (transcript) {
            if (!mounted) return;
            _insertIntoField(key, transcript);
            setState(() { _sttInterim = ''; });
          },
          onError: (code) {
            if (!mounted) return;
            setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
            _showSttMobileError(code);
          },
          onEnd: () {
            if (mounted) setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
          },
        );
      } catch (e, st) {
        debugPrint('[HistoryScreen][_startSttForField] SttHelper.start exception: $e\n$st');
        if (mounted) setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
      }
    }

    _sttActiveKey = key;
    if (mounted) setState(() { _sttListening = true; _sttInterim = ''; });
  }

  /// Insere texto transcrito no campo correto, com espaço inteligente.
  void _insertIntoField(String key, String transcript) {
    if (transcript.isEmpty) return;
    // Caso especial: evolutionNote → insere no último card de evolução (ou cria um)
    if (key == 'evolutionNote') {
      setState(() {
        final list = List<EvolutionEntry>.from(_draft.evolutions);
        if (list.isEmpty) {
          list.add(EvolutionEntry.blank().copyWith(text: transcript));
        } else {
          final last = list.last;
          final spacer = last.text.isNotEmpty &&
              !last.text.endsWith(' ') && !last.text.endsWith('\n') ? ' ' : '';
          list[list.length - 1] = last.copyWith(text: last.text + spacer + transcript);
        }
        _draft = _draft.copyWith(evolutions: list);
      });
      return;
    }
    final ctrl = _ctrls[key];
    if (ctrl == null) return;
    final current = ctrl.text;
    final spacer  = current.isNotEmpty &&
        !current.endsWith(' ') && !current.endsWith('\n') ? ' ' : '';
    ctrl.text = current + spacer + transcript;
    ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: ctrl.text.length),
    );
  }

  /// Para qualquer sessão STT ativa (web ou mobile).
  void _stopAllStt() {
    _sttRecog?.stop();        // Web
    SttHelper.stop();         // Mobile
    if (mounted) setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
  }

  /// Exibe snackbar de erro do STT nativo (mobile).
  void _showSttMobileError(String code) {
    final isEs = widget.p.lang == 'es';
    String msg;
    switch (code) {
      case 'permission_denied':
        msg = isEs
            ? 'Permiso de micrófono denegado. Habilítalo en Ajustes → MedCases Pro → Micrófono.'
            : 'Permissão de microfone negada. Habilite em Ajustes → MedCases Pro → Microfone.';
      case 'not_available':
        msg = isEs
            ? 'Dictado no disponible. Verifica que el Reconocimiento de Voz esté activo en Ajustes → Accesibilidad → Texto introducido.'
            : 'Ditado indisponível. Verifique se o Reconhecimento de Voz está ativo em Ajustes → Acessibilidade → Texto Digitado.';
      case 'network':
        msg = isEs
            ? 'Verifica tu conexión a internet para el dictado.'
            : 'Verifique sua conexão com a internet para o ditado.';
      case 'audio_session':
        msg = isEs
            ? 'Error de sesión de audio. Cierra y vuelve a abrir la app.'
            : 'Erro na sessão de áudio. Feche e reabra o app.';
      case 'no_speech':
        return; // silencioso
      default:
        return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    ));
  }

  void _save() {
    final updated = _draft.copyWith(
      patientInitials: _ctrls['patientInitials']!.text.trim(),
      patientAge: _ctrls['patientAge']!.text.trim(),
      patientWeight: _ctrls['patientWeight']!.text.trim(),
      patientHeight: _ctrls['patientHeight']!.text.trim(),
      patientRecord: _ctrls['patientRecord']!.text.trim(),
      chiefComplaint: _ctrls['chiefComplaint']!.text.trim(),
      hpi: _ctrls['hpi']!.text.trim(),
      pastHistory: _ctrls['pastHistory']!.text.trim(),
      familyHistory: _ctrls['familyHistory']!.text.trim(),
      socialHistory: _ctrls['socialHistory']!.text.trim(),
      medications: _ctrls['medications']!.text.trim(),
      allergies: _ctrls['allergies']!.text.trim(),
      reviewOfSystems: _ctrls['reviewOfSystems']!.text.trim(),
      vitalSigns: _ctrls['vitalSigns']!.text.trim(),
      physicalExam: _ctrls['physicalExam']!.text.trim(),
      workingDiagnosis: _ctrls['workingDiagnosis']!.text.trim(),
      differentialDx: _ctrls['differentialDx']!.text.trim(),
      finalDiagnosis: _ctrls['finalDiagnosis']!.text.trim(),
      cid: _ctrls['cid']!.text.trim(),
      labResults: _ctrls['labResults']!.text.trim(),
      imagingResults: _ctrls['imagingResults']!.text.trim(),
      otherResults: _ctrls['otherResults']!.text.trim(),
      treatmentPlan: _ctrls['treatmentPlan']!.text.trim(),
      procedures: _ctrls['procedures']!.text.trim(),
      dischargeCondition: _ctrls['dischargeCondition']!.text.trim(),
      followUp: _ctrls['followUp']!.text.trim(),
      tags: _ctrls['tags']!.text.trim(),
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final completion = _draft.completionRatio;
    final bp = MedBreakpoints.of(context);
    // Desktop: header gradiente completo (sem shell AppBar).
    // Mobile/tablet: shell AppBar já visível → header compacto sem gradiente
    // (apenas barra de ações + progresso + tabs — sem duplicar o título).
    final showFullEditorHeader = bp.isDesktop;

    // Conteúdo da barra de ações (Row com fechar, título, ver, salvar)
    final actionRow = Row(children: [
      GestureDetector(onTap: widget.onCancel,
        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withOpacity(0.1)),
          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white))),
      const SizedBox(width: 10),
      Expanded(child: Text(_draft.chiefComplaint.isNotEmpty ? _draft.chiefComplaint : _hcT(widget.p.lang, 'new_hc_title'),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white), overflow: TextOverflow.ellipsis)),
      // Botão Pré-visualizar
      GestureDetector(onTap: _showPreview,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withOpacity(0.12), border: Border.all(color: Colors.white.withOpacity(0.2))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.visibility_rounded, size: 14, color: Colors.white),
            SizedBox(width: 5),
            Text('Ver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ]))),
      GestureDetector(onTap: _save,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kGold),
          child: Text(_hcT(widget.p.lang, 'save_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F1116))))),
    ]);

    // Barra de progresso
    final progressRow = Row(children: [
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: completion, minHeight: 4, backgroundColor: Colors.white.withOpacity(0.15),
          valueColor: const AlwaysStoppedAnimation(kGold)))),
      const SizedBox(width: 8),
      Text('${(completion * 100).round()}${_hcT(widget.p.lang, "progress_label")}', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700)),
    ]);

    return Column(children: [
      // Header — desktop: gradiente completo; mobile: compacto sem gradiente duplicado
      if (showFullEditorHeader)
        PremiumCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(children: [
            actionRow,
            const SizedBox(height: 10),
            progressRow,
            const SizedBox(height: 10),
            // Navegação de seções
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: List.generate(_sections.length, (i) {
              final active = _section == i;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _section = i;
                    if (_smartDictActive) {
                      final newField = _defaultFieldForSection(i);
                      if (newField == null) {
                        // Seção sem microfone (Paciente, Exames, Desfecho) → para o ditado
                        _smartRecog?.stop();
                        SttHelper.stop();
                        _smartDictActive = false;
                        _smartInterim = '';
                        _smartCurrentField = '';
                      } else {
                        // Seção com microfone → redireciona para o campo padrão da nova seção
                        _smartCurrentField = newField;
                      }
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: active ? kGold : Colors.white.withOpacity(0.1),
                      border: Border.all(color: active ? kGold : Colors.white.withOpacity(0.15)),
                    ),
                    child: Text(_sections[i].$2,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFF0F1116) : Colors.white.withOpacity(0.85))),
                  ),
                ),
              );
            })),
          ),
        ]),
      )
      else
        // Mobile/tablet: header compacto — ações + progresso + tabs sem gradiente
        // BUILD 277: flat dark header
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF12161F),
            border: Border(bottom: BorderSide(color: Color(0xFF1E2330), width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            actionRow,
            const SizedBox(height: 8),
            progressRow,
            const SizedBox(height: 8),
            // Navegação de seções (tabs compactos)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: List.generate(_sections.length, (i) {
                final active = _section == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _section = i;
                      if (_smartDictActive) {
                        final newField = _defaultFieldForSection(i);
                        if (newField == null) {
                          _smartRecog?.stop();
                          SttHelper.stop();
                          _smartDictActive = false;
                          _smartInterim = '';
                          _smartCurrentField = '';
                        } else {
                          _smartCurrentField = newField;
                        }
                      }
                    }),
                    // BUILD 277: minimalist underline tab (no background, no border box)
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                          child: Text(_sections[i].$2,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.45),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        // Thin underline for active tab
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 2,
                          width: active ? 24 : 0,
                          decoration: BoxDecoration(
                            color: const Color(0xFFAC2A2A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              })),
            ),
          ]),
        ),

      // Conteúdo da seção — no desktop: centraliza com max-width maior
      Expanded(child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final hPad = isDesktop ? 48.0 : 16.0;
          // Seções que têm campos de texto ditáveis (não Exames/Desfecho)
          final hasMic = _section == 1 || _section == 2 || _section == 4 || _section == 5;
          // Padding inferior adaptativo:
          //   Expandida: 168px (barra completa ~110px + SafeArea 34px + buffer 24px)
          //   Recolhida:  72px (pílula ~40px + SafeArea 24px + buffer 8px)
          final micPad = hasMic
              ? (_micBarExpanded ? 118.0 : 50.0)
              : 24.0;
          Widget content = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, micPad),
            child: isDesktop
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: _buildSection(),
                    ),
                  )
                : _buildSection(),
          );
          if (!hasMic) return content;
          return Stack(
            children: [
              content,
              // ── Barra de controle inferior (mic + IA + navegação) ────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _MicControlBar(
                  lang:          widget.p.lang,
                  // Colapso / expansão
                  expanded:      _micBarExpanded,
                  onToggleExpand: () => setState(() => _micBarExpanded = !_micBarExpanded),
                  // Estado ditáfone inteligente
                  smartActive:   _smartDictActive,
                  sttListening:  _sttListening,
                  currentField:  _smartDictActive ? _smartCurrentField : (_sttActiveKey ?? ''),
                  smartInterim:  _smartDictActive ? _smartInterim : _sttInterim,
                  onTapSmart:    _toggleSmartDictaphone,
                  // Estado relato livre
                  relatoActive:  _relatoActive,
                  aiProcessing:  _aiProcessing,
                  relatoInterim: _relatoInterim,
                  onTapRelato:   _toggleRelatoLivre,
                  // Organizar com IA (texto → campos)
                  onOrganizarIA: () => _showOrganizarIASheet(),
                  // Navegação entre campos
                  onPrevField:   () => FocusScope.of(context).previousFocus(),
                  onNextField:   () => FocusScope.of(context).nextFocus(),
                ),
              ),
            ],
          );
        },
      )),
    ]);
  }

  Widget _buildSection() {
    switch (_section) {
      case 0: return _buildPatientSection();
      case 1: return _buildAnamnesisSection();
      case 2: return _buildPhysicalExamSection();
      case 3: return _buildExamsSection();
      case 4: return _buildTreatmentSection();
      case 5: return _buildEvolutionSection();
      case 6: return _buildOutcomeSection();
      default: return const SizedBox();
    }
  }

  // ── Seção 0: Paciente ──────────────────────────────────────────────────────
  Widget _buildPatientSection() => Column(children: [
    _EditorField(_hcT(widget.p.lang, 'f_initials'), _ctrls['patientInitials']!, hint: _hcT(widget.p.lang, 'h_initials')),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _EditorField(_hcT(widget.p.lang, 'f_age'), _ctrls['patientAge']!, hint: '68', numeric: true)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_hcT(widget.p.lang, 'f_sex').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF6B7280))),
        const SizedBox(height: 5),
        Builder(builder: (ctx) {
          final isDarkDrop = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12), height: 44,
            decoration: BoxDecoration(
              color: isDarkDrop ? const Color(0xFF252930) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDarkDrop ? const Color(0xFF3A4A42) : kBorder)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _draft.patientSex, isExpanded: true,
              dropdownColor: isDarkDrop ? const Color(0xFF1C2226) : Colors.white,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDarkDrop ? const Color(0xFFE8F0EC) : const Color(0xFF0D1611)),
              items: [_hcT(widget.p.lang, 'sex_male'), _hcT(widget.p.lang, 'sex_female')].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _draft = _draft.copyWith(patientSex: v ?? _hcT(widget.p.lang, 'sex_male'))),
            )),
          );
        }),
      ])),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _EditorField(_hcT(widget.p.lang, 'f_weight'), _ctrls['patientWeight']!, hint: '72', numeric: true)),
      const SizedBox(width: 10),
      Expanded(child: _EditorField(_hcT(widget.p.lang, 'f_height'), _ctrls['patientHeight']!, hint: '170', numeric: true)),
    ]),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_record'), _ctrls['patientRecord']!, hint: '00123456'),
    const SizedBox(height: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_hcT(widget.p.lang, 'f_category').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF6B7280))),
      const SizedBox(height: 5),
      Builder(builder: (ctx) {
        final isDarkDrop = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12), height: 44,
          decoration: BoxDecoration(
            color: isDarkDrop ? const Color(0xFF252930) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDarkDrop ? const Color(0xFF3A4A42) : kBorder)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _draft.category, isExpanded: true,
            dropdownColor: isDarkDrop ? const Color(0xFF1C2226) : Colors.white,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDarkDrop ? const Color(0xFFE8F0EC) : const Color(0xFF0D1611)),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _draft = _draft.copyWith(category: v ?? 'Clínica Geral')),
          )),
        );
      }),
    ]),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_tags'), _ctrls['tags']!, hint: _hcT(widget.p.lang, 'h_tags')),
    const SizedBox(height: 14),
    // Compartilhar toggle
    GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(isPublic: !_draft.isPublic)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _draft.isPublic ? const Color(0xFF1E40AF).withOpacity(0.4) : kBorder),
          color: _draft.isPublic ? const Color(0xFF1E40AF).withOpacity(0.06) : Colors.white),
        child: Row(children: [
          Icon(_draft.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded, size: 20, color: _draft.isPublic ? const Color(0xFF1E40AF) : const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_draft.isPublic ? _hcT(widget.p.lang, 'public_on') : _hcT(widget.p.lang, 'public_off'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _draft.isPublic ? const Color(0xFF1E40AF) : kDark)),
            const SizedBox(height: 2),
            Text(_hcT(widget.p.lang, 'public_hint'), style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ])),
          Switch(value: _draft.isPublic, onChanged: (v) => setState(() => _draft = _draft.copyWith(isPublic: v)),
            thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? const Color(0xFF1E40AF) : null)),
        ]),
      ),
    ),
  ]);

  // ── Seção 1: Anamnese ─────────────────────────────────────────────────────
  Widget _buildAnamnesisSection() => Column(children: [
    _EditorField(_hcT(widget.p.lang, 'f_chief'), _ctrls['chiefComplaint']!, hint: _hcT(widget.p.lang, 'h_chief'), multiline: true, fieldKey: 'chiefComplaint', focusNode: _fieldFocusNodes['chiefComplaint']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_hpi'), _ctrls['hpi']!, hint: _hcT(widget.p.lang, 'h_hpi'), multiline: true, lines: 5, fieldKey: 'hpi', focusNode: _fieldFocusNodes['hpi']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_past'), _ctrls['pastHistory']!, hint: _hcT(widget.p.lang, 'h_past'), multiline: true, fieldKey: 'pastHistory', focusNode: _fieldFocusNodes['pastHistory']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_family'), _ctrls['familyHistory']!, hint: _hcT(widget.p.lang, 'h_family'), multiline: true, fieldKey: 'familyHistory', focusNode: _fieldFocusNodes['familyHistory']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_social'), _ctrls['socialHistory']!, hint: _hcT(widget.p.lang, 'h_social'), multiline: true, fieldKey: 'socialHistory', focusNode: _fieldFocusNodes['socialHistory']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_meds'), _ctrls['medications']!, hint: _hcT(widget.p.lang, 'h_meds'), multiline: true, fieldKey: 'medications', focusNode: _fieldFocusNodes['medications']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_allergies'), _ctrls['allergies']!, hint: _hcT(widget.p.lang, 'h_allergies'), multiline: true, fieldKey: 'allergies', focusNode: _fieldFocusNodes['allergies']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_ros'), _ctrls['reviewOfSystems']!, hint: _hcT(widget.p.lang, 'h_ros'), multiline: true, fieldKey: 'reviewOfSystems', focusNode: _fieldFocusNodes['reviewOfSystems']),
  ]);

  // ── Seção 2: Exame físico ──────────────────────────────────────────────────
  Widget _buildPhysicalExamSection() => Column(children: [
    // ── Sinais Vitais Estruturados ─────────────────────────────────────────
    _VitalSignsWidget(
      controller: _ctrls['vitalSigns']!,
    ),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_pe'), _ctrls['physicalExam']!, hint: _hcT(widget.p.lang, 'h_pe'), multiline: true, lines: 8, fieldKey: 'physicalExam', focusNode: _fieldFocusNodes['physicalExam']),
    const SizedBox(height: 10),
    // Diagnóstico logo após o exame físico
    _EditorField(_hcT(widget.p.lang, 'f_wdx'), _ctrls['workingDiagnosis']!, hint: _hcT(widget.p.lang, 'h_wdx'), fieldKey: 'workingDiagnosis', focusNode: _fieldFocusNodes['workingDiagnosis']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_diffdx'), _ctrls['differentialDx']!, hint: _hcT(widget.p.lang, 'h_diffdx'), multiline: true, fieldKey: 'differentialDx'),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(flex: 2, child: _EditorField(_hcT(widget.p.lang, 'f_finaldx'), _ctrls['finalDiagnosis']!, hint: _hcT(widget.p.lang, 'h_finaldx'))),
      const SizedBox(width: 10),
      Expanded(child: _EditorField(_hcT(widget.p.lang, 'f_cid'), _ctrls['cid']!, hint: 'I21.0')),
    ]),
  ]);

  // ── Seção 3: Exames ───────────────────────────────────────────────────────
  Widget _buildExamsSection() => Column(children: [
    // ── Botão OCR de Exame por IA ──────────────────────────────────────────
    _OcrExamButton(
      lang: widget.p.lang,
      onResult: (text) {
        final current = _ctrls['labResults']!.text.trim();
        _ctrls['labResults']!.text = current.isEmpty
            ? text
            : '$current\n\n$text';
      },
    ),
    const SizedBox(height: 10),
    // ── Lab Estruturado + OCR ──────────────────────────────────────────────
    _LabStructuredWidget(controller: _ctrls['labResults']!),
    const SizedBox(height: 10),
    // ── ECG Estruturado ────────────────────────────────────────────────────
    _EcgStructuredWidget(controller: _ctrls['otherResults']!),
    const SizedBox(height: 10),
    // ── Exames de imagem ───────────────────────────────────────────────────
    _EditorField(_hcT(widget.p.lang, 'f_imaging'), _ctrls['imagingResults']!, hint: _hcT(widget.p.lang, 'h_imaging'), multiline: true, lines: 5, fieldKey: 'imagingResults'),
  ]);

  // ── Seção 4: Conduta / Tratamento ────────────────────────────────────────
  Widget _buildTreatmentSection() => Column(children: [
    _EditorField(_hcT(widget.p.lang, 'f_plan'), _ctrls['treatmentPlan']!, hint: _hcT(widget.p.lang, 'h_plan'), multiline: true, lines: 7, fieldKey: 'treatmentPlan', focusNode: _fieldFocusNodes['treatmentPlan']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_procedures'), _ctrls['procedures']!, hint: _hcT(widget.p.lang, 'h_procedures'), multiline: true, fieldKey: 'procedures', focusNode: _fieldFocusNodes['procedures']),
  ]);

  // ── Seção 5: Evolução ─────────────────────────────────────────────────────
  Widget _buildEvolutionSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_hcT(widget.p.lang, 'evol_title').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF6B7280))),
      const SizedBox(height: 4),
      Text(_hcT(widget.p.lang, 'evol_hint'), style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ..._draft.evolutions.asMap().entries.map((entry) {
        final i = entry.key;
        final evo = entry.value;
        return _EvolutionEditorCard(
          evo: evo,
          onDelete: () => setState(() {
            final list = List<EvolutionEntry>.from(_draft.evolutions);
            list.removeAt(i);
            _draft = _draft.copyWith(evolutions: list);
          }),
          onUpdate: (updated) => setState(() {
            final list = List<EvolutionEntry>.from(_draft.evolutions);
            list[i] = updated;
            _draft = _draft.copyWith(evolutions: list);
          }),
        );
      }),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => setState(() {
          final list = List<EvolutionEntry>.from(_draft.evolutions);
          list.add(EvolutionEntry.blank());
          _draft = _draft.copyWith(evolutions: list);
        }),
        child: Container(
          width: double.infinity, height: 48,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder, style: BorderStyle.solid), color: kSurface),
          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_circle_outline_rounded, size: 16, color: kGold),
            const SizedBox(width: 6),
            Text(_hcT(widget.p.lang, 'add_evol'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGold)),
          ])),
        ),
      ),
    ]);
  }

  // ── Seção 6: Desfecho ──────────────────────────────────────────────────────
  Widget _buildOutcomeSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(_hcT(widget.p.lang, 'outcome_title').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF6B7280))),
    const SizedBox(height: 8),
    Row(children: List.generate(_outcomes.length, (i) {
      final selected = _draft.outcome == _outcomes[i];
      final colors = [const Color(0xFFC5A365), const Color(0xFF065F46), const Color(0xFFCC2222), const Color(0xFF1E40AF)];
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: i < _outcomes.length - 1 ? 6 : 0),
        child: GestureDetector(
          onTap: () => setState(() => _draft = _draft.copyWith(outcome: _outcomes[i])),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              color: selected ? colors[i] : Colors.white,
              border: Border.all(color: selected ? colors[i] : kBorder)),
            child: Column(children: [
              Icon(i == 0 ? Icons.hotel_rounded : i == 1 ? Icons.home_rounded : i == 2 ? Icons.close_rounded : Icons.arrow_forward_rounded,
                size: 16, color: selected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(height: 3),
              Text(_outcomesLabel[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: selected ? Colors.white : const Color(0xFF6B7280))),
            ]),
          ),
        ),
      ));
    })),
    const SizedBox(height: 14),
    _EditorField(_hcT(widget.p.lang, 'f_discharge'), _ctrls['dischargeCondition']!, hint: _hcT(widget.p.lang, 'h_discharge'), multiline: true, fieldKey: 'dischargeCondition', focusNode: _fieldFocusNodes['dischargeCondition']),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_followup'), _ctrls['followUp']!, hint: _hcT(widget.p.lang, 'h_followup'), multiline: true, fieldKey: 'followUp', focusNode: _fieldFocusNodes['followUp']),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _EditorField extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final bool multiline, numeric;
  final int lines;
  final VoidCallback? onMic;
  /// Chave usada para persistir sugestões adaptativas (ex: 'hpi', 'physicalExam').
  /// Se null, autocomplete não é habilitado para este campo.
  final String? fieldKey;
  /// FocusNode externo — permite rastrear qual campo está focado (nav pelas setas).
  final FocusNode? focusNode;
  /// Chamado com a fieldKey quando este campo ganha foco (para atualizar badge do ditáfone).
  final void Function(String key)? onFocused;

  const _EditorField(this.label, this.ctrl, {
    required this.hint,
    this.multiline = false,
    this.numeric = false,
    this.lines = 3,
    this.onMic,
    this.fieldKey,
    this.focusNode,
    this.onFocused,
  });

  @override
  State<_EditorField> createState() => _EditorFieldState();
}

class _EditorFieldState extends State<_EditorField> {
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.fieldKey != null) {
      widget.ctrl.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.fieldKey != null) {
      widget.ctrl.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final text = widget.ctrl.text;
      // Pega a última palavra/frase digitada após pontuação ou quebra de linha
      final query = _getActiveQuery(text);
      if (query.length < 3) {
        if (_showSuggestions) setState(() { _showSuggestions = false; _suggestions = []; });
        return;
      }
      final sugs = await SuggestionService.getSuggestions(widget.fieldKey!, query, limit: 5);
      if (!mounted) return;
      setState(() {
        _suggestions = sugs;
        _showSuggestions = sugs.isNotEmpty;
      });
    });
  }

  /// Extrai o fragmento de texto atual que o usuário está digitando
  /// (texto após o último ponto, vírgula, quebra de linha ou início).
  String _getActiveQuery(String text) {
    if (text.isEmpty) return '';
    final segments = text.split(RegExp(r'[.;\n,]'));
    final last = segments.last.trim();
    return last;
  }

  /// Aplica a sugestão selecionada pelo usuário.
  void _applySuggestion(String suggestion) {
    final text = widget.ctrl.text;
    // Encontra onde começa o fragmento atual
    final lastBreak = text.lastIndexOf(RegExp(r'[.;\n,]'));
    String newText;
    if (lastBreak == -1) {
      // Campo inteiro é o fragmento atual
      newText = suggestion;
    } else {
      // Preserva tudo antes do último separador + adiciona sugestão
      newText = '${text.substring(0, lastBreak + 1)} $suggestion';
    }
    widget.ctrl.text = newText;
    // Posiciona cursor no final
    widget.ctrl.selection = TextSelection.collapsed(offset: newText.length);
    setState(() { _showSuggestions = false; _suggestions = []; });
  }

  /// Salva o conteúdo do campo ao perder foco (quando o usuário termina de digitar).
  void _saveSuggestions() {
    final key = widget.fieldKey;
    if (key == null) return;
    final text = widget.ctrl.text.trim();
    if (text.length < 3) return;
    SuggestionService.saveEntry(key, text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header: label + botão mic ──────────────────────────────────────────
      Row(children: [
        Text(widget.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF6B7280))),
        if (widget.onMic != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: widget.onMic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFDC2626).withOpacity(0.08),
                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.25)),
              ),
              child: Builder(builder: (ctx) {
                final localLang = ctx.read<AppProvider>().lang;
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mic_rounded, size: 11, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(_hcT(localLang, 'dictate_btn'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                ]);
              }),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 5),
      // ── Campo de texto ─────────────────────────────────────────────────────
      Focus(
        focusNode: widget.focusNode,
        onFocusChange: (hasFocus) {
          if (hasFocus && widget.fieldKey != null && widget.onFocused != null) {
            widget.onFocused!(widget.fieldKey!);
          }
          if (!hasFocus) {
            _saveSuggestions();
            if (_showSuggestions) setState(() { _showSuggestions = false; });
          }
        },
        child: MedInput(
          controller: widget.ctrl,
          hintText: widget.hint,
          maxLines: widget.multiline ? widget.lines : 1,
          keyboardType: widget.numeric
              ? TextInputType.number
              : widget.multiline
                  ? TextInputType.multiline
                  : null,
        ),
      ),
      // ── Chips de sugestão adaptativa ───────────────────────────────────────
      if (_showSuggestions && _suggestions.isNotEmpty) ...[
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Ícone indicador
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFFC5A365)),
              ),
              ..._suggestions.map((sug) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => _applySuggestion(sug),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFC5A365).withOpacity(0.10),
                      border: Border.all(color: const Color(0xFFC5A365).withOpacity(0.40)),
                    ),
                    child: Text(
                      sug.length > 40 ? '${sug.substring(0, 40)}…' : sug,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B6914),
                      ),
                    ),
                  ),
                ),
              )),
              // Botão para dispensar sugestões
              GestureDetector(
                onTap: () => setState(() { _showSuggestions = false; }),
                child: const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.close_rounded, size: 14, color: Color(0xFFBBBBBB)),
                ),
              ),
            ],
          ),
        ),
      ],
    ]);
  }
}

// Widget de ponto pulsante para o banner de ditado
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({this.color = const Color(0xFFDC2626)});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÃO DITÁFONE INTELIGENTE
// Botão grande único para ditado contínuo com roteamento automático de campos
// ─────────────────────────────────────────────────────────────────────────────
class _SmartDictaphoneButton extends StatelessWidget {
  final bool active;
  final String currentField;
  final VoidCallback onTap;
  final String lang;

  const _SmartDictaphoneButton({
    required this.active,
    required this.currentField,
    required this.onTap,
    required this.lang,
  });

  static Map<String, String> _labels(String lang) => lang == 'es' ? {
    'chiefComplaint': 'Motivo de consulta',
    'hpi': 'Enfermedad actual',
    'pastHistory': 'Antecedentes personales',
    'familyHistory': 'Antecedentes familiares',
    'socialHistory': 'Historia social',
    'medications': 'Medicación habitual',
    'allergies': 'Alergias',
    'reviewOfSystems': 'Revisión de sistemas',
    'vitalSigns': 'Signos vitales',
    'physicalExam': 'Examen físico',
    'workingDiagnosis': 'Hipótesis diagnóstica',
    'treatmentPlan': 'Plan terapéutico',
  } : {
    'chiefComplaint': 'Queixa principal',
    'hpi': 'HDA',
    'pastHistory': 'Antecedentes pessoais',
    'familyHistory': 'Antecedentes familiares',
    'socialHistory': 'História social',
    'medications': 'Medicamentos',
    'allergies': 'Alergias',
    'reviewOfSystems': 'Revisão de sistemas',
    'vitalSigns': 'Sinais vitais',
    'physicalExam': 'Exame físico',
    'workingDiagnosis': 'Hipótese diagnóstica',
    'treatmentPlan': 'Conduta',
  };

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: active
            ? const LinearGradient(colors: [Color(0xFF0F1116), Color(0xFF10B981)], begin: Alignment.centerLeft, end: Alignment.centerRight)
            : null,
          color: active ? null : const Color(0xFFF0F7F4),
          border: Border.all(
            color: active ? const Color(0xFF10B981) : const Color(0xFFBBD6C8),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          // Ícone mic animado
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white.withOpacity(0.15) : const Color(0xFF10B981).withOpacity(0.12),
              border: Border.all(color: active ? Colors.white.withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Center(child: Icon(
              active ? Icons.mic_rounded : Icons.mic_none_rounded,
              size: 22,
              color: active ? Colors.white : const Color(0xFF10B981),
            )),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              active
                ? _hcT(lang, 'dictaphone_active')
                : _hcT(lang, 'dictaphone'),
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: active ? Colors.white : const Color(0xFF10B981),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              active && currentField.isNotEmpty
                ? '→ ${_labels(lang)[currentField] ?? currentField}'
                : (isEs
                    ? 'Diga "queja", "antecedentes", "examen"... y el texto va al campo correcto'
                    : 'Diga "queixa", "antecedentes", "exame físico"... e o texto vai para o campo certo'),
              style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600,
                color: active ? Colors.white.withOpacity(0.80) : const Color(0xFF666666),
                height: 1.4,
              ),
              maxLines: 2,
            ),
          ])),
          const SizedBox(width: 8),
          if (active)
            _PulseDot(color: const Color(0xFF86EFAC))
          else
            Icon(Icons.chevron_right_rounded, size: 20, color: const Color(0xFF10B981).withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MIC CONTROL BAR — colapsável: pílula compacta ↔ barra completa
// Collapsed: botão mic compacto + indicador de estado.
// Expanded:  status badge + ditáfone + relato + organizar + navegação.
// ─────────────────────────────────────────────────────────────────────────────
class _MicControlBar extends StatelessWidget {
  final String lang;

  // Expansão
  final bool       expanded;
  final VoidCallback onToggleExpand;

  // Ditáfone inteligente
  final bool   smartActive;
  final bool   sttListening;
  final String currentField;
  final String smartInterim;
  final VoidCallback onTapSmart;

  // Relato livre (IA)
  final bool   relatoActive;
  final bool   aiProcessing;
  final String relatoInterim;
  final VoidCallback onTapRelato;

  // Organizar com IA (texto livre → campos)
  final VoidCallback onOrganizarIA;

  // Navegação de campos
  final VoidCallback onPrevField;
  final VoidCallback onNextField;
  final void Function(String fieldKey)? onFieldFocused;

  const _MicControlBar({
    required this.lang,
    required this.expanded,
    required this.onToggleExpand,
    required this.smartActive,
    required this.sttListening,
    required this.currentField,
    required this.smartInterim,
    required this.onTapSmart,
    required this.relatoActive,
    required this.aiProcessing,
    required this.relatoInterim,
    required this.onTapRelato,
    required this.onOrganizarIA,
    required this.onPrevField,
    required this.onNextField,
    this.onFieldFocused,
  });

  bool get _anyActive => smartActive || sttListening || relatoActive || aiProcessing;

  @override
  Widget build(BuildContext context) {
    const bg         = Color(0xFFF8FAF9);
    const bgDark     = Color(0xFF141F19);
    const border     = Color(0xFFD4E8DC);
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cardBg     = isDark ? bgDark : bg;
    final cardBorder = isDark ? const Color(0xFF1F3829) : border;

    // Se qualquer modo está ativo, força expansão visual (botões devem aparecer)
    final showFull = expanded || _anyActive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: cardBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.40 : 0.08),
            blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, showFull ? 7 : 4, 10, showFull ? 5 : 3),
          child: showFull
              // ── BARRA EXPANDIDA ────────────────────────────────────────────
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status badge + botão fechar
                    Row(children: [
                      Expanded(
                        child: _MicStatusBadge(
                          lang:         lang,
                          smartActive:  smartActive || sttListening,
                          relatoActive: relatoActive,
                          aiProcessing: aiProcessing,
                          currentField: currentField,
                          interim:      relatoActive ? relatoInterim : smartInterim,
                        ),
                      ),
                      // Botão recolher (só quando não há modo ativo)
                      if (!_anyActive) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onToggleExpand,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.white.withOpacity(0.07)
                                  : const Color(0xFFE8EFF0),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.10)
                                    : const Color(0xFFCDD8DC)),
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 15,
                              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                            ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 6),

                    // Botões de ação — linha 1: Ditáfone + Relato + Nav
                    Row(children: [
                      // Ditáfone inteligente
                      Expanded(
                        child: _MicActionBtn(
                          icon:    smartActive || sttListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          label:   smartActive || sttListening
                              ? _hcT(lang, 'dictaphone_active').replaceAll(' • Gravando', '').replaceAll(' • Grabando', '')
                              : _hcT(lang, 'dictaphone'),
                          active:  smartActive || sttListening,
                          color:   const Color(0xFF10B981),
                          onTap:   onTapSmart,
                          enabled: !relatoActive && !aiProcessing,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Relato Livre (IA)
                      Expanded(
                        child: _MicActionBtn(
                          icon:    aiProcessing
                              ? Icons.auto_awesome_rounded
                              : (relatoActive
                                  ? Icons.stop_circle_rounded
                                  : Icons.record_voice_over_rounded),
                          label:   aiProcessing
                              ? _hcT(lang, 'relato_processing')
                              : (relatoActive
                                  ? _hcT(lang, 'relato_active')
                                  : _hcT(lang, 'relato_btn')),
                          active:  relatoActive,
                          color:   relatoActive
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF7C3AED),
                          onTap:   onTapRelato,
                          enabled: !smartActive && !sttListening && !aiProcessing,
                          loading: aiProcessing,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Navegação entre campos
                      _FieldNavBar(
                        onPrev: onPrevField,
                        onNext: onNextField,
                        isDark: isDark,
                        onFieldFocused: onFieldFocused,
                      ),
                    ]),
                    const SizedBox(height: 5),

                    // Botão "Organizar com IA" — linha 2, largura total
                    GestureDetector(
                      onTap: (!smartActive && !sttListening && !relatoActive && !aiProcessing)
                          ? onOrganizarIA
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: (!smartActive && !sttListening && !relatoActive && !aiProcessing)
                              ? const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: (!smartActive && !sttListening && !relatoActive && !aiProcessing)
                              ? null
                              : (isDark ? Colors.white12 : const Color(0xFFE8E8F0)),
                          border: Border.all(
                            color: (!smartActive && !sttListening && !relatoActive && !aiProcessing)
                                ? const Color(0xFF7C3AED).withOpacity(0.5)
                                : (isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : const Color(0xFFD0D0E8)),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_fix_high_rounded,
                              size: 15,
                              color: (!smartActive && !sttListening && !relatoActive && !aiProcessing)
                                  ? Colors.white
                                  : (isDark ? Colors.white38 : const Color(0xFFB0B0C8)),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _hcT(lang, 'organizar_btn'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: (!smartActive && !sttListening && !relatoActive && !aiProcessing)
                                    ? Colors.white
                                    : (isDark ? Colors.white38 : const Color(0xFFB0B0C8)),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              // ── PÍLULA RECOLHIDA ───────────────────────────────────────────
              : GestureDetector(
                  onTap: onToggleExpand,
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: isDark
                          ? const Color(0xFF10B981).withOpacity(0.14)
                          : const Color(0xFF10B981).withOpacity(0.07),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_none_rounded, size: 13,
                            color: const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          lang == 'es' ? 'Dictado e IA' : 'Ditado e IA',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(Icons.keyboard_arrow_up_rounded, size: 13,
                            color: const Color(0xFF10B981).withOpacity(0.6)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MIC STATUS BADGE — indicador visual de estado de captação
// Vermelho quando gravando, Verde quando pronto, Roxo quando IA processa
// ─────────────────────────────────────────────────────────────────────────────
class _MicStatusBadge extends StatelessWidget {
  final String lang;
  final bool smartActive;
  final bool relatoActive;
  final bool aiProcessing;
  final String currentField;
  final String interim;

  const _MicStatusBadge({
    required this.lang,
    required this.smartActive,
    required this.relatoActive,
    required this.aiProcessing,
    required this.currentField,
    required this.interim,
  });

  // Mapa de chaves internas → nomes legíveis por idioma
  static String _fieldReadable(String key, String lang) {
    final isEs = lang == 'es';
    const Map<String, Map<String, String>> _map = {
      'chiefComplaint': {'pt': 'Queixa principal',        'es': 'Motivo de consulta'},
      'hpi':            {'pt': 'HDA',                      'es': 'Enfermedad actual'},
      'pastHistory':    {'pt': 'Antecedentes pessoais',    'es': 'Antecedentes personales'},
      'familyHistory':  {'pt': 'Antecedentes familiares',  'es': 'Antecedentes familiares'},
      'socialHistory':  {'pt': 'História social',          'es': 'Historia social'},
      'medications':    {'pt': 'Medicamentos',             'es': 'Medicación'},
      'allergies':      {'pt': 'Alergias',                 'es': 'Alergias'},
      'reviewOfSystems':{'pt': 'Revisão de sistemas',      'es': 'Revisión de sistemas'},
      'vitalSigns':     {'pt': 'Sinais vitais',            'es': 'Signos vitales'},
      'physicalExam':   {'pt': 'Exame físico',             'es': 'Examen físico'},
      'workingDiagnosis':{'pt': 'Hipótese diagnóstica',    'es': 'Hipótesis diagnóstica'},
      'treatmentPlan':  {'pt': 'Conduta',                  'es': 'Plan terapéutico'},
      'evolutionNote':  {'pt': 'Nota de evolução',         'es': 'Nota de evolución'},
    };
    final entry = _map[key];
    if (entry == null) return '';
    return isEs ? (entry['es'] ?? '') : (entry['pt'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    // Determina estado dominante
    final isRecording = relatoActive || smartActive;
    final Color bgColor;
    final Color dotColor;
    final String label;
    final IconData icon;

    // ── Rótulo do campo ativo para o ditáfone inteligente ─────────────────
    final String fieldReadable = currentField.isNotEmpty
        ? _fieldReadable(currentField, lang)
        : '';
    final bool isEs = lang == 'es';

    if (aiProcessing) {
      bgColor  = const Color(0xFF7C3AED).withOpacity(0.10);
      dotColor = const Color(0xFF7C3AED);
      icon     = Icons.auto_awesome_rounded;
      label    = _hcT(lang, 'relato_processing');
    } else if (relatoActive) {
      bgColor  = const Color(0xFFDC2626).withOpacity(0.08);
      dotColor = const Color(0xFFDC2626);
      icon     = Icons.fiber_manual_record_rounded;
      label    = _hcT(lang, 'relato_active');
    } else if (smartActive) {
      bgColor  = const Color(0xFF10B981).withOpacity(0.10);
      dotColor = const Color(0xFF16A34A);
      icon     = Icons.fiber_manual_record_rounded;
      // ✅ MELHORIA 1: mostra exatamente qual campo está escutando
      label    = fieldReadable.isNotEmpty
          ? (isEs ? 'Grabando: $fieldReadable' : 'Gravando: $fieldReadable')
          : _hcT(lang, 'dictaphone_active');
    } else {
      bgColor  = const Color(0xFF10B981).withOpacity(0.06);
      dotColor = const Color(0xFF10B981);
      icon     = Icons.mic_none_rounded;
      label    = _hcT(lang, 'relato_ready');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bgColor,
        border: Border.all(color: dotColor.withOpacity(0.20), width: 1),
      ),
      child: Row(children: [
        // Ícone / dot pulsante
        if (isRecording || aiProcessing)
          _PulseDot(color: dotColor)
        else
          Icon(icon, size: 14, color: dotColor),
        const SizedBox(width: 8),
        // Texto principal — mostra interim se houver, senão o label do campo
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              key: ValueKey(interim.isNotEmpty ? 'interim' : label),
              interim.isNotEmpty ? interim : label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isRecording ? FontWeight.w800 : FontWeight.w600,
                color: dotColor,
                letterSpacing: isRecording ? 0.3 : 0,
                fontStyle: interim.isNotEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // Chip com seta de campo para ditáfone inteligente
        // (campo legível já aparece no texto principal — chip vira ícone de microfone)
        if (smartActive) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor.withOpacity(0.15),
            ),
            child: Icon(Icons.hearing_rounded, size: 12, color: dotColor),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MIC ACTION BTN — botão compacto de ação na barra inferior
// ─────────────────────────────────────────────────────────────────────────────
class _MicActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final bool     enabled;
  final bool     loading;
  final Color    color;
  final VoidCallback onTap;

  const _MicActionBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withOpacity(0.35);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active
              ? effectiveColor.withOpacity(0.12)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? effectiveColor.withOpacity(0.55)
                : effectiveColor.withOpacity(0.25),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 13, height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(effectiveColor),
                ),
              )
            else
              Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: effectiveColor,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD NAV BAR — botões de navegação anterior/próximo campo
// ─────────────────────────────────────────────────────────────────────────────
class _FieldNavBar extends StatelessWidget {
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isDark;
  /// Chamado após mover o foco — recebe a fieldKey do campo que ganhou foco.
  final void Function(String fieldKey)? onFieldFocused;

  const _FieldNavBar({
    required this.onPrev,
    required this.onNext,
    required this.isDark,
    this.onFieldFocused,
  });

  // Mapa de debugLabel → fieldKey dos _EditorField que usam fieldKey
  static const _kKnownKeys = [
    'chiefComplaint', 'hpi', 'pastHistory', 'familyHistory',
    'socialHistory', 'medications', 'allergies', 'reviewOfSystems',
    'vitalSigns', 'physicalExam', 'workingDiagnosis', 'treatmentPlan',
    'procedures', 'evolution', 'dischargeCondition', 'followUp',
  ];

  void _afterNav(BuildContext context) {
    if (onFieldFocused == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final scope   = FocusScope.of(context);
        final focused = scope.focusedChild;
        if (focused == null) return;
        final label = focused.debugLabel ?? '';
        for (final key in _kKnownKeys) {
          if (label.contains(key)) { onFieldFocused!(key); return; }
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final btnBg     = isDark
        ? Colors.white.withOpacity(0.07)
        : const Color(0xFFEFF2F5);
    final btnBorder = isDark
        ? Colors.white.withOpacity(0.10)
        : const Color(0xFFD1D9E0);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Row(mainAxisSize: MainAxisSize.min, children: [
      _NavBtn(
        icon:    Icons.keyboard_arrow_up_rounded,
        bg:      btnBg,
        border:  btnBorder,
        iconC:   iconColor,
        onTap:   () { onPrev(); _afterNav(context); },
        tooltip: 'Campo anterior',
      ),
      const SizedBox(width: 6),
      _NavBtn(
        icon:    Icons.keyboard_arrow_down_rounded,
        bg:      btnBg,
        border:  btnBorder,
        iconC:   iconColor,
        onTap:   () { onNext(); _afterNav(context); },
        tooltip: 'Próximo campo',
      ),
    ]);
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final Color    bg;
  final Color    border;
  final Color    iconC;
  final VoidCallback onTap;
  final String   tooltip;
  const _NavBtn({required this.icon, required this.bg, required this.border,
    required this.iconC, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: bg,
          border: Border.all(color: border, width: 1),
        ),
        child: Icon(icon, size: 22, color: iconC),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÃO MIC CENTRAL — estilo Gemini
// Único microfone flutuante, centralizado, com animação de ondas quando ativo
// ─────────────────────────────────────────────────────────────────────────────
class _CentralMicButton extends StatefulWidget {
  final bool active;
  final bool smartActive;
  final bool sttListening;
  final String currentField;
  final String interim;
  final String lang;
  final VoidCallback onTap;

  const _CentralMicButton({
    required this.active,
    required this.smartActive,
    required this.sttListening,
    required this.currentField,
    required this.interim,
    required this.lang,
    required this.onTap,
  });

  @override
  State<_CentralMicButton> createState() => _CentralMicButtonState();
}

class _CentralMicButtonState extends State<_CentralMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _wave;
  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _ring3;

  static const Map<String, String> _labelsEs = {
    'chiefComplaint': 'Motivo de consulta',
    'hpi': 'Enfermedad actual',
    'pastHistory': 'Antecedentes personales',
    'familyHistory': 'Antecedentes familiares',
    'socialHistory': 'Historia social',
    'medications': 'Medicación habitual',
    'allergies': 'Alergias',
    'reviewOfSystems': 'Revisión de sistemas',
    'vitalSigns': 'Signos vitales',
    'physicalExam': 'Examen físico',
    'workingDiagnosis': 'Hipótesis diagnóstica',
    'treatmentPlan': 'Plan terapéutico',
    'procedures': 'Procedimientos',
  };
  static const Map<String, String> _labelsPt = {
    'chiefComplaint': 'Queixa principal',
    'hpi': 'HDA',
    'pastHistory': 'Antecedentes pessoais',
    'familyHistory': 'Antecedentes familiares',
    'socialHistory': 'História social',
    'medications': 'Medicamentos',
    'allergies': 'Alergias',
    'reviewOfSystems': 'Revisão de sistemas',
    'vitalSigns': 'Sinais vitais',
    'physicalExam': 'Exame físico',
    'workingDiagnosis': 'Hipótese diagnóstica',
    'treatmentPlan': 'Conduta',
    'procedures': 'Procedimentos',
  };

  String _fieldLabel(String key) {
    final map = widget.lang == 'es' ? _labelsEs : _labelsPt;
    return map[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Três anéis desfasados
    _ring1 = Tween<double>(begin: 1.0, end: 1.9).animate(
        CurvedAnimation(parent: _wave, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _ring2 = Tween<double>(begin: 1.0, end: 1.65).animate(
        CurvedAnimation(parent: _wave, curve: const Interval(0.2, 0.9, curve: Curves.easeOut)));
    _ring3 = Tween<double>(begin: 1.0, end: 1.38).animate(
        CurvedAnimation(parent: _wave, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));
    if (widget.active) _wave.repeat();
  }

  @override
  void didUpdateWidget(_CentralMicButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _wave.repeat();
    } else if (!widget.active && old.active) {
      _wave.stop();
      _wave.reset();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    const kGreen  = Color(0xFF10B981);
    const kGreenL = Color(0xFF34A870);
    final btnColor = active ? kGreen : const Color(0xFFF0F7F4);
    final iconColor = active ? Colors.white : kGreen;
    const btnSize  = 64.0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── Texto interim / campo ativo ─────────────────────────────────────
      if (active && (widget.interim.isNotEmpty || widget.currentField.isNotEmpty))
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
            boxShadow: [BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))],
            border: Border.all(color: kGreen.withOpacity(0.25)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.currentField.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_right_alt_rounded, size: 14, color: kGreen),
                const SizedBox(width: 4),
                Text(
                  _fieldLabel(widget.currentField),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kGreen),
                ),
              ]),
            if (widget.interim.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                widget.interim,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF444444), fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ]),
        ),

      // ── Botão mic com ondas ─────────────────────────────────────────────
      GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _wave,
          builder: (ctx, child) {
            return SizedBox(
              width: btnSize * 2.2,
              height: btnSize * 2.2,
              child: Stack(alignment: Alignment.center, children: [
                // Anel externo
                if (active)
                  Transform.scale(
                    scale: _ring1.value,
                    child: Container(
                      width: btnSize,
                      height: btnSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kGreen.withOpacity((1 - _ring1.value / 2.0).clamp(0.0, 0.12)),
                        border: Border.all(color: kGreen.withOpacity((1 - _ring1.value / 2.0).clamp(0.0, 0.25)), width: 1),
                      ),
                    ),
                  ),
                // Anel médio
                if (active)
                  Transform.scale(
                    scale: _ring2.value,
                    child: Container(
                      width: btnSize,
                      height: btnSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kGreen.withOpacity((1 - _ring2.value / 1.8).clamp(0.0, 0.12)),
                        border: Border.all(color: kGreen.withOpacity((1 - _ring2.value / 1.8).clamp(0.0, 0.3)), width: 1.2),
                      ),
                    ),
                  ),
                // Anel interno
                if (active)
                  Transform.scale(
                    scale: _ring3.value,
                    child: Container(
                      width: btnSize,
                      height: btnSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kGreen.withOpacity((1 - _ring3.value / 1.5).clamp(0.0, 0.12)),
                        border: Border.all(color: kGreen.withOpacity((1 - _ring3.value / 1.5).clamp(0.0, 0.35)), width: 1.5),
                      ),
                    ),
                  ),
                // Botão central
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: active ? btnSize + 8 : btnSize,
                  height: active ? btnSize + 8 : btnSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: btnColor,
                    gradient: active
                        ? const LinearGradient(
                            colors: [kGreen, kGreenL],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: Border.all(
                      color: active ? kGreen : kGreen.withOpacity(0.35),
                      width: active ? 0 : 1.5,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(color: kGreen.withOpacity(0.40), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 6)),
                            BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2)),
                          ]
                        : [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Icon(
                    active ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: active ? 32 : 28,
                    color: iconColor,
                  ),
                ),
              ]),
            );
          },
        ),
      ),

      // ── Label abaixo ────────────────────────────────────────────────────
      const SizedBox(height: 4),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          active
              ? (widget.lang == 'es' ? 'Tocá para detener' : 'Toque para parar')
              : (widget.lang == 'es' ? 'Dictar' : 'Ditar'),
          key: ValueKey(active),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? kGreen : const Color(0xFF6B7280),
            letterSpacing: 0.3,
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRÉ-VISUALIZAÇÃO DA HISTÓRIA CLÍNICA
// Sheet formatado como documento clínico completo
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryPreviewSheet extends StatelessWidget {
  final ClinicalHistoryModel history;
  final String lang;
  const _HistoryPreviewSheet({required this.history, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}  ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: const Color(0xFFA8B2C1)),
          ),
          // Header da sheet
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [Color(0xFF0F1116), Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(children: [
              const Icon(Icons.description_rounded, size: 20, color: Color(0xFFC5A365)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_hcT(lang, 'preview_title'),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFC5A365), letterSpacing: 1.5)),
                Text(_hcT(lang, 'pdf_hc_title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withOpacity(0.12)),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white)),
              ),
            ]),
          ),
          // Conteúdo scrollável
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // ── Cabeçalho do documento ──────────────────────────────────────
              _PreviewDocHeader(history: history, dateStr: dateStr, isEs: isEs),
              const SizedBox(height: 14),

              // ── ANAMNESE ────────────────────────────────────────────────────
              if (_hasAny([history.chiefComplaint, history.hpi, history.pastHistory,
                           history.familyHistory, history.socialHistory,
                           history.medications, history.allergies, history.reviewOfSystems])) ...[
                _PreviewSection(
                  title: _hcT(lang, 'prev_anamnese'),
                  icon: Icons.history_edu_rounded,
                  color: const Color(0xFF1E40AF),
                  children: [
                    if (history.chiefComplaint.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_chief'), history.chiefComplaint),
                    if (history.hpi.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_hpi'), history.hpi),
                    if (history.pastHistory.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_past'), history.pastHistory),
                    if (history.familyHistory.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_family'), history.familyHistory),
                    if (history.socialHistory.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_social'), history.socialHistory),
                    if (history.medications.isNotEmpty) _PreviewItemHighlight(_hcT(lang, 'prev_meds'), history.medications, const Color(0xFF1E40AF)),
                    if (history.allergies.isNotEmpty) _PreviewItemHighlight(_hcT(lang, 'prev_allerg'), history.allergies, const Color(0xFFDC2626)),
                    if (history.reviewOfSystems.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_rvs'), history.reviewOfSystems),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── EXAME FÍSICO ─────────────────────────────────────────────────
              if (_hasAny([history.vitalSigns, history.physicalExam])) ...[
                _PreviewSection(
                  title: _hcT(lang, 'prev_exam'),
                  icon: Icons.accessibility_new_rounded,
                  color: const Color(0xFF065F46),
                  children: [
                    if (history.vitalSigns.isNotEmpty) _PreviewItemHighlight(_hcT(lang, 'prev_vitals'), history.vitalSigns, const Color(0xFF065F46)),
                    if (history.physicalExam.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_pe'), history.physicalExam),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── DIAGNÓSTICO ──────────────────────────────────────────────────
              if (_hasAny([history.workingDiagnosis, history.finalDiagnosis, history.differentialDx])) ...[
                _PreviewSection(
                  title: _hcT(lang, 'prev_dx'),
                  icon: Icons.lightbulb_rounded,
                  color: const Color(0xFF92400E),
                  children: [
                    if (history.finalDiagnosis.isNotEmpty) _PreviewItemHighlight(_hcT(lang, 'prev_final_dx'), '${history.finalDiagnosis}${history.cid.isNotEmpty ? "  (CID: ${history.cid})" : ""}', const Color(0xFF065F46)),
                    if (history.workingDiagnosis.isNotEmpty && history.finalDiagnosis.isEmpty) _PreviewItemHighlight(_hcT(lang, 'prev_work_dx'), history.workingDiagnosis, const Color(0xFF92400E)),
                    if (history.differentialDx.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_diff_dx'), history.differentialDx),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── EXAMES ───────────────────────────────────────────────────────
              if (_hasAny([history.labResults, history.imagingResults, history.otherResults])) ...[
                _PreviewSection(
                  title: _hcT(lang, 'prev_labs'),
                  icon: Icons.biotech_rounded,
                  color: const Color(0xFF6B21A8),
                  children: [
                    if (history.labResults.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_lab'), history.labResults),
                    if (history.imagingResults.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_img'), history.imagingResults),
                    if (history.otherResults.isNotEmpty) _PreviewItem('ECG / Biópsia', history.otherResults),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── CONDUTA ──────────────────────────────────────────────────────
              if (_hasAny([history.treatmentPlan, history.procedures])) ...[
                _PreviewSection(
                  title: _hcT(lang, 'prev_treat'),
                  icon: Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF0F1116),
                  children: [
                    if (history.treatmentPlan.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_plan'), history.treatmentPlan),
                    if (history.procedures.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_proc'), history.procedures),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── DESFECHO ─────────────────────────────────────────────────────
              if (_hasAny([history.dischargeCondition, history.followUp]) || history.outcome.isNotEmpty) ...[
                _PreviewSection(
                  title: _hcT(lang, 'prev_outcome'),
                  icon: Icons.door_front_door_rounded,
                  color: const Color(0xFF1E40AF),
                  children: [
                    if (history.outcome.isNotEmpty) _PreviewItemHighlight(_hcT(lang, 'prev_discharge'), _outcomeLabel(history.outcome, isEs), const Color(0xFF1E40AF)),
                    if (history.dischargeCondition.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_discharge'), history.dischargeCondition),
                    if (history.followUp.isNotEmpty) _PreviewItem(_hcT(lang, 'prev_followup'), history.followUp),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Rodapé
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFF5F5F5)),
                child: Text(
                  isEs
                    ? 'Documento generado el $dateStr por MedCases Pro. Para uso exclusivamente educativo.'
                    : 'Documento gerado em $dateStr pelo MedCases Pro. Para uso exclusivamente educacional.',
                  style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          )),
        ]),
      ),
    );
  }

  static bool _hasAny(List<String> fields) => fields.any((f) => f.isNotEmpty);

  static String _outcomeLabel(String outcome, bool isEs) {
    if (isEs) {
      const m = {'internado': 'Internado', 'alta': 'Alta hospitalaria', 'obito': 'Óbito', 'transferencia': 'Transferencia'};
      return m[outcome] ?? outcome;
    }
    const m = {'internado': 'Internado', 'alta': 'Alta hospitalar', 'obito': 'Óbito', 'transferencia': 'Transferência'};
    return m[outcome] ?? outcome;
  }
}

class _PreviewDocHeader extends StatelessWidget {
  final ClinicalHistoryModel history;
  final String dateStr;
  final bool isEs;
  const _PreviewDocHeader({required this.history, required this.dateStr, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF8FAFB),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: const Color(0xFF0F1116)),
            child: Text('HC', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFC5A365), letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(_hcT(isEs ? 'es' : 'pt', 'tab_title'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF374151), letterSpacing: 1.2))),
          Text(dateStr, style: const TextStyle(fontSize: 9, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600)),
        ]),
        const Divider(height: 16, color: Color(0xFFEEEEEE)),
        // Dados do paciente
        Wrap(spacing: 16, runSpacing: 6, children: [
          if (history.patientInitials.isNotEmpty) _PHItem(_hcT(isEs ? 'es' : 'pt', 'pdf_patient'), history.patientInitials),
          if (history.patientAge.isNotEmpty) _PHItem(_hcT(isEs ? 'es' : 'pt', 'pdf_age_label'), '${history.patientAge} ${_hcT(isEs ? "es" : "pt", "years")}'),
          if (history.patientSex.isNotEmpty) _PHItem(isEs ? 'Sexo' : 'Sexo', history.patientSex),
          if (history.patientWeight.isNotEmpty) _PHItem(isEs ? 'Peso' : 'Peso', '${history.patientWeight} kg'),
          if (history.category.isNotEmpty) _PHItem(_hcT(isEs ? 'es' : 'pt', 'pdf_specialty'), history.category),
        ]),
      ]),
    );
  }
}

class _PHItem extends StatelessWidget {
  final String label, value;
  const _PHItem(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFAAAAAA), letterSpacing: 0.8)),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
  ]);
}

class _PreviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  const _PreviewSection({required this.title, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    final visible = children.where((w) => w is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            color: color.withOpacity(0.06),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.12))),
          ),
          child: Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Center(child: Icon(icon, size: 14, color: Colors.white))),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: color)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: visible),
        ),
      ]),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final String label, text;
  const _PreviewItem(this.label, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF999999), letterSpacing: 0.8)),
      const SizedBox(height: 3),
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF222222), height: 1.55)),
    ]),
  );
}

class _PreviewItemHighlight extends StatelessWidget {
  final String label, text;
  final Color color;
  const _PreviewItemHighlight(this.label, this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withOpacity(0.06), border: Border.all(color: color.withOpacity(0.18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color.withOpacity(0.7), letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, height: 1.5)),
      ]),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withOpacity(0.12), border: Border.all(color: Colors.white.withOpacity(0.2))),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _DetailCard({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final filled = children.where((c) => c is! SizedBox).isNotEmpty;
    if (!filled) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header da seção
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: kDark.withOpacity(0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: const Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: kDark),
              child: Center(child: Icon(icon, size: 15, color: kGoldLight)),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: kDark)),
          ]),
        ),
        // Conteúdo com padding
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String label, text;
  final IconData? icon;
  const _SectionBlock(this.label, this.text, {this.icon});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ícone circular verde
        if (icon != null) ...[  
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.1),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
            ),
            child: Center(child: Icon(icon, size: 13, color: const Color(0xFF10B981))),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF6B7280))),
          const SizedBox(height: 3),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222), height: 1.55)),
        ])),
      ]),
    );
  }
}

class _AllergyBanner extends StatelessWidget {
  final String text;
  const _AllergyBanner(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFFFF1F1),
          border: Border.all(color: const Color(0xFFFF8080), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFFCC2222).withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFCC2222).withOpacity(0.12),
              border: Border.all(color: const Color(0xFFCC2222).withOpacity(0.3)),
            ),
            child: const Center(child: Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFCC2222))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚠ ALERGIAS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFCC2222), letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C), height: 1.4)),
          ])),
        ]),
      ),
    );
  }
}

class _DxBanner extends StatelessWidget {
  final String final_, working, cid, differential, lang;
  const _DxBanner({required this.final_, required this.working, required this.cid, required this.differential, required this.lang});
  @override
  Widget build(BuildContext context) {
    final hasFinal = final_.isNotEmpty;
    final primaryColor = hasFinal ? const Color(0xFF065F46) : const Color(0xFF92400E);
    final bgColor = hasFinal ? const Color(0xFFECFDF5) : const Color(0xFFFFF8E6);
    final borderColor = hasFinal ? const Color(0xFF6EE7B7) : const Color(0xFFFFD580);
    final textColor = hasFinal ? const Color(0xFF064E3B) : const Color(0xFF78350F);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header da caixa de diagnóstico
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
              child: Center(child: Icon(
                hasFinal ? Icons.check_rounded : Icons.lightbulb_outline_rounded,
                size: 14, color: Colors.white,
              )),
            ),
            const SizedBox(width: 10),
            Text(
              hasFinal ? _hcT(lang, 'dx_final_label') : _hcT(lang, 'dx_working_label'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                letterSpacing: 1.3, color: primaryColor),
            ),
          ]),
        ),
        // Conteúdo
        Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hasFinal ? final_ : working,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textColor, height: 1.25)),
            if (cid.isNotEmpty) ...[const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: primaryColor.withOpacity(0.1),
                ),
                child: Text('CID-10: $cid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryColor)),
              )],
            if (differential.isNotEmpty) ...[const SizedBox(height: 8),
              Text(_hcT(lang, 'dx_diff_label'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryColor.withOpacity(0.6), letterSpacing: 1.1)),
              const SizedBox(height: 3),
              Text(differential, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555), height: 1.4))],
          ],
        )),
      ]),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  final String outcome;
  const _OutcomeBadge(this.outcome);
  @override
  Widget build(BuildContext context) {
    final lang = context.read<AppProvider>().lang;
    final map = {
      'internado': (_hcT(lang, 'out_internado'), const Color(0xFFC5A365)),
      'alta': (_hcT(lang, 'pdf_out_alta'), const Color(0xFF065F46)),
      'obito': (_hcT(lang, 'out_obito'), const Color(0xFFCC2222)),
      'transferencia': (_hcT(lang, 'out_transf'), const Color(0xFF1E40AF)),
    };
    final info = map[outcome] ?? (_hcT(lang, 'out_internado'), kGold);
    final outcomeLabel = info.$1;
    final outcomeColor = info.$2;
    final outcomePrefix = _hcT(lang, 'outcome_title');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: outcomeColor.withOpacity(0.1), border: Border.all(color: outcomeColor.withOpacity(0.3))),
        child: Text('$outcomePrefix: $outcomeLabel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: outcomeColor)),
      ),
    );
  }
}

class _DrugChips extends StatelessWidget {
  final List<String> ids;
  final AppProvider p;
  const _DrugChips(this.ids, this.p);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('FÁRMACOS UTILIZADOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF6B7280))),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: ids.map((id) {
        final drug = p.drugsDB.where((d) => d.id == id).firstOrNull;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: kDark),
          child: Text(drug?.name ?? id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kGoldLight)),
        );
      }).toList()),
    ]);
  }
}

class _EvolutionSection extends StatelessWidget {
  final List<EvolutionEntry> evolutions;
  const _EvolutionSection({required this.evolutions});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.timeline_rounded, size: 16, color: kGold),
          SizedBox(width: 8),
          Text('EVOLUÇÃO CLÍNICA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: kDark)),
        ]),
        const SizedBox(height: 12),
        ...evolutions.map((e) {
          final _lang4 = context.read<AppProvider>().lang;
          final dt = DateTime.tryParse(e.date);
          final dateStr = dt != null
            ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${_lang4 == "es" ? "a las" : "às"} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
            : '';
          final typeLabels = _lang4 == 'es'
            ? {'evolution': 'Evolución', 'nursing': 'Enfermería', 'lab': 'Lab', 'imaging': 'Imagen', 'procedure': 'Procedimiento'}
            : {'evolution': 'Evolução', 'nursing': 'Enfermagem', 'lab': 'Lab', 'imaging': 'Imagem', 'procedure': 'Procedimento'};
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
                Container(width: 2, height: 40, color: kBorder),
              ]),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(typeLabels[e.type] ?? (_lang4 == 'es' ? 'Evolución' : 'Evolução'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGold)),
                  const Spacer(),
                  Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                ]),
                if (e.author.isNotEmpty) Text(e.author, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151), height: 1.5)),
              ])),
            ]),
          );
        }),
      ]),
    );
  }
}

class _EvolutionEditorCard extends StatefulWidget {
  final EvolutionEntry evo;
  final VoidCallback onDelete;
  final ValueChanged<EvolutionEntry> onUpdate;
  const _EvolutionEditorCard({required this.evo, required this.onDelete, required this.onUpdate});
  @override
  State<_EvolutionEditorCard> createState() => _EvolutionEditorCardState();
}

class _EvolutionEditorCardState extends State<_EvolutionEditorCard> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _authorCtrl;
  late String _type;

  static const _types = ['evolution', 'nursing', 'lab', 'imaging', 'procedure'];
  static const _typeLabelsEs = ['Evolución', 'Enfermería', 'Lab', 'Imagen', 'Procedimiento'];
  static const _typeLabels   = ['Evolução',  'Enfermagem', 'Lab', 'Imagem', 'Procedimento'];

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.evo.text);
    _authorCtrl = TextEditingController(text: widget.evo.author);
    _type = widget.evo.type;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  void _update() {
    widget.onUpdate(widget.evo.copyWith(text: _textCtrl.text, author: _authorCtrl.text, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(widget.evo.date);
    final _evoLang = context.read<AppProvider>().lang;
    final _evoLabels = _evoLang == 'es' ? _typeLabelsEs : _typeLabels;
    final dateStr = dt != null ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: kSurface),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(dateStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
          const Spacer(),
          GestureDetector(onTap: widget.onDelete, child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFCC2222))),
        ]),
        const SizedBox(height: 8),
        // Tipo de nota
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(_types.length, (i) {
          final sel = _type == _types[i];
          return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
            onTap: () { setState(() => _type = _types[i]); _update(); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: sel ? kDark : Colors.white, border: Border.all(color: sel ? kDark : kBorder)),
              child: Text(_evoLabels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sel ? kGoldLight : const Color(0xFF6B7280)))),
          ));
        }))),
        const SizedBox(height: 8),
        MedInput(controller: _authorCtrl, hintText: _evoLang == 'es' ? 'Dr./Enf. nombre del profesional' : 'Dr./Enf. nome do profissional', onChanged: (_) => _update()),
        const SizedBox(height: 6),
        MedInput(controller: _textCtrl, hintText: _evoLang == 'es' ? 'Nota de evolución...' : 'Nota de evolução...', maxLines: 4, onChanged: (_) => _update()),
      ]),
    );
  }
}

class _CommunityLoadingState extends StatelessWidget {
  final String lang;
  const _CommunityLoadingState({this.lang = 'pt'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: kGreen, strokeWidth: 2.5),
          const SizedBox(height: 14),
          Text(
            _hcT(lang, 'loading_comm'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final VoidCallback onNew;
  final String lang;
  const _EmptyHistoryState({required this.onNew, this.lang = 'pt'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Ícone discreto com opacidade suave ──────────────────────
            Icon(
              Icons.description_outlined,
              size: 38,
              color: isDark
                  ? Colors.white.withOpacity(0.18)
                  : Colors.black.withOpacity(0.13),
            ),
            const SizedBox(height: 18),

            // ── Título ───────────────────────────────────────────────────
            Text(
              _hcT(lang, 'empty_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 8),

            // ── Subtítulo ────────────────────────────────────────────────
            Text(
              _hcT(lang, 'empty_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),

            // ── Botão elegante centralizado — outlined sutil ─────────────
            GestureDetector(
              onTap: onNew,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFF27405).withOpacity(0.65),
                    width: 1.4,
                  ),
                  color: const Color(0xFFF27405).withOpacity(
                    isDark ? 0.10 : 0.07,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: isDark
                          ? const Color(0xFFFF9A3C)
                          : const Color(0xFFD46500),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hcT(lang, 'new_history_btn'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFFF9A3C)
                            : const Color(0xFFD46500),
                        letterSpacing: 0.1,
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

class _EmptyCommunityState extends StatelessWidget {
  final VoidCallback onRefresh;
  final String lang;
  const _EmptyCommunityState({required this.onRefresh, this.lang = 'pt'});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey[300]),
      const SizedBox(height: 14),
      Text(_hcT(lang, 'empty_comm_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFAAAAAA))),
      const SizedBox(height: 6),
      Text(_hcT(lang, 'empty_comm_sub'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      GestureDetector(onTap: onRefresh, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kDark),
        child: Text(_hcT(lang, 'refresh'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGoldLight)),
      )),
    ]));
  }
}

class _CommunityErrorState extends StatelessWidget {
  final VoidCallback onRefresh;
  final String lang;
  final String errorMessage;
  const _CommunityErrorState({
    required this.onRefresh,
    required this.errorMessage,
    this.lang = 'pt',
  });

  @override
  Widget build(BuildContext context) {
    final details = errorMessage.trim();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 58, color: Color(0xFFD97D54)),
            const SizedBox(height: 14),
            Text(
              _hcT(lang, 'community_error_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFAAAAAA)),
            ),
            const SizedBox(height: 6),
            Text(
              _hcT(lang, 'community_error_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7E7E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5B8A8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hcT(lang, 'error_details'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7A3C20)),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      details,
                      style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF8D4C2A), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kDark),
                child: Text(_hcT(lang, 'refresh'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGoldLight)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECIMAL INPUT FORMATTER
// Permite apenas dígitos + um único separador decimal (ponto ou vírgula).
// Normaliza vírgula → ponto para consistência no parse posterior.
// ─────────────────────────────────────────────────────────────────────────────
class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Permite vazio
    if (text.isEmpty) return newValue;

    // Substitui vírgula por ponto
    final normalized = text.replaceAll(',', '.');

    // Bloqueia se tiver mais de um ponto após normalização
    if ('.'.allMatches(normalized).length > 1) return oldValue;

    // Bloqueia caracteres que não sejam dígitos ou ponto
    if (!RegExp(r'^[0-9.]*$').hasMatch(normalized)) return oldValue;

    // Retorna com cursor ajustado ao novo texto (normalizado)
    return newValue.copyWith(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINAIS VITAIS ESTRUTURADOS
// Campos pré-definidos; texto livre gerado automaticamente no controller
// ─────────────────────────────────────────────────────────────────────────────
class _VitalSignsWidget extends StatefulWidget {
  final TextEditingController controller;
  const _VitalSignsWidget({required this.controller});
  @override
  State<_VitalSignsWidget> createState() => _VitalSignsWidgetState();
}

class _VitalSignsWidgetState extends State<_VitalSignsWidget> {
  final _pas   = TextEditingController();
  final _pad   = TextEditingController();
  final _fc    = TextEditingController();
  final _fr    = TextEditingController();
  final _temp  = TextEditingController();
  final _spo2  = TextEditingController();
  final _dext  = TextEditingController();
  final _peso  = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Parse existing text back into fields on open
    _parseExisting(widget.controller.text);
    for (final c in [_pas,_pad,_fc,_fr,_temp,_spo2,_dext,_peso]) {
      c.addListener(_syncToController);
    }
  }

  void _parseExisting(String text) {
    final regexPA  = RegExp(r'PA[:\s]+(\d+)[/\\](\d+)', caseSensitive: false);
    final regexFC  = RegExp(r'FC[:\s]+(\d+)', caseSensitive: false);
    final regexFR  = RegExp(r'FR[:\s]+(\d+)', caseSensitive: false);
    final regexT   = RegExp(r'[Tt]emp[:\s]+([\d,\.]+)', caseSensitive: false);
    final regexSp  = RegExp(r'SpO2[:\s]+([\d,\.]+)', caseSensitive: false);
    final regexDx  = RegExp(r'[Dd]extro[:\s]+([\d,\.]+)', caseSensitive: false);
    final regexP   = RegExp(r'[Pp]eso[:\s]+([\d,\.]+)', caseSensitive: false);
    final mPA  = regexPA.firstMatch(text);
    if (mPA != null) { _pas.text = mPA.group(1) ?? ''; _pad.text = mPA.group(2) ?? ''; }
    final mFC  = regexFC.firstMatch(text);  if (mFC  != null) _fc.text   = mFC.group(1)  ?? '';
    final mFR  = regexFR.firstMatch(text);  if (mFR  != null) _fr.text   = mFR.group(1)  ?? '';
    final mT   = regexT.firstMatch(text);   if (mT   != null) _temp.text = mT.group(1)   ?? '';
    final mSp  = regexSp.firstMatch(text);  if (mSp  != null) _spo2.text = mSp.group(1)  ?? '';
    final mDx  = regexDx.firstMatch(text);  if (mDx  != null) _dext.text = mDx.group(1)  ?? '';
    final mP   = regexP.firstMatch(text);   if (mP   != null) _peso.text = mP.group(1)   ?? '';
  }

  void _syncToController() {
    final parts = <String>[];
    if (_pas.text.isNotEmpty || _pad.text.isNotEmpty) parts.add('PA ${_pas.text.isNotEmpty ? _pas.text : "?"}/${_pad.text.isNotEmpty ? _pad.text : "?"} mmHg');
    if (_fc.text.isNotEmpty)   parts.add('FC ${_fc.text} bpm');
    if (_fr.text.isNotEmpty)   parts.add('FR ${_fr.text} irpm');
    if (_temp.text.isNotEmpty) parts.add('Temp ${_temp.text}°C');
    if (_spo2.text.isNotEmpty) parts.add('SpO2 ${_spo2.text}%');
    if (_dext.text.isNotEmpty) parts.add('Dextro ${_dext.text} mg/dL');
    if (_peso.text.isNotEmpty) parts.add('Peso ${_peso.text} kg');
    widget.controller.text = parts.join(' | ');
  }

  @override
  void dispose() {
    // MEMLEAK-FIX: remove listeners antes de chamar dispose() nos controllers,
    // evitando callbacks disparados depois que o widget já foi desmontado.
    for (final c in [_pas,_pad,_fc,_fr,_temp,_spo2,_dext,_peso]) {
      c.removeListener(_syncToController);
      c.dispose();
    }
    super.dispose();
  }

  Widget _vsField(String label, TextEditingController ctrl, String unit,
      {String hint = '', bool wide = false, bool decimal = false,
       required bool isDark, required Color inputFill, required Color inputText}) {
    final borderColor = isDark ? const Color(0xFF3A4A42) : kBorder;
    return SizedBox(
      width: wide ? double.infinity : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: isDark ? const Color(0xFF9AADA5) : const Color(0xFF6B7280))),
        const SizedBox(height: 3),
        Row(children: [
          SizedBox(
            width: wide ? 80 : 56,
            height: 36,
            child: TextField(
              controller: ctrl,
              // iOS: numberWithOptions(decimal:true) não garante ponto no teclado
              // quando locale usa vírgula. TextInputType.text força teclado QWERTY
              // completo onde ponto/vírgula estão sempre disponíveis.
              keyboardType: decimal
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(decimal: false, signed: false),
              inputFormatters: decimal
                  ? [_DecimalInputFormatter()]
                  : [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: inputText),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: hint,
                hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF5A6A62) : const Color(0xFFBBBBBB)),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Text(unit, style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9AADA5) : const Color(0xFF6B7280), fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Dark mode: fundo do card escuro, texto de input visível
    final cardBg    = isDark ? const Color(0xFF252930) : const Color(0xFFF8FBFA);
    final inputFill = isDark ? const Color(0xFF1C2226) : const Color(0xFFF8F8F8);
    final inputText = isDark ? const Color(0xFFE8F0EC) : const Color(0xFF0D1611);
    final borderColor = isDark ? const Color(0xFF3A4A42) : kBorder;
    final labelColor = isDark ? const Color(0xFF9AADA5) : const Color(0xFF555555);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        color: cardBg,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.monitor_heart_rounded, size: 14, color: kGreen),
          const SizedBox(width: 6),
          Text(_hcT(context.read<AppProvider>().lang, 'vitals_title').toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: labelColor)),
          const Spacer(),

        ]),
        const SizedBox(height: 10),
        // Linha 1: PA (2 campos) + FC + FR
        Wrap(spacing: 10, runSpacing: 10, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: isDark ? const Color(0xFF9AADA5) : const Color(0xFF6B7280))),
            const SizedBox(height: 3),
            Row(children: [
              SizedBox(width: 50, height: 36, child: TextField(
                controller: _pas, keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: inputText),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: '120',
                  hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF5A6A62) : const Color(0xFFBBBBBB)),
                  filled: true, fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5))),
              )),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text('/', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300, color: isDark ? const Color(0xFF9AADA5) : const Color(0xFF6B7280)))),
              SizedBox(width: 50, height: 36, child: TextField(
                controller: _pad, keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: inputText),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: '80',
                  hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF5A6A62) : const Color(0xFFBBBBBB)),
                  filled: true, fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5))),
              )),
              const SizedBox(width: 4),
              Text('mmHg', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9AADA5) : const Color(0xFF6B7280), fontWeight: FontWeight.w700)),
            ]),
          ]),
          _vsField('FC', _fc, 'bpm', hint: '80', isDark: isDark, inputFill: inputFill, inputText: inputText),
          _vsField('FR', _fr, 'irpm', hint: '16', isDark: isDark, inputFill: inputFill, inputText: inputText),
          _vsField('Temp', _temp, '°C', hint: '36,5', decimal: true, isDark: isDark, inputFill: inputFill, inputText: inputText),
          _vsField('SpO₂', _spo2, '%', hint: '98', decimal: true, isDark: isDark, inputFill: inputFill, inputText: inputText),
          _vsField('Dextro', _dext, 'mg/dL', hint: '100', decimal: true, isDark: isDark, inputFill: inputFill, inputText: inputText),
          _vsField('Peso', _peso, 'kg', hint: '70', wide: true, decimal: true, isDark: isDark, inputFill: inputFill, inputText: inputText),
        ]),
        if (widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withOpacity(0.06)),
            child: Text(widget.controller.text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ECG ESTRUTURADO
// ─────────────────────────────────────────────────────────────────────────────
class _EcgStructuredWidget extends StatefulWidget {
  final TextEditingController controller;
  const _EcgStructuredWidget({required this.controller});
  @override
  State<_EcgStructuredWidget> createState() => _EcgStructuredWidgetState();
}

class _EcgStructuredWidgetState extends State<_EcgStructuredWidget> {
  bool _expanded = false;
  String _ritmo = 'Sinusal';
  final _fc    = TextEditingController();
  final _pr    = TextEditingController();
  final _qrs   = TextEditingController();
  final _qt    = TextEditingController();
  final _eixo  = TextEditingController();
  final _st    = TextEditingController();
  final _outros = TextEditingController();

  static const _ritmos = ['Sinusal', 'FA', 'Flutter', 'BAV 1º', 'BAV 2º', 'BAV 3º', 'ESSV', 'TV', 'FV', 'Marcapasso', 'Outro'];

  @override
  void dispose() {
    for (final c in [_fc, _pr, _qrs, _qt, _eixo, _st, _outros]) c.dispose();
    super.dispose();
  }

  void _sync() {
    final parts = <String>[];
    parts.add('Ritmo: $_ritmo');
    if (_fc.text.isNotEmpty)    parts.add('FC: ${_fc.text} bpm');
    if (_pr.text.isNotEmpty)    parts.add('PR: ${_pr.text} ms');
    if (_qrs.text.isNotEmpty)   parts.add('QRS: ${_qrs.text} ms');
    if (_qt.text.isNotEmpty)    parts.add('QTc: ${_qt.text} ms');
    if (_eixo.text.isNotEmpty)  parts.add('Eixo: ${_eixo.text}°');
    if (_st.text.isNotEmpty)    parts.add('ST/T: ${_st.text}');
    if (_outros.text.isNotEmpty) parts.add('Outros: ${_outros.text}');
    widget.controller.text = 'ECG — ${parts.join(' | ')}';
    setState(() {});
  }

  Widget _numField(String label, TextEditingController ctrl, {String hint = ''}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF6B7280))),
      const SizedBox(height: 3),
      SizedBox(width: 64, height: 34, child: TextField(
        controller: ctrl, keyboardType: TextInputType.number, onChanged: (_) => _sync(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), hintText: hint,
          hintStyle: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.5))),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: const Color(0xFFFFFBF2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header clicável
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
            const Icon(Icons.monitor_rounded, size: 14, color: kGold),
            const SizedBox(width: 6),
            const Text('ECG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF555555))),
            const SizedBox(width: 8),
            if (widget.controller.text.isNotEmpty)
              Expanded(child: Text(widget.controller.text, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            const Spacer(),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: const Color(0xFF6B7280)),
          ])),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: kBorder),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ritmo
            Text(_hcT(context.read<AppProvider>().lang, 'ecg_ritmo').toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _ritmos.map((r) {
              final sel = r == _ritmo;
              return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                onTap: () { setState(() => _ritmo = r); _sync(); },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: sel ? kDark : Colors.white, border: Border.all(color: sel ? kDark : kBorder)),
                  child: Text(r, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sel ? kGoldLight : const Color(0xFF666666)))),
              ));
            }).toList())),
            const SizedBox(height: 10),
            // Intervalos
            Wrap(spacing: 10, runSpacing: 10, children: [
              _numField('FC (bpm)', _fc, hint: '72'),
              _numField('PR (ms)', _pr, hint: '160'),
              _numField('QRS (ms)', _qrs, hint: '90'),
              _numField('QTc (ms)', _qt, hint: '440'),
              _numField('Eixo (°)', _eixo, hint: '60'),
            ]),
            const SizedBox(height: 10),
            // ST livre
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_hcT(context.read<AppProvider>().lang, 'ecg_st').toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF6B7280))),
              const SizedBox(height: 3),
              TextField(controller: _st, onChanged: (_) => _sync(),
                enableSuggestions: true,
                autocorrect: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: 'Supra V1-V4, infra lateral, invertida...',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.5)))),
            ]),
            const SizedBox(height: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_hcT(context.read<AppProvider>().lang, 'ecg_outros').toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF6B7280))),
              const SizedBox(height: 3),
              TextField(controller: _outros, onChanged: (_) => _sync(),
                enableSuggestions: true,
                autocorrect: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: 'BRD, BRE, HVE, ESSV, ondas Q...',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.5)))),
            ]),
          ])),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LAB ESTRUTURADO + OCR via FILE INPUT
// ─────────────────────────────────────────────────────────────────────────────
class _LabStructuredWidget extends StatefulWidget {
  final TextEditingController controller;
  const _LabStructuredWidget({required this.controller});
  @override
  State<_LabStructuredWidget> createState() => _LabStructuredWidgetState();
}

class _LabStructuredWidgetState extends State<_LabStructuredWidget> {
  bool _expanded = false;
  bool _ocrLoading = false;
  String _ocrStatus = '';

  final _hb    = TextEditingController();
  final _ht    = TextEditingController();
  final _leuco = TextEditingController();
  final _plaq  = TextEditingController();
  final _na    = TextEditingController();
  final _k     = TextEditingController();
  final _cr    = TextEditingController();
  final _ur    = TextEditingController();
  final _gli   = TextEditingController();
  final _pcr   = TextEditingController();
  final _tni   = TextEditingController();
  final _bnp   = TextEditingController();
  final _lac   = TextEditingController();
  final _tp    = TextEditingController();
  final _tgo   = TextEditingController();
  final _tgp   = TextEditingController();
  final _outros = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_hb,_ht,_leuco,_plaq,_na,_k,_cr,_ur,_gli,_pcr,_tni,_bnp,_lac,_tp,_tgo,_tgp,_outros]) {
      c.addListener(_sync);
    }
  }

  @override
  void dispose() {
    // MEMLEAK-FIX: remove listeners antes de chamar dispose() nos controllers.
    for (final c in [_hb,_ht,_leuco,_plaq,_na,_k,_cr,_ur,_gli,_pcr,_tni,_bnp,_lac,_tp,_tgo,_tgp,_outros]) {
      c.removeListener(_sync);
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    final parts = <String>[];
    void add(String label, TextEditingController ctrl, String unit) {
      if (ctrl.text.isNotEmpty) parts.add('$label: ${ctrl.text} $unit'.trim());
    }
    add('Hb', _hb, 'g/dL'); add('Ht', _ht, '%'); add('Leuco', _leuco, '/mm³'); add('Plaq', _plaq, '×10³');
    add('Na⁺', _na, 'mEq/L'); add('K⁺', _k, 'mEq/L'); add('Cr', _cr, 'mg/dL'); add('Ur', _ur, 'mg/dL');
    add('Gli', _gli, 'mg/dL'); add('PCR', _pcr, 'mg/L'); add('TnI', _tni, 'ng/mL'); add('BNP', _bnp, 'pg/mL');
    add('Lactato', _lac, 'mmol/L'); add('TP', _tp, '%'); add('TGO', _tgo, 'U/L'); add('TGP', _tgp, 'U/L');
    if (_outros.text.isNotEmpty) parts.add(_outros.text.trim());
    widget.controller.text = parts.join('\n');
    if (mounted) setState(() {});
  }

  // ── OCR: Web via dart:html | Nativo via image_picker + Gemini ───────────
  Future<void> _openOcrPicker() async {
    if (kIsWeb) {
      // ── Web: fluxo original ──────────────────────────────────────────────
      setState(() { _ocrLoading = true; _ocrStatus = 'Lendo imagem...'; });
      try {
        final text = await webPlatform.webPickImageAndOcr();
        if (text.isEmpty) {
          if (mounted) setState(() {
            _ocrLoading = false;
            _ocrStatus = 'Imagem carregada — preencha os campos manualmente';
            _outros.text = '(Laudo de imagem — edite os valores acima)';
          });
        } else {
          _applyOcrText(text);
          if (mounted) setState(() { _ocrLoading = false; _ocrStatus = 'Texto extraído! Revise os campos.'; });
        }
      } catch (e) {
        if (mounted) setState(() { _ocrLoading = false; _ocrStatus = 'Falha OCR: $e'; });
      }
      return;
    }

    // ── Nativo: solicitar permissão → image_picker → Gemini Vision ─────────
    final lang = context.read<AppProvider>().lang;
    final isEs = lang == 'es';

    // Mostra bottom sheet de seleção: câmera ou galeria
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1D23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isEs ? 'Importar Examen' : 'Importar Exame',
                style: const TextStyle(
                  color: Color(0xFFEEF2EE),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEs
                    ? 'Fotografíe o seleccione el examen de laboratorio'
                    : 'Fotografe ou selecione o exame laboratorial',
                style: const TextStyle(color: Color(0xFF7A9486), fontSize: 12),
              ),
              const SizedBox(height: 16),
              // Câmera
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF46E28C).withOpacity(0.10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF46E28C), size: 20),
                ),
                title: Text(
                  isEs ? 'Tirar Foto' : 'Tirar Foto',
                  style: const TextStyle(
                    color: Color(0xFFEEF2EE),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  isEs
                      ? 'Capturar con la cámara del dispositivo'
                      : 'Capturar usando a câmera do dispositivo',
                  style: const TextStyle(
                    color: Color(0xFF7A9486), fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              // Galeria
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF46E28C).withOpacity(0.10),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFF46E28C), size: 20),
                ),
                title: Text(
                  isEs ? 'Elegir de la Galería' : 'Escolher da Galeria',
                  style: const TextStyle(
                    color: Color(0xFFEEF2EE),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  isEs
                      ? 'Seleccionar imagen guardada'
                      : 'Selecionar imagem salva',
                  style: const TextStyle(
                    color: Color(0xFF7A9486), fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    // Solicitar permissão de acordo com a fonte selecionada
    final PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = await Permission.photos.request();
    }

    if (!mounted) return;

    if (status.isPermanentlyDenied) {
      _showOcrPermissionDenied(isEs, source == ImageSource.camera);
      return;
    }
    if (!status.isGranted && !status.isLimited) {
      _setOcrStatus(isEs
          ? 'Permiso denegado. Intente de nuevo.'
          : 'Permissão negada. Tente novamente.');
      return;
    }

    // Permissão concedida → capturar imagem
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: source,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (!mounted) return;
    if (photo == null) return;

    setState(() {
      _ocrLoading = true;
      _ocrStatus = isEs ? 'Analizando examen...' : 'Analisando exame...';
    });

    try {
      final bytes = await photo.readAsBytes();
      final ext   = photo.name.toLowerCase().split('.').last;
      final mime  = ext == 'png' ? 'image/png'
                  : ext == 'webp' ? 'image/webp'
                  : 'image/jpeg';

      // Gemini Vision extrai o texto do laudo
      final results = await _LabOcrService.extractText(bytes, mime, lang);

      if (results.isEmpty) {
        if (mounted) setState(() {
          _ocrLoading = false;
          _ocrStatus = isEs
              ? 'No se identificaron valores. Complete manualmente.'
              : 'Nenhum valor identificado. Preencha manualmente.';
        });
      } else {
        _applyOcrText(results);
        if (mounted) setState(() {
          _ocrLoading = false;
          _ocrStatus = isEs
              ? 'Valores extraídos. Revise los campos.'
              : 'Valores extraídos. Revise os campos.';
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _ocrLoading = false;
        _ocrStatus = isEs ? 'Error: $e' : 'Erro: $e';
      });
    }
  }

  void _setOcrStatus(String msg) {
    if (mounted) setState(() { _ocrLoading = false; _ocrStatus = msg; });
  }

  void _showOcrPermissionDenied(bool isEs, bool isCamera) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D23),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            isCamera ? Icons.camera_alt_rounded : Icons.photo_library_rounded,
            color: const Color(0xFFF59E0B), size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            isEs
                ? (isCamera ? 'Acceso a la Cámara' : 'Acceso a la Galería')
                : (isCamera ? 'Acesso à Câmera' : 'Acesso à Galeria'),
            style: const TextStyle(
              color: Color(0xFFEEF2EE),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        content: Text(
          isEs
              ? 'MedCases Pro necesita este permiso para importar exámenes. Toque "Configuración" para habilitarlo.'
              : 'O MedCases Pro precisa desta permissão para importar exames. Toque em "Configurações" para habilitá-la.',
          style: const TextStyle(
            color: Color(0xFF7A9486), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isEs ? 'Cancelar' : 'Cancelar',
              style: const TextStyle(color: Color(0xFF7A9486)),
            ),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); openAppSettings(); },
            child: Text(
              isEs ? 'Configuración' : 'Configurações',
              style: const TextStyle(
                color: Color(0xFF46E28C), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _applyOcrText(String text) {
    // Heurística para extrair valores comuns de laudos
    final t = text.toLowerCase();
    void extract(TextEditingController c, List<String> patterns) {
      for (final p in patterns) {
        final m = RegExp('$p[:\\s]+(\\d+[,.]?\\d*)').firstMatch(t);
        if (m != null && c.text.isEmpty) { c.text = m.group(1)?.replaceAll(',', '.') ?? ''; break; }
      }
    }
    extract(_hb,   ['hemoglobina', 'hb']);
    extract(_ht,   ['hematocrito', 'ht']);
    extract(_leuco,['leucocitos', 'leuco', 'glóbulos blancos']);
    extract(_plaq, ['plaquetas', 'plaq', 'trombocitos']);
    extract(_na,   ['sodio', 'na']);
    extract(_k,    ['potasio', 'potássio', 'kalium', '\\bk\\b']);
    extract(_cr,   ['creatinina', 'cr']);
    extract(_ur,   ['ureia', 'urea', 'ur']);
    extract(_gli,  ['glicose', 'glucosa', 'glucose']);
    extract(_pcr,  ['pcr', 'proteina c reativa', 'proteína c reactiva']);
    extract(_tni,  ['troponina', 'tni', 'tnI']);
    extract(_bnp,  ['bnp', 'nt-probnp', 'proBNP']);
    extract(_lac,  ['lactato', 'lactic']);
    extract(_tp,   ['tp', 'tp%', 'atividade protrombinica']);
    extract(_tgo,  ['tgo', 'ast', 'aspartato']);
    extract(_tgp,  ['tgp', 'alt', 'alanino']);
    // Restante vai para "outros" se houver linhas relevantes
    if (_outros.text.isEmpty && text.length > 50) {
      _outros.text = text.substring(0, text.length > 300 ? 300 : text.length).trim();
    }
  }

  Widget _labField(String label, TextEditingController ctrl, String hint, {Color? flagColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF6B7280))),
      const SizedBox(height: 3),
      SizedBox(width: 68, height: 34, child: TextField(
        controller: ctrl, keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: flagColor ?? const Color(0xFF1A1D23)),
        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7), hintText: hint,
          hintStyle: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flagColor?.withOpacity(0.4) ?? kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flagColor?.withOpacity(0.4) ?? kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flagColor ?? const Color(0xFF065F46), width: 1.5))),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: const Color(0xFFF7FFFE)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
            const Icon(Icons.science_rounded, size: 14, color: Color(0xFF065F46)),
            const SizedBox(width: 6),
            Text(_hcT(context.read<AppProvider>().lang, 'lab_exams').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF555555))),
            const SizedBox(width: 8),
            if (widget.controller.text.isNotEmpty && !_expanded)
              Expanded(child: Text(_hcT(context.read<AppProvider>().lang, 'lab_filled'), style: const TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w700))),
            const Spacer(),
            // Botão OCR
            GestureDetector(
              onTap: _ocrLoading ? null : _openOcrPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withOpacity(0.08), border: Border.all(color: const Color(0xFF065F46).withOpacity(0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_ocrLoading)
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF065F46)))
                  else
                    const Icon(Icons.document_scanner_rounded, size: 11, color: Color(0xFF065F46)),
                  const SizedBox(width: 3),
                  Text(_ocrLoading ? _hcT(context.read<AppProvider>().lang, 'ocr_loading') : _hcT(context.read<AppProvider>().lang, 'ocr_btn'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: const Color(0xFF6B7280)),
          ])),
        ),
        if (_ocrStatus.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(_ocrStatus, style: TextStyle(fontSize: 10, color: _ocrStatus.startsWith('Erro') || _ocrStatus.startsWith('Falha') ? Colors.red : const Color(0xFF065F46), fontWeight: FontWeight.w700))),
        if (_expanded) ...[
          const Divider(height: 1, color: kBorder),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Hemograma
            const Text('HEMOGRAMA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFFAAAAAA))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _labField('Hb (g/dL)', _hb, '12–16'),
              _labField('Ht (%)', _ht, '36–48'),
              _labField('Leuco (/mm³)', _leuco, '4–11k'),
              _labField('Plaq (×10³)', _plaq, '150–400'),
            ]),
            const SizedBox(height: 10),
            // Eletrólitos / Função Renal
            const Text('ELETRÓLITOS / FUNÇÃO RENAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFFAAAAAA))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _labField('Na⁺ (mEq/L)', _na, '135–145'),
              _labField('K⁺ (mEq/L)', _k, '3.5–5.0'),
              _labField('Cr (mg/dL)', _cr, '<1.2'),
              _labField('Ur (mg/dL)', _ur, '15–40'),
              _labField('Gli (mg/dL)', _gli, '70–100'),
            ]),
            const SizedBox(height: 10),
            // Marcadores
            const Text('MARCADORES / OUTROS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFFAAAAAA))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _labField('PCR (mg/L)', _pcr, '<5'),
              _labField('TnI (ng/mL)', _tni, '<0.04'),
              _labField('BNP (pg/mL)', _bnp, '<100'),
              _labField('Lactato', _lac, '<2.0'),
              _labField('TP (%)', _tp, '70–120'),
              _labField('TGO (U/L)', _tgo, '<40'),
              _labField('TGP (U/L)', _tgp, '<40'),
            ]),
            const SizedBox(height: 10),
            // Campo livre
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_hcT(context.read<AppProvider>().lang, 'lab_others_title').toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFFAAAAAA))),
              const SizedBox(height: 3),
              TextField(controller: _outros,
                maxLines: 3,
                enableSuggestions: true,
                autocorrect: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: _hcT(context.read<AppProvider>().lang, 'lab_others_hint'),
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF065F46), width: 1.5))),),
            ]),
          ])),
        ],
        // Preview resumo
        if (widget.controller.text.isNotEmpty && !_expanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withOpacity(0.06)),
              child: Text(widget.controller.text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF065F46), height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PNG CANVAS HELPERS — Widgets para captura RepaintBoundary (fondo blanco)
// Esquema oficial 11 secciones — Argentina — MedCases Pro
// ─────────────────────────────────────────────────────────────────────────────

// Divisor dourado fino reutilizável
class _PngDivider extends StatelessWidget {
  const _PngDivider();
  @override
  Widget build(BuildContext context) => Container(
    height: 0.75, margin: const EdgeInsets.symmetric(vertical: 7),
    color: const Color(0xFFC5A365).withOpacity(0.55),
  );
}

// Título de seção: texto UPPERCASE bold + divisor dourado fino
class _PngSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PngSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final nonEmpty = children.where((w) => w is! SizedBox).toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PngDivider(),
      Text(title,
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
              letterSpacing: 1.6, color: Color(0xFF111827))),
      const SizedBox(height: 6),
      ...children,
      const SizedBox(height: 4),
    ]);
  }
}

// Campo individual: etiqueta cinza + valor grafito
class _PngField extends StatelessWidget {
  final String label;
  final String value;
  final bool large;
  final bool mono;
  const _PngField(this.label, this.value, {this.large = false, this.mono = false});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label.isNotEmpty)
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700,
                  color: Color(0xFF6b7280), letterSpacing: 0.9)),
        if (label.isNotEmpty) const SizedBox(height: 1),
        Text(value,
            style: TextStyle(
              fontSize: large ? 13 : 11,
              fontWeight: large ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xFF1a1a1a),
              fontFamily: mono ? 'monospace' : null,
              height: 1.5,
            )),
      ]),
    );
  }
}

// Bloco de alergias: linha vermelha discreta
class _PngAllergyField extends StatelessWidget {
  final String value;
  const _PngAllergyField(this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        border: Border(left: BorderSide(color: const Color(0xFFDC2626), width: 2.5)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⚠ ALÉRGICOS',
            style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900,
                color: Color(0xFFDC2626), letterSpacing: 0.9)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B), height: 1.4)),
      ]),
    );
  }
}

// Sección diagnóstica con fondo verde muy suave
class _PngDxSection extends StatelessWidget {
  final String title;
  final String working;
  final String differential;
  final String final_;
  final String cid;
  const _PngDxSection({
    required this.title, required this.working,
    required this.differential, required this.final_, required this.cid,
  });

  @override
  Widget build(BuildContext context) {
    if (working.isEmpty && differential.isEmpty && final_.isEmpty)
      return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PngDivider(),
      Text(title,
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
              letterSpacing: 1.6, color: Color(0xFF111827))),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          border: Border(left: BorderSide(color: const Color(0xFF16A34A), width: 2.5)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (working.isNotEmpty) ...[
            const Text('IMPRESIÓN / HIPÓTESIS',
                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900,
                    color: Color(0xFF15803D), letterSpacing: 0.9)),
            const SizedBox(height: 2),
            Text(working,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF14532D), height: 1.4)),
          ],
          if (differential.isNotEmpty) ...[
            const SizedBox(height: 5),
            const Text('DIAGNÓSTICOS DIFERENCIALES',
                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D), letterSpacing: 0.9)),
            const SizedBox(height: 2),
            Text(differential,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF166534), height: 1.4)),
          ],
          if (final_.isNotEmpty) ...[
            if (working.isNotEmpty || differential.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(height: 0.5, color: const Color(0xFF16A34A).withOpacity(0.35)),
              const SizedBox(height: 6),
            ],
            Text(final_,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                    color: Color(0xFF0D4A24), height: 1.4)),
            if (cid.isNotEmpty)
              Text('CIE-10: $cid',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D))),
          ],
        ]),
      ),
      const SizedBox(height: 4),
    ]);
  }
}

// Entrada de evolución clínica (línea dorada izquierda)
class _PngEvolution extends StatelessWidget {
  final String dateStr;
  final String author;
  final String text;
  const _PngEvolution({required this.dateStr, required this.author, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFC5A365), width: 2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          [if (dateStr.isNotEmpty) dateStr, if (author.isNotEmpty) author].join('  ·  '),
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700,
              color: Color(0xFF6b7280)),
        ),
        const SizedBox(height: 2),
        Text(text,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF1a1a1a), height: 1.5)),
      ]),
    );
  }
}

// Badge de desfecho/alta
class _PngOutcomeBadge extends StatelessWidget {
  final String outcome;
  final String lang;
  const _PngOutcomeBadge(this.outcome, this.lang);

  @override
  Widget build(BuildContext context) {
    final labels = {
      'internado':    lang == 'es' ? 'Hospitalizado'   : 'Internado',
      'alta':         lang == 'es' ? 'Alta hospitalaria' : 'Alta hospitalar',
      'obito':        lang == 'es' ? 'Fallecimiento'   : 'Óbito',
      'transferencia': lang == 'es' ? 'Traslado'        : 'Transferência',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4), width: 1),
      ),
      child: Text(labels[outcome] ?? outcome,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
              color: Color(0xFF15803D))),
    );
  }
}

// ── Serviço OCR nativo via Gemini Vision ───────────────────────────────────
// Envia a imagem do exame laboratorial ao Gemini 2.5 Flash e retorna
// o texto extraído. Usado exclusivamente no fluxo nativo (iOS/Android).
// Web continua usando webPlatform.webPickImageAndOcr() (Tesseract.js).
class _LabOcrService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static final _promptPt =
      'Você é um leitor especializado de resultados de exames laboratoriais. '
      'Extraia TODOS os valores numéricos do exame na imagem. '
      'Para cada parâmetro retorne uma linha no formato: "NOME: VALOR UNIDADE". '
      'Exemplo: "Hemoglobina: 12.5 g/dL". '
      'Inclua todos os valores visíveis. Retorne SOMENTE as linhas de resultados, sem texto adicional.';

  static final _promptEs =
      'Eres un lector especializado de resultados de exámenes de laboratorio. '
      'Extrae TODOS los valores numéricos del examen en la imagen. '
      'Para cada parámetro retorna una línea en el formato: "NOMBRE: VALOR UNIDAD". '
      'Ejemplo: "Hemoglobina: 12.5 g/dL". '
      'Incluye todos los valores visibles. Retorna SOLAMENTE las líneas de resultados, sin texto adicional.';

  /// Retorna texto extraído da imagem ou string vazia se não encontrar valores.
  static Future<String> extractText(
    Uint8List imageBytes,
    String mimeType,
    String lang,
  ) async {
    final apiKey = GeminiService.apiKeyForLab;
    if (apiKey.isEmpty) {
      throw Exception(lang == 'es'
          ? 'Conecta tu cuenta Google en el menú lateral.'
          : 'Conecte sua conta Google no menu lateral.');
    }

    final b64 = base64Encode(imageBytes);
    final prompt = lang == 'es' ? _promptEs : _promptPt;

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': b64,
              }
            },
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 1024,
      },
    };

    final response = await http
        .post(
          Uri.parse('$_endpoint?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Gemini ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List? ?? [];
    if (candidates.isEmpty) return '';
    final content = candidates.first['content'] as Map<String, dynamic>? ?? {};
    final parts   = content['parts'] as List? ?? [];
    if (parts.isEmpty) return '';
    return (parts.first['text'] as String? ?? '').trim();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORGANIZAR COM IA — sheet de texto livre → IA distribui nos campos da HC
// Suporta: digitação manual, colar texto ou ditado por voz.
// Prompt completo: extrai 10 campos clínicos do texto bruto.
// ─────────────────────────────────────────────────────────────────────────────
class _OrganizarIASheet extends StatefulWidget {
  final String lang;
  final String apiKey;
  final void Function(Map<String, String> data) onFill;

  const _OrganizarIASheet({
    required this.lang,
    required this.apiKey,
    required this.onFill,
  });

  @override
  State<_OrganizarIASheet> createState() => _OrganizarIASheetState();
}

class _OrganizarIASheetState extends State<_OrganizarIASheet> {
  final _ctrl        = TextEditingController();
  bool  _processing  = false;
  bool  _voiceActive = false;
  String _voiceInterim = '';
  String _voiceBuffer  = '';
  webPlatform.WebSpeechRecognizer? _voiceRecog;

  static const _kGreen  = Color(0xFF10B981);
  static const _kPurple = Color(0xFF7C3AED);

  String get _lang => widget.lang;
  bool   get _isEs => _lang == 'es';

  @override
  void dispose() {
    _ctrl.dispose();
    _voiceRecog?.stop();
    SttHelper.stop();
    super.dispose();
  }

  // ── Ditado de voz para o campo de texto livre ─────────────────────────────
  void _toggleVoice() {
    FocusScope.of(context).unfocus();
    if (_voiceActive) {
      _voiceRecog?.stop();
      SttHelper.stop();
      // Flush buffer
      if (_voiceBuffer.isNotEmpty) {
        final existing = _ctrl.text.trim();
        _ctrl.text = existing.isEmpty ? _voiceBuffer : '$existing $_voiceBuffer';
        _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
      }
      if (mounted) setState(() { _voiceActive = false; _voiceInterim = ''; _voiceBuffer = ''; });
      return;
    }

    _voiceBuffer = '';
    final locale = _isEs ? 'es-ES' : 'pt-BR';

    if (kIsWeb) {
      final recog = webPlatform.WebSpeechRecognizer();
      recog.start('organizar', locale,
        onResult: (t, isFinal) {
          if (!mounted) return;
          if (isFinal) {
            _voiceBuffer += (_voiceBuffer.isEmpty ? '' : ' ') + t.trim();
            if (mounted) setState(() => _voiceInterim = '');
          } else {
            if (mounted) setState(() => _voiceInterim = t);
          }
        },
        onEnd: () {
          if (_voiceActive && mounted) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_voiceActive && mounted) {
                _voiceRecog?.start('organizar', locale,
                  onResult: (t, f) {}, onEnd: () {}, onError: (_) {});
              }
            });
          }
        },
        onError: (code) {
          if (code != 'no-speech' && mounted) {
            setState(() { _voiceActive = false; _voiceInterim = ''; });
          }
        },
      );
      _voiceRecog = recog;
    } else {
      void startLoop() {
        // STT-GUARD: erros nativos de áudio / microfone não devem fechar o app.
        try {
          SttHelper.start(
            locale: locale,
            onResult: (t) {
              if (!mounted || !_voiceActive) return;
              _voiceBuffer += (_voiceBuffer.isEmpty ? '' : ' ') + t.trim();
              if (mounted) setState(() => _voiceInterim = '');
            },
            onError: (code) {
              if (!mounted) return;
              if (code == 'no_speech' || code == 'no-speech') {
                if (_voiceActive) Future.delayed(const Duration(milliseconds: 300), startLoop);
                return;
              }
              setState(() { _voiceActive = false; _voiceInterim = ''; });
            },
            onEnd: () {
              if (_voiceActive && mounted) {
                Future.delayed(const Duration(milliseconds: 300), startLoop);
              }
            },
          );
        } catch (e, st) {
          debugPrint('[HistoryScreen][organizar.startLoop] SttHelper.start exception: $e\n$st');
          if (mounted) setState(() { _voiceActive = false; _voiceInterim = ''; });
        }
      }
      startLoop();
    }
    if (mounted) setState(() { _voiceActive = true; _voiceInterim = ''; });
  }

  // ── Chama IA para estruturar o texto ─────────────────────────────────────
  Future<void> _process() async {
    // Flush voice se ativo
    if (_voiceActive) {
      _voiceRecog?.stop();
      SttHelper.stop();
      if (_voiceBuffer.isNotEmpty) {
        final existing = _ctrl.text.trim();
        _ctrl.text = existing.isEmpty ? _voiceBuffer : '$existing $_voiceBuffer';
        _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
      }
      if (mounted) setState(() { _voiceActive = false; _voiceInterim = ''; _voiceBuffer = ''; });
    }

    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_hcT(_lang, 'organizar_empty')),
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
      return;
    }

    if (widget.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_hcT(_lang, 'relato_no_key')),
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
      return;
    }

    if (mounted) setState(() => _processing = true);

    const systemPrompt =
        'Você é um assistente especializado em registros médicos. '
        'Receba um texto clínico bruto (digitado ou ditado) e distribua '
        'as informações nos campos corretos do prontuário médico.\n\n'
        'Retorne SOMENTE um objeto JSON válido (sem markdown, sem ```json) '
        'com estas chaves (use string vazia "" para campos não encontrados):\n'
        '{\n'
        '  "motivo_consulta": "",\n'
        '  "anamnese": "",\n'
        '  "antecedentes": "",\n'
        '  "medicamentos": "",\n'
        '  "alergias": "",\n'
        '  "sinais_vitais": "",\n'
        '  "exame_fisico": "",\n'
        '  "hipotese_diagnostica": "",\n'
        '  "conduta": "",\n'
        '  "exames": ""\n'
        '}';

    try {
      final result = await AiService.chat(
        apiKey:       widget.apiKey,
        systemPrompt: systemPrompt,
        userMessage:  'Texto clínico:\n$text',
        maxTokens:    1200,
      );

      if (!mounted) return;
      setState(() => _processing = false);

      if (result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_hcT(_lang, 'organizar_error')),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        ));
        return;
      }

      final clean = result.text
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();

      final data = jsonDecode(clean) as Map<String, dynamic>;
      final mapped = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      Navigator.of(context).pop();
      widget.onFill(mapped);
    } catch (_) {
      if (mounted) setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_hcT(_lang, 'organizar_error')),
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0F1A14) : Colors.white;
    final border = isDark ? const Color(0xFF1F3829) : const Color(0xFFE2EDE7);
    final textCol= isDark ? Colors.white : const Color(0xFF0F1116);
    final subCol = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: border),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCDD6E0),
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                  ),
                  child: const Icon(Icons.auto_fix_high_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _hcT(_lang, 'organizar_title'),
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: textCol),
                    ),
                    Text(
                      _hcT(_lang, 'organizar_hint'),
                      style: TextStyle(fontSize: 10, color: subCol, height: 1.4),
                      maxLines: 2,
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            // Campo de texto livre
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 120,
                        maxHeight: 260,
                      ),
                      child: TextField(
                        controller: _ctrl,
                        maxLines: null,
                        minLines: 5,
                        style: TextStyle(fontSize: 13, color: textCol, height: 1.5),
                        decoration: InputDecoration(
                          hintText: _hcT(_lang, 'organizar_placeholder'),
                          hintStyle: TextStyle(
                            fontSize: 12, color: subCol.withOpacity(0.6),
                            fontStyle: FontStyle.italic),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.04)
                              : const Color(0xFFF6FAF8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _kGreen, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.fromLTRB(14, 12, 48, 12),
                        ),
                      ),
                    ),
                    // Indicador de ditado em tempo real
                    if (_voiceActive && _voiceInterim.isNotEmpty)
                      Positioned(
                        bottom: 8, left: 14, right: 48,
                        child: Text(
                          _voiceInterim,
                          style: TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic,
                            color: _kGreen.withOpacity(0.8)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botões: Voz + Organizar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                // Botão microfone
                GestureDetector(
                  onTap: _processing ? null : _toggleVoice,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _voiceActive
                          ? const Color(0xFFDC2626).withOpacity(0.12)
                          : (isDark
                              ? Colors.white.withOpacity(0.06)
                              : const Color(0xFFF0F7F4)),
                      border: Border.all(
                        color: _voiceActive
                            ? const Color(0xFFDC2626).withOpacity(0.45)
                            : border,
                        width: _voiceActive ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: _voiceActive
                          ? _PulseDot(color: const Color(0xFFDC2626))
                          : Icon(Icons.mic_none_rounded, size: 20, color: _kGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Botão principal "Organizar"
                Expanded(
                  child: GestureDetector(
                    onTap: _processing ? null : _process,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: _processing
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: _processing
                            ? (isDark ? Colors.white12 : const Color(0xFFE8E8F0))
                            : null,
                      ),
                      child: Center(
                        child: _processing
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(Colors.white70),
                                ),
                              )
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  _hcT(_lang, 'organizar_process'),
                                  style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 0.3),
                                ),
                              ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OCR EXAM BUTTON — Botão de escaneamento de exame por IA
// Aparece na seção de Exames do editor de História Clínica
// ═══════════════════════════════════════════════════════════════════════════════
class _OcrExamButton extends StatelessWidget {
  final String lang;
  final void Function(String) onResult;

  const _OcrExamButton({required this.lang, required this.onResult});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => ClinicalRecorderSheet.showOcrScanner(
        context,
        onResult: onResult,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F766E).withOpacity(0.15),
              const Color(0xFF14B8A6).withOpacity(0.08),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF0F766E).withOpacity(0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Text('🔬', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'es' ? 'Escanear Examen con IA' : 'Escanear Exame com IA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : const Color(0xFF111111),
                    ),
                  ),
                  Text(
                    lang == 'es'
                        ? 'Foto ou PDF → extração automática por OCR multimodal'
                        : 'Foto ou PDF → extração automática por OCR multimodal',
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.camera_alt_rounded,
              color: Color(0xFF0F766E),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
