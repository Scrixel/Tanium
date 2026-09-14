/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Reads, and where necessary authors, the Nue message records that gate
 *            Submit for Approval.
 *
 *            Division of labour, per CPQ_Product_Rules_Grouped_V7 "Action" column:
 *              - 33 rules are "UI Plugin Validation"          -> plugin only, not here
 *              -  2 rules are "UI Plugin Validation and Apex" -> #26 and #49, authored here
 *              - the rest are Nue bundles or dropped
 *
 *            Three further rules are authored in Apex only, in ELV_QuoteComplianceRuleHook and ELV_QuoteComplianceRules,
 *            because each needs data the plugin cannot reach - the Account's deployment
 *            method and the Opportunity account's Type: TNCI-100, TNCI-118 and TNCI-102.
 *
 *            Ownership rule: every message this class authors carries a Ruby__Field__c
 *            beginning with FIELD_PREFIX, and deletion is scoped by that prefix. That is
 *            what keeps it from ever deleting a plugin-authored or Nue-authored message.
 *            The plugin uses the ELV_UI_ prefix, so the two namespaces cannot collide.
 */
public with sharing class ELV_QuoteMessageService {
	/** Marker for messages this class owns. Plugin messages use ELV_UI_ instead. */
	public static final String FIELD_PREFIX = 'ELV_APEX_';

	public static final String LEVEL_ERROR = 'Error';
	public static final String LEVEL_WARNING = 'Warning';
	public static final String LEVEL_INFO = 'Info';

	/**
	 * Error and Warning block submission; Info does not.
	 *
	 * The workbook labels levels "Error", "Warn" and "Info", but Ruby__Level__c accepts
	 * only Error, Warning, Info - so "Warn" must be written as "Warning".
	 */
	public static List<Ruby__Message__c> getBlockingMessages(Id quoteId) {
		return [
			SELECT Id, Ruby__Level__c, Ruby__Field__c, Ruby__Message__c, Ruby__QuoteLineItem__c
			FROM Ruby__Message__c
			WHERE Ruby__Quote__c = :quoteId AND Ruby__Level__c IN (:LEVEL_ERROR, :LEVEL_WARNING)
			ORDER BY Ruby__Level__c, Ruby__Field__c
		];
	}

	/** True when the quote currently carries no blocking message. */
	public static Boolean isSubmittable(Id quoteId) {
		return getBlockingMessages(quoteId).isEmpty();
	}

	/** One rule outcome awaiting persistence. */
	public class RuleMessage {
		public Id quoteId;
		public Id quoteLineItemId;
		public String level;
		public String field;
		public String message;

		public RuleMessage(Id quoteId, String level, String field, String message) {
			this.quoteId = quoteId;
			this.level = level;
			this.field = FIELD_PREFIX + field;
			this.message = message;
		}
	}

	/**
	 * Replaces this class's messages for the supplied Quotes with the current outcome.
	 * Scoped by FIELD_PREFIX so plugin and Nue messages are untouched, and de-duplicated
	 * on Quote + Level + Field so each rule owns exactly one message.
	 */
	public static void sync(Set<Id> quoteIds, List<RuleMessage> outcomes) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		String prefixLike = FIELD_PREFIX + '%';

		List<Ruby__Message__c> mine = [
			SELECT Id
			FROM Ruby__Message__c
			WHERE Ruby__Quote__c IN :quoteIds AND Ruby__Field__c LIKE :prefixLike
		];

		if (!mine.isEmpty()) {
			delete mine;
		}

		Map<String, Ruby__Message__c> toInsert = new Map<String, Ruby__Message__c>();
		for (RuleMessage rm : (outcomes == null ? new List<RuleMessage>() : outcomes)) {
			toInsert.put(
				rm.quoteId + '|' + rm.level + '|' + rm.field,
				new Ruby__Message__c(
					Ruby__Quote__c = rm.quoteId,
					Ruby__QuoteLineItem__c = rm.quoteLineItemId,
					Ruby__Level__c = rm.level,
					Ruby__Field__c = rm.field,
					Ruby__Message__c = rm.message
				)
			);
		}

		if (!toInsert.isEmpty()) {
			insert toInsert.values();
		}
	}

	/**
	 * Backwards-compatible entry point retained for existing callers. Delegates to
	 * ELV_QuoteComplianceRuleHook so rule composition lives in one place.
	 */
	public static void evaluateApexRules(Set<Id> quoteIds) {
		ELV_QuoteComplianceRuleHook.evaluateApexRules(quoteIds);
	}
}