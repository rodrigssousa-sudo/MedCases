'use strict';
// No free-form text accepted by this sink. Level is selected by code, not input.
const sink = globalThis.console;
module.exports = Object.freeze(Object.fromEntries(
 ['log','info','warn','error','debug'].map(level => [level, (..._untrusted) =>
   sink[level]('MEDCASES_' + level.toUpperCase() + '_EVENT_REDACTED')])));
