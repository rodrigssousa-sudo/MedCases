import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'testimonial_service.dart';

class TestimonialScreen extends StatefulWidget {
  const TestimonialScreen(
      {super.key, required this.user, required this.onClose, this.service});
  final UserModel user;
  final VoidCallback onClose;
  final TestimonialService? service;
  @override
  State<TestimonialScreen> createState() => _TestimonialScreenState();
}

class _TestimonialScreenState extends State<TestimonialScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName);
  late final _profession =
      TextEditingController(text: widget.user.profession ?? '');
  final _text = TextEditingController();
  late final _service = widget.service ?? TestimonialService();
  TestimonialRecord? _mine;
  List<TestimonialRecord> _queue = [];
  String _status = 'pending', _photo = '', _notice = '';
  bool _busy = true,
      _loaded = false,
      _consent = false,
      _usePhoto = false,
      _moderating = false;
  bool get _es => widget.user.lang == 'es';
  String t(String pt, String es) => _es ? es : pt;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) AuthService.webUser.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (mounted && AuthService.webUser.value?.uid != widget.user.uid) {
      widget.onClose();
    }
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _notice = '';
    });
    try {
      final mine = await _service.mine(widget.user.uid);
      final prefs = await SharedPreferences.getInstance();
      final localPhoto =
          prefs.getString('medcases_profile_avatar_${widget.user.uid}');
      String photo = mine?.text('photo') ?? '';
      if (photo.isEmpty && localPhoto != null && localPhoto.isNotEmpty) {
        try {
          final codec = await ui.instantiateImageCodec(base64Decode(localPhoto),
              targetWidth: 160);
          final frame = await codec.getNextFrame();
          final bytes =
              await frame.image.toByteData(format: ui.ImageByteFormat.png);
          frame.image.dispose();
          codec.dispose();
          if (bytes != null && bytes.lengthInBytes <= 130000) {
            photo =
                'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
          }
        } catch (_) {
          /* A missing/invalid optional avatar does not block text. */
        }
      }
      if (!mounted) return;
      setState(() {
        _mine = mine;
        _photo = photo;
        _loaded = true;
        if (mine != null) {
          _name.text = mine.text('displayName');
          _profession.text = mine.text('profession');
          _text.text = mine.text('text');
          _usePhoto = mine.text('photo').isNotEmpty;
        }
        // Consent is explicit for every submission, never prechecked.
        _consent = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _notice = t(
            'Não foi possível carregar. Tente novamente.',
            'No se pudo cargar. Inténtalo de nuevo.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _notice = '';
    });
    try {
      // Server rules are authoritative even if the cached role/session is stale.
      await action();
      if (!mounted) return;
      if (_moderating) {
        await _loadQueue();
      } else {
        await _load();
      }
      if (mounted) {
        setState(() => _notice = success);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = t(
            'Não foi possível salvar. Verifique sua conexão e sessão. Se o conteúdo mudou, recarregue antes de tentar novamente.',
            'No se pudo guardar. Revisa tu conexión y sesión. Si el contenido cambió, recarga antes de intentarlo de nuevo.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadQueue() async {
    setState(() => _busy = true);
    try {
      final rows = await _service.moderation(_status);
      if (mounted) {
        setState(() {
          _queue = rows;
          _notice = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _queue = [];
          _notice = t('Fila indisponível ou acesso não autorizado.',
              'Cola no disponible o acceso no autorizado.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(TestimonialRecord row) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(t('Excluir depoimento?', '¿Eliminar testimonio?')),
                content: Text(t(
                    'O texto e a foto serão removidos da página pública e da fila de moderação.',
                    'El texto y la foto se eliminarán de la página pública y de la cola de moderación.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(t('Cancelar', 'Cancelar'))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(t('Excluir', 'Eliminar')))
                ]));
    if (confirmed == true && mounted) {
      await _run(() => _service.remove(row),
          t('Depoimento excluído.', 'Testimonio eliminado.'));
      if (!_moderating && mounted) {
        _text.clear();
        setState(() => _usePhoto = false);
      }
    }
  }

  Widget _avatar(String photo) {
    if (photo.isEmpty) return const Icon(Icons.person_outline);
    try {
      return ClipOval(
          child: Image.memory(base64Decode(photo.split(',').last),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_outline)));
    } catch (_) {
      return const Icon(Icons.person_outline);
    }
  }

  String _statusLabel(String status) => switch (status) {
        'approved' => t('Publicado', 'Publicado'),
        'rejected' => t('Não aprovado', 'No aprobado'),
        _ => t('Em moderação', 'En moderación'),
      };
  Widget _editor() => Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            t('Conte sua experiência com o MedCases.',
                'Cuenta tu experiencia con MedCases.'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(t(
            'Após aprovação, seu nome, cargo, texto e foto escolhida aparecerão publicamente. Não inclua informações de pacientes.',
            'Tras la aprobación, tu nombre, cargo, texto y foto elegida se mostrarán públicamente. No incluyas información de pacientes.')),
        if (_mine != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_statusLabel(_mine!.text('status')))),
        TextFormField(
            controller: _name,
            maxLength: 80,
            decoration:
                InputDecoration(labelText: t('Nome público', 'Nombre público')),
            validator: (v) => v == null || v.trim().isEmpty
                ? t('Informe seu nome', 'Escribe tu nombre')
                : null),
        TextFormField(
            controller: _profession,
            maxLength: 80,
            decoration: InputDecoration(
                labelText: t('Cargo ou profissão', 'Cargo o profesión')),
            validator: (v) => v == null || v.trim().isEmpty
                ? t('Informe seu cargo', 'Escribe tu cargo')
                : null),
        TextFormField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            decoration: InputDecoration(
                labelText: t('Seu depoimento', 'Tu testimonio')),
            validator: (v) => v == null || v.trim().length < 10
                ? t('Escreva ao menos 10 caracteres',
                    'Escribe al menos 10 caracteres')
                : null),
        if (_photo.isNotEmpty)
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              secondary: _avatar(_photo),
              title: Text(t(
                  'Incluir minha foto de perfil', 'Incluir mi foto de perfil')),
              value: _usePhoto,
              onChanged:
                  _busy ? null : (v) => setState(() => _usePhoto = v == true)),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent,
            title: Text(t(
                'Autorizo a publicação destes dados e da foto selecionada na página do MedCases. Posso retirar o depoimento neste menu.',
                'Autorizo la publicación de estos datos y de la foto seleccionada en la página de MedCases. Puedo retirar el testimonio desde este menú.')),
            onChanged:
                _busy ? null : (v) => setState(() => _consent = v == true)),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: _busy || !_loaded || !_consent
                ? null
                : () {
                    if (!_form.currentState!.validate()) return;
                    _run(
                        () => _service.submit(
                            uid: widget.user.uid,
                            name: _name.text,
                            profession: _profession.text,
                            text: _text.text,
                            photo: _usePhoto ? _photo : '',
                            consent: _consent,
                            existing: _mine),
                        t('Enviado para moderação.', 'Enviado a moderación.'));
                  },
            child: Text(t('Enviar para moderação', 'Enviar a moderación'))),
        if (_mine != null)
          TextButton(
              onPressed: _busy ? null : () => _remove(_mine!),
              child: Text(t('Excluir e retirar autorização',
                  'Eliminar y retirar autorización'))),
      ]));
  Widget _moderation() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButton<String>(
            value: _status,
            items: ['pending', 'approved', 'rejected']
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text(_statusLabel(s))))
                .toList(),
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _status = v!);
                    _loadQueue();
                  }),
        Text(t(
            'Até 100 registros por estado. Aprove apenas experiências reais com consentimento.',
            'Hasta 100 registros por estado. Aprueba solo experiencias reales con consentimiento.')),
        if (_queue.isEmpty && !_busy)
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text(t('Nenhum depoimento nesta fila.',
                  'No hay testimonios en esta cola.'))),
        for (final row in _queue)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _avatar(row.text('photo')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  '${row.text('displayName')} · ${row.text('profession')}'))
                        ]),
                        const SizedBox(height: 12),
                        Text(row.text('text')),
                        const SizedBox(height: 12),
                        Wrap(spacing: 12, children: [
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      () => _service.moderate(row,
                                          approved: true),
                                      t('Publicado.', 'Publicado.')),
                              child: Text(t('Aprovar', 'Aprobar'))),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      () => _service.moderate(row,
                                          approved: true,
                                          featured: !row.featured),
                                      t('Destaque atualizado.',
                                          'Destacado actualizado.')),
                              child: Text(row.featured
                                  ? t('Remover destaque', 'Quitar destacado')
                                  : t('Aprovar e destacar',
                                      'Aprobar y destacar'))),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      () => _service.moderate(row,
                                          approved: false),
                                      t('Retirado da publicação.',
                                          'Retirado de la publicación.')),
                              child: Text(t('Não aprovar', 'No aprobar'))),
                          TextButton(
                              onPressed: _busy ? null : () => _remove(row),
                              child: Text(t('Excluir', 'Eliminar'))),
                        ]),
                      ]))),
      ]);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: t('Voltar ao aplicativo', 'Volver a la aplicación'),
                onPressed: widget.onClose),
            title: Text(t('Depoimentos', 'Testimonios')),
            actions: [
              IconButton(
                  onPressed:
                      _busy ? null : () => _moderating ? _loadQueue() : _load(),
                  icon: const Icon(Icons.refresh),
                  tooltip: t('Recarregar', 'Recargar'))
            ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  if (widget.user.isAdmin)
                    Wrap(spacing: 12, children: [
                      ChoiceChip(
                          label: Text(t('Meu depoimento', 'Mi testimonio')),
                          selected: !_moderating,
                          onSelected: _busy
                              ? null
                              : (_) {
                                  setState(() => _moderating = false);
                                  _load();
                                }),
                      ChoiceChip(
                          label: Text(t('Moderação', 'Moderación')),
                          selected: _moderating,
                          onSelected: _busy
                              ? null
                              : (_) {
                                  setState(() => _moderating = true);
                                  _loadQueue();
                                }),
                    ]),
                  if (_busy) const LinearProgressIndicator(),
                  if (_notice.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child:
                            Semantics(liveRegion: true, child: Text(_notice))),
                  const SizedBox(height: 16),
                  if (_moderating) _moderation() else _editor(),
                ]))),
      );
  @override
  void dispose() {
    if (kIsWeb) AuthService.webUser.removeListener(_sessionChanged);
    _name.dispose();
    _profession.dispose();
    _text.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }
}
