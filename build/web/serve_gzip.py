#!/usr/bin/env python3
"""
MedCases Pro — Servidor HTTP com gzip + CORS
main.dart.js: 7.5MB → 2.2MB (71% menor) via Content-Encoding: gzip
"""
import http.server
import socketserver
import os
import sys
import urllib.parse

PORT = 5060

GZ_TYPES = {
    '.js':   'application/javascript',
    '.wasm': 'application/wasm',
    '.css':  'text/css',
    '.json': 'application/json',
}

class GzipCORSHandler(http.server.SimpleHTTPRequestHandler):

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        p      = parsed.path.lstrip('/') or 'index.html'
        ext    = os.path.splitext(p)[1]
        full   = os.path.join(os.getcwd(), p)
        gz     = full + '.gz'
        ae     = self.headers.get('Accept-Encoding', '')

        # Serve gzip se cliente aceita, arquivo .gz existe e tipo suportado
        if 'gzip' in ae and ext in GZ_TYPES and os.path.isfile(gz):
            try:
                with open(gz, 'rb') as f:
                    data = f.read()
                self.send_response(200)
                self.send_header('Content-Type',     GZ_TYPES[ext])
                self.send_header('Content-Encoding', 'gzip')
                self.send_header('Content-Length',   str(len(data)))
                self.send_header('Cache-Control',    'no-cache')
                self.send_header('Vary',             'Accept-Encoding')
                self.send_header('Access-Control-Allow-Origin',  '*')
                self.send_header('X-Frame-Options',  'ALLOWALL')
                self.send_header('Content-Security-Policy', 'frame-ancestors *')
                self.end_headers()
                self.wfile.write(data)
                return
            except Exception as e:
                print(f'[gzip] erro ao servir {gz}: {e}', file=sys.stderr)

        # index.html: sem cache
        if p == 'index.html' and os.path.isfile(full):
            try:
                with open(full, 'rb') as f:
                    data = f.read()
                self.send_response(200)
                self.send_header('Content-Type',   'text/html; charset=utf-8')
                self.send_header('Content-Length', str(len(data)))
                self.send_header('Cache-Control',  'no-cache, no-store, must-revalidate')
                self.send_header('Pragma',         'no-cache')
                self.send_header('Expires',        '0')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('X-Frame-Options', 'ALLOWALL')
                self.send_header('Content-Security-Policy', 'frame-ancestors *')
                self.end_headers()
                self.wfile.write(data)
                return
            except Exception:
                pass

        # Fallback: SimpleHTTPRequestHandler padrão (sem query string)
        self.path = parsed.path
        super().do_GET()

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin',  '*')
        self.send_header('X-Frame-Options',              'ALLOWALL')
        self.send_header('Content-Security-Policy',      'frame-ancestors *')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, fmt, *args):
        msg = fmt % args
        if any(c in msg for c in ('404', '500', '403')):
            print(f'[WARN] {self.address_string()} {msg}', file=sys.stderr)


if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    try:
        js_kb = os.path.getsize('main.dart.js')   // 1024
        gz_kb = os.path.getsize('main.dart.js.gz') // 1024
        pct   = int((1 - gz_kb / js_kb) * 100)
        print(f'🚀 MedCases Pro @ :{PORT} — gzip+CORS', flush=True)
        print(f'   main.dart.js {js_kb}KB → {gz_kb}KB gzip ({pct}% menor)', flush=True)
    except Exception:
        print(f'🚀 MedCases Pro @ :{PORT}', flush=True)

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(('0.0.0.0', PORT), GzipCORSHandler) as httpd:
        httpd.serve_forever()
