import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../providers/app_provider.dart';
import '../models/clinical_history_model.dart';
import '../services/firestore_service.dart';
import '../services/suggestion_service.dart';
import '../widgets/common_widgets.dart';
import '../services/stt_helper.dart';
import '../platform/web_impl.dart'
    if (dart.library.io) '../platform/web_stub.dart' as webPlatform;

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
  // Copiar conteúdo (StringBuffer)
  'copy_header':        {'pt': '=== MEDCASES PRO — HISTÓRIA CLÍNICA ===', 'es': '=== MEDCASES PRO — HISTORIA CLÍNICA ==='},
  'copy_date':          {'pt': 'Data:',                                 'es': 'Fecha:'},
  'copy_author':        {'pt': 'Autor:',                                'es': 'Autor:'},
  'copy_patient':       {'pt': 'Paciente:',                            'es': 'Paciente:'},
  'copy_chief':         {'pt': '\nQUEIXA PRINCIPAL:\n',                 'es': '\nMOTIVO DE CONSULTA:\n'},
  'copy_hpi':           {'pt': '\nHISTÓRIA DA DOENÇA ATUAL:\n',        'es': '\nENFERMEDAD ACTUAL:\n'},
  'copy_past':          {'pt': '\nANTECEDENTES PESSOAIS:\n',           'es': '\nANTECEDENTES PERSONALES:\n'},
  'copy_meds':          {'pt': '\nMEDICAMENTOS EM USO:\n',             'es': '\nMEDICACIÓN HABITUAL:\n'},
  'copy_allerg':        {'pt': '\nALERGIAS: ',                         'es': '\nALERGIAS: '},
  'copy_vitals':        {'pt': '\nSINAIS VITAIS:\n',                   'es': '\nSIGNOS VITALES:\n'},
  'copy_pe':            {'pt': '\nEXAME FÍSICO:\n',                    'es': '\nEXAMEN FÍSICO:\n'},
  'copy_work_dx':       {'pt': '\nHIPÓTESE DIAGNÓSTICA: ',             'es': '\nHIPÓTESIS DIAGNÓSTICA: '},
  'copy_final_dx':      {'pt': 'DIAGNÓSTICO FINAL: ',                  'es': 'DIAGNÓSTICO FINAL: '},
  'copy_lab':           {'pt': '\nEXAMES LABORATORIAIS:\n',            'es': '\nESTUDIOS DE LABORATORIO:\n'},
  'copy_img':           {'pt': '\nEXAMES DE IMAGEM:\n',                'es': '\nESTUDIOS DE IMAGEN:\n'},
  'copy_treat':         {'pt': '\nCONDUTA / TRATAMENTO:\n',            'es': '\nCONDUCTA / TRATAMIENTO:\n'},
  'copy_evol':          {'pt': '\nEVOLUÇÃO ',                          'es': '\nEVOLUCIÓN '},
  'copy_outcome':       {'pt': '\nDESFECHO: ',                         'es': '\nDESENLACE: '},
  'copy_followup':      {'pt': 'SEGUIMENTO: ',                         'es': 'SEGUIMIENTO: '},
  // PDF sections
  'pdf_hc_title':       {'pt': 'História Clínica',                     'es': 'Historia Clínica'},
  'pdf_section1':       {'pt': '1. Identificação do Paciente',         'es': '1. Identificación del Paciente'},
  'pdf_initials':       {'pt': 'Iniciais',                             'es': 'Iniciales'},
  'pdf_demog':          {'pt': 'Dados demográficos',                   'es': 'Datos demográficos'},
  'pdf_patient':        {'pt': 'Paciente',                             'es': 'Paciente'},
  'pdf_age_label':      {'pt': 'Idade',                                'es': 'Edad'},
  'pdf_specialty':      {'pt': 'Especialidade',                        'es': 'Especialidad'},
  'pdf_section2':       {'pt': '2. Queixa Principal',                  'es': '2. Motivo de Consulta'},
  'pdf_section3':       {'pt': '3. Anamnese',                          'es': '3. Anamnesis'},
  'pdf_hpi':            {'pt': 'História da doença atual',             'es': 'Enfermedad actual'},
  'pdf_past':           {'pt': 'Antecedentes pessoais',                'es': 'Antecedentes personales'},
  'pdf_family':         {'pt': 'Antecedentes familiares',              'es': 'Antecedentes familiares'},
  'pdf_social':         {'pt': 'História social (tabagismo, etilismo, ocupação)', 'es': 'Historia social (tabaquismo, alcohol, ocupación)'},
  'pdf_rvs':            {'pt': 'Revisão de sistemas',                  'es': 'Revisión de sistemas'},
  'pdf_meds':           {'pt': 'Medicamentos em uso',                  'es': 'Medicación habitual'},
  'pdf_section4':       {'pt': '4. Exame Físico',                      'es': '4. Examen Físico'},
  'pdf_vitals':         {'pt': 'Sinais vitais',                        'es': 'Signos vitales'},
  'pdf_pe':             {'pt': 'Exame físico por sistemas',            'es': 'Examen físico por sistemas'},
  'pdf_section5':       {'pt': '5. Hipóteses Diagnósticas',            'es': '5. Hipótesis Diagnósticas'},
  'pdf_work_dx':        {'pt': 'Hipótese principal',                   'es': 'Hipótesis principal'},
  'pdf_diff_dx':        {'pt': 'Diagnósticos diferenciais',            'es': 'Diagnósticos diferenciales'},
  'pdf_section6':       {'pt': '6. Exames Complementares',             'es': '6. Estudios Complementarios'},
  'pdf_lab':            {'pt': 'Exames laboratoriais',                 'es': 'Estudios de laboratorio'},
  'pdf_ecg':            {'pt': 'ECG / Outros (biópsia, EEG...)',       'es': 'ECG / Otros (biopsia, EEG...)'},
  'pdf_img':            {'pt': 'Exames de imagem',                     'es': 'Estudios de imagen'},
  'pdf_section7':       {'pt': '7. DIAGNÓSTICO FINAL',                 'es': '7. DIAGNÓSTICO FINAL'},
  'pdf_cid':            {'pt': 'CID-10:',                              'es': 'CIE-10:'},
  'pdf_section8':       {'pt': '8. Conduta e Plano Terapêutico',       'es': '8. Conducta y Plan Terapéutico'},
  'pdf_plan':           {'pt': 'Plano terapêutico',                    'es': 'Plan terapéutico'},
  'pdf_proc':           {'pt': 'Procedimentos realizados',             'es': 'Procedimientos realizados'},
  'pdf_section9':       {'pt': '9. Evolução Clínica',                  'es': '9. Evolución Clínica'},
  'pdf_section10':      {'pt': '10. Desfecho e Alta',                  'es': '10. Desenlace y Alta'},
  'pdf_discharge':      {'pt': 'Condições de alta',                    'es': 'Condiciones de alta'},
  'pdf_followup':       {'pt': 'Seguimento / Orientações',             'es': 'Seguimiento / Indicaciones'},
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
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  ClinicalHistoryModel? _viewing;
  ClinicalHistoryModel? _editing;
  bool _viewingPublic = false;
  // Filtro por intervalo de datas (null = sem filtro)
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 1 && mounted) {
        context.read<AppProvider>().loadPublicHistories();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
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
              primary: Color(0xFF0F1C14),
              onPrimary: Color(0xFFFFE8A6),
              surface: Colors.white,
              onSurface: Color(0xFF0F1C14),
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
    final q = _searchCtrl.text.toLowerCase();
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
          setState(() => _editing = null);
        },
        onCancel: () => setState(() => _editing = null),
      );
    }

    // ── Modo visualização ──────────────────────────────────────────────────
    if (_viewing != null) {
      return _HistoryDetail(
        history: _viewing!,
        p: p,
        readOnly: _viewingPublic,
        onBack: () => setState(() { _viewing = null; _viewingPublic = false; }),
        onEdit: _viewingPublic ? null : () {
          final h = _viewing!;
          setState(() { _viewing = null; _editing = h; });
        },
        onDelete: _viewingPublic ? null : () async {
          await p.deleteHistory(_viewing!.id, wasPublic: _viewing!.isPublic);
          if (!mounted) return;
          setState(() => _viewing = null);
        },
      );
    }

    // ── Lista ───────────────────────────────────────────────────────────────
    final mine = _applyFilters(p.myHistories);
    final pub  = _applyFilters(p.publicHistories);
    final bp   = MedBreakpoints.of(context);

    return Column(children: [
      // Header — SafeArea próprio (header global removido para tab 3)
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1C14), Color(0xFF1B3D2A), Color(0xFF1F6B48)],
          ),
        ),
        child: Padding(
            padding: EdgeInsets.fromLTRB(bp.hPadding, 10, bp.hPadding, 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _hcT(lang, 'tab_title'),
                  style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w900,
                    color: Color(0xBFFFE8A6), letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(
                  _hcT(lang, 'tab_subtitle'),
                  style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  '${mine.length} ${_hcT(lang, 'my_hcs_count')} • ${pub.length} ${_hcT(lang, 'pub_count')}',
                  style: TextStyle(fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500)),
              ])),
              GestureDetector(
                onTap: () {
                  final uid  = p.currentUser?.uid ?? 'local';
                  final name = p.currentUser?.displayName ?? p.currentUser?.email ?? _hcT(lang, 'anon');
                  final email = p.currentUser?.email ?? '';
                  setState(() => _editing = ClinicalHistoryModel.blank(
                    authorUid: uid, authorName: name, authorEmail: email));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.add_rounded, size: 15, color: Color(0xFFFFE8A6)),
                    const SizedBox(width: 4),
                    Text(_hcT(lang, 'new_hc'), style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: Color(0xFFFFE8A6))),
                  ]),
                ),
              ),
            ]),
          ),
      ),

      // Tabs
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppColors.of(context).cardBg, border: Border.all(color: AppColors.of(context).border)),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.of(context).darkBtn),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            labelColor: kGoldLight,
            unselectedLabelColor: const Color(0xFF888888),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: '${_hcT(lang, 'my_hcs')} (${mine.length})'),
              Tab(text: '${_hcT(lang, 'community')} (${pub.length})'),
            ],
          ),
        ),
      ),

      // Busca + Filtro por data
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          Expanded(
            child: MedInput(
              controller: _searchCtrl,
              hintText: _hcT(lang, 'search_hint'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // Botão filtro por data
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
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_rounded, size: 16,
                    color: _dateFilter != null
                        ? const Color(0xFFFFE8A6)
                        : const Color(0xFF888888)),
              ]),
            ),
          ),
        ]),
      ),

      // Chip do filtro de data ativo
      if (_dateFilter != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.of(context).surface,
                border: Border.all(color: AppColors.of(context).border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_rounded, size: 12, color: AppColors.of(context).textPrimary),
                const SizedBox(width: 6),
                Text(_dateFilterLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearDateFilter,
                  child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF555555)),
                ),
              ]),
            ),
          ]),
        ),

      const SizedBox(height: 4),

      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Minhas HCs ──────────────────────────────────────────────
            mine.isEmpty
              ? _EmptyHistoryState(lang: lang, onNew: () {
                  final uid = p.currentUser?.uid ?? 'local';
                  final name = p.currentUser?.displayName ?? p.currentUser?.email ?? _hcT(lang, 'anon');
                  final email = p.currentUser?.email ?? '';
                  setState(() => _editing = ClinicalHistoryModel.blank(authorUid: uid, authorName: name, authorEmail: email));
                })
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    bp.isDesktop ? bp.hPadding : 0,
                    8,
                    bp.isDesktop ? bp.hPadding : 0,
                    100,
                  ),
                  itemCount: mine.length,
                  itemBuilder: (_, i) => bp.isDesktop
                      ? Center(child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: _HistoryCard(
                            h: mine[i], p: p,
                            onTap: () => setState(() { _viewing = mine[i]; _viewingPublic = false; }),
                            onEdit: () => setState(() => _editing = mine[i]),
                            onDelete: () async {
                              final confirm = await _confirmDelete(context);
                              if (confirm) await p.deleteHistory(mine[i].id, wasPublic: mine[i].isPublic);
                            },
                            onTogglePublic: () => p.toggleHistoryPublic(mine[i]),
                          ),
                        ))
                      : _HistoryCard(
                          h: mine[i], p: p,
                          onTap: () => setState(() { _viewing = mine[i]; _viewingPublic = false; }),
                          onEdit: () => setState(() => _editing = mine[i]),
                          onDelete: () async {
                            final confirm = await _confirmDelete(context);
                            if (confirm) await p.deleteHistory(mine[i].id, wasPublic: mine[i].isPublic);
                          },
                          onTogglePublic: () => p.toggleHistoryPublic(mine[i]),
                        ),
                ),

            // ── Comunidade ───────────────────────────────────────────────
            p.isLoadingPublic
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: kGreen, strokeWidth: 2.5),
                      const SizedBox(height: 14),
                      Text(_hcT(lang, 'loading_comm'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : pub.isEmpty
                ? _EmptyCommunityState(lang: lang, onRefresh: () => p.loadPublicHistories())
                : RefreshIndicator(
                    color: kGreen,
                    onRefresh: () => p.loadPublicHistories(),
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        bp.isDesktop ? bp.hPadding : 0,
                        8,
                        bp.isDesktop ? bp.hPadding : 0,
                        100,
                      ),
                      itemCount: pub.length,
                      itemBuilder: (ctx, i) {
                        final h = pub[i];
                        final canModerate = p.canModerateContent;
                        // Usuários comuns não veem HCs ocultas
                        if (h.isHidden && !canModerate) return const SizedBox.shrink();
                        final card = _HistoryCard(
                          h: h, p: p,
                          onTap: () => setState(() { _viewing = h; _viewingPublic = true; }),
                          readOnly: true,
                          onModHide: canModerate ? () async {
                            final wasHidden = h.isHidden;
                            await p.toggleHistoryHidden(h.id);
                            if (context.mounted) _showModSnack(context,
                              _hcT(lang, wasHidden ? 'hc_visible' : 'hc_hidden'));
                          } : null,
                          onModDelete: canModerate ? () async {
                            final confirm = await _confirmModDelete(context);
                            if (!confirm) return;
                            await FirestoreService.adminDeletePublicHistory(h.id);
                            p.loadPublicHistories();
                            if (context.mounted) _showModSnack(context, _hcT(lang, 'hc_del_perm'), isError: true);
                          } : null,
                        );
                        return bp.isDesktop
                            ? Center(child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 900),
                                child: card,
                              ))
                            : card;
                      },
                    ),
                  ),
          ],
        ),
      ),
    ]);
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
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F1C14))),
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

  @override
  Widget build(BuildContext context) {
    final lang = p.lang;
    final completion = h.completionRatio;
    return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.of(context).border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Categoria badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.of(context).darkBtn),
                child: Text(h.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoldLight)),
              ),
              const SizedBox(width: 6),
              // Outcome badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _outcomeColor.withValues(alpha: 0.12), border: Border.all(color: _outcomeColor.withValues(alpha: 0.3))),
                child: Text(_outcomeLabel(lang), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _outcomeColor)),
              ),
              if (h.isPublic) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF1E40AF).withValues(alpha: 0.1), border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.3))),
                  child: Text(_hcT(lang, 'public_badge'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF))),
                ),
              ],
              const Spacer(),
              Text(h.formattedDate, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text(h.displayTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.of(context).textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (h.patientInitials.isNotEmpty || h.patientAge.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${h.patientInitials.isNotEmpty ? h.patientInitials : ''}${h.patientAge.isNotEmpty ? " • ${h.patientAge} ${_hcT(p.lang, "years")}" : ""} • ${h.patientSex}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
            ],
            if (h.finalDiagnosis.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Text('Dx: ${h.finalDiagnosis}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)), overflow: TextOverflow.ellipsis),
              ),
            ] else if (h.workingDiagnosis.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFFFFF8E6), border: Border.all(color: const Color(0xFFFFE0A0))),
                child: Text('${p.lang == "es" ? "Hipótesis" : "Hipótese"}: ${h.workingDiagnosis}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)), overflow: TextOverflow.ellipsis),
              ),
            ],
            const SizedBox(height: 10),
            // Barra de progresso
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completion,
                  minHeight: 4,
                  backgroundColor: AppColors.of(context).border,
                  valueColor: AlwaysStoppedAnimation(completion > 0.7 ? const Color(0xFF065F46) : completion > 0.4 ? kGold : const Color(0xFFCCCCCC)),
                ),
              )),
              const SizedBox(width: 8),
              Text('${(completion * 100).round()}%', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF888888))),
            ]),
            if (!readOnly) ...[
              const SizedBox(height: 10),
              Row(children: [
                // Compartilhar
                GestureDetector(
                  onTap: onTogglePublic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: h.isPublic ? const Color(0xFF1E40AF).withValues(alpha: 0.1) : AppColors.of(context).surface,
                      border: Border.all(color: h.isPublic ? const Color(0xFF1E40AF).withValues(alpha: 0.3) : AppColors.of(context).border),
                    ),
                    child: Row(children: [
                      Icon(h.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded, size: 12,
                        color: h.isPublic ? const Color(0xFF1E40AF) : const Color(0xFF888888)),
                      const SizedBox(width: 4),
                      Text(h.isPublic ? _hcT(p.lang, 'public_badge') : _hcT(p.lang, 'private_badge'),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                          color: h.isPublic ? const Color(0xFF1E40AF) : const Color(0xFF888888))),
                    ]),
                  ),
                ),
                const Spacer(),
                GestureDetector(onTap: onEdit, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_rounded, size: 16, color: kGold))),
                GestureDetector(onTap: onDelete, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFCC2222)))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.of(context).darkBtn, borderRadius: BorderRadius.circular(10)),
                  child: Text(_hcT(p.lang, 'open'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
                ),
              ]),
            ] else ...[
              // Banner de HC oculta (visível apenas para moderadores)
              if (h.isHidden) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.visibility_off_rounded, size: 12, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(_hcT(p.lang, 'hidden_mod'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange)),
                  ]),
                ),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.authorName.isNotEmpty ? h.authorName : _hcT(p.lang, 'anon'),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF333333), fontWeight: FontWeight.w700)),
                  if (h.authorEmail.isNotEmpty)
                    Text(h.authorEmail,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
                  if (h.uploadedAt.isNotEmpty)
                    Text(_formatUploadedAt(h.uploadedAt),
                      style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
                ])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.of(context).darkBtn, borderRadius: BorderRadius.circular(10)),
                  child: Text(_hcT(p.lang, 'view'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
                ),
              ]),
              // Botões de moderação
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
                          color: Colors.orange.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
                          color: Colors.red.withValues(alpha: 0.07),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
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
            ],
          ]),
        ),
    );
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
    buf.writeln(_hcT(lang, 'copy_header'));
    buf.writeln('${_hcT(lang, 'copy_date')} ${history.formattedDate}');
    if (history.authorName.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_author')} ${history.authorName}${history.authorEmail.isNotEmpty ? " (${history.authorEmail})" : ""}');
    if (history.patientInitials.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_patient')} ${history.patientInitials} • ${history.patientAge} ${_hcT(lang, 'years')} • ${history.patientSex}');
    if (history.chiefComplaint.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_chief')}${history.chiefComplaint}');
    if (history.hpi.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_hpi')}${history.hpi}');
    if (history.pastHistory.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_past')}${history.pastHistory}');
    if (history.medications.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_meds')}${history.medications}');
    if (history.allergies.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_allerg')}${history.allergies}');
    if (history.vitalSigns.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_vitals')}${history.vitalSigns}');
    if (history.physicalExam.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_pe')}${history.physicalExam}');
    if (history.workingDiagnosis.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_work_dx')}${history.workingDiagnosis}');
    if (history.finalDiagnosis.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_final_dx')}${history.finalDiagnosis}${history.cid.isNotEmpty ? " (${history.cid})" : ""}');
    if (history.labResults.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_lab')}${history.labResults}');
    if (history.imagingResults.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_img')}${history.imagingResults}');
    if (history.treatmentPlan.isNotEmpty) buf.writeln('${_hcT(lang, 'copy_treat')}${history.treatmentPlan}');
    for (final e in history.evolutions) {
      final dt = DateTime.tryParse(e.date);
      final dateStr = dt != null ? '${dt.day.toString().padLeft(2, "0")}/${dt.month.toString().padLeft(2, "0")} ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}' : '';
      buf.writeln('${_hcT(lang, "copy_evol")}($dateStr — ${e.author}):\n${e.text}');
    }
    if (history.outcome != 'internado') buf.writeln('${_hcT(lang, "copy_outcome")}${history.outcome.toUpperCase()}');
    if (history.followUp.isNotEmpty) buf.writeln('${_hcT(lang, "copy_followup")}${history.followUp}');
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_hcT(lang, "copied")), duration: const Duration(seconds: 1)));
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

  // ── Exportar como PDF (web: janela de impressão) ──────────────────────────
  void _exportPdf() {
    final buf = StringBuffer();
    buf.write('''<!DOCTYPE html><html><head>
<meta charset="utf-8">
<title>${_hcT(p.lang, 'pdf_hc_title')} — MedCases Pro</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Georgia, serif; font-size: 13px; color: #111; background: #fff; padding: 40px; line-height: 1.6; }
  .header { background: #07110d; color: #FFE8A6; padding: 20px 24px; border-radius: 10px; margin-bottom: 24px; }
  .header h1 { font-size: 22px; font-weight: 900; margin-bottom: 4px; }
  .header .meta { font-size: 11px; opacity: 0.75; }
  .section { margin-bottom: 18px; border: 1px solid #ddd; border-radius: 8px; padding: 14px 16px; }
  .section-title { font-size: 10px; font-weight: 900; letter-spacing: 1.5px; color: #555; text-transform: uppercase; margin-bottom: 8px; border-bottom: 1px solid #eee; padding-bottom: 6px; }
  .field-label { font-size: 9px; font-weight: 700; color: #888; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 2px; margin-top: 10px; }
  .field-value { font-size: 13px; color: #222; line-height: 1.6; }
  .dx-box { background: #ECFDF5; border: 1px solid #BBF7D0; border-radius: 8px; padding: 12px 14px; margin-bottom: 18px; }
  .dx-box h2 { font-size: 10px; font-weight: 900; color: #065F46; letter-spacing: 1.2px; margin-bottom: 4px; }
  .dx-box p { font-size: 16px; font-weight: 900; color: #064E3B; }
  .allergy-box { background: #FFF0F0; border: 1px solid #FFCCCC; border-radius: 8px; padding: 10px 12px; margin-top: 8px; }
  .allergy-box .label { color: #CC2222; font-size: 9px; font-weight: 900; letter-spacing: 1px; }
  .allergy-box p { color: #CC2222; font-weight: 700; }
  .author-row { font-size: 11px; color: #555; margin-top: 6px; }
  .evolution { border-left: 3px solid #C5A365; padding-left: 10px; margin-bottom: 12px; }
  .evolution .evo-meta { font-size: 10px; color: #888; font-weight: 700; }
  .outcome { display: inline-block; padding: 5px 12px; border-radius: 6px; font-size: 12px; font-weight: 900; background: #ECFDF5; color: #065F46; margin-bottom: 10px; }
  .footer { margin-top: 30px; font-size: 10px; color: #aaa; text-align: center; border-top: 1px solid #eee; padding-top: 12px; }
  @media print { body { padding: 20px; } }
</style>
</head><body>
<div class="header">
  <div class="meta">MedCases Pro • ${_hcT(p.lang, 'pdf_hc_title')}</div>
  <h1>${_esc(history.displayTitle)}</h1>
  <div class="meta">${history.category} &nbsp;|&nbsp; ${history.formattedDate}</div>
  ${history.authorName.isNotEmpty ? '<div class="meta" style="margin-top:4px">${_hcT(p.lang, 'copy_author')} ${_esc(history.authorName)}${history.authorEmail.isNotEmpty ? " &lt;${_esc(history.authorEmail)}&gt;" : ""}${history.uploadedAt.isNotEmpty ? " — Publicado: ${_formatUploadedAt(history.uploadedAt)}" : ""}</div>' : ''}
</div>
''');

    void section(String title, List<(String, String)> fields, {String? allergyText}) {
      final hasContent = fields.any((f) => f.$2.isNotEmpty) || (allergyText?.isNotEmpty ?? false);
      if (!hasContent) return;
      buf.write('<div class="section"><div class="section-title">$title</div>');
      if (allergyText != null && allergyText.isNotEmpty) {
        buf.write('<div class="allergy-box"><div class="label">⚠ ALERGIAS</div><p>${_esc(allergyText)}</p></div>');
      }
      for (final f in fields) {
        if (f.$2.isEmpty) continue;
        buf.write('<div class="field-label">${f.$1}</div><div class="field-value">${_escNl(f.$2)}</div>');
      }
      buf.write('</div>');
    }

    // ── 1. IDENTIFICAÇÃO DO PACIENTE ──────────────────────────────────────
    if (history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(p.lang, "pdf_section1")}</div>');
      if (history.patientInitials.isNotEmpty)
        buf.write('<div class="field-label">${_hcT(p.lang, "pdf_initials")}</div><div class="field-value">${_esc(history.patientInitials)}</div>');
      buf.write('<div class="field-label">${_hcT(p.lang, "pdf_demog")}</div><div class="field-value">'
          '${history.patientAge.isNotEmpty ? "${history.patientAge} ${_hcT(p.lang, 'years')}" : ""}${history.patientAge.isNotEmpty ? " • " : ""}${history.patientSex}'
          '${history.patientWeight.isNotEmpty ? " • ${history.patientWeight} kg" : ""}'
          '${history.patientHeight.isNotEmpty ? " • ${history.patientHeight} cm" : ""}'
          '${history.patientRecord.isNotEmpty ? " • Pront. ${_esc(history.patientRecord)}" : ""}'
          '</div>');
      buf.write('</div>');
    }

    // ── 2. QUEIXA PRINCIPAL ────────────────────────────────────────────────
    if (history.chiefComplaint.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(p.lang, "pdf_section2")}</div>');
      buf.write('<div class="field-value" style="font-size:15px;font-weight:700">${_esc(history.chiefComplaint)}</div>');
      buf.write('</div>');
    }

    // ── 3. ANAMNESE ────────────────────────────────────────────────────────
    section(_hcT(p.lang, 'pdf_section3'), [
      (_hcT(p.lang, 'pdf_hpi'), history.hpi),
      (_hcT(p.lang, 'pdf_past'), history.pastHistory),
      (_hcT(p.lang, 'pdf_family'), history.familyHistory),
      (_hcT(p.lang, 'pdf_social'), history.socialHistory),
      (_hcT(p.lang, 'pdf_rvs'), history.reviewOfSystems),
      (_hcT(p.lang, 'pdf_meds'), history.medications),
    ], allergyText: history.allergies);

    // ── 4. EXAME FÍSICO ────────────────────────────────────────────────────
    section(_hcT(p.lang, 'pdf_section4'), [
      (_hcT(p.lang, 'pdf_vitals'), history.vitalSigns),
      (_hcT(p.lang, 'pdf_pe'), history.physicalExam),
    ]);

    // ── 5. HIPÓTESES DIAGNÓSTICAS ──────────────────────────────────────────
    if (history.workingDiagnosis.isNotEmpty || history.differentialDx.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(p.lang, "pdf_section5")}</div>');
      if (history.workingDiagnosis.isNotEmpty) {
        buf.write('<div class="field-label">${_hcT(p.lang, "pdf_work_dx")}</div>');
        buf.write('<div class="field-value" style="font-size:14px;font-weight:700;color:#064E3B">${_esc(history.workingDiagnosis)}</div>');
      }
      if (history.differentialDx.isNotEmpty) {
        buf.write('<div class="field-label" style="margin-top:10px">${_hcT(p.lang, "pdf_diff_dx")}</div>');
        buf.write('<div class="field-value">${_escNl(history.differentialDx)}</div>');
      }
      buf.write('</div>');
    }

    // ── 6. EXAMES COMPLEMENTARES ──────────────────────────────────────────
    section(_hcT(p.lang, 'pdf_section6'), [
      (_hcT(p.lang, 'pdf_lab_results'), history.labResults),
      (_hcT(p.lang, 'pdf_ecg_others'), history.otherResults),
      (_hcT(p.lang, 'pdf_imaging_results'), history.imagingResults),
    ]);

    // ── 7. DIAGNÓSTICO FINAL ───────────────────────────────────────────────
    if (history.finalDiagnosis.isNotEmpty) {
      buf.write('<div class="dx-box">');
      buf.write('<h2>${_hcT(p.lang, "pdf_section7")}</h2>');
      buf.write('<p>${_esc(history.finalDiagnosis)}</p>');
      if (history.cid.isNotEmpty)
        buf.write('<div style="font-size:12px;color:#065F46;margin-top:6px;font-weight:700">CID-10: ${_esc(history.cid)}</div>');
      buf.write('</div>');
    }

    // ── 8. CONDUTA / TRATAMENTO ────────────────────────────────────────────
    section(_hcT(p.lang, 'pdf_section8'), [
      (_hcT(p.lang, 'pdf_plan'), history.treatmentPlan),
      (_hcT(p.lang, 'pdf_procedures'), history.procedures),
    ]);

    // ── 9. EVOLUÇÃO CLÍNICA ────────────────────────────────────────────────
    if (history.evolutions.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(p.lang, "pdf_section9")}</div>');
      for (final e in history.evolutions) {
        final dt = DateTime.tryParse(e.date)?.toLocal();
        final ds = dt != null
            ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
            : '';
        final typeMap = {'evolution': _hcT(p.lang, 'pdf_evo_med'), 'nursing': _hcT(p.lang, 'pdf_evo_nurse'), 'lab': _hcT(p.lang, 'pdf_evo_lab'), 'imaging': _hcT(p.lang, 'pdf_evo_img'), 'procedure': _hcT(p.lang, 'pdf_evo_proc')};
        buf.write('<div class="evolution">');
        buf.write('<div class="evo-meta">${typeMap[e.type] ?? _hcT(p.lang, "pdf_evo_med")} — $ds${e.author.isNotEmpty ? " — ${_esc(e.author)}" : ""}</div>');
        buf.write('<div class="field-value" style="margin-top:4px">${_escNl(e.text)}</div>');
        buf.write('</div>');
      }
      buf.write('</div>');
    }

    // ── 10. DESFECHO E ALTA ────────────────────────────────────────────────
    final outcomeMap = {'internado': _hcT(p.lang, 'out_internado'), 'alta': _hcT(p.lang, 'pdf_out_alta'), 'obito': _hcT(p.lang, 'out_obito'), 'transferencia': _hcT(p.lang, 'out_transf')};
    if (history.outcome != 'internado' || history.dischargeCondition.isNotEmpty || history.followUp.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">${_hcT(p.lang, "pdf_section10")}</div>');
      buf.write('<div class="outcome">${outcomeMap[history.outcome] ?? history.outcome}</div>');
      if (history.dischargeCondition.isNotEmpty)
        buf.write('<div class="field-label">${_hcT(p.lang, "f_discharge")}</div><div class="field-value">${_escNl(history.dischargeCondition)}</div>');
      if (history.followUp.isNotEmpty)
        buf.write('<div class="field-label">${_hcT(p.lang, "f_followup")}</div><div class="field-value">${_escNl(history.followUp)}</div>');
      buf.write('</div>');
    }

    buf.write('<div class="footer">${_hcT(p.lang, "pdf_footer")}</div>');
    buf.write('\n</body></html>');

    // Abre janela de impressão (PDF via browser)
    webPlatform.webOpenHtmlPrint(buf.toString());
  }

  String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  String _escNl(String s) => _esc(s).replaceAll('\n', '<br>');
  String _safeFilename() => 'HC_${history.displayTitle.replaceAll(RegExp(r'[^a-zA-Z0-9\u00C0-\u024F ]'), '').trim().replaceAll(' ', '_').substring(0, history.displayTitle.length.clamp(0, 30))}_${history.formattedDate.replaceAll('/', '-')}';

  void _downloadBytes(Uint8List bytes, String filename, String mime) {
    webPlatform.webDownloadBytes(bytes, filename, mime);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // ── Conteúdo principal scrollável ──────────────────────────────────────
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ══ HEADER CARD VERDE ESCURO COM GRADIENTE ══════════════════════════
          _HistoryHeroHeader(
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

              // ══ CARD DIAGNÓSTICO FINAL (verde menta com check) ═══════════════
              // Tudo que será capturado como PNG
              RepaintBoundary(
                key: _printKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (history.finalDiagnosis.isNotEmpty || history.workingDiagnosis.isNotEmpty)
                    _DxBanner(final_: history.finalDiagnosis, working: history.workingDiagnosis, cid: history.cid, differential: history.differentialDx, lang: p.lang),
                  if (history.finalDiagnosis.isNotEmpty || history.workingDiagnosis.isNotEmpty) const SizedBox(height: 14),

                  // ══ SEÇÃO ANAMNESE com ícones circulares verdes ══════════════
                  _DetailCard(icon: Icons.record_voice_over_rounded, title: _hcT(p.lang, 'det_anamnese'), children: [
                    if (history.chiefComplaint.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_chief'), history.chiefComplaint, icon: Icons.announcement_rounded),
                    if (history.hpi.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_hpi'), history.hpi, icon: Icons.history_edu_rounded),
                    if (history.pastHistory.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_past'), history.pastHistory, icon: Icons.person_rounded),
                    if (history.familyHistory.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_family'), history.familyHistory, icon: Icons.family_restroom_rounded),
                    if (history.socialHistory.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_social'), history.socialHistory, icon: Icons.groups_rounded),
                    if (history.medications.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_meds'), history.medications, icon: Icons.medication_rounded),
                    if (history.reviewOfSystems.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_rvs'), history.reviewOfSystems, icon: Icons.checklist_rounded),
                    // ── Bloco ALERGIAS em destaque vermelho ──────────────────
                    if (history.allergies.isNotEmpty) _AllergyBanner(history.allergies),
                  ]),
                  const SizedBox(height: 12),

                  _DetailCard(icon: Icons.monitor_heart_rounded, title: _hcT(p.lang, 'det_exam'), children: [
                    if (history.vitalSigns.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_vitals'), history.vitalSigns, icon: Icons.favorite_rounded),
                    if (history.physicalExam.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_pe'), history.physicalExam, icon: Icons.accessibility_new_rounded),
                  ]),
                  const SizedBox(height: 12),

                  _DetailCard(icon: Icons.science_rounded, title: _hcT(p.lang, 'det_labs'), children: [
                    if (history.labResults.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_lab_res'), history.labResults, icon: Icons.biotech_rounded),
                    if (history.imagingResults.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_img'), history.imagingResults, icon: Icons.image_search_rounded),
                    if (history.otherResults.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_other'), history.otherResults, icon: Icons.analytics_rounded),
                  ]),
                  const SizedBox(height: 12),

                  _DetailCard(icon: Icons.medical_services_rounded, title: _hcT(p.lang, 'det_treat'), children: [
                    if (history.treatmentPlan.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_plan'), history.treatmentPlan, icon: Icons.assignment_turned_in_rounded),
                    if (history.procedures.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_proc'), history.procedures, icon: Icons.build_circle_rounded),
                    if (history.drugIds.isNotEmpty) _DrugChips(history.drugIds, p),
                  ]),
                  const SizedBox(height: 12),

                  // Evoluções
                  if (history.evolutions.isNotEmpty) ...[
                    _EvolutionSection(evolutions: history.evolutions),
                    const SizedBox(height: 12),
                  ],

                  // Desfecho
                  if (history.outcome != 'internado' || history.dischargeCondition.isNotEmpty || history.followUp.isNotEmpty)
                    _DetailCard(icon: Icons.flag_rounded, title: _hcT(p.lang, 'det_outcome'), children: [
                      _OutcomeBadge(history.outcome),
                      if (history.dischargeCondition.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_discharge'), history.dischargeCondition, icon: Icons.door_front_door_rounded),
                      if (history.followUp.isNotEmpty) _SectionBlock(_hcT(p.lang, 'det_followup'), history.followUp, icon: Icons.event_note_rounded),
                    ]),
                ]),
              ),

              const SizedBox(height: 16),

              // ── Ações ──────────────────────────────────────────────────────
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: _copy,
                  child: Container(height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDark, boxShadow: [BoxShadow(color: kDark.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0,4))]),
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
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF1E40AF), boxShadow: [BoxShadow(color: const Color(0xFF1E40AF).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0,3))]),
                    child: const Center(child: Icon(Icons.picture_as_pdf_rounded, size: 20, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _exporting ? null : _exportPng,
                  child: Container(
                    height: 48, width: 48,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF065F46), boxShadow: [BoxShadow(color: const Color(0xFF065F46).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0,3))]),
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
                    colors: [Color(0xFF1F6B48), Color(0xFF0A3D2A)],
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFF1F6B48).withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 5))],
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
          colors: [Color(0xFF071A10), Color(0xFF0F2D1C), Color(0xFF155131), Color(0xFF1F6B48)],
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
            color: Colors.white.withValues(alpha: 0.04)),
        ),
        Positioned(
          right: 60, bottom: -10,
          child: Icon(Icons.local_hospital_rounded, size: 80,
            color: Colors.white.withValues(alpha: 0.04)),
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
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_back_ios_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(_hcT(lang, 'back'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Categoria badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: const Color(0xFFFFE8A6).withValues(alpha: 0.35)),
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
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
                    border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.4)),
                  ),
                  child: const Center(child: Icon(Icons.person_rounded, size: 12, color: Color(0xFF4ADE80))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    history.authorName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (history.authorEmail.isNotEmpty)
                    Text(history.authorEmail,
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w500)),
                ])),
                if (history.uploadedAt.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: Text(
                      _formatUploadedAt(history.uploadedAt),
                      style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
                    ),
                  ),
              ]),

            // Badges do paciente
            if (history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (history.patientInitials.isNotEmpty) _PatientBadge(
                  icon: Icons.badge_rounded, text: history.patientInitials, accent: const Color(0xFF4ADE80)),
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
              Text(history.tags, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500, letterSpacing: 0.3)),
            ],
          ]),
        ),
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
        color: accent.withValues(alpha: 0.15),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
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
    SttHelper.stop();           // Mobile: para speech_to_text nativo
    for (final c in _ctrls.values) c.dispose();
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
    };
    return labels[key] ?? key;
  }

  void _toggleSmartDictaphone() {
    // No mobile: o ditáfone inteligente global usa o mesmo _startStt() por campo.
    // O botão de ditáfone global só está disponível no Web (requer Web Speech API contínua).
    if (!kIsWeb) return;
    if (_smartDictActive) {
      _smartRecog?.stop();
      if (mounted) setState(() { _smartDictActive = false; _smartInterim = ''; _smartCurrentField = ''; });
      return;
    }
    if (!webPlatform.webHasSpeechRecognition()) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Ditado não suportado'),
        content: const Text('Use Chrome ou Safari para o ditado.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ));
      return;
    }
    // Para STT de campo individual se estava ativo
    if (_sttListening) _stopAllStt();

    final lang = widget.p.lang == 'es' ? 'es-ES' : 'pt-BR';
    // Campo inicial: seção ativa
    _smartCurrentField = _section == 1 ? 'chiefComplaint' : 'vitalSigns';

    final recog = webPlatform.WebSpeechRecognizer();
    recog.start('smart', lang,
      onResult: (transcript, isFinal) {
        if (!mounted) return;
        // Detecta se há palavra-gatilho de campo no texto
        final detected = _detectFieldFromText(transcript);
        if (detected.isNotEmpty && detected != _smartCurrentField) {
          setState(() => _smartCurrentField = detected);
        }
        if (isFinal) {
          // Remove a palavra-gatilho do texto antes de inserir
          String clean = transcript;
          for (final trigger in _kTriggers.keys) {
            clean = clean.replaceAll(RegExp(trigger, caseSensitive: false), '');
          }
          clean = clean.trim().replaceAll(RegExp(r'^[,:\s]+'), '');
          if (clean.isNotEmpty && _smartCurrentField.isNotEmpty) {
            final ctrl = _ctrls[_smartCurrentField];
            if (ctrl != null) {
              final cur = ctrl.text;
              final spacer = cur.isNotEmpty && !cur.endsWith('\n') && !cur.endsWith(' ') ? ' ' : '';
              ctrl.text = cur + spacer + clean;
              ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
            }
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
        // Reinicia automaticamente para ditado contínuo
        if (_smartDictActive && mounted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (_smartDictActive && mounted) _smartRecog?.start('smart', lang,
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
    if (mounted) setState(() { _smartDictActive = true; _smartInterim = ''; });
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
    }

    _sttActiveKey = key;
    if (mounted) setState(() { _sttListening = true; _sttInterim = ''; });
  }

  /// Insere texto transcrito no campo correto, com espaço inteligente.
  void _insertIntoField(String key, String transcript) {
    if (transcript.isEmpty) return;
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
    return Column(children: [
      // Header
      PremiumCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(children: [
          Row(children: [
            GestureDetector(onTap: widget.onCancel,
              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1)),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white))),
            const SizedBox(width: 10),
            Expanded(child: Text(_draft.chiefComplaint.isNotEmpty ? _draft.chiefComplaint : _hcT(widget.p.lang, 'new_hc_title'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white), overflow: TextOverflow.ellipsis)),
            // Botão Pré-visualizar
            GestureDetector(onTap: _showPreview,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withValues(alpha: 0.12), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.visibility_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Ver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                ]))),
            GestureDetector(onTap: _save,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kGold),
                child: Text(_hcT(widget.p.lang, 'save_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F1C14))))),
          ]),
          const SizedBox(height: 10),
          // Barra de progresso
          Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: completion, minHeight: 4, backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(kGold)))),
            const SizedBox(width: 8),
            Text('${(completion * 100).round()}${_hcT(widget.p.lang, "progress_label")}', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          // Navegação de seções
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: List.generate(_sections.length, (i) {
              final active = _section == i;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _section = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: active ? kGold : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(color: active ? kGold : Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(_sections[i].$2,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFF0F1C14) : Colors.white.withValues(alpha: 0.85))),
                  ),
                ),
              );
            })),
          ),
        ]),
      ),

      // ── Banner do Ditáfone Inteligente ────────────────────────────────
      if (_smartDictActive)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF1F6B48).withValues(alpha: 0.10),
            border: Border.all(color: const Color(0xFF1F6B48).withValues(alpha: 0.45)),
          ),
          child: Row(children: [
            _PulseDot(color: const Color(0xFF1F6B48)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF1F6B48)),
                const SizedBox(width: 4),
                Text('DITÁFONE INTELIGENTE • Gravando...', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF1F6B48), letterSpacing: 0.5)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Text('Campo: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
                Text(_smartCurrentField.isNotEmpty ? _fieldLabel(_smartCurrentField) : '—',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1F6B48))),
              ]),
              if (_smartInterim.isNotEmpty) ...[const SizedBox(height: 2),
                Text(_smartInterim, style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                  maxLines: 2, overflow: TextOverflow.ellipsis)],
            ])),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleSmartDictaphone,
              child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF1F6B48).withValues(alpha: 0.15)),
                child: const Icon(Icons.stop_rounded, size: 18, color: Color(0xFF1F6B48))),
            ),
          ]),
        ),
      // ── Banner de ditado por campo ativo (STT individual) ─────────────
      if (_sttListening && !_smartDictActive)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            _PulseDot(),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_hcT(widget.p.lang, 'dictating'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFDC2626), letterSpacing: 0.5)),
              if (_sttInterim.isNotEmpty)
                Text(_sttInterim, style: const TextStyle(fontSize: 12, color: Color(0xFF555555), fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _stopAllStt,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFDC2626).withValues(alpha: 0.12)),
                child: const Icon(Icons.mic_off_rounded, size: 16, color: Color(0xFFDC2626)),
              ),
            ),
          ]),
        ),

      // Conteúdo da seção — no desktop: centraliza com max-width maior
      Expanded(child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final hPad = isDesktop ? 48.0 : 16.0;
          Widget content = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 100),
            child: isDesktop
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: _buildSection(),
                    ),
                  )
                : _buildSection(),
          );
          return content;
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
        Text(_hcT(widget.p.lang, 'f_sex').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12), height: 44,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _draft.patientSex, isExpanded: true,
            items: [_hcT(widget.p.lang, 'sex_male'), _hcT(widget.p.lang, 'sex_female')].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)))).toList(),
            onChanged: (v) => setState(() => _draft = _draft.copyWith(patientSex: v ?? _hcT(widget.p.lang, 'sex_male'))),
          )),
        ),
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
      Text(_hcT(widget.p.lang, 'f_category').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12), height: 44,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _draft.category, isExpanded: true,
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))).toList(),
          onChanged: (v) => setState(() => _draft = _draft.copyWith(category: v ?? 'Clínica Geral')),
        )),
      ),
    ]),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_tags'), _ctrls['tags']!, hint: _hcT(widget.p.lang, 'h_tags')),
    const SizedBox(height: 14),
    // Compartilhar toggle
    GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(isPublic: !_draft.isPublic)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _draft.isPublic ? const Color(0xFF1E40AF).withValues(alpha: 0.4) : kBorder),
          color: _draft.isPublic ? const Color(0xFF1E40AF).withValues(alpha: 0.06) : Colors.white),
        child: Row(children: [
          Icon(_draft.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded, size: 20, color: _draft.isPublic ? const Color(0xFF1E40AF) : const Color(0xFF888888)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_draft.isPublic ? _hcT(widget.p.lang, 'public_on') : _hcT(widget.p.lang, 'public_off'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _draft.isPublic ? const Color(0xFF1E40AF) : kDark)),
            const SizedBox(height: 2),
            Text(_hcT(widget.p.lang, 'public_hint'), style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
          ])),
          Switch(value: _draft.isPublic, onChanged: (v) => setState(() => _draft = _draft.copyWith(isPublic: v)),
            activeThumbColor: const Color(0xFF1E40AF)),
        ]),
      ),
    ),
  ]);

  // ── Seção 1: Anamnese ─────────────────────────────────────────────────────
  Widget _buildAnamnesisSection() => Column(children: [
    // ── Ditáfone inteligente ─────────────────────────────────────────────
    _SmartDictaphoneButton(
      active: _smartDictActive,
      currentField: _smartCurrentField,
      onTap: _toggleSmartDictaphone,
      lang: widget.p.lang,
    ),
    const SizedBox(height: 12),
    _EditorField(_hcT(widget.p.lang, 'f_chief'), _ctrls['chiefComplaint']!, hint: _hcT(widget.p.lang, 'h_chief'), multiline: true, onMic: () => _startStt('chiefComplaint'), fieldKey: 'chiefComplaint'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_hpi'), _ctrls['hpi']!, hint: _hcT(widget.p.lang, 'h_hpi'), multiline: true, lines: 5, onMic: () => _startStt('hpi'), fieldKey: 'hpi'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_past'), _ctrls['pastHistory']!, hint: _hcT(widget.p.lang, 'h_past'), multiline: true, onMic: () => _startStt('pastHistory'), fieldKey: 'pastHistory'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_family'), _ctrls['familyHistory']!, hint: _hcT(widget.p.lang, 'h_family'), multiline: true, onMic: () => _startStt('familyHistory'), fieldKey: 'familyHistory'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_social'), _ctrls['socialHistory']!, hint: _hcT(widget.p.lang, 'h_social'), multiline: true, onMic: () => _startStt('socialHistory'), fieldKey: 'socialHistory'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_meds'), _ctrls['medications']!, hint: _hcT(widget.p.lang, 'h_meds'), multiline: true, onMic: () => _startStt('medications'), fieldKey: 'medications'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_allergies'), _ctrls['allergies']!, hint: _hcT(widget.p.lang, 'h_allergies'), multiline: true, onMic: () => _startStt('allergies'), fieldKey: 'allergies'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_ros'), _ctrls['reviewOfSystems']!, hint: _hcT(widget.p.lang, 'h_ros'), multiline: true, onMic: () => _startStt('reviewOfSystems'), fieldKey: 'reviewOfSystems'),
  ]);

  // ── Seção 2: Exame físico ──────────────────────────────────────────────────
  Widget _buildPhysicalExamSection() => Column(children: [
    // ── Ditáfone inteligente ─────────────────────────────────────────────
    _SmartDictaphoneButton(
      active: _smartDictActive,
      currentField: _smartCurrentField,
      onTap: _toggleSmartDictaphone,
      lang: widget.p.lang,
    ),
    const SizedBox(height: 12),
    // ── Sinais Vitais Estruturados ─────────────────────────────────────────
    _VitalSignsWidget(
      controller: _ctrls['vitalSigns']!,
      onMic: () => _startStt('vitalSigns'),
    ),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_pe'), _ctrls['physicalExam']!, hint: _hcT(widget.p.lang, 'h_pe'), multiline: true, lines: 8, onMic: () => _startStt('physicalExam'), fieldKey: 'physicalExam'),
    const SizedBox(height: 10),
    // Diagnóstico logo após o exame físico
    _EditorField(_hcT(widget.p.lang, 'f_wdx'), _ctrls['workingDiagnosis']!, hint: _hcT(widget.p.lang, 'h_wdx'), fieldKey: 'workingDiagnosis'),
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
    _EditorField(_hcT(widget.p.lang, 'f_plan'), _ctrls['treatmentPlan']!, hint: _hcT(widget.p.lang, 'h_plan'), multiline: true, lines: 7, onMic: () => _startStt('treatmentPlan'), fieldKey: 'treatmentPlan'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_procedures'), _ctrls['procedures']!, hint: _hcT(widget.p.lang, 'h_procedures'), multiline: true, onMic: () => _startStt('procedures'), fieldKey: 'procedures'),
  ]);

  // ── Seção 5: Evolução ─────────────────────────────────────────────────────
  Widget _buildEvolutionSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_hcT(widget.p.lang, 'evol_title').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
      const SizedBox(height: 4),
      Text(_hcT(widget.p.lang, 'evol_hint'), style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
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
    Text(_hcT(widget.p.lang, 'outcome_title').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
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
                size: 16, color: selected ? Colors.white : const Color(0xFF888888)),
              const SizedBox(height: 3),
              Text(_outcomesLabel[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: selected ? Colors.white : const Color(0xFF888888))),
            ]),
          ),
        ),
      ));
    })),
    const SizedBox(height: 14),
    _EditorField(_hcT(widget.p.lang, 'f_discharge'), _ctrls['dischargeCondition']!, hint: _hcT(widget.p.lang, 'h_discharge'), multiline: true, fieldKey: 'dischargeCondition'),
    const SizedBox(height: 10),
    _EditorField(_hcT(widget.p.lang, 'f_followup'), _ctrls['followUp']!, hint: _hcT(widget.p.lang, 'h_followup'), multiline: true, fieldKey: 'followUp'),
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

  const _EditorField(this.label, this.ctrl, {
    required this.hint,
    this.multiline = false,
    this.numeric = false,
    this.lines = 3,
    this.onMic,
    this.fieldKey,
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
        Text(widget.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
        if (widget.onMic != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: widget.onMic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
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
        onFocusChange: (hasFocus) {
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
                      color: const Color(0xFFC5A365).withValues(alpha: 0.10),
                      border: Border.all(color: const Color(0xFFC5A365).withValues(alpha: 0.40)),
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
            ? const LinearGradient(colors: [Color(0xFF0F1C14), Color(0xFF1F6B48)], begin: Alignment.centerLeft, end: Alignment.centerRight)
            : null,
          color: active ? null : const Color(0xFFF0F7F4),
          border: Border.all(
            color: active ? const Color(0xFF1F6B48) : const Color(0xFFBBD6C8),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [BoxShadow(color: const Color(0xFF1F6B48).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          // Ícone mic animado
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF1F6B48).withValues(alpha: 0.12),
              border: Border.all(color: active ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1F6B48).withValues(alpha: 0.3)),
            ),
            child: Center(child: Icon(
              active ? Icons.mic_rounded : Icons.mic_none_rounded,
              size: 22,
              color: active ? Colors.white : const Color(0xFF1F6B48),
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
                color: active ? Colors.white : const Color(0xFF1F6B48),
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
                color: active ? Colors.white.withValues(alpha: 0.80) : const Color(0xFF666666),
                height: 1.4,
              ),
              maxLines: 2,
            ),
          ])),
          const SizedBox(width: 8),
          if (active)
            _PulseDot(color: const Color(0xFF86EFAC))
          else
            Icon(Icons.chevron_right_rounded, size: 20, color: const Color(0xFF1F6B48).withValues(alpha: 0.5)),
        ]),
      ),
    );
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: const Color(0xFFDDDDDD)),
          ),
          // Header da sheet
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [Color(0xFF0F1C14), Color(0xFF1F6B48)], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.12)),
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
                  color: const Color(0xFF0F1C14),
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: const Color(0xFF0F1C14)),
            child: Text('HC', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFC5A365), letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(_hcT(isEs ? 'es' : 'pt', 'tab_title'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF333333), letterSpacing: 1.2))),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            color: color.withValues(alpha: 0.06),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.12))),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withValues(alpha: 0.06), border: Border.all(color: color.withValues(alpha: 0.18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color.withValues(alpha: 0.7), letterSpacing: 0.8)),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.12), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header da seção
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: kDark.withValues(alpha: 0.04),
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
              color: const Color(0xFF1F6B48).withValues(alpha: 0.1),
              border: Border.all(color: const Color(0xFF1F6B48).withValues(alpha: 0.2)),
            ),
            child: Center(child: Icon(icon, size: 13, color: const Color(0xFF1F6B48))),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
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
          boxShadow: [BoxShadow(color: const Color(0xFFCC2222).withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFCC2222).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFFCC2222).withValues(alpha: 0.3)),
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
        boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header da caixa de diagnóstico
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
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
                  color: primaryColor.withValues(alpha: 0.1),
                ),
                child: Text('CID-10: $cid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryColor)),
              )],
            if (differential.isNotEmpty) ...[const SizedBox(height: 8),
              Text(_hcT(lang, 'dx_diff_label'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryColor.withValues(alpha: 0.6), letterSpacing: 1.1)),
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: outcomeColor.withValues(alpha: 0.1), border: Border.all(color: outcomeColor.withValues(alpha: 0.3))),
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
      const Text('FÁRMACOS UTILIZADOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
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
                  Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                ]),
                if (e.author.isNotEmpty) Text(e.author, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF333333), height: 1.5)),
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
          Text(dateStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
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
              child: Text(_evoLabels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sel ? kGoldLight : const Color(0xFF888888)))),
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

class _EmptyHistoryState extends StatelessWidget {
  final VoidCallback onNew;
  final String lang;
  const _EmptyHistoryState({required this.onNew, this.lang = 'pt'});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.description_outlined, size: 56, color: Colors.grey[300]),
      const SizedBox(height: 14),
      Text(_hcT(lang, 'empty_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFAAAAAA))),
      const SizedBox(height: 6),
      Text(_hcT(lang, 'empty_sub'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      MedButton(label: _hcT(lang, "new_history_btn"), onTap: onNew),
    ]));
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
  final VoidCallback? onMic;
  const _VitalSignsWidget({required this.controller, this.onMic});
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
    for (final c in [_pas,_pad,_fc,_fr,_temp,_spo2,_dext,_peso]) c.dispose();
    super.dispose();
  }

  Widget _vsField(String label, TextEditingController ctrl, String unit, {String hint = '', bool wide = false, bool decimal = false}) {
    return SizedBox(
      width: wide ? double.infinity : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFF888888))),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Text(unit, style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        color: const Color(0xFFF8FBFA),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.monitor_heart_rounded, size: 14, color: kGreen),
          const SizedBox(width: 6),
          Text(_hcT(context.read<AppProvider>().lang, 'vitals_title').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF555555))),
          const Spacer(),
          if (widget.onMic != null)
            GestureDetector(
              onTap: widget.onMic,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFDC2626).withValues(alpha: 0.08), border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25))),
                child: Builder(builder: (ctx) {
                  final localLang = ctx.read<AppProvider>().lang;
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.mic_rounded, size: 11, color: Color(0xFFDC2626)),
                    const SizedBox(width: 3),
                    Text(_hcT(localLang, 'dictate_btn'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                  ]);
                }),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        // Linha 1: PA (2 campos) + FC + FR
        Wrap(spacing: 10, runSpacing: 10, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFF888888))),
            const SizedBox(height: 3),
            Row(children: [
              SizedBox(width: 50, height: 36, child: TextField(
                controller: _pas, keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: '120',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5))),
              )),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Text('/', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300, color: Color(0xFF888888)))),
              SizedBox(width: 50, height: 36, child: TextField(
                controller: _pad, keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: '80',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5))),
              )),
              const SizedBox(width: 4),
              const Text('mmHg', style: TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w700)),
            ]),
          ]),
          _vsField('FC', _fc, 'bpm', hint: '80'),
          _vsField('FR', _fr, 'irpm', hint: '16'),
          _vsField('Temp', _temp, '°C', hint: '36,5', decimal: true),
          _vsField('SpO₂', _spo2, '%', hint: '98', decimal: true),
          _vsField('Dextro', _dext, 'mg/dL', hint: '100', decimal: true),
          _vsField('Peso', _peso, 'kg', hint: '70', wide: true, decimal: true),
        ]),
        if (widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withValues(alpha: 0.06)),
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
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
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
              Expanded(child: Text(widget.controller.text, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            const Spacer(),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: const Color(0xFF888888)),
          ])),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: kBorder),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ritmo
            Text(_hcT(context.read<AppProvider>().lang, 'ecg_ritmo').toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
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
              Text(_hcT(context.read<AppProvider>().lang, 'ecg_st').toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
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
              Text(_hcT(context.read<AppProvider>().lang, 'ecg_outros').toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
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
    for (final c in [_hb,_ht,_leuco,_plaq,_na,_k,_cr,_ur,_gli,_pcr,_tni,_bnp,_lac,_tp,_tgo,_tgp,_outros]) {
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

  // ── OCR via File Input (Web) ──────────────────────────────────────────────
  Future<void> _openOcrPicker() async {
    if (!kIsWeb) return; // OCR só disponível no web
    setState(() { _ocrLoading = true; _ocrStatus = 'Lendo imagem...'; });
    try {
      final text = await webPlatform.webPickImageAndOcr();
      if (text.isEmpty) {
        if (mounted) setState(() {
          _ocrLoading = false;
          _ocrStatus = 'Imagem carregada — preencha os campos manualmente ou instale Tesseract.js';
          _outros.text = '(Laudo de imagem — edite os valores acima)';
        });
      } else {
        _applyOcrText(text);
        if (mounted) setState(() { _ocrLoading = false; _ocrStatus = 'Texto extraído! Revise os campos.'; });
      }
    } catch (e) {
      if (mounted) setState(() { _ocrLoading = false; _ocrStatus = 'Falha OCR: $e'; });
    }
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
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
      const SizedBox(height: 3),
      SizedBox(width: 68, height: 34, child: TextField(
        controller: ctrl, keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: flagColor ?? const Color(0xFF1A1A1A)),
        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7), hintText: hint,
          hintStyle: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flagColor?.withValues(alpha: 0.4) ?? kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flagColor?.withValues(alpha: 0.4) ?? kBorder)),
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
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withValues(alpha: 0.08), border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.25))),
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
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: const Color(0xFF888888)),
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
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withValues(alpha: 0.06)),
              child: Text(widget.controller.text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF065F46), height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ]),
    );
  }
}
