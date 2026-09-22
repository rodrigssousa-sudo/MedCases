/// Commercial gates only. Wrapped clinical functions still execute their own
/// unchanged authority/safety checks after authorization.
const entitlementWebViewActions = <String, String>{
  '_fdCalcDoseFromModal': 'drugsWeightDose',
  'calcDrugDose': 'drugsWeightDose',
  'calcShowInlineResult': 'drugsWeightDose',
  'calculateInfusion': 'drugsAdvancedInfusion',
};
const entitlementWebViewGuardScript = r'''
(() => {
  const actions = {
    _fdCalcDoseFromModal:'drugsWeightDose',
    calcDrugDose:'drugsWeightDose',
    calcShowInlineResult:'drugsWeightDose',
    calculateInfusion:'drugsAdvancedInfusion'
  };
  for (const [name, feature] of Object.entries(actions)) {
    const original=window[name];
    if (typeof original!=='function' || original.__mcEntitlementGuard) continue;
    function guarded(...args) {
      const bridge=window.__medcasesMcc1Bridge;
      if (!bridge || !Array.isArray(bridge.features) || !bridge.features.includes(feature)) {
        try { window.MCUpgrade?.postMessage(document.documentElement.lang==='pt'?'pt':'es'); } catch (_) {}
        return undefined;
      }
      return original.apply(this,args);
    }
    Object.defineProperty(guarded,'__mcEntitlementGuard',{value:true});
    window[name]=guarded;
  }
})()
''';
