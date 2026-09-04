import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

const followUpLexicon150 = <List<String>>[
  <String>['1', 'Classificação e estratificação', 'classificação', 'clasificación', 'E a classificação?', '¿Y la clasificación?'],
  <String>['2', 'Classificação e estratificação', 'categoria', 'categoría', 'E a categoria?', '¿Y la categoría?'],
  <String>['3', 'Classificação e estratificação', 'risco', 'riesgo', 'E o risco?', '¿Y el riesgo?'],
  <String>['4', 'Classificação e estratificação', 'gravidade', 'gravedad', 'E a gravidade?', '¿Y la gravedad?'],
  <String>['5', 'Classificação e estratificação', 'estágio', 'estadio', 'E o estágio?', '¿Y el estadio?'],
  <String>['6', 'Classificação e estratificação', 'grau', 'grado', 'E o grau?', '¿Y el grado?'],
  <String>['7', 'Classificação e estratificação', 'escore', 'puntaje', 'E o escore?', '¿Y el puntaje?'],
  <String>['8', 'Classificação e estratificação', 'classe', 'clase', 'E a classe?', '¿Y la clase?'],
  <String>['9', 'Classificação e estratificação', 'subtipo', 'subtipo', 'E o subtipo?', '¿Y el subtipo?'],
  <String>['10', 'Classificação e estratificação', 'prognóstico', 'pronóstico', 'E o prognóstico?', '¿Y el pronóstico?'],
  <String>['11', 'Dose e posologia', 'dose', 'dosis', 'E a dose?', '¿Y la dosis?'],
  <String>['12', 'Dose e posologia', 'dose inicial', 'dosis inicial', 'E a dose inicial?', '¿Y la dosis inicial?'],
  <String>['13', 'Dose e posologia', 'dose de manutenção', 'dosis de mantenimiento', 'E a manutenção?', '¿Y la dosis de mantenimiento?'],
  <String>['14', 'Dose e posologia', 'dose de ataque', 'dosis de carga', 'E a dose de ataque?', '¿Y la dosis de carga?'],
  <String>['15', 'Dose e posologia', 'dose máxima', 'dosis máxima', 'E a dose máxima?', '¿Y la dosis máxima?'],
  <String>['16', 'Dose e posologia', 'intervalo', 'intervalo', 'E o intervalo?', '¿Y el intervalo?'],
  <String>['17', 'Dose e posologia', 'frequência', 'frecuencia', 'E a frequência?', '¿Y la frecuencia?'],
  <String>['18', 'Dose e posologia', 'duração', 'duración', 'E por quanto tempo?', '¿Y por cuánto tiempo?'],
  <String>['19', 'Dose e posologia', 'titulação', 'titulación', 'E como titular?', '¿Y cómo titular?'],
  <String>['20', 'Dose e posologia', 'desmame', 'retirada gradual', 'E como desmamar?', '¿Y cómo retirarlo gradualmente?'],
  <String>['21', 'Preparo, diluição e administração', 'diluição', 'dilución', 'E a diluição?', '¿Y la dilución?'],
  <String>['22', 'Preparo, diluição e administração', 'reconstituição', 'reconstitución', 'E a reconstituição?', '¿Y la reconstitución?'],
  <String>['23', 'Preparo, diluição e administração', 'concentração', 'concentración', 'E a concentração?', '¿Y la concentración?'],
  <String>['24', 'Preparo, diluição e administração', 'volume final', 'volumen final', 'E o volume final?', '¿Y el volumen final?'],
  <String>['25', 'Preparo, diluição e administração', 'diluente', 'diluyente', 'Qual diluente?', '¿Qué diluyente?'],
  <String>['26', 'Preparo, diluição e administração', 'solvente', 'solvente', 'Qual solvente?', '¿Qué solvente?'],
  <String>['27', 'Preparo, diluição e administração', 'compatibilidade', 'compatibilidad', 'É compatível?', '¿Es compatible?'],
  <String>['28', 'Preparo, diluição e administração', 'via', 'vía', 'E a via?', '¿Y la vía?'],
  <String>['29', 'Preparo, diluição e administração', 'velocidade de infusão', 'velocidad de infusión', 'E a velocidade de infusão?', '¿Y la velocidad de infusión?'],
  <String>['30', 'Preparo, diluição e administração', 'tempo de infusão', 'tiempo de infusión', 'Em quanto tempo infundir?', '¿En cuánto tiempo infundir?'],
  <String>['31', 'Ajustes e populações especiais', 'ajuste renal', 'ajuste renal', 'E o ajuste renal?', '¿Y el ajuste renal?'],
  <String>['32', 'Ajustes e populações especiais', 'ajuste hepático', 'ajuste hepático', 'E o ajuste hepático?', '¿Y el ajuste hepático?'],
  <String>['33', 'Ajustes e populações especiais', 'hemodiálise', 'hemodiálisis', 'E se estiver em hemodiálise?', '¿Y si está en hemodiálisis?'],
  <String>['34', 'Ajustes e populações especiais', 'gestação', 'embarazo', 'E na gestação?', '¿Y en el embarazo?'],
  <String>['35', 'Ajustes e populações especiais', 'lactação', 'lactancia', 'E na lactação?', '¿Y en la lactancia?'],
  <String>['36', 'Ajustes e populações especiais', 'pediatria', 'pediatría', 'E em pediatria?', '¿Y en pediatría?'],
  <String>['37', 'Ajustes e populações especiais', 'idoso', 'adulto mayor', 'E no idoso?', '¿Y en el adulto mayor?'],
  <String>['38', 'Ajustes e populações especiais', 'obesidade', 'obesidad', 'E na obesidade?', '¿Y en obesidad?'],
  <String>['39', 'Ajustes e populações especiais', 'alergia', 'alergia', 'E se tiver alergia?', '¿Y si tiene alergia?'],
  <String>['40', 'Ajustes e populações especiais', 'interação', 'interacción', 'E as interações?', '¿Y las interacciones?'],
  <String>['41', 'Monitorização e exames', 'monitorização', 'monitorización', 'E a monitorização?', '¿Y la monitorización?'],
  <String>['42', 'Monitorização e exames', 'ECG', 'ECG', 'E o ECG?', '¿Y el ECG?'],
  <String>['43', 'Monitorização e exames', 'laboratório', 'laboratorio', 'E os exames laboratoriais?', '¿Y los laboratorios?'],
  <String>['44', 'Monitorização e exames', 'função renal', 'función renal', 'E a função renal?', '¿Y la función renal?'],
  <String>['45', 'Monitorização e exames', 'eletrólitos', 'electrolitos', 'E os eletrólitos?', '¿Y los electrolitos?'],
  <String>['46', 'Monitorização e exames', 'glicemia', 'glucemia', 'E a glicemia?', '¿Y la glucemia?'],
  <String>['47', 'Monitorização e exames', 'lactato', 'lactato', 'E o lactato?', '¿Y el lactato?'],
  <String>['48', 'Monitorização e exames', 'gasometria', 'gasometría', 'E a gasometria?', '¿Y la gasometría?'],
  <String>['49', 'Monitorização e exames', 'imagem', 'imagen', 'E a imagem?', '¿Y las imágenes?'],
  <String>['50', 'Monitorização e exames', 'repetir exame', 'repetir estudio', 'Quando repetir o exame?', '¿Cuándo repetir el estudio?'],
  <String>['51', 'Diagnóstico e diferenciais', 'diagnóstico', 'diagnóstico', 'E o diagnóstico?', '¿Y el diagnóstico?'],
  <String>['52', 'Diagnóstico e diferenciais', 'diagnóstico diferencial', 'diagnóstico diferencial', 'E os diferenciais?', '¿Y los diferenciales?'],
  <String>['53', 'Diagnóstico e diferenciais', 'critérios', 'criterios', 'E os critérios?', '¿Y los criterios?'],
  <String>['54', 'Diagnóstico e diferenciais', 'confirmação', 'confirmación', 'Como confirmar?', '¿Cómo confirmarlo?'],
  <String>['55', 'Diagnóstico e diferenciais', 'exclusão', 'exclusión', 'Como excluir?', '¿Cómo descartarlo?'],
  <String>['56', 'Diagnóstico e diferenciais', 'causa', 'causa', 'E a causa?', '¿Y la causa?'],
  <String>['57', 'Diagnóstico e diferenciais', 'etiologia', 'etiología', 'E a etiologia?', '¿Y la etiología?'],
  <String>['58', 'Diagnóstico e diferenciais', 'mecanismo', 'mecanismo', 'E o mecanismo?', '¿Y el mecanismo?'],
  <String>['59', 'Diagnóstico e diferenciais', 'achados', 'hallazgos', 'E os achados?', '¿Y los hallazgos?'],
  <String>['60', 'Diagnóstico e diferenciais', 'interpretação', 'interpretación', 'Como interpretar?', '¿Cómo interpretarlo?'],
  <String>['61', 'Conduta e tratamento', 'conduta', 'conducta', 'E a conduta?', '¿Y la conducta?'],
  <String>['62', 'Conduta e tratamento', 'próximo passo', 'siguiente paso', 'E agora?', '¿Y ahora?'],
  <String>['63', 'Conduta e tratamento', 'tratamento', 'tratamiento', 'E o tratamento?', '¿Y el tratamiento?'],
  <String>['64', 'Conduta e tratamento', 'primeira linha', 'primera línea', 'Qual a primeira linha?', '¿Cuál es la primera línea?'],
  <String>['65', 'Conduta e tratamento', 'segunda linha', 'segunda línea', 'E a segunda linha?', '¿Y la segunda línea?'],
  <String>['66', 'Conduta e tratamento', 'procedimento', 'procedimiento', 'Precisa de procedimento?', '¿Necesita procedimiento?'],
  <String>['67', 'Conduta e tratamento', 'cirurgia', 'cirugía', 'Precisa de cirurgia?', '¿Necesita cirugía?'],
  <String>['68', 'Conduta e tratamento', 'drenagem', 'drenaje', 'E a drenagem?', '¿Y el drenaje?'],
  <String>['69', 'Conduta e tratamento', 'intubação', 'intubación', 'Precisa intubar?', '¿Hay que intubar?'],
  <String>['70', 'Conduta e tratamento', 'acesso vascular', 'acceso vascular', 'E o acesso?', '¿Y el acceso?'],
  <String>['71', 'Escalonamento e destino', 'internação', 'internación', 'Precisa internar?', '¿Necesita internación?'],
  <String>['72', 'Escalonamento e destino', 'UTI', 'UCI', 'Precisa de UTI?', '¿Necesita UCI?'],
  <String>['73', 'Escalonamento e destino', 'alta', 'alta', 'Pode ter alta?', '¿Puede darse de alta?'],
  <String>['74', 'Escalonamento e destino', 'transferência', 'traslado', 'Precisa transferir?', '¿Hay que trasladarlo?'],
  <String>['75', 'Escalonamento e destino', 'observação', 'observación', 'Fica em observação?', '¿Queda en observación?'],
  <String>['76', 'Escalonamento e destino', 'reavaliação', 'reevaluación', 'Quando reavaliar?', '¿Cuándo reevaluar?'],
  <String>['77', 'Escalonamento e destino', 'piora', 'deterioro', 'E se piorar?', '¿Y si empeora?'],
  <String>['78', 'Escalonamento e destino', 'sinais de alarme', 'señales de alarma', 'Quais os sinais de alarme?', '¿Cuáles son las señales de alarma?'],
  <String>['79', 'Escalonamento e destino', 'escalonamento', 'escalamiento', 'Quando escalar?', '¿Cuándo escalar?'],
  <String>['80', 'Escalonamento e destino', 'seguimento', 'seguimiento', 'E o seguimento?', '¿Y el seguimiento?'],
  <String>['81', 'Modificadores do paciente', 'criança', 'niño', 'E se for criança?', '¿Y si es un niño?'],
  <String>['82', 'Modificadores do paciente', 'gestante', 'embarazada', 'E se estiver grávida?', '¿Y si está embarazada?'],
  <String>['83', 'Modificadores do paciente', 'insuficiência renal', 'insuficiencia renal', 'E se tiver insuficiência renal?', '¿Y si tiene insuficiencia renal?'],
  <String>['84', 'Modificadores do paciente', 'hepatopatia', 'hepatopatía', 'E se tiver hepatopatia?', '¿Y si tiene hepatopatía?'],
  <String>['85', 'Modificadores do paciente', 'hipotensão', 'hipotensión', 'E se estiver hipotenso?', '¿Y si está hipotenso?'],
  <String>['86', 'Modificadores do paciente', 'bradicardia', 'bradicardia', 'E se estiver bradicárdico?', '¿Y si está bradicárdico?'],
  <String>['87', 'Modificadores do paciente', 'taquicardia', 'taquicardia', 'E se estiver taquicárdico?', '¿Y si está taquicárdico?'],
  <String>['88', 'Modificadores do paciente', 'baixo peso', 'bajo peso', 'E se tiver baixo peso?', '¿Y si tiene bajo peso?'],
  <String>['89', 'Modificadores do paciente', 'imunossupressão', 'inmunosupresión', 'E se for imunossuprimido?', '¿Y si está inmunosuprimido?'],
  <String>['90', 'Modificadores do paciente', 'comorbidades', 'comorbilidades', 'E com essas comorbidades?', '¿Y con esas comorbilidades?'],
  <String>['91', 'Tempo e resposta', 'início de ação', 'inicio de acción', 'Quando começa a agir?', '¿Cuándo empieza a actuar?'],
  <String>['92', 'Tempo e resposta', 'duração de ação', 'duración de acción', 'Quanto dura o efeito?', '¿Cuánto dura el efecto?'],
  <String>['93', 'Tempo e resposta', 'meia-vida', 'vida media', 'E a meia-vida?', '¿Y la vida media?'],
  <String>['94', 'Tempo e resposta', 'repetir dose', 'repetir dosis', 'Quando repetir a dose?', '¿Cuándo repetir la dosis?'],
  <String>['95', 'Tempo e resposta', 'alvo terapêutico', 'objetivo terapéutico', 'Qual o alvo?', '¿Cuál es el objetivo?'],
  <String>['96', 'Tempo e resposta', 'resposta esperada', 'respuesta esperada', 'Qual resposta esperar?', '¿Qué respuesta esperar?'],
  <String>['97', 'Tempo e resposta', 'tempo para resposta', 'tiempo de respuesta', 'Em quanto tempo deve responder?', '¿En cuánto tiempo debería responder?'],
  <String>['98', 'Tempo e resposta', 'frequência de reavaliação', 'frecuencia de reevaluación', 'Com que frequência reavaliar?', '¿Con qué frecuencia reevaluar?'],
  <String>['99', 'Tempo e resposta', 'quando suspender', 'cuándo suspender', 'Quando suspender?', '¿Cuándo suspender?'],
  <String>['100', 'Tempo e resposta', 'quando trocar', 'cuándo cambiar', 'Quando trocar?', '¿Cuándo cambiar?'],
  <String>['101', 'Fluidos e eletrólitos', 'fluidos', 'fluidos', 'E os fluidos?', '¿Y los fluidos?'],
  <String>['102', 'Fluidos e eletrólitos', 'volume', 'volumen', 'E o volume?', '¿Y el volumen?'],
  <String>['103', 'Fluidos e eletrólitos', 'taxa de infusão', 'velocidad de infusión', 'E a taxa de infusão?', '¿Y la velocidad de infusión?'],
  <String>['104', 'Fluidos e eletrólitos', 'bolus', 'bolo', 'E o bolus?', '¿Y el bolo?'],
  <String>['105', 'Fluidos e eletrólitos', 'manutenção', 'mantenimiento', 'E a manutenção?', '¿Y el mantenimiento?'],
  <String>['106', 'Fluidos e eletrólitos', 'reposição', 'reposición', 'E a reposição?', '¿Y la reposición?'],
  <String>['107', 'Fluidos e eletrólitos', 'balanço hídrico', 'balance hídrico', 'E o balanço hídrico?', '¿Y el balance hídrico?'],
  <String>['108', 'Fluidos e eletrólitos', 'sódio', 'sodio', 'E o sódio?', '¿Y el sodio?'],
  <String>['109', 'Fluidos e eletrólitos', 'potássio', 'potasio', 'E o potássio?', '¿Y el potasio?'],
  <String>['110', 'Fluidos e eletrólitos', 'osmolaridade', 'osmolaridad', 'E a osmolaridade?', '¿Y la osmolaridad?'],
  <String>['111', 'Antimicrobianos e infecção', 'antibiótico', 'antibiótico', 'E o antibiótico?', '¿Y el antibiótico?'],
  <String>['112', 'Antimicrobianos e infecção', 'cobertura', 'cobertura', 'E a cobertura?', '¿Y la cobertura?'],
  <String>['113', 'Antimicrobianos e infecção', 'culturas', 'cultivos', 'E as culturas?', '¿Y los cultivos?'],
  <String>['114', 'Antimicrobianos e infecção', 'descalonamento', 'desescalada', 'Quando descalonar?', '¿Cuándo desescalar?'],
  <String>['115', 'Antimicrobianos e infecção', 'foco infeccioso', 'foco infeccioso', 'E o foco?', '¿Y el foco?'],
  <String>['116', 'Antimicrobianos e infecção', 'isolamento', 'aislamiento', 'Precisa isolamento?', '¿Necesita aislamiento?'],
  <String>['117', 'Antimicrobianos e infecção', 'profilaxia', 'profilaxis', 'E a profilaxia?', '¿Y la profilaxis?'],
  <String>['118', 'Antimicrobianos e infecção', 'resistência', 'resistencia', 'E a resistência?', '¿Y la resistencia?'],
  <String>['119', 'Antimicrobianos e infecção', 'duração do antibiótico', 'duración del antibiótico', 'Por quantos dias?', '¿Por cuántos días?'],
  <String>['120', 'Antimicrobianos e infecção', 'ajuste do antibiótico', 'ajuste del antibiótico', 'E como ajustar?', '¿Y cómo ajustarlo?'],
  <String>['121', 'Suporte cardio-respiratório', 'oxigênio', 'oxígeno', 'E o oxigênio?', '¿Y el oxígeno?'],
  <String>['122', 'Suporte cardio-respiratório', 'ventilação', 'ventilación', 'E a ventilação?', '¿Y la ventilación?'],
  <String>['123', 'Suporte cardio-respiratório', 'PEEP', 'PEEP', 'E a PEEP?', '¿Y la PEEP?'],
  <String>['124', 'Suporte cardio-respiratório', 'anticoagulação', 'anticoagulación', 'E a anticoagulação?', '¿Y la anticoagulación?'],
  <String>['125', 'Suporte cardio-respiratório', 'antiagregação', 'antiagregación', 'E a antiagregação?', '¿Y la antiagregación?'],
  <String>['126', 'Suporte cardio-respiratório', 'reperfusão', 'reperfusión', 'E a reperfusão?', '¿Y la reperfusión?'],
  <String>['127', 'Suporte cardio-respiratório', 'trombólise', 'trombólisis', 'E a trombólise?', '¿Y la trombólisis?'],
  <String>['128', 'Suporte cardio-respiratório', 'cardioversão', 'cardioversión', 'E a cardioversão?', '¿Y la cardioversión?'],
  <String>['129', 'Suporte cardio-respiratório', 'desfibrilação', 'desfibrilación', 'E a desfibrilação?', '¿Y la desfibrilación?'],
  <String>['130', 'Suporte cardio-respiratório', 'vasopressor', 'vasopresor', 'E o vasopressor?', '¿Y el vasopresor?'],
  <String>['131', 'Toxicologia e antídotos', 'antídoto', 'antídoto', 'E o antídoto?', '¿Y el antídoto?'],
  <String>['132', 'Toxicologia e antídotos', 'descontaminação', 'descontaminación', 'E a descontaminação?', '¿Y la descontaminación?'],
  <String>['133', 'Toxicologia e antídotos', 'carvão ativado', 'carbón activado', 'E o carvão ativado?', '¿Y el carbón activado?'],
  <String>['134', 'Toxicologia e antídotos', 'eliminação', 'eliminación', 'Como aumentar a eliminação?', '¿Cómo aumentar la eliminación?'],
  <String>['135', 'Toxicologia e antídotos', 'nível sérico', 'nivel sérico', 'E o nível sérico?', '¿Y el nivel sérico?'],
  <String>['136', 'Toxicologia e antídotos', 'janela de tratamento', 'ventana terapéutica', 'Qual a janela?', '¿Cuál es la ventana?'],
  <String>['137', 'Toxicologia e antídotos', 'toxicidade', 'toxicidad', 'E a toxicidade?', '¿Y la toxicidad?'],
  <String>['138', 'Toxicologia e antídotos', 'dose tóxica', 'dosis tóxica', 'Qual a dose tóxica?', '¿Cuál es la dosis tóxica?'],
  <String>['139', 'Toxicologia e antídotos', 'observação toxicológica', 'observación toxicológica', 'Quanto tempo observar?', '¿Cuánto tiempo observar?'],
  <String>['140', 'Toxicologia e antídotos', 'critério de alta toxicológica', 'criterio de alta toxicológica', 'Quando pode ter alta?', '¿Cuándo puede darse de alta?'],
  <String>['141', 'Conectores conversacionais', 'e depois', 'y después', 'E depois?', '¿Y después?'],
  <String>['142', 'Conectores conversacionais', 'e agora', 'y ahora', 'E agora?', '¿Y ahora?'],
  <String>['143', 'Conectores conversacionais', 'por quê', 'por qué', 'Por quê?', '¿Por qué?'],
  <String>['144', 'Conectores conversacionais', 'como', 'cómo', 'E como?', '¿Y cómo?'],
  <String>['145', 'Conectores conversacionais', 'quanto', 'cuánto', 'E quanto?', '¿Y cuánto?'],
  <String>['146', 'Conectores conversacionais', 'qual', 'cuál', 'E qual?', '¿Y cuál?'],
  <String>['147', 'Conectores conversacionais', 'quando', 'cuándo', 'E quando?', '¿Y cuándo?'],
  <String>['148', 'Conectores conversacionais', 'precisa', 'necesita', 'Precisa?', '¿Necesita?'],
  <String>['149', 'Conectores conversacionais', 'pode', 'puede', 'Pode?', '¿Puede?'],
  <String>['150', 'Conectores conversacionais', 'é contraindicado', 'está contraindicado', 'É contraindicado?', '¿Está contraindicado?'],
];

void main() {
  group('Global conversational context continuity V1-B-R0', () {
    test('150 PT/ES entries are regression corpus only', () {
      expect(followUpLexicon150, hasLength(150));
      for (final row in followUpLexicon150) {
        expect(row, hasLength(6), reason: row.isEmpty ? 'empty' : row.first);
        expect(row[2].trim(), isNotEmpty);
        expect(row[3].trim(), isNotEmpty);
        expect(row[4].trim(), isNotEmpty);
        expect(row[5].trim(), isNotEmpty);
      }
    });

    test('known high-signal elliptical follow-ups stay in active thread', () {
      const followUps = <String>[
        'E qual é a classificação?',
        'E a dose?',
        'E a diluição?',
        'E a infusão?',
        'E a monitorização?',
        'E a conduta?',
        '¿Y cuál es la clasificación?',
        '¿Y la dosis?',
        '¿Y la dilución?',
        '¿Y la infusión?',
        '¿Y el monitoreo?',
        '¿Y la conducta?',
      ];

      for (final followUp in followUps) {
        final manager = ClinicalThreadManager();
        manager.evaluate(
          currentUserText:
              'Paciente adulto de 75 kg em tratamento clínico ativo e monitorização.',
          isPlantaoMode: true,
        );
        final status = manager.evaluate(
          currentUserText: followUp,
          isPlantaoMode: true,
        );
        expect(status.action, ThreadAction.continueThread, reason: followUp);
      }
    });

    test('explicit different patient remains absolute switch', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText:
            'Paciente adulto de 75 kg em tratamento clínico ativo e monitorização.',
        isPlantaoMode: true,
      );
      final status = manager.evaluate(
        currentUserText:
            'Novo caso: outro paciente com cefaleia súbita intensa.',
        isPlantaoMode: true,
      );
      expect(status.action, ThreadAction.newThread);
    });

    test('AppProvider has one productive continue-switch owner', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        isNot(contains('_sessionMemory.resetIfTopicChanged(input)')),
      );
      expect(source, contains('qaThreadStatus.isContinuation'));
      expect(source, contains('threadStatus.isContinuation'));
      expect(source, contains('threadStatusAnswer.isContinuation'));
      expect(source, contains('_expandedQuery(input, forceContext: true)'));
      expect(source, contains('userQuery: qaExpandedInput'));
      expect(
        RegExp(r'userQuery:\s+expandedInput,').allMatches(source).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('all productive retry history obeys canonical thread policy', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        isNot(
          contains(
            'history: List<Map<String, String>>.from(_sanitizedHistory)',
          ),
        ),
      );
      expect(
        RegExp(r'ClinicalThreadManager\.buildThreadHistory\s*\(')
            .allMatches(source)
            .length,
        greaterThanOrEqualTo(8),
      );
    });

    test('R7/R8 physical owners remain present', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();
      expect(source, contains('M77_R8_CANONICAL_AUTHORITY_SPECIALTY_GUARD_LOCK_V1'));
      expect(source, contains('M77_R8_PRE_PERSIST_MACHINE_GATE_V1'));
      expect(source, contains('M77_CLINICAL_NEW_THREAD_SESSION_ROTATION_V1'));
      expect(source, contains('onDone(guardedText);'));
    });
  });
}
