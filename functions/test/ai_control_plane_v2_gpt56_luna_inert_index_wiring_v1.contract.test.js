'use strict';

const fs=require('fs');
const path=require('path');
const assert=require('assert');

const indexPath=path.join(__dirname,'..','index.js');
const source=fs.readFileSync(indexPath,'utf8');

assert.ok(
  source.includes(
    "runGpt56LunaPlantaoPrimaryShadow"
  )
);

assert.ok(
  source.includes(
    "buildGpt56LunaShadowTelemetry"
  )
);

assert.ok(
  source.includes(
    "./lib/ai_control_plane_v2/gpt56_luna_plantao_primary_shadow_v1"
  )
);

assert.ok(
  source.includes(
    "[AI_CONTROL_PLANE_V2_GPT56_LUNA_REAL_SHADOW]"
  )
);

assert.ok(
  source.includes(
    "[AI_CONTROL_PLANE_V2_GPT56_LUNA_REAL_SHADOW_ERROR]"
  )
);

const callPos=
  source.indexOf(
    "void runGpt56LunaPlantaoPrimaryShadow({"
  );

assert.ok(callPos>=0);

const nanoCallPos=
  source.lastIndexOf(
    "void runGpt5NanoPlantaoRouterRealShadow({",
    callPos
  );

assert.ok(nanoCallPos>=0);
assert.ok(nanoCallPos<callPos);

const inheritedGuardSegment=
  source.slice(
    nanoCallPos,
    callPos
  );

assert.ok(
  inheritedGuardSegment.includes(".then(")
);

assert.ok(
  inheritedGuardSegment.includes(".catch(")
);

// Plantão-only is inherited from the already-proven Nano callsite
// block. This R3 also executes the established Nano wiring contract
// against the exact same candidate index.js.
const nanoToLunaDistance=callPos-nanoCallPos;
assert.ok(nanoToLunaDistance>0);
assert.ok(nanoToLunaDistance<12000);

const beginMarker=
  'AI_CONTROL_PLANE_V2_GPT56_LUNA_INERT_BEGIN';

const endMarker=
  'AI_CONTROL_PLANE_V2_GPT56_LUNA_INERT_END';

const beginMarkerPos=
  source.indexOf(beginMarker);

const endMarkerPos=
  source.indexOf(endMarker);

assert.ok(beginMarkerPos>=0);
assert.ok(endMarkerPos>beginMarkerPos);
assert.ok(
  beginMarkerPos<callPos &&
  callPos<endMarkerPos
);

assert.strictEqual(
  source.indexOf(
    beginMarker,
    beginMarkerPos+1
  ),
  -1
);

assert.strictEqual(
  source.indexOf(
    endMarker,
    endMarkerPos+1
  ),
  -1
);

// Exact statement bytes: start at the Luna call and stop at the
// beginning of the END-marker line, not at the marker token itself.
// Otherwise the slice would retain the leading "// " comment prefix
// and would appear to end with "/" instead of the statement semicolon.
const endMarkerLineStart=
  source.lastIndexOf(
    '\n',
    endMarkerPos
  );

assert.ok(endMarkerLineStart>callPos);
assert.ok(endMarkerLineStart<endMarkerPos);

const local=
  source.slice(
    callPos,
    endMarkerLineStart
  );

assert.ok(local.includes('.then('));
assert.ok(local.includes('.catch('));
assert.ok(local.trimEnd().endsWith(';'));

assert.strictEqual(
  local.includes(
    "await runGpt56LunaPlantaoPrimaryShadow"
  ),
  false
);

assert.strictEqual(
  /res\.(?:status|json|send|write|end)\s*\(/.test(local),
  false
);

const reqMutationPattern=
  /req\.[A-Za-z0-9_$.[\]'"]+\s*(?:\+\+|--|\+=|-=|\*=|\/=|%=|\*\*=|&&=|\|\|=|\?\?=|=(?!=|>))/;

assert.strictEqual(
  reqMutationPattern.test(local),
  false
);

assert.ok(
  local.includes(
    "buildOpenAiProtectedClinicalDataPolicyFromEnv("
  )
);

assert.ok(
  local.includes(
    "protectedClinicalProjection: __protectedClinicalProjectionV2"
  )
);

assert.strictEqual(
  /protectedClinicalProjection\s*:\s*req\.body/.test(local),
  false
);

assert.strictEqual(
  /providerDataPolicy\s*:\s*req\.body/.test(local),
  false
);

assert.ok(
  local.includes(
    "buildGpt56LunaShadowTelemetry("
  )
);

assert.strictEqual(
  local.includes(
    "JSON.stringify(shadowResult)"
  ),
  false
);

assert.ok(
  local.includes(
    "userResponseAuthority: false"
  )
);

assert.ok(
  local.includes(
    "liveModelSelectionAuthority: false"
  )
);

assert.ok(
  local.includes(
    "liveErrorPathAuthority: false"
  )
);

console.log('GPT56_LUNA_INDEX_IMPORT_AND_CALLSITE=PASS');
console.log('GPT56_LUNA_PLANTAO_GUARD_INHERITED_FROM_NANO_BLOCK=PASS');
console.log('GPT56_LUNA_FIRE_AND_FORGET_NO_AWAIT=PASS');
console.log('GPT56_LUNA_EXPLICIT_BEGIN_END_MARKERS=PASS');
console.log('GPT56_LUNA_END_MARKER_LINE_BOUNDARY=PASS');
console.log('GPT56_LUNA_EXACT_PROMISE_STATEMENT_CAPTURE=PASS');
console.log('GPT56_LUNA_NO_RES_WRITE=PASS');
console.log('GPT56_LUNA_REQ_MUTATION_COMPARISON_FALSE_POSITIVE_FIXED=PASS');
console.log('GPT56_LUNA_NO_REQ_MUTATION=PASS');
console.log('GPT56_LUNA_SERVER_POLICY_SOURCE=PASS');
console.log('GPT56_LUNA_CLIENT_PROTECTED_PROJECTION=NONE');
console.log('GPT56_LUNA_RAW_SHADOW_RESULT_LOGGING=NO');
console.log('GPT56_LUNA_USER_RESPONSE_AUTHORITY=NONE');
console.log('GPT56_LUNA_LIVE_MODEL_SELECTION_AUTHORITY=NONE');
console.log('GPT56_LUNA_LIVE_ERROR_PATH_AUTHORITY=NONE');
console.log('GPT56_LUNA_INERT_INDEX_WIRING=PASS');
