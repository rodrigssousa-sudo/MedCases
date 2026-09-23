'use strict';
// Execute exact production AST nodes without starting HTTP/cloud services.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const acorn = require('acorn');
function source(file) {
  const text = fs.readFileSync(path.resolve(__dirname, '../../', file), 'utf8');
  return {text, ast: acorn.parse(text, {ecmaVersion: 'latest'})};
}
function loadServer(environment, allowedOrigin = 'https://medcasespro.com') {
  const {text, ast} = source('server/server.js');
  const origins = [];
  function walk(node) {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'CallExpression' && node.callee.name === 'cors') {
      const property = node.arguments[0]?.properties?.find(p => p.key.name === 'origin');
      if (property) origins.push(property.value);
    }
    for (const v of Object.values(node)) {
      if (Array.isArray(v)) v.forEach(walk);
      else if (v && typeof v === 'object') walk(v);
    }
  }
  walk(ast); assert.equal(origins.length, 1);
  const callback = vm.runInNewContext('(' + text.slice(origins[0].start, origins[0].end) + ')', {
    process: {env: {NODE_ENV: environment}}, ALLOWED_ORIGIN: allowedOrigin, log: {warn() {}}
  });
  return origin => {
    let result; let calls = 0;
    callback(origin, (err, allowed) => { calls++; result = !err && allowed === true; });
    assert.equal(calls, 1);
    return result;
  };
}
function loadFunctions(environment) {
  const {text, ast} = source('functions/index.js');
  const policy = ast.body.find(n => n.type === 'VariableDeclaration' &&
    n.declarations.some(d => d.id.name === 'PAID_PROXY_ALLOWED_ORIGINS'));
  const resolver = ast.body.find(n => n.type === 'FunctionDeclaration' && n.id.name === 'resolveCorsOrigin');
  const headers = ast.body.find(n => n.type === 'FunctionDeclaration' && n.id.name === 'setCorsHeaders');
  assert.ok(policy && resolver && headers);
  const context = vm.createContext({process: {env: {NODE_ENV: environment}}});
  vm.runInContext([policy, resolver, headers].map(n => text.slice(n.start, n.end)).join('\n'), context);
  return origin => {
    const emitted = {};
    context.setCorsHeaders({headers: {origin}}, {set: (k, v) => { emitted[k] = v; }});
    return emitted['Access-Control-Allow-Origin'] === origin && Boolean(origin);
  };
}
module.exports = {loadServer, loadFunctions};
