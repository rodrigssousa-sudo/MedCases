import 'dart:io';

void main() {
  final source =
      File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

  final required = <String>[
    'ADMIN_V2_AI_COSTS_SEMANTIC_CONSISTENCY_V1',
    "'Custo 24h'",
    "'Proxy pago hoje'",
    "'Sem uso registrado nas últimas 24h'",
    r"'${provider.model} · observado 24h'",
    'chamada(s) no proxy pago hoje',
    "label: 'Modelo mais usado (24h)'",
    "label: 'Outro modelo observado (24h)'",
    "label: 'Base da leitura'",
    "'Uso observado nas últimas 24h'",
    'Os modelos exibidos refletem uso observado nas últimas 24h.',
  ];

  for (final token in required) {
    if (!source.contains(token)) {
      throw StateError('Missing semantic consistency token: $token');
    }
  }

  final forbidden = <String>[
    "'Custo hoje'",
    "'Fallback pago hoje'",
    "'Modelo definido pelo backend'",
    'chamada(s) paga(s) hoje',
    "label: 'Modelo primário'",
    "label: 'Fallback'",
    "label: 'Roteamento'",
  ];

  for (final token in forbidden) {
    if (source.contains(token)) {
      throw StateError('Stale/misleading semantic token remains: $token');
    }
  }

  print('ADMIN_V2_AI_COSTS_SEMANTIC_CONSISTENCY_V1_CONTRACT=PASS');
  print('COST_WINDOW_LABEL=ROLLING_24H');
  print('PAID_BUDGET_COUNTER_SCOPE=PAID_PROXY_GLOBAL');
  print('PROVIDER_MODEL_LABEL=OBSERVED_24H');
  print('CLINICAL_ROUTING_LABEL_FAKE=NO');
}
