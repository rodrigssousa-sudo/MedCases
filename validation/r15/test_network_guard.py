import json,unittest,subprocess
from network_guard import setup,verify,require_mapping,cleanup,RULES,BRIDGE
class Tests(unittest.TestCase):
 def readback(self,args):
  if args[:3]==['docker','network','inspect']:return json.dumps([{'Internal':False,'EnableIPv6':False,'Options':{'com.docker.network.bridge.name':BRIDGE}}])
  if '-S' in args:return '\n'.join('-A '+args[-1]+' '+' '.join(r) for c,r in RULES if c==args[-1]).replace('ESTABLISHED,RELATED','RELATED,ESTABLISHED')
  return ''
 def test_exact_loopback_binding(self):
  self.assertTrue(require_mapping({'NetworkSettings':{'Ports':{'8080/tcp':[{'HostIp':'127.0.0.1','HostPort':'18080'}]}},'HostConfig':{'Dns':['127.0.0.1']}}))
 def test_missing_or_public_mapping_rejected(self):
  for ports in [{},{'8080/tcp':None},{'8080/tcp':[{'HostIp':'0.0.0.0','HostPort':'18080'}]}]:
   with self.assertRaisesRegex(RuntimeError,'PORT_MAPPING'):require_mapping({'NetworkSettings':{'Ports':ports}})
 def test_external_dns_rejected(self):
  with self.assertRaisesRegex(RuntimeError,'DNS'):require_mapping({'NetworkSettings':{'Ports':{'8080/tcp':[{'HostIp':'127.0.0.1','HostPort':'18080'}]}},'HostConfig':{'Dns':['8.8.8.8']}})
 def mapping(self,ports,dns=None):
  return require_mapping({'NetworkSettings':{'Ports':ports},'HostConfig':{'Dns':['127.0.0.1'] if dns is None else dns}})
 def binding(self,ip='127.0.0.1',port='18080'):
  return [{'HostIp':ip,'HostPort':port}]
 def test_unpublished_null_port_accepted(self):
  self.assertTrue(self.mapping({'80/tcp':None,'8080/tcp':self.binding()}))
 def test_unpublished_empty_port_accepted(self):
  self.assertTrue(self.mapping({'80/tcp':[],'8080/tcp':self.binding()}))
 def test_expected_binding_absent_rejected(self):
  for ports in [None,{}, {'8080/tcp':None},{'8080/tcp':[]}]:
   with self.subTest(ports=ports),self.assertRaisesRegex(RuntimeError,'PORT_MAPPING'):self.mapping(ports)
 def test_ipv6_and_public_hosts_rejected(self):
  for ip in ['0.0.0.0','::','203.0.113.1','']:
   with self.subTest(ip=ip),self.assertRaisesRegex(RuntimeError,'PORT_MAPPING'):self.mapping({'8080/tcp':self.binding(ip=ip)})
 def test_wrong_host_port_rejected(self):
  with self.assertRaisesRegex(RuntimeError,'PORT_MAPPING'):self.mapping({'8080/tcp':self.binding(port='8080')})
 def test_additional_published_port_rejected(self):
  with self.assertRaisesRegex(RuntimeError,'PORT_MAPPING'):self.mapping({'8080/tcp':self.binding(),'80/tcp':self.binding(port='18081')})
 def test_multiple_bindings_rejected(self):
  for extra in [self.binding(),self.binding(ip='0.0.0.0')]:
   with self.subTest(extra=extra),self.assertRaisesRegex(RuntimeError,'PORT_MAPPING'):self.mapping({'8080/tcp':self.binding()+extra})
 def test_malformed_additional_binding_not_ignored(self):
  for invalid in ['',False,0,{}]:
   with self.subTest(invalid=invalid),self.assertRaisesRegex(RuntimeError,'PORT_MAPPING'):self.mapping({'8080/tcp':self.binding(),'80/tcp':invalid})
 def test_rule_readback(self):self.assertEqual(verify(self.readback)['outbound'],'DROP')
 def test_shadowed_rule_rejected(self):
  with self.assertRaisesRegex(RuntimeError,'FIREWALL'):
   verify(lambda a:'-A '+a[-1]+' -j RETURN\n'+self.readback(a) if '-S' in a else self.readback(a))
 def test_missing_rule_rejected(self):
  with self.assertRaisesRegex(RuntimeError,'FIREWALL'):verify(lambda a:'' if '-S' in a else self.readback(a))
 def test_ipv6_rejected(self):
  with self.assertRaisesRegex(RuntimeError,'NETWORK'):verify(lambda a:self.readback(a).replace('"EnableIPv6": false','"EnableIPv6": true'))
 def test_setup_installs_deny_before_allow_and_verifies(self):
  calls=[]
  setup(lambda a:(calls.append(a),self.readback(a))[1])
  rules=[a for a in calls if '-I' in a];self.assertEqual(rules[0][-1],'DROP');self.assertEqual(rules[2][-1],'DROP')
 def test_cleanup_refuses_running_container(self):
  with self.assertRaisesRegex(RuntimeError,'REMOVE_CONTAINER'):cleanup(lambda a:'[]')
if __name__=='__main__':unittest.main(verbosity=2)
