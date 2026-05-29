#!/bin/bash
# build_web.sh — Build Flutter Web sem Service Worker + Cache Busting
# Uso: bash build_web.sh

set -e

echo "🔨 Building Flutter Web (release)..."
/home/user/flutter/bin/flutter build web --release --dart-define=flutter.inspector.structuredErrors=false

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

echo "🧩 Sincronizando pwa-sw.js customizado..."
cp web/pwa-sw.js build/web/pwa-sw.js

# ═══════════════════════════════════════════════════════════════════════════════
# CACHE BUSTING — Injeta git commit hash no bootstrap e APP_VERSION.
# main.dart.js NÃO recebe preload/cache-bust aqui porque o pwa-sw.js usa
# network-first para ele, evitando servir bundle antigo e warnings de preload.
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "🔑 Injetando cache-bust hash no index.html..."

# Gera hash único: git short hash + timestamp para garantir unicidade absoluta
BUILD_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "$(date +%s)")
BUILD_TS=$(date +%s)
CACHE_KEY="${BUILD_HASH}-${BUILD_TS}"

echo "  → Hash: ${CACHE_KEY}"

python3 - <<PYEOF2
import re

cache_key = "${CACHE_KEY}"

with open('build/web/index.html', 'r', encoding='utf-8') as f:
    html = f.read()

original = html

# ── 1. Preload links: href="flutter_bootstrap.js" → href="flutter_bootstrap.js?v=HASH"
# Remove versão anterior se já existir (?v=...) antes de injetar nova
html = re.sub(
    r'(href=["\'])flutter_bootstrap\.js(?:\?v=[^"\']*)?(["\'])',
    lambda m: m.group(1) + 'flutter_bootstrap.js?v=' + cache_key + m.group(2),
    html
)

# ── 2. Remove preload de main.dart.js (network-first no pwa-sw.js)
html = re.sub(
    r'\s*<link rel=["\']preload["\'] href=["\']main\.dart\.js(?:\?v=[^"\']*)?["\'] as=["\']script["\']>\s*\n?',
    '\n',
    html
)

# ── 3. Script src: src="flutter_bootstrap.js" → src="flutter_bootstrap.js?v=HASH"
html = re.sub(
    r'(src=["\'])flutter_bootstrap\.js(?:\?v=[^"\']*)?(["\'])',
    lambda m: m.group(1) + 'flutter_bootstrap.js?v=' + cache_key + m.group(2),
    html
)

# ── 4. JS dinâmico: s.src = 'flutter_bootstrap.js' → s.src = 'flutter_bootstrap.js?v=HASH'
html = re.sub(
    r"(s\.src\s*=\s*['\"])flutter_bootstrap\.js(?:\?v=[^'\"]*)?(['\"])",
    lambda m: m.group(1) + 'flutter_bootstrap.js?v=' + cache_key + m.group(2),
    html
)

# ── 5. Atualiza APP_VERSION no index.html para forçar limpeza de SW/cache no browser
# Usa o CACHE_KEY como versão — muda a cada deploy
html = re.sub(
    r"var APP_VERSION\s*=\s*'[^']*'",
    "var APP_VERSION = '" + cache_key + "'",
    html
)
html = re.sub(
    r'var APP_VERSION\s*=\s*"[^"]*"',
    'var APP_VERSION = "' + cache_key + '"',
    html
)

if html != original:
    with open('build/web/index.html', 'w', encoding='utf-8') as f:
        f.write(html)
    print("  ✅ Cache-bust injetado com sucesso:")
    # Confirma as substituições
    import re as _re
    matches = _re.findall(r'flutter_bootstrap\.js\?v=[^\'">\s]+', html)
    for m in set(matches):
        print(f"    {m}")
else:
    print("  ⚠️  Nenhuma substituição aplicada — verifique o index.html")

PYEOF2

echo ""
echo "✅ Build completo! Arquivos em build/web/"
echo ""
echo "Verificando resultado:"
grep "loader.load" build/web/flutter_bootstrap.js | tail -3
echo ""
head -2 build/web/flutter_service_worker.js
echo ""
echo "Cache-bust no index.html:"
grep -o 'flutter_bootstrap\.js?v=[^"'\''> ]*' build/web/index.html | head -5

echo ""
echo "📦 Commitando build/web no git (necessário para deploy DigitalOcean)..."
git add -f build/web/
# Só faz commit se houver mudanças staged
if git diff --cached --quiet; then
  echo "  ℹ️  Nenhuma mudança no build/web — nada a commitar"
else
  git commit -m "build: cache-bust ${CACHE_KEY} [$(date '+%Y-%m-%d %H:%M')]"
  echo "  ✅ build/web commitado com hash ${CACHE_KEY}"
fi
