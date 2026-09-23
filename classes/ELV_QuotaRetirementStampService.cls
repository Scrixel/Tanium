/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036. Maintains QuoteLineItem.ELV_Quota_Retirement_ARR_EDW__c,
 *            the stored copy of the ELV_Quota_Retirement_ARR__c line formula.
 *
 *            The copy exists because the formula is not roll-up eligible: it depends on
 *            ELV_Start_Date_in_Opp_Fiscal_Year__c, which reaches through
 *            Quote.Opportunity.CloseDate. CPQ solved the same problem the same way, copying
 *            Quota_Retirement_ARR__c into Quota_Retirement_ARR_EDW__c through the Quote Line
 *            after-insert flow and rolling up the copy.
 *
 *            Stamping happens after save because a cross-object formula is not resolved on an
 *            in-memory record. The recursion guard stops the resulting line update from
 *            re-entering the trigger, and a line already carrying the right value costs no DML.
 */
public with sharing class ELV_QuotaRetirementStampService {
	@TestVisible
	private static Boolean isStamping = false;

	public static void stampLines(Set<Id> lineIds) {
		if (isStamping || lineIds == null || lineIds.isEmpty()) {
			return;
		}

		List<QuoteLineItem> linesToUpdate = buildUpdates(
			[
				SELECT Id, ELV_Quota_Retirement_ARR__c, ELV_Quota_Retirement_ARR_EDW__c
				FROM QuoteLineItem
				WHERE Id IN :lineIds
			]
		);

		if (linesToUpdate.isEmpty()) {
			return;
		}

		isStamping = true;
		try {
			update linesToUpdate;
		} finally {
			isStamping = false;
		}
	}

	/** Returns only the lines whose stored copy has drifted from the formula. */
	@TestVisible
	private static List<QuoteLineItem> buildUpdates(List<QuoteLineItem> lines) {
		List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();

		for (QuoteLineItem line : lines) {
			Decimal target = line.ELV_Quota_Retirement_ARR__c == null
				? 0
				: line.ELV_Quota_Retirement_ARR__c;

			if (
				line.ELV_Quota_Retirement_ARR_EDW__c != null &&
				line.ELV_Quota_Retirement_ARR_EDW__c == target
			) {
				continue;
			}

			linesToUpdate.add(
				new QuoteLineItem(Id = line.Id, ELV_Quota_Retirement_ARR_EDW__c = target)
			);
		}

		return linesToUpdate;
	}
}