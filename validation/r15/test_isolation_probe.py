import unittest
from isolation_probe import drop_counter,validate_negative
from verify_inputs import allowed_dockerfile
class Tests(unittest.TestCase):
 def test_counter_matching(self):
  self.assertEqual(drop_counter('INPUT',lambda _: '[7:420] -A INPUT -i br-r15-b1 -j DROP\n'),7)
 def test_counter_missing_fails(self):
  with self.assertRaises(RuntimeError):drop_counter('INPUT',lambda _:'')
 def test_reachable_control_and_dropped_probe(self):validate_negative(200,1,0,1)
 def test_false_positive_denials_rejected(self):
  for values in [(503,1,0,1),(200,0,0,1),(200,1,3,3)]:
   with self.assertRaises(RuntimeError):validate_negative(*values)
 def test_healthcheck_exact_delta(self):
  before='CMD wget http://localhost:8080/health';self.assertTrue(allowed_dockerfile(before,'CMD wget http://127.0.0.1:8080/health'))
  self.assertFalse(allowed_dockerfile(before,'CMD wget http://127.0.0.1:9090/health'))
  self.assertFalse(allowed_dockerfile(before,'CMD wget http://127.0.0.1:8080/health\nRUN unsafe'))
