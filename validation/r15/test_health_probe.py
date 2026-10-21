import http.server
import json
import pathlib
import subprocess
import tempfile
import threading
import time
import unittest
from health_probe import probe_health, wait_health, collect_runtime

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        if self.path == '/slow': time.sleep(.15)
        status = 503 if self.path == '/unavailable' else 200
        self.send_response(status); self.end_headers()
        body = b'not-json' if self.path == '/invalid' else b'{"status":"wrong"}' if self.path == '/wrong' else b'{"status":"ok"}'
        try: self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError): pass

class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
        cls.url='http://127.0.0.1:'+str(cls.server.server_port)
    @classmethod
    def tearDownClass(cls):cls.server.shutdown();cls.server.server_close();cls.thread.join()
    def test_real_http_200(self):
        r=probe_health(self.url+'/health');self.assertTrue(r['ok']);self.assertEqual(r['httpStatus'],200)
    def test_real_http_503(self):
        r=probe_health(self.url+'/unavailable');self.assertFalse(r['ok']);self.assertEqual(r['httpStatus'],503);self.assertEqual(r['failure'],'HTTP_ERROR')
    def test_real_malformed_json(self):
        r=probe_health(self.url+'/invalid');self.assertFalse(r['ok']);self.assertEqual(r['failure'],'INVALID_RESPONSE');self.assertEqual(r['body'],'not-json')
    def test_real_wrong_health_body(self):
        r=probe_health(self.url+'/wrong');self.assertFalse(r['ok']);self.assertEqual(r['failure'],'UNEXPECTED_HEALTH_RESPONSE')
    def test_real_timeout(self):
        r=probe_health(self.url+'/slow',timeout=.02);self.assertFalse(r['ok']);self.assertEqual(r['failure'],'TIMEOUT')
    def test_real_connection_refused(self):
        server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);port=server.server_port;server.server_close()
        r=probe_health('http://127.0.0.1:'+str(port)+'/health');self.assertFalse(r['ok']);self.assertEqual(r['failure'],'CONNECTION_ERROR');self.assertIsNotNone(r['errno'])
    def test_attempts_preserved_and_failure_not_ignored(self):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'attempts.json';sleeps=[]
            with self.assertRaisesRegex(RuntimeError,'HEALTH_FAILED:HTTP_ERROR'):
                wait_health(p,attempts=3,probe=lambda:probe_health(self.url+'/unavailable'),sleep=sleeps.append)
            self.assertEqual(len(json.loads(p.read_text())),3);self.assertEqual(sleeps,[1,1,1])
    def test_success_does_not_retry(self):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'attempts.json'
            wait_health(p,probe=lambda:probe_health(self.url+'/health'),sleep=lambda _:self.fail('unexpected sleep'))
            self.assertEqual(len(json.loads(p.read_text())),1)
    def test_diagnostics_collect_all_even_if_one_command_fails(self):
        calls=[]
        def run(args,**kwargs):
            calls.append(args)
            if args[1]=='logs':raise subprocess.TimeoutExpired(args,10)
            return subprocess.CompletedProcess(args,1,b'controlled diagnostic fixture')
        with tempfile.TemporaryDirectory() as d:
            records=collect_runtime(pathlib.Path(d),runner=run)
            self.assertEqual(len(calls),7);self.assertEqual(records['container-logs']['collectionErrorClass'],'TimeoutExpired')
            self.assertEqual(records['internal-http-health']['exitCode'],1)
            self.assertTrue((pathlib.Path(d)/'container-state.log').exists())
            self.assertTrue(any('http://127.0.0.1:8080/health' in c for c in calls))

if __name__=='__main__':unittest.main(verbosity=2)
