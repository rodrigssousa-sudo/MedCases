import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/entitlement_service.dart';
import '../services/revenuecat_billing_service.dart';

class RevenueCatPurchaseSheet extends StatefulWidget {
  const RevenueCatPurchaseSheet({super.key, required this.isEs});
  final bool isEs;

  @override
  State<RevenueCatPurchaseSheet> createState() =>
      _RevenueCatPurchaseSheetState();
}

class _RevenueCatPurchaseSheetState extends State<RevenueCatPurchaseSheet> {
  RevenueCatPlan _plan = RevenueCatPlan.monthly;
  RevenueCatCatalog? _catalog;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (kIsWeb) return;
    try {
      final catalog = await RevenueCatBillingService.instance.loadCatalog();
      if (mounted) setState(() => _catalog = catalog);
    } catch (_) {}
  }

  void _message(String es, String pt) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(widget.isEs ? es : pt),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<bool> _waitForAuthoritativePremium() async {
    const delays = <Duration>[
      Duration.zero,
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 6),
    ];
    for (final delay in delays) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final snapshot = await EntitlementService.instance
          .refreshAuthoritativeTier(force: true);
      if (snapshot.tier == EntitlementTier.premium) return true;
    }
    return false;
  }

  Future<void> _purchase() async {
    if (_busy) return;
    if (kIsWeb) {
      _message(
        'Las compras están disponibles en iOS y Android.',
        'As compras estão disponíveis no iOS e Android.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await RevenueCatBillingService.instance.purchase(_plan);
      if (result.cancelled) return;
      final authoritative = await _waitForAuthoritativePremium();
      if (!mounted) return;
      if (authoritative) {
        Navigator.of(context).pop(true);
      } else {
        _message(
          'Compra confirmada. Estamos sincronizando tu acceso Premium.',
          'Compra confirmada. Estamos sincronizando seu acesso Premium.',
        );
      }
    } catch (_) {
      _message(
        'No fue posible completar la compra.',
        'Não foi possível concluir a compra.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    if (kIsWeb) return;
    setState(() => _busy = true);
    try {
      final result = await RevenueCatBillingService.instance.restorePurchases();
      if (!result.storeEntitlementActive) {
        _message(
          'No encontramos una suscripción Premium activa.',
          'Não encontramos uma assinatura Premium ativa.',
        );
        return;
      }
      final authoritative = await _waitForAuthoritativePremium();
      if (!mounted) return;
      if (authoritative) {
        Navigator.of(context).pop(true);
      } else {
        _message(
          'Compra restaurada. Estamos sincronizando tu acceso.',
          'Compra restaurada. Estamos sincronizando seu acesso.',
        );
      }
    } catch (_) {
      _message(
        'No fue posible restaurar las compras.',
        'Não foi possível restaurar as compras.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = widget.isEs;
    final monthly = _catalog?.monthlyPrice ?? 'US\$ 14,99';
    final annual = _catalog?.annualPrice ?? 'US\$ 180,00';
    final selectedPrice = _plan == RevenueCatPlan.monthly ? monthly : annual;
    final selectedPeriod = _plan == RevenueCatPlan.monthly
        ? (es ? '/mes' : '/mês')
        : (es ? '/año' : '/ano');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              es ? 'Elige tu plan Premium' : 'Escolha seu plano Premium',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _PlanButton(
                label: es ? 'Mensual' : 'Mensal',
                selected: _plan == RevenueCatPlan.monthly,
                onTap: _busy
                    ? null
                    : () => setState(() => _plan = RevenueCatPlan.monthly),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _PlanButton(
                label: 'Anual',
                selected: _plan == RevenueCatPlan.annual,
                onTap: _busy
                    ? null
                    : () => setState(() => _plan = RevenueCatPlan.annual),
              )),
            ]),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Flexible(
                  child: Text(
                selectedPrice,
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              )),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(selectedPeriod),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              _plan == RevenueCatPlan.monthly
                  ? (es
                      ? '1 mes gratis para nuevos clientes elegibles; después se renueva mensualmente.'
                      : '1 mês grátis para novos clientes elegíveis; depois renova mensalmente.')
                  : (es
                      ? 'Suscripción anual con renovación automática.'
                      : 'Assinatura anual com renovação automática.'),
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _purchase,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _plan == RevenueCatPlan.monthly
                            ? (es
                                ? 'Continuar con mensual'
                                : 'Continuar com mensal')
                            : (es
                                ? 'Continuar con anual'
                                : 'Continuar com anual'),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: Text(es ? 'Restaurar compras' : 'Restaurar compras'),
            ),
            Text(
              es
                  ? 'El precio final y la elegibilidad del período gratuito son confirmados por la tienda antes de la compra.'
                  : 'O preço final e a elegibilidade do período grátis são confirmados pela loja antes da compra.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFC5A365) : Colors.grey.shade400,
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
