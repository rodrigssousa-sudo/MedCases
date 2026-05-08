import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/brand_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'demo@medcases.com');
  final _passCtrl = TextEditingController(text: '123456');
  bool _showLocal = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _loginGoogle(AppProvider p) => p.login('Dr. Demo Google');
  void _loginLocal(AppProvider p) {
    if (_emailCtrl.text.isNotEmpty && _passCtrl.text.isNotEmpty) p.login('Dr. Demo');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 24),
            // Header card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF07110d), Color(0xFF123326), Color(0xFF075f45)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const BrandMark(),
                const SizedBox(height: 20),
                const Text('MedCases AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xCCFFE8A6), letterSpacing: 2)),
                const SizedBox(height: 4),
                const Text('Acesso Clínico\nSeguro', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                const SizedBox(height: 8),
                Text('Entre para usar IA médica, histórico clínico e auditoria por usuário.', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 20),
            // Google button
            _bigBtn(
              onTap: () => _loginGoogle(p),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E0E0))),
                  child: const Center(child: Text('G', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF075f45), fontSize: 14))),
                ),
                const SizedBox(width: 12),
                const Text('Continuar com Google', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF07110d))),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Container(height: 1, color: const Color(0xFFE8E1D2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Preview', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 2)),
              ),
              Expanded(child: Container(height: 1, color: const Color(0xFFE8E1D2))),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _showLocal = !_showLocal),
              child: Container(
                width: double.infinity, height: 40,
                decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(_showLocal ? 'Ocultar acesso local' : 'Usar acesso local de teste', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF666666)))),
              ),
            ),
            if (_showLocal) ...[
              const SizedBox(height: 12),
              _inputField(_emailCtrl, 'E-mail'),
              const SizedBox(height: 8),
              _inputField(_passCtrl, 'Senha', obscure: true),
              const SizedBox(height: 12),
              _bigBtn(
                onTap: () => _loginLocal(p),
                bg: const Color(0xFF07110d),
                child: const Text('Entrar no modo teste', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6), fontSize: 15)),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E7), border: Border.all(color: const Color(0xFFFFE0A0)), borderRadius: BorderRadius.circular(16)),
              child: const Text('Produção: validar Google ID Token no backend antes de liberar IA médica. Nunca enviar dados sensíveis sem controle de privacidade, consentimento e auditoria.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7A5F00))),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE8E1D2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE8E1D2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFC5A365), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _bigBtn({required VoidCallback onTap, required Widget child, Color bg = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: bg == Colors.white ? Border.all(color: const Color(0xFFE8E1D2)) : null, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 4))]),
        child: Center(child: child),
      ),
    );
  }
}
