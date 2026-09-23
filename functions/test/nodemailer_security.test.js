'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const nodemailer = require('nodemailer');
const { singleProfileEmail } = require('../profile_email_boundary');
const source = fs.readFileSync(require.resolve('../index.js'), 'utf8');
const invalid = [null, undefined, [], {}, 3, true, '', 'g0:g1:user@example.com;', 'a@b.com,'.repeat(50000), 'a'.repeat(20000)+'@example.com', 'a@b.com\r\nBcc:x@y.com', 'a@b.com\n', 'a@b.com\t', 'a@b.com,b@c.com', 'a@b.com;b@c.com', 'Name <a@b.com>', 'a..b@example.com', '.a@example.com', 'a@-example.com', 'a@b', 'a@@b.com'];
// Execute the exact mail callback and template source in a VM; cloud registration,
// secrets and admin notification/push dependencies are test adapters. No clinical
// module is loaded and no generated clinical registry is invented for this test.
function harness({ fail = false, password = 'synthetic-test-only' } = {}) {
  const calls = [], creations = [], messages = [], logs = [];
  const context = {
    exports: {}, singleProfileEmail,
    onDocumentCreated: (_options, handler) => handler,
    onDocumentUpdated: (_options, handler) => handler,
    GMAIL_PASS: { value: () => password }, ADMIN_EMAIL: { value: () => 'admin@example.com' },
    GMAIL_USER: 'sender@example.com',
    createAdminNotification: async () => {}, sendFcmPushToAdmins: async () => {},
    console: Object.fromEntries(['log','warn','error'].map(k=>[k, (...x)=>logs.push([k,...x])])),
    nodemailer: { createTransport(options) {
      creations.push(options);
      const transport = nodemailer.createTransport({ streamTransport: true, buffer: true });
      return { async sendMail(mail) {
        calls.push(mail);
        if (fail) throw Error('synthetic transport failure');
        const result = await transport.sendMail(mail);
        messages.push(result);
        return result;
      }};
    }}
  };
  vm.createContext(context);
  const helper = source.slice(source.indexOf('function getTransporter('), source.indexOf('// ═', source.indexOf('function getTransporter(')));
  const handlers = source.slice(source.indexOf('exports.onNewUserRegistered ='), source.indexOf('// ═', source.indexOf('exports.onUserUnblocked =') + 50));
  const templates = source.slice(source.indexOf('function buildAdminNotificationHtml('), source.indexOf('// ═', source.indexOf('function buildUserEmailHtml(')));
  vm.runInContext(helper + '\n' + handlers + '\n' + templates, context, { timeout: 1000 });
  return { ...context, calls, creations, messages, logs };
}
function event(before, after) { return { params: {uid:'test-user'}, data: {before:{data:()=>before}, after:{data:()=>after}} }; }
test('exact installed Nodemailer and production manifest target', () => {
  assert.equal(require('nodemailer/package.json').version, '10.0.10');
  assert.equal(require('../package.json').dependencies.nodemailer, '10.0.10');
  const smtp = nodemailer.createTransport({service:'gmail',auth:{user:'sender@example.com',pass:'synthetic-test-only'}});
  assert.equal(smtp.transporter.options.service,'gmail');
  smtp.close(); // Construction only: never connect, verify or send.
});
test('single profile mailbox preserves trim/case/plus; rejects complex or unbounded inputs', () => {
  assert.equal(singleProfileEmail(' User+tag@example.com '),'User+tag@example.com');
  assert.equal(singleProfileEmail("o'connor@example.com"),"o'connor@example.com");
  for (const value of invalid) assert.equal(singleProfileEmail(value), null);
});
for (const [name, status] of [['onUserApproved','pending'],['onUserUnblocked','blocked']]) {
  test(name+' rejects each hostile input before transporter and sendMail', async () => {
    const h=harness();
    for (const email of invalid) await h.exports[name](event({status},{status:'approved',email}));
    assert.equal(h.creations.length,0); assert.equal(h.calls.length,0);
    assert.equal(h.logs.length, invalid.length);
    for(const line of h.logs)assert.deepEqual(line,['warn','PROFILE_EMAIL_INVALID']);
  });
  test(name+' PT/ES sends once, preserves mail fields and exact templates', async () => {
    for(const lang of ['pt','es']) {
      const h=harness();
      await h.exports[name](event({status},{status:'approved',email:' User+tag@example.com ',displayName:'Synthetic User',lang}));
      assert.equal(h.calls.length,1); assert.equal(h.creations.length,1);
      assert.equal(h.creations[0].service,'gmail');
      assert.equal(h.calls[0].from,'"MedCases Pro" <sender@example.com>');
      assert.equal(h.calls[0].to,'User+tag@example.com');
      assert.match(h.calls[0].subject, lang==='es'?/Tu acceso/:/Seu acesso/);
      assert.equal(h.calls[0].html,h.buildUserEmailHtml('Synthetic User',lang==='es',status==='blocked'));
      assert.equal(h.calls[0].replyTo,undefined); assert.equal(h.calls[0].text,undefined);
      assert.equal(h.messages[0].envelope.to.length,1);
      assert.match(h.messages[0].message.toString(),/Content-Type: text\/html/);
    }
  });
  test(name+' transport failure remains handled and missing secret skips delivery', async () => {
    const h=harness({fail:true});
    assert.equal(await h.exports[name](event({status},{status:'approved',email:'user@example.com'})),null);
    assert.equal(h.calls.length,1); assert.equal(h.logs.at(-1)[0],'error');
    const absent=harness({password:''});
    await absent.exports[name](event({status},{status:'approved',email:'user@example.com'}));
    assert.equal(absent.calls.length,0);
  });
}
test('existing transitions neither duplicate approval nor send on unrelated update', async()=>{
  const h=harness();
  for(const status of ['blocked','approved']) await h.exports.onUserApproved(event({status},{status:'approved',email:'user@example.com'}));
  await h.exports.onUserUnblocked(event({status:'pending'},{status:'approved',email:'user@example.com'}));
  assert.equal(h.calls.length,0);
});
test('admin registration caller retains recipient, template and one stream send',async()=>{
  const h=harness();
  await h.exports.onNewUserRegistered({params:{uid:'synthetic-user'},data:{data:()=>({email:'user@example.com',displayName:'Synthetic User',status:'pending'})}});
  assert.equal(h.calls.length,1); assert.equal(h.calls[0].to,'admin@example.com');
  assert.match(h.calls[0].subject,/Novo cadastro/); assert.match(h.calls[0].html,/Synthetic/);
  assert.equal(h.messages[0].envelope.to.length,1);
});
test('Nodemailer 10 JSON transport supports text/html/replyTo without network',async()=>{
  const input={from:'sender@example.com',to:'user@example.com',subject:'Synthetic',text:'text',html:'<p>text</p>',replyTo:'reply@example.com'};
  const result=await nodemailer.createTransport({jsonTransport:true}).sendMail(input);
  const mail=JSON.parse(result.message);assert.equal(mail.text,input.text);assert.equal(mail.html,input.html);assert.equal(mail.replyTo[0].address,input.replyTo);
});
for(const kind of ['recursive-group','quadratic-list'])test('bounded isolated advisory PoC '+kind,{timeout:12000},()=>{
  const code=`const parse=require('nodemailer/lib/addressparser'); const input=${kind==='recursive-group'?"'g:'.repeat(3000)+'user@example.com;'":"'a@b.com,'.repeat(25000)"}; const start=Date.now();try { parse(input); } catch(e){ if(e instanceof RangeError) process.exit(2); if(!/group|nest|limit|recip|depth/i.test(e.message)) throw e; } console.log(JSON.stringify({elapsedMs:Date.now()-start,bytes:input.length}));`;
  const result=spawnSync(process.execPath,['--max-old-space-size=128','-e',code],{cwd:require('node:path').join(__dirname,'..'),timeout:8000,encoding:'utf8',maxBuffer:4096});
  assert.equal(result.error,undefined);assert.equal(result.status,0,result.stderr);console.log(kind,result.stdout.trim());
});
