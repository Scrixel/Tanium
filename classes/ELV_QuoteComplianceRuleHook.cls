/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: The Apex-rule hook called before Submit for Approval. Keeps compliance-rule
 *            composition separate from ELV_QuoteMessageService's persistence concerns.
 */
public with sharing class ELV_QuoteComplianceRuleHook {
	/**
	 * Evaluates the Apex-authored rules and replaces only ELV_APEX_ messages.
	 *
	 * Implemented: TNCI-100 deployment method versus the Account, TNCI-118 component
	 * co-term with Core, and TNCI-102 MSP program compliance.
	 *
	 * Still outstanding, because each needs a decision that is not in the workbook:
	 *   #26 Tanium Essentials for Microsoft restrictions.
	 *   #49 Multiple TAN-PREM-ESR-1W lines (Info-only; workbook says Review Needed).
	 */
	public static void evaluateApexRules(Set<Id> quoteIds) {
		List<ELV_QuoteMessageService.RuleMessage> outcomes =
			ELV_QuoteComplianceRules.collect(quoteIds);

		// TODO #26 - restriction set not defined.
		// TODO #49 - confirm whether an Apex half is wanted for an Info-only rule.

		ELV_QuoteMessageService.sync(quoteIds, outcomes);
	}
}