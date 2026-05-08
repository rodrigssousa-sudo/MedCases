#!/bin/bash
# build_web.sh — Build Flutter Web sem Service Worker
# Uso: bash build_web.sh

set -e

echo "🔨 Building Flutter Web (release)..."
flutter build web --release --dart-define=flutter.inspector.structuredErrors=false

echo "🔪 Removendo serviceWorkerSettings do flutter_bootstrap.js..."
# Remove a linha que registra o SW — mantém tudo mais
sed -i 's/_flutter\.loader\.load({[^}]*serviceWorkerSettings[^}]*{[^}]*}[^}]*});/_flutter.loader.load({});/' build/web/flutter_bootstrap.js

# Fallback: se o sed acima não funcionar (multiline), usa Python
python3 - <<'PYEOF'
import re, sys

with open('build/web/flutter_bootstrap.js', 'r') as f:
    content = f.read()

# Substitui o bloco loader.load({ serviceWorkerSettings: {...} }) por load({})
original = content

# Padrão: _flutter.loader.load({ serviceWorkerSettings: { ... } });
content = re.sub(
    r'_flutter\.loader\.load\(\s*\{[^}]*serviceWorkerSettings[^}]*\{[^}]*\}[^}]*\}\s*\);',
    '_flutter.loader.load({});',
    content,
    flags=re.DOTALL
)

if content != original:
    with open('build/web/flutter_bootstrap.js', 'w') as f:
        f.write(content)
    print("  ✅ serviceWorkerSettings removido com sucesso")
else:
    print("  ⚠️  Padrão não encontrado — tentando substituição direta...")
    # Substituição direta da linha exata gerada pelo Flutter
    content = re.sub(
        r'_flutter\.loader\.load\(\{[\s\n]*serviceWorkerSettings:\s*\{[\s\S]*?\}[\s\n]*\}\);',
        '_flutter.loader.load({});',
        content
    )
    with open('build/web/flutter_bootstrap.js', 'w') as f:
        f.write(content)
    print("  ✅ Substituição aplicada")
PYEOF

echo "💀 Substituindo flutter_service_worker.js por SW destruidor..."
cat > build/web/flutter_service_worker.js << 'SWEOF'
// MedCases Pro — SW Destruidor
// Apaga todos os caches do browser e se auto-remove.
'use strict';
self.addEventListener('install', function(e) { self.skipWaiting(); });
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.map(function(k) { return caches.delete(k); }));
    }).then(function() { return self.registration.unregister(); })
    .then(function() { return self.clients.matchAll({ type: 'window' }); })
    .then(function(cs) { cs.forEach(function(c) { c.navigate(c.url); }); })
  );
});
self.addEventListener('fetch', function(e) { e.respondWith(fetch(e.request)); });
SWEOF

echo "✅ Build completo! Arquivos em build/web/"
echo ""
echo "Verificando resultado:"
grep "loader.load" build/web/flutter_bootstrap.js | tail -3
echo ""
head -2 build/web/flutter_service_worker.js
