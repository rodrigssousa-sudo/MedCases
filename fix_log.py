content = open('/home/user/webapp/lib/services/gemini_service_v2.dart').read()
lines = content.split('\n')
bad = [(i, l) for i,l in enumerate(lines) if l.startswith('_log(')]
print(f'bad lines: {len(bad)}')
for i,l in bad[:5]:
    print(f'  line {i+1}: {repr(l[:100])}')
