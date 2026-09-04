import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'services/study/study_google_ai_oauth_physical_canary_client_v1.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const _StudyOAuthPhysicalCanaryApp());
}

class _StudyOAuthPhysicalCanaryApp extends StatelessWidget {
  const _StudyOAuthPhysicalCanaryApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedCases OAuth Canary',
      theme: ThemeData(useMaterial3: true),
      home: const _StudyOAuthPhysicalCanaryPage(),
    );
  }
}

class _StudyOAuthPhysicalCanaryPage extends StatefulWidget {
  const _StudyOAuthPhysicalCanaryPage();

  @override
  State<_StudyOAuthPhysicalCanaryPage> createState() =>
      _StudyOAuthPhysicalCanaryPageState();
}

class _StudyOAuthPhysicalCanaryPageState
    extends State<_StudyOAuthPhysicalCanaryPage> {
  bool _running = false;
  bool _oauthAttempted = false;
  String _status = 'Pronto para o canary one-time.';
  List<String> _projectIds = const <String>[];
  String? _selectedProjectId;
  String? _selectionId;
  int? _selectionExpiresAtMs;

  Future<void> _runCanary() async {
    if (_running || _oauthAttempted || _selectionId != null) {
      return;
    }

    setState(() {
      _running = true;
      _oauthAttempted = true;
      _status = 'Executando canary OAuth one-time...';
    });

    try {
      final result = await StudyGoogleAiOAuthPhysicalCanaryClientV1.run();

      if (!mounted) {
        return;
      }

      setState(() {
        _projectIds = result.discoveredProjectIds;
        _selectedProjectId = null;
        _selectionId = result.selectionId;
        _selectionExpiresAtMs = result.selectionExpiresAtMs;

        if (result.completed) {
          _status = 'PASS: OAuth físico concluído.';
        } else if (result.selectionRequired) {
          _status = 'Seleção de projeto pendente protegida. '
              'Nenhum novo login Google deve ser feito.';
        } else {
          _status = 'Resultado: ${result.safeReason}';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha segura no canary. Consulte o diagnóstico.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _continueSelection() async {
    final opaqueSelectionId = _selectionId;
    final selectedProjectId = _selectedProjectId;

    if (_running ||
        opaqueSelectionId == null ||
        opaqueSelectionId.isEmpty ||
        selectedProjectId == null ||
        selectedProjectId.isEmpty) {
      return;
    }

    setState(() {
      _running = true;
      _status = 'Continuando seleção sem novo OAuth...';
    });

    try {
      final result = await StudyGoogleAiOAuthPhysicalCanaryClientV1
          .continueProjectSelection(
        selectionId: opaqueSelectionId,
        requestedProjectId: selectedProjectId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (result.discoveredProjectIds.isNotEmpty) {
          _projectIds = result.discoveredProjectIds;
        }
        _selectionId = null;
        _selectionExpiresAtMs = null;

        _status = result.completed
            ? 'PASS: seleção concluída sem novo OAuth.'
            : 'Resultado da continuação: ${result.safeReason}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectionId = null;
        _selectionExpiresAtMs = null;
        _status = 'Falha segura na continuação. '
            'Não execute um novo OAuth sem diagnóstico.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = StudyGoogleAiOAuthPhysicalCanaryClientV1.configurationReady;
    final hasPendingSelection = _selectionId != null && _projectIds.length > 1;
    final canContinue = hasPendingSelection && _selectedProjectId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('MedCases · OAuth Canary')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const Text(
              'Ambiente temporário de validação',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Este build não habilita o Modo Estudo geral. '
              'Ele executa somente um canary OAuth one-time.',
            ),
            const SizedBox(height: 20),
            Text(
              ready
                  ? 'Configuração do canary: pronta'
                  : 'Configuração do canary: bloqueada',
            ),
            const SizedBox(height: 16),
            if (hasPendingSelection)
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: 'Projeto Google Cloud',
                  border: OutlineInputBorder(),
                ),
                items: _projectIds
                    .map(
                      (projectId) => DropdownMenuItem<String>(
                        value: projectId,
                        child: Text(projectId),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _running
                    ? null
                    : (value) {
                        setState(() {
                          _selectedProjectId = value;
                        });
                      },
              ),
            if (hasPendingSelection) const SizedBox(height: 16),
            FilledButton(
              onPressed: !ready || _running
                  ? null
                  : hasPendingSelection
                      ? (canContinue ? _continueSelection : null)
                      : (_oauthAttempted ? null : _runCanary),
              child: Text(
                _running
                    ? 'Executando...'
                    : _selectedProjectId == null
                        ? 'Executar canary OAuth'
                        : 'Continuar sem novo OAuth',
              ),
            ),
            const SizedBox(height: 20),
            SelectableText(_status),
            if (hasPendingSelection) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'Mais de um projeto foi encontrado. '
                'Selecione um projeto e continue sem novo login Google.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
