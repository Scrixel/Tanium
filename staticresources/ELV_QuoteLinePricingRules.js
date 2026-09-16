/**
 * ELV_QuoteLinePricingRules — Nue UI Pricing Plug-in
 * ═══════════════════════════════════════════════════
 * Consolidated pricing plug-in for the Nue Quote Line Editor.
 * Separate from ELV_QuoteLineRules (validation plug-in).
 *
 * This plug-in implements the 24 consolidated price-rule families that
 * run at edit time in the QLE.  It mirrors ELV_PricingLineService.cls
 * for interactive behavior; Apex owns persisted values.
 *
 * Architecture:
 *   onBeforeCalculate  → date defaults, sub term, schedule clears,
 *                         distributor discount, bundle propagation,
 *                         transaction type classification
 *   onAfterCalculate   → (reserved for post-calc adjustments)
 *
 * Plug-in Variables:
 *   All 78 variables from the Product Rules workbook are computed
 *   client-side over $$quoteLines for validation use.
 *
 * FIELD MAPPING (SBQQ → Nue Standard):
 *   SBQQ__StartDate__c        → ServiceDate / ELV_Start_Date__c
 *   SBQQ__EndDate__c          → ELV_End_Date__c
 *   SBQQ__SubscriptionTerm__c → Ruby__ActualSubscriptionTerm__c
 *   SBQQ__ProductCode__c      → Product2.ProductCode / ELV_Product_Code__c
 *   SBQQ__Type__c             → ELV_Quote_Type__c
 *   SBQQ__Discount__c         → Discount
 *   SBQQ__DistributorDiscount__c → ELV_Distributor_Discount__c
 *   (etc. — see ELV_PricingLineService.cls header for full map)
 */

// ═══════════════════════════════════════════════════════════════════════
// Helper: compute line aggregates (mirrors ELV_LineCountService)
// ═══════════════════════════════════════════════════════════════════════
function computeLineAggregates(quoteLines) {
  const agg = {
    skuQty: {},
    skuMaxEnd: {},
    coreQuantity: 0,
    onPremCount: 0,
    cloudCount: 0,
    cloudGovCount: 0,
    named: {}
  };

  for (const li of quoteLines) {
    const sku = (li.ELV_Product_Code__c || li.ProductCode || '').toUpperCase();
    const qty = Number(li.Quantity) || 0;
    const productLine = li.ELV_Product_Line__c || '';
    const productGroup = li.ELV_Product_Group__c || '';
    const deployMethod = li.ELV_Deployment_Method__c || '';

    // SKU quantity totals
    agg.skuQty[sku] = (agg.skuQty[sku] || 0) + qty;

    // SKU max end dates
    const endDate = li.ELV_End_Date__c || li.ServiceDate;
    if (endDate) {
      if (!agg.skuMaxEnd[sku] || endDate > agg.skuMaxEnd[sku]) {
        agg.skuMaxEnd[sku] = endDate;
      }
    }

    // Core Quantity
    if (productGroup.toLowerCase() === 'software' &&
        productLine.toLowerCase().includes('core')) {
      agg.coreQuantity += qty;
    }

    // Deployment counts
    if (deployMethod) {
      const dm = deployMethod.toLowerCase();
      if (dm.includes('gov cloud') || dm.includes('govcloud')) {
        agg.cloudGovCount += qty;
      } else if (dm.includes('cloud')) {
        agg.cloudCount += qty;
      } else if (dm.includes('on-prem') || dm.includes('on-premise')) {
        agg.onPremCount += qty;
      }
    }

    // Training promo count
    const promoName = li.ELV_Product_Promotion_Name__c || '';
    if (promoName.trim()) {
      agg.named.TrainingPromoLineCount = (agg.named.TrainingPromoLineCount || 0) + 1;
    }

    // Training bundle quantity limit
    const isBundle = li.ELV_Is_Bundle__c;
    if (isBundle && productLine.toLowerCase() === 'training' && promoName.trim()) {
      agg.named.TrainingBundleQuantityLimit = (agg.named.TrainingBundleQuantityLimit || 0) + qty;
    }

    // Training bundle tier counts
    const TIER_SKUS = [
      'TAN-TRN-TIER1BUNDLE', 'TAN-TRN-TIER2BUNDLE', 'TAN-TRN-TIER3BUNDLE',
      'TAN-TRN-TIER4BUNDLE', 'TAN-TRN-TIER5BUNDLE'
    ];
    for (const ts of TIER_SKUS) {
      if (sku === ts.toUpperCase()) {
        agg.named['Count_' + ts] = (agg.named['Count_' + ts] || 0) + 1;
      }
    }

    // XEM Core / Solution product counts
    if (li.ELV_Is_XEM_Core__c) {
      const key = deployMethod.toLowerCase().includes('cloud') ? 'CloudXEMCore' : 'SubscriptionXEMCore';
      agg.named[key] = (agg.named[key] || 0) + qty;
    }
    if (li.ELV_Is_Solution_Product__c) {
      const key = deployMethod.toLowerCase().includes('cloud') ? 'CloudSolutionProducts' : 'SubscriptionSolutionProducts';
      agg.named[key] = (agg.named[key] || 0) + qty;
    }

    // Provision module counts
    if (li.ELV_Is_Provision_Module__c) {
      if (deployMethod.toLowerCase().includes('gov cloud')) {
        agg.named.ProvisionCloudGovModule = (agg.named.ProvisionCloudGovModule || 0) + qty;
      } else if (deployMethod.toLowerCase().includes('cloud')) {
        agg.named.ProvisionCloudModule = (agg.named.ProvisionCloudModule || 0) + qty;
      } else {
        agg.named.ProvisionSubscriptionModule = (agg.named.ProvisionSubscriptionModule || 0) + qty;
      }
    }

    // Required-for-provision counts
    if (li.ELV_Required_for_Provision_Cloud__c) {
      agg.named.ReqProvisionCloud = (agg.named.ReqProvisionCloud || 0) + qty;
    }
    if (li.ELV_Required_for_Provision_Gov_Cloud__c) {
      agg.named.ReqProvisionGovCloud = (agg.named.ReqProvisionGovCloud || 0) + qty;
    }
    if (li.ELV_Required_for_Provision_Subscription__c) {
      agg.named.ReqProvisionSubscription = (agg.named.ReqProvisionSubscription || 0) + qty;
    }

    // Threat Response required
    if (li.ELV_Threat_Response_Required__c) {
      agg.named.ThreatResponseRequired = (agg.named.ThreatResponseRequired || 0) + qty;
    }

    // AEM solution family counts
    const aemFamily = li.ELV_AEM_Solution_Family__c;
    if (aemFamily) {
      agg.named['AEM_' + aemFamily] = (agg.named['AEM_' + aemFamily] || 0) + qty;
    }
  }

  return agg;
}

function getSkuQty(agg, sku) {
  return agg.skuQty[(sku || '').toUpperCase()] || 0;
}
function getNamed(agg, name) {
  return agg.named[name] || 0;
}

// ═══════════════════════════════════════════════════════════════════════
// Price Rule Families — onBeforeCalculate
// ═══════════════════════════════════════════════════════════════════════

/**
 * Family: Date Defaults (Rules #2, #4)
 */
function applyDateDefaults(line, quote) {
  // Rule #4: Start Date
  if (!line.ServiceDate && quote.ELV_Start_Date__c) {
    line.ServiceDate = quote.ELV_Start_Date__c;
  }
  // Rule #2: End Date
  if (!line.ELV_End_Date__c && quote.ELV_End_Date__c) {
    line.ELV_End_Date__c = quote.ELV_End_Date__c;
  }
}

/**
 * Family: Subscription Term Defaults (Rules #5, #6, #7)
 */
function applySubscriptionTerm(line, quote) {
  const sku = (line.ELV_Product_Code__c || '').toUpperCase();
  const productLine = (line.ELV_Product_Line__c || '').toLowerCase();
  const qlTerm = line.Ruby__ActualSubscriptionTerm__c;
  const qTerm = quote.Ruby__ActualSubscriptionTerm__c;

  // Rule #5: Deployment SKU → 12
  if (sku === 'TAN-ESR-DEPLMT-EE') {
    line.Ruby__ActualSubscriptionTerm__c = 12;
    return;
  }

  // Rule #6: Training → 12
  if (!qlTerm && productLine === 'training' && qTerm) {
    line.Ruby__ActualSubscriptionTerm__c = 12;
    return;
  }

  // Rule #7: General default from quote
  if (!qlTerm && qTerm && productLine !== 'training') {
    if (sku === 'TAN-PREM-ESR-1D/W') {
      line.Ruby__ActualSubscriptionTerm__c = 2;
    } else {
      line.Ruby__ActualSubscriptionTerm__c = qTerm;
    }
  }
}

/**
 * Family: Schedule Clears (Rules #17, #41)
 */
function applyScheduleClears(line, quote) {
  const volOff = quote.ELV_Apply_Volume_Discount__c === false;
  const termOff = quote.ELV_Apply_Term_Discount__c === false;

  if (volOff && termOff) {
    line.ELV_Term_Discount_Schedule__c = null;
    line.ELV_Term_Discount_Tier__c = null;
  }
  if (volOff) {
    line.ELV_Discount_Schedule__c = null;
    line.ELV_Discount_Tier__c = null;
  }
}

/**
 * Family: Distributor Discount (Rules #18, #39, #69, #72)
 */
function applyDistributorDiscount(line, quote) {
  const pg = (line.ELV_Product_Group__c || '').toLowerCase();
  if (pg !== 'software') return;

  const marketplace = quote.ELV_Marketplace_Partner__c === true;
  const eligible = quote.ELV_Eligible_for_Distributor_Discount__c === true;
  const quoteType = (quote.ELV_Quote_Type__c || '').toLowerCase();

  if (marketplace) {
    line.ELV_Distributor_Discount__c = quote.ELV_Disti_Discount_Percent_Marketplace__c;
    line.ELV_Distribution_Involvement_Discount__c = true;
  } else if (eligible) {
    line.ELV_Distributor_Discount__c = quoteType === 'renewal'
      ? quote.ELV_Disti_Renewal_Discount_Percent__c
      : quote.ELV_Disti_Discount_Percent__c;
    line.ELV_Distribution_Involvement_Discount__c = true;
  } else {
    line.ELV_Distributor_Discount__c = null;
    line.ELV_Distribution_Involvement_Discount__c = false;
  }
}

/**
 * Family: Bundle Propagation (Rules #65, #68, #85)
 */
function applyBundlePropagation(line, quote, parentLine) {
  if (!parentLine) return;

  const isBundled = line.ELV_Bundled_Product__c === true;
  const isBundle = line.ELV_Is_Bundle__c === true;

  // Rule #65: Component propagation
  if (isBundled) {
    const COPY_FIELDS = [
      'ELV_Standard_Partner_Discount__c',
      'ELV_Distribution_Involvement_Discount__c',
      'ELV_Advantage_Plus_Partner_Discount__c',
      'ELV_Partner_Discretionary_Discount__c',
      'ELV_Opportunity_Registration_Discount__c',
      'ELV_Partner_Discount__c',
      'Ruby__ActualSubscriptionTerm__c'
    ];
    for (const f of COPY_FIELDS) {
      line[f] = parentLine[f];
    }
    line.ELV_Hidden__c = true;
    line.ELV_Show_on_Invoice__c = false;
    line.ServiceDate = parentLine.ServiceDate;
    line.ELV_End_Date__c = parentLine.ELV_End_Date__c;
    line.ELV_Transaction_Type__c = parentLine.ELV_Transaction_Type__c;
  }

  // Rules #68, #85: Bundle parent gets discount from parent
  if (isBundle) {
    line.Ruby__DiscountAmount__c = parentLine.Ruby__DiscountAmount__c;
    line.Discount = parentLine.Discount;
  }
}

/**
 * Family: Transaction Type Classification (Rules #104, #106, #107, #109)
 */
function applyTransactionType(line, quote) {
  const oppType = (quote.ELV_Opportunity_Type__c || '').toLowerCase();
  const quoteType = (quote.ELV_Quote_Type__c || '').toLowerCase();

  if (oppType === 'renewal' && line.Ruby__ChangeReferenceQuoteLineItem__c) {
    line.ELV_Transaction_Type__c = 'Renewal';
    return;
  }
  if (oppType === 'new customer' || oppType === 'new msp end user') {
    line.ELV_Transaction_Type__c = 'New Customer';
    return;
  }
  if (quoteType === 'amendment' && line.ELV_Upgraded_Subscription__c) {
    line.ELV_Transaction_Type__c = 'Add-on';
    return;
  }
  if (quoteType === 'amendment' && !line.ELV_Upgraded_Subscription__c) {
    line.ELV_Transaction_Type__c = 'Upsell';
    return;
  }
}


// ═══════════════════════════════════════════════════════════════════════
// Plug-in Registration
// ═══════════════════════════════════════════════════════════════════════

/**
 * Fail-closed gate check.
 * ────────────────────────
 * The plug-in NEVER evaluates user identity — it only trusts the
 * server-stamped ELV_Pilot_Gate_Active__c marker written by
 * ELV_PricingControl.stampPilotGate() in the Quote trigger. Any
 * missing, undefined, or non-true value is treated as inactive.
 * No pilot user ID is present in this file, by design.
 */
function isGateActive(quote) {
  return quote && quote.ELV_Pilot_Gate_Active__c === true;
}

export default {
  /**
   * onBeforeCalculate — runs before Nue pricing calculation.
   * Applies all consolidated price-rule families.
   * No-ops entirely unless the server-stamped pilot gate marker is true.
   *
   * @param {Object} quote - The current quote record
   * @param {Array} quoteLines - All quote line items
   * @param {Object} conn - Nue connection object ($$addMessage, etc.)
   */
  onBeforeCalculate(quote, quoteLines, conn) {
    if (!isGateActive(quote)) return; // fail-closed

    // Build parent-line lookup for bundle propagation
    const parentMap = {};
    for (const li of quoteLines) {
      if (li.Id) parentMap[li.Id] = li;
    }

    for (const line of quoteLines) {
      const parentLine = line.ELV_Required_By__c
        ? parentMap[line.ELV_Required_By__c]
        : null;

      applyDateDefaults(line, quote);
      applySubscriptionTerm(line, quote);
      applyScheduleClears(line, quote);
      applyDistributorDiscount(line, quote);
      applyBundlePropagation(line, quote, parentLine);
      applyTransactionType(line, quote);
    }
  },

  /**
   * onAfterCalculate — runs after Nue pricing calculation.
   * Reserved for post-calc adjustments (currently no-op).
   * Also fail-closed on the pilot gate marker, for when logic is added here.
   */
  onAfterCalculate(quote, quoteLines, conn) {
    if (!isGateActive(quote)) return; // fail-closed
    // Reserved for future post-calculation adjustments
  }
};
