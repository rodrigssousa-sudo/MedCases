"""Diagnostics for a fixed local health endpoint; never substitutes for Docker evidence."""
import datetime
import hashlib
import json
import subprocess
import time
import urllib.error
import urllib.request

URL = 'http://127.0.0.1:18080/health'

def probe_health(url=URL, timeout=2):
    start = time.monotonic()
    record = {'url': url, 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'ok': False}
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            record['httpStatus'] = response.status
            raw = response.read(4097)
        record['bodyTruncated'] = len(raw) > 4096
        record['body'] = raw[:4096].decode('utf-8', errors='replace')
        record['bodySHA256'] = hashlib.sha256(raw).hexdigest()
        payload = json.loads(raw)
        record['ok'] = response.status == 200 and isinstance(payload, dict) and payload.get('status') == 'ok'
        if not record['ok']:
            record['failure'] = 'UNEXPECTED_HEALTH_RESPONSE'
    except urllib.error.HTTPError as error:
        try:
            record.update(httpStatus=error.code, failure='HTTP_ERROR', body=error.read(4096).decode('utf-8', errors='replace'))
        finally:
            error.close()
    except urllib.error.URLError as error:
        record.update(failure='CONNECTION_ERROR', errorClass=type(error.reason).__name__, errno=getattr(error.reason, 'errno', None), reason=str(error.reason))
    except (TimeoutError, OSError, ValueError) as error:
        record.update(failure='TIMEOUT' if isinstance(error, TimeoutError) else 'INVALID_RESPONSE' if isinstance(error, ValueError) else 'IO_ERROR', errorClass=type(error).__name__, errno=getattr(error, 'errno', None), reason=str(error))
    finally:
        record['elapsedSeconds'] = round(time.monotonic() - start, 4)
    return record

def wait_health(path, attempts=40, interval=1, probe=probe_health, sleep=time.sleep):
    records = []
    for _ in range(attempts):
        record = probe()
        records.append(record)
        path.write_text(json.dumps(records, indent=2))
        if record['ok']:
            return record
        sleep(interval)
    raise RuntimeError('HEALTH_FAILED:' + records[-1].get('failure', 'UNKNOWN'))

def collect_runtime(output, runner=subprocess.run):
    """Always run before docker rm. Individual collection errors cannot mask B1 failure."""
    captures = {
        'localhost-resolution-and-sockets': ['docker', 'exec', 'r15-web', 'sh', '-c', 'cat /etc/hosts; cat /proc/net/tcp; cat /proc/net/tcp6'],
        'localhost-http-health': ['docker', 'exec', 'r15-web', 'wget', '-S', '-T', '2', '-O', '-', 'http://localhost:8080/health'],
        'container-logs': ['docker', 'logs', '--timestamps', 'r15-web'],
        'container-state': ['docker', 'inspect', '--format', '{{json .State}}', 'r15-web'],
        'container-health-policy': ['docker', 'inspect', '--format', '{{json .Config.Healthcheck}}', 'r15-web'],
        'container-port-binding': ['docker', 'inspect', '--format', '{{json .NetworkSettings.Ports}}', 'r15-web'],
        'container-network': ['docker', 'network', 'inspect', 'r15-validation'],
        'runtime-nginx-config': ['docker', 'exec', 'r15-web', 'nginx', '-T'],
        'internal-http-health': ['docker', 'exec', 'r15-web', 'wget', '-S', '-T', '2', '-O', '-', 'http://127.0.0.1:8080/health'],
    }
    index = {}
    for name, command in captures.items():
        try:
            completed = runner(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
            (output / (name + '.log')).write_bytes(completed.stdout)
            index[name] = {'exitCode': completed.returncode}
        except Exception as error:
            index[name] = {'collectionErrorClass': type(error).__name__}
    (output / 'runtime-diagnostics.json').write_text(json.dumps(index, indent=2))
    return index
