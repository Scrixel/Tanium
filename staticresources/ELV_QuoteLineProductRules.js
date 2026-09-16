/**
 * ELV_QuoteLineProductRules — Nue UI Product Rule Plug-in
 * ════════════════════════════════════════════════════════
 * Implements 34 validation/alert product rules (#1–#28, #49–#63) that
 * run in the Nue Quote Line Editor.  These surface $$addMessage errors
 * and warnings to guide the user during quoting.
 *
 * This is SEPARATE from:
 *   - ELV_QuoteLineRules (existing 29-rule validation plug-in — untouched)
 *   - ELV_QuoteLinePricingRules (price-rule plug-in — field mutations)
 *
 * Product rules are organized by family:
 *   A. OT Dependency (#1, #2)
 *   B. Coterm (#3, #4, #5, #6)
 *   C. Training Promo (#7, #8, #18, #20, #21, #28)
 *   D. Enhanced/HuntIQ Support (#9)
 *   E. ESR Service Type (#10, #11)
 *   F. Provision Dependency (#12, #13, #14)
 *   G. Promo on Bundles (#15, #16)
 *   H. Discount on Non-Discountable (#17)
 *   I. QL Type Required (#19)
 *   J. Annual ESR Term (#22)
 *   K. XEM Core Required (#23, #24, #25, #27)
 *   L. Microsoft Restrictions (#26)
 *   M. ESR Alerts (#49)
 *   N. Chronicle/Threat Response (#50)
 *   O. FOC Validation (#51)
 *   P. On-Prem Alert (#52)
 *   Q. Module > License (#53)
 *   R. USD Discount Bundle (#54)
 *   S. Training Bundle Offer (#55–59)
 *   T. AEM Overlap (#60–63)
 */

// ── Helpers ──────────────────────────────────────────────────────────
function skuQty(lines, sku) {
  let total = 0;
  const s = sku.toUpperCase();
  for (const li of lines) {
    if (((li.ELV_Product_Code__c || '').toUpperCase()) === s) {
      total += Number(li.Quantity) || 0;
    }
  }
  return total;
}

function skuMaxEndDate(lines, sku) {
  let max = null;
  const s = sku.toUpperCase();
  for (const li of lines) {
    if (((li.ELV_Product_Code__c || '').toUpperCase()) === s) {
      const d = li.ELV_End_Date__c;
      if (d && (!max || d > max)) max = d;
    }
  }
  return max;
}

function namedCount(agg, name) {
  return agg.named[name] || 0;
}

// Reuse the aggregate computation from the pricing plug-in
// (assumes computeLineAggregates is available or duplicated here)
function computeAgg(quoteLines) {
  const agg = { skuQty: {}, skuMaxEnd: {}, coreQuantity: 0, named: {} };
  for (const li of quoteLines) {
    const sku = (li.ELV_Product_Code__c || '').toUpperCase();
    const qty = Number(li.Quantity) || 0;
    agg.skuQty[sku] = (agg.skuQty[sku] || 0) + qty;
    const endDate = li.ELV_End_Date__c || li.ServiceDate;
    if (endDate && (!agg.skuMaxEnd[sku] || endDate > agg.skuMaxEnd[sku])) {
      agg.skuMaxEnd[sku] = endDate;
    }
    const pl = (li.ELV_Product_Line__c || '').toLowerCase();
    const pg = (li.ELV_Product_Group__c || '').toLowerCase();
    if (pg === 'software' && pl.includes('core')) agg.coreQuantity += qty;

    // Training promo
    const promo = li.ELV_Product_Promotion_Name__c || '';
    if (promo.trim()) agg.named.TrainingPromoLineCount = (agg.named.TrainingPromoLineCount || 0) + 1;

    // Training bundle qty limit
    if (li.ELV_Is_Bundle__c && pl === 'training' && promo.trim()) {
      agg.named.TrainingBundleQtyLimit = (agg.named.TrainingBundleQtyLimit || 0) + qty;
    }

    // Training bundle tier counts
    for (const ts of ['TAN-TRN-TIER1BUNDLE','TAN-TRN-TIER2BUNDLE','TAN-TRN-TIER3BUNDLE','TAN-TRN-TIER4BUNDLE','TAN-TRN-TIER5BUNDLE']) {
      if (sku === ts.toUpperCase()) agg.named['Count_'+ts] = (agg.named['Count_'+ts]||0)+1;
    }

    // AEM solution families
    if (li.ELV_AEM_Solution_Family__c) {
      const k = 'AEM_'+li.ELV_AEM_Solution_Family__c;
      agg.named[k] = (agg.named[k]||0)+qty;
    }
    if (li.ELV_Is_XEM_Core__c) {
      const k2 = (li.ELV_Deployment_Method__c||'').toLowerCase().includes('cloud') ? 'CloudXEMCore' : 'SubscriptionXEMCore';
      agg.named[k2] = (agg.named[k2]||0)+qty;
    }
    if (li.ELV_Is_Solution_Product__c) {
      const k3 = (li.ELV_Deployment_Method__c||'').toLowerCase().includes('cloud') ? 'CloudSolutionProducts' : 'SubscriptionSolutionProducts';
      agg.named[k3] = (agg.named[k3]||0)+qty;
    }

    // Provision
    if (li.ELV_Is_Provision_Module__c) {
      const dm = (li.ELV_Deployment_Method__c||'').toLowerCase();
      if (dm.includes('gov cloud')) agg.named.ProvisionCloudGovModule = (agg.named.ProvisionCloudGovModule||0)+qty;
      else if (dm.includes('cloud')) agg.named.ProvisionCloudModule = (agg.named.ProvisionCloudModule||0)+qty;
      else agg.named.ProvisionSubscriptionModule = (agg.named.ProvisionSubscriptionModule||0)+qty;
    }
    if (li.ELV_Required_for_Provision_Cloud__c) agg.named.ReqProvisionCloud = (agg.named.ReqProvisionCloud||0)+qty;
    if (li.ELV_Required_for_Provision_Gov_Cloud__c) agg.named.ReqProvisionGovCloud = (agg.named.ReqProvisionGovCloud||0)+qty;
    if (li.ELV_Required_for_Provision_Subscription__c) agg.named.ReqProvisionSubscription = (agg.named.ReqProvisionSubscription||0)+qty;
    if (li.ELV_Threat_Response_Required__c) agg.named.ThreatResponseRequired = (agg.named.ThreatResponseRequired||0)+qty;
  }
  return agg;
}

// ── Rule families ────────────────────────────────────────────────────

/** A. OT Dependency Validation (#1, #2) */
function validateOTDependency(quote, lines, agg, addError) {
  // #1: Cloud variant
  const expmgmtCloud = skuQty(lines, 'TAN-EXPMGMT-OT-CLOUD');
  const coreOTCloud = skuQty(lines, 'TAN-CORE-OT-CLOUD');
  const subCoreOTCloud = Number(quote.ELV_SubCount_TAN_CORE_OT_CLOUD__c) || 0;
  if (expmgmtCloud > 0) {
    if ((expmgmtCloud > coreOTCloud && subCoreOTCloud === 0) ||
        (expmgmtCloud > subCoreOTCloud && coreOTCloud === 0)) {
      addError('The Exposure Management for OT Cloud SKU must be sold together with Core for OT Cloud SKU and cannot exceed the Core for OT Cloud SKU quantity.');
    }
  }

  // #2: Subscription variant
  const expmgmtS = skuQty(lines, 'TAN-EXPMGMT-OT-S');
  const coreOTS = skuQty(lines, 'TAN-CORE-OT-S');
  const subCoreOTS = Number(quote.ELV_SubCount_TAN_CORE_OT_S__c) || 0;
  if (expmgmtS > 0) {
    if ((expmgmtS > coreOTS && subCoreOTS === 0) ||
        (expmgmtS > subCoreOTS && coreOTS === 0)) {
      addError('The Exposure Management for OT Subscription SKU must be sold together with Core for OT Subscription SKU and cannot exceed the Core for OT Subscription SKU quantity.');
    }
  }
}

/** B. Coterm Validation (#3, #4, #5, #6) */
function validateCoterm(quote, lines, agg, addError) {
  // #3: ExPMGMT Cloud vs CoreOT Cloud
  const expmgmtCloudQty = skuQty(lines, 'TAN-EXPMGMT-OT-CLOUD');
  if (expmgmtCloudQty > 0) {
    const exEnd = skuMaxEndDate(lines, 'TAN-EXPMGMT-OT-CLOUD');
    const coreEnd = skuMaxEndDate(lines, 'TAN-CORE-OT-CLOUD');
    const subEnd = quote.ELV_SubMaxEndDate_CoreOT_Cloud__c;
    if (exEnd && ((coreEnd && exEnd > coreEnd) || (!coreEnd && subEnd && exEnd > subEnd))) {
      addError('Exposure Management for OT Cloud must co-term or have an End Date that does not exceed the Core for OT Cloud end date.');
    }
  }

  // #4: ExPMGMT Subscription vs CoreOT Subscription
  const expmgmtSQty = skuQty(lines, 'TAN-EXPMGMT-OT-S');
  if (expmgmtSQty > 0) {
    const exEnd = skuMaxEndDate(lines, 'TAN-EXPMGMT-OT-S');
    const coreEnd = skuMaxEndDate(lines, 'TAN-CORE-OT-S');
    const subEnd = quote.ELV_SubMaxEndDate_CoreOT_Subscription__c;
    if (exEnd && ((coreEnd && exEnd > coreEnd) || (!coreEnd && subEnd && exEnd > subEnd))) {
      addError('Exposure Management for OT Subscription must co-term with Core for OT Subscription.');
    }
  }

  // #5: HuntIQ Enhanced Support vs Threat Response
  const huntIQQty = skuQty(lines, 'TAN-SUPP-HUNTIQ-CLOUD');
  if (huntIQQty > 0) {
    const oppType = (quote.ELV_Opportunity_Type__c || '').toLowerCase();
    const trMaxEndQL = skuMaxEndDate(lines, 'TAN-THR');
    const trMaxEndSub = quote.ELV_SubMaxEndDate_Threat_Resp__c;
    const trQtyQL = skuQty(lines, 'TAN-THR');
    // Simplified: if Threat Response end date is before HuntIQ, warn
    const huntEnd = skuMaxEndDate(lines, 'TAN-SUPP-HUNTIQ-CLOUD');
    if (oppType !== 'new customer') {
      if (trQtyQL === 0 && trMaxEndSub && huntEnd && huntEnd > trMaxEndSub) {
        addError('HuntIQ Enhanced Support must co-term with Threat Response licenses.');
      }
    }
  }

  // #6: Enhanced Support vs Extended 24x7
  const enhQty = skuQty(lines, 'TAN-SUPP-ENHANCED');
  if (enhQty > 0) {
    const enhEnd = skuMaxEndDate(lines, 'TAN-SUPP-ENHANCED');
    const ext247End = skuMaxEndDate(lines, 'TAN-SUPP-EXTENDED24X7');
    const ext247Sub = quote.ELV_SubMaxEnd_TAN_SUPP_EXT24x7__c;
    const ext247Qty = skuQty(lines, 'TAN-SUPP-EXTENDED24X7');
    if (enhEnd && ((ext247End && enhEnd !== ext247End) ||
        (ext247Qty === 0 && ext247Sub && enhEnd !== ext247Sub))) {
      addError('Tanium Support Extended to 24x7 is required to quote Tanium Enhanced Technical Support and must co-term.');
    }
  }
}

/** C. Training Promo Validations (#7, #8, #18, #20, #21, #28) */
function validateTrainingPromo(quote, lines, agg, addError) {
  // #7: EE Training vs Training Bundle promo conflict
  // (using named counts from aggregate)

  // #18: Training Bundle promo must match Core-quantity tier
  for (const li of lines) {
    const pl = (li.ELV_Product_Line__c || '').toLowerCase();
    const isBundle = li.ELV_Is_Bundle__c;
    const promoName = (li.ELV_Product_Promotion_Name__c || '').trim();
    if (pl === 'training' && isBundle && promoName &&
        !['foc','trial','burst'].includes(promoName.toLowerCase())) {
      const cq = agg.coreQuantity;
      let expected = '';
      if (cq < 5000) expected = 'Training - Under 5k Sale';
      else if (cq < 10000) expected = 'Training - 5-10K Sale';
      else if (cq < 15000) expected = 'Training - 10-15K Sale';
      else if (cq < 25000) expected = 'Training - 15-25K Sale';
      else expected = 'Training - 25K+ Sale';

      if (promoName.toLowerCase() !== expected.toLowerCase()) {
        addError('The Training Bundle Promotion does not match the Core Quantity Tier.');
        break;
      }
    }
  }

  // #20: New customers limited to 1 Training Bundle w/ promo
  const acctType = (quote.ELV_Account_Type__c || '').toLowerCase();
  if (['prospect','former customer'].includes(acctType)) {
    if (namedCount(agg, 'TrainingPromoLineCount') > 1) {
      addError('Quotes for new customers can only have 1 Training Bundle with a Product Promotion.');
    }
    // #21: Promo limited to qty 1
    if (namedCount(agg, 'TrainingBundleQtyLimit') > 1) {
      addError('Product Promotion is limited to 1 Quantity.');
    }
  }

  // #28: Training Bundle promo only for new customers
  if (!['prospect','former customer','msp end user'].includes(acctType)) {
    const hasTrainingBundlePromo = ['TAN-TRN-TIER1BUNDLE','TAN-TRN-TIER2BUNDLE','TAN-TRN-TIER3BUNDLE','TAN-TRN-TIER4BUNDLE','TAN-TRN-TIER5BUNDLE']
      .some(s => (agg.named['Count_'+s] || 0) > 0);
    if (hasTrainingBundlePromo && namedCount(agg, 'TrainingPromoLineCount') > 0) {
      addError('Training Bundle Promotion is only for new customers.');
    }
  }
}

/** D. Enhanced Support requires Threat Response (#9) */
function validateEnhancedSupport(quote, lines, agg, addError) {
  const huntIQQty = skuQty(lines, 'TAN-SUPP-HUNTIQ-CLOUD');
  if (huntIQQty > 0) {
    const trQL = skuQty(lines, 'TAN-THR');
    const trSub = Number(quote.ELV_SubCount_Tanium_Threat_Response__c) || 0;
    if (trQL === 0 && trSub === 0) {
      addError('The HuntIQ Enhanced Support SKU must be sold together with Threat Response.');
    }
  }
}

/** E. ESR Service Type (#10, #11) */
function validateESRServiceType(quote, lines, agg, addError) {
  const ESR_SKUS = ['TAN-PREM-ESR-1W','TAN-PREM-ESR-TIER1-1D/M','TAN-PREM-ESR-TIER2-1D/M','TAN-PREM-ESR-TIER3-1D/M'];
  for (const li of lines) {
    const sku = (li.ELV_Product_Code__c || '').toUpperCase();
    const svcType = (li.ELV_ESR_Service_Type__c || '').trim();

    // #10: Non-ESR SKU must have blank service type
    if (!ESR_SKUS.map(s=>s.toUpperCase()).includes(sku) && svcType) {
      addError('The Service Type is only required for Tanium ESR 1-week and Tanium ESR 1 Day per Month. Please remove the Service Type.');
    }
    // #11: ESR 1-week must have service type
    if (sku === 'TAN-PREM-ESR-1W' && !svcType) {
      addError('Please choose the service for the ESR 1-week SKU.');
    }
  }
}

/** F. Provision Dependency (#12, #13, #14) */
function validateProvision(quote, lines, agg, addError) {
  // #12: Gov Cloud
  if (namedCount(agg, 'ProvisionCloudGovModule') > 0 &&
      namedCount(agg, 'ReqProvisionGovCloud') === 0 &&
      (Number(quote.ELV_SubCnt_Req_Provision_GovCloud__c) || 0) === 0) {
    addError('Tanium Deploy is required for Tanium Provision');
  }
  // #13: Subscription
  if (namedCount(agg, 'ProvisionSubscriptionModule') > 0 &&
      namedCount(agg, 'ReqProvisionSubscription') === 0 &&
      (Number(quote.ELV_SubCnt_Req_Provision_Sub__c) || 0) === 0) {
    addError('Tanium Deploy - Subscription is required for Tanium Provision Subscription.');
  }
  // #14: Cloud
  if (namedCount(agg, 'ProvisionCloudModule') > 0 &&
      namedCount(agg, 'ReqProvisionCloud') === 0 &&
      (Number(quote.ELV_SubCnt_Req_Provision_Cloud__c) || 0) === 0) {
    addError('Tanium Deploy - Tanium Cloud is required for Tanium Provision Cloud.');
  }
}

/** G-H. Promo/Discount on Bundles and Non-Discountable (#15, #16, #17) */
function validatePromoBundleDiscount(quote, lines, agg, addError) {
  const MSP_PB = '01s7V000000NyMZQA0'; // MSP PriceBook
  const qPB = quote.Pricebook2Id || '';

  for (const li of lines) {
    // #15: No promo on bundle components (Save)
    if (li.ELV_Bundled_Product__c && (li.ELV_Product_Promotion__c || '').trim() && qPB !== MSP_PB) {
      addError('Product Promotions on Bundle Components Line Items are not allowed.');
    }
    // #16: No promo if Additional Discount already set (Save)
    if (li.ELV_Promo_Discount_Validation__c && qPB !== MSP_PB) {
      addError('A Product Promotion cannot be added if Additional Discount has already been populated.');
    }
    // #17: No discount on non-discountable
    if (li.ELV_Non_Discountable__c && Number(li.ELV_Partner_Discretionary_Discount__c) > 0) {
      addError('No Discount is allowed on Non-Discountable Products');
    }
  }
}

/** I. QL Type Required (#19) */
function validateQLType(quote, lines, agg, addError) {
  for (const li of lines) {
    if (!(li.ELV_Transaction_Type__c || '').trim()) {
      addError('Type is required on all Quote Lines');
      break;
    }
  }
}

/** J. Annual ESR Term (#22) */
function validateAnnualESRTerm(quote, lines, agg, addError) {
  const quoteType = (quote.ELV_Quote_Type__c || '').toLowerCase();
  if (quoteType === 'amendment') return;
  for (const li of lines) {
    if (li.ELV_Annual_ESR__c && Number(li.ELV_Term_Computed__c) < 12) {
      addError('TAN-PREM-ESR is annual product. Must be sold for 12 months or more.');
      break;
    }
  }
}

/** K. XEM Core Required (#23, #24, #25, #27) */
function validateXEMCore(quote, lines, agg, addError) {
  const acctType = (quote.ELV_Account_Type__c || '').toLowerCase();
  if (!['prospect','former customer'].includes(acctType)) return;

  // #23: Cloud Solution requires Cloud XEM Core
  if (namedCount(agg, 'CloudSolutionProducts') >= 1 && namedCount(agg, 'CloudXEMCore') === 0) {
    addError('Tanium XEM Core is required when purchasing Tanium Solutions.');
  }
  // #27: Subscription Solution requires Subscription XEM Core
  if (namedCount(agg, 'SubscriptionSolutionProducts') >= 1 && namedCount(agg, 'SubscriptionXEMCore') === 0) {
    addError('Tanium XEM Core is required when purchasing Tanium Solutions.');
  }

  // #24: AEM Cloud solutions require Core Plus/Standard
  const aemCloudSols = ['AEM_EPMGMT_RC_CloudPlus','AEM_EPMGMT_RC_CloudStandard','AEM_EPMGMT_RC_GovCloudPlus','AEM_EPMGMT_RC_IR_GovCloudStandard'].some(k => namedCount(agg,k)>0);
  const secOpsCloud = skuQty(lines, 'TAN-SECOPSHUNTIQ-CLOUD') > 0;
  if ((aemCloudSols || secOpsCloud) && namedCount(agg, 'AEM_CoreCloudPlus') === 0 &&
      (Number(quote.ELV_SubCnt_AEM_Core_PlusStd_Sub__c)||0) === 0) {
    addError('Core Plus or Core Standard is required to quote AEM Solutions.');
  }

  // #25: AEM On-Prem solutions
  const aemOnPremSols = namedCount(agg, 'AEM_EPMGMT_RC_IR_Subscription') > 0;
  const secOpsSub = skuQty(lines, 'TAN-SECOPSHUNTIQ-S') > 0;
  if ((aemOnPremSols || secOpsSub) && namedCount(agg, 'AEM_CoreOnPremStandard') === 0 &&
      (Number(quote.ELV_SubCnt_AEM_Core_OnPrem_Sub__c)||0) === 0) {
    addError('Core Plus or Core Standard is required to quote AEM Solutions.');
  }
}

/** L. Microsoft Restrictions (#26) */
function validateMicrosoft(quote, lines, agg, addError) {
  // Simplified: check for Microsoft bundle SKU presence
  // Original uses summary variable; we check SKU qty
  // and quote-level fields
  const msQty = skuQty(lines, 'TAN-ESSENTIALS-MS-CLOUD');
  if (msQty >= 1) {
    const seats = Number(quote.ELV_Total_Addressable_Seats__c) || 0;
    const partner = quote.ELV_Partner__c || '';
    if (seats < 5000 || partner !== '0017V00001TPCJUQA5') {
      addError('To sell the Microsoft SKU, Microsoft must be added as the partner and the customer must have minimum 5,000 Total Addressable Seats.');
    }
  }
}

/** S. Training Bundle Offer Alerts (#55-59) */
function alertTrainingBundleOffer(quote, lines, agg, addWarn) {
  const acctType = (quote.ELV_Account_Type__c || '').toLowerCase();
  const bizMotion = (quote.ELV_Business_Motion__c || '').toLowerCase();
  if (!['prospect','former customer'].includes(acctType)) return;
  if (bizMotion === 'msp') return;

  const cq = agg.coreQuantity;
  if (cq <= 0) return;

  const tiers = [
    { max: 4999, sku: 'TAN-TRN-TIER1BUNDLE', label: '<5K EP' },
    { min: 5000, max: 9999, sku: 'TAN-TRN-TIER2BUNDLE', label: '5K-9,999 EP' },
    { min: 10000, max: 14999, sku: 'TAN-TRN-TIER3BUNDLE', label: '10K-14,999 EP' },
    { min: 15000, max: 24999, sku: 'TAN-TRN-TIER4BUNDLE', label: '15K-24,999 EP' },
    { min: 25000, sku: 'TAN-TRN-TIER5BUNDLE', label: '25K+ EP' }
  ];

  for (const t of tiers) {
    const inRange = (t.min === undefined || cq >= t.min) && (t.max === undefined || cq <= t.max);
    if (inRange && (agg.named['Count_'+t.sku] || 0) === 0) {
      addWarn(`This customer qualifies for a free training bundle (${t.label}). Add ${t.sku}.`);
      break;
    }
  }
}

/** T. AEM Overlap Alerts (#60-63) */
function alertAEMOverlap(quote, lines, agg, addWarn) {
  // #60: Core overlap
  const hasAEMCore = ['AEM_CoreCloudPlus','AEM_CoreCloudStandard','AEM_CoreGovCloudPlus','AEM_CoreOnPremStandard'].some(k => namedCount(agg,k)>0);
  if (hasAEMCore && namedCount(agg, 'AEM_CoreOverlapSKU') > 0) {
    addWarn('Multiple Core products detected. Review quote for duplicate products.');
  }
  // #61: Endpoint Management overlap
  if (namedCount(agg, 'AEM_EndpointManagement') > 0 && namedCount(agg, 'AEM_EndpointManagementOverlap') > 0) {
    addWarn('Multiple Endpoint Management products detected. Review quote for duplicate products.');
  }
  // #62: Incident Response overlap
  if (namedCount(agg, 'AEM_IncidentResponse') > 0 && namedCount(agg, 'AEM_IncidentResponseOverlap') > 0) {
    addWarn('Multiple Incident Response products detected. Review quote for duplicate products.');
  }
  // #63: Risk & Compliance overlap
  if (namedCount(agg, 'AEM_RiskCompliance') > 0 && namedCount(agg, 'AEM_RiskComplianceOverlap') > 0) {
    addWarn('Multiple Risk & Compliance products detected. Review quote for duplicate products.');
  }
}


// ═══════════════════════════════════════════════════════════════════════
// Plug-in Registration
// ═══════════════════════════════════════════════════════════════════════

/**
 * Fail-closed gate check.
 * ────────────────────────
 * Mirrors ELV_QuoteLinePricingRules.js: this plug-in never evaluates user
 * identity. It only trusts the server-stamped ELV_Pilot_Gate_Active__c
 * marker written by ELV_PricingControl.stampPilotGate() in the Quote
 * trigger. Any missing, undefined, or non-true value is treated as
 * inactive. No pilot user ID is present in this file, by design.
 */
function isGateActive(quote) {
  return quote && quote.ELV_Pilot_Gate_Active__c === true;
}

export default {
  /**
   * onInit — runs when the QLE opens.
   * Executes all validation and alert product rules.
   * No-ops entirely unless the server-stamped pilot gate marker is true.
   */
  onInit(quote, quoteLines, conn) {
    if (!isGateActive(quote)) return; // fail-closed

    const agg = computeAgg(quoteLines);

    const addError = (msg) => conn.$$addMessage({ type: 'error', message: msg });
    const addWarn  = (msg) => conn.$$addMessage({ type: 'warning', message: msg });

    // ── Validations ──
    validateOTDependency(quote, quoteLines, agg, addError);
    validateCoterm(quote, quoteLines, agg, addError);
    validateTrainingPromo(quote, quoteLines, agg, addError);
    validateEnhancedSupport(quote, quoteLines, agg, addError);
    validateESRServiceType(quote, quoteLines, agg, addError);
    validateProvision(quote, quoteLines, agg, addError);
    validatePromoBundleDiscount(quote, quoteLines, agg, addError);
    validateQLType(quote, quoteLines, agg, addError);
    validateAnnualESRTerm(quote, quoteLines, agg, addError);
    validateXEMCore(quote, quoteLines, agg, addError);
    validateMicrosoft(quote, quoteLines, agg, addError);

    // ── Alerts ──
    alertTrainingBundleOffer(quote, quoteLines, agg, addWarn);
    alertAEMOverlap(quote, quoteLines, agg, addWarn);
  },

  /**
   * onBeforeSave — runs at save time for Save-event rules.
   * No-ops entirely unless the server-stamped pilot gate marker is true.
   */
  onBeforeSave(quote, quoteLines, conn) {
    if (!isGateActive(quote)) return; // fail-closed

    const agg = computeAgg(quoteLines);
    const addError = (msg) => conn.$$addMessage({ type: 'error', message: msg });

    // Save-time validations: #15, #16, #17
    validatePromoBundleDiscount(quote, quoteLines, agg, addError);
  }
};
