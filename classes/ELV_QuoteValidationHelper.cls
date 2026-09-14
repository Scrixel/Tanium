/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Evaluates the Apex-side Product & Price rules for a set of Quotes and
 *            synchronises Ruby__Message__c records. Rules evaluated inside the Nue
 *            Line Editor UI Plugin are NOT duplicated here.
 *
 *            Every message this class owns is keyed by the Ruby__Field__c value, which
 *            must start with FIELD_PREFIX so the class only ever deletes its own messages
 *            and never removes messages raised by the Nue managed package or the UI Plugin.
 */
public with sharing class ELV_QuoteValidationHelper {
	/** Marker so this class only manages the messages it owns. */
	public static final String FIELD_PREFIX = 'ELV_';

	public static final String LEVEL_ERROR = 'Error';
	public static final String LEVEL_WARNING = 'Warning';
	public static final String LEVEL_INFO = 'Info';

	/** In-memory representation of one rule outcome. */
	public class RuleMessage {
		public Id quoteId;
		public Id quoteLineItemId;
		public String level;
		public String field;
		public String message;

		public RuleMessage(Id quoteId, String level, String field, String message) {
			this.quoteId = quoteId;
			this.level = level;
			this.field = field;
			this.message = message;
		}
	}

	/**
	 * Re-evaluates all Apex-side rules for the supplied Quotes and replaces this class's
	 * Ruby__Message__c records with the current outcome.
	 */
	public static void evaluate(Set<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		List<Quote> quotes = [
			SELECT
				Id,
				AccountId,
				Status,
				ELV_Partner__c,
				ELV_Channel_Quote__c,
				ELV_Subscription_Count__c,
				ELV_Current_Seats_Purchased__c,
				ELV_SubMaxEndDate__c,
				ELV_Pricing_Discount_Justification__c,
				ELV_Pricing_Discount_Explanation__c,
				ELV_Deployment_Method__c,
				ELV_Deployment_Partner__c
			FROM Quote
			WHERE Id IN :quoteIds
		];

		List<RuleMessage> outcomes = new List<RuleMessage>();
		for (Quote q : quotes) {
			outcomes.addAll(runRules(q));
		}

		syncMessages(quoteIds, outcomes);
	}

	/**
	 * The rule registry. Add one private static method per rule from the
	 * CPQ_Product_Rules_Grouped workbook where the Action column is not
	 * "UI Plugin Validation", and call it from here.
	 */
	@TestVisible
	private static List<RuleMessage> runRules(Quote q) {
		List<RuleMessage> results = new List<RuleMessage>();

		ruleChannelQuoteRequiresPartner(q, results);
		ruleDiscountJustificationRequired(q, results);
		rulePartnerDeploymentRequiresPartner(q, results);

		return results;
	}

	/** A channel quote must name a partner before it can be approved. */
	@TestVisible
	private static void ruleChannelQuoteRequiresPartner(Quote q, List<RuleMessage> results) {
		if (q.ELV_Channel_Quote__c == true && q.ELV_Partner__c == null) {
			results.add(
				new RuleMessage(
					q.Id,
					LEVEL_ERROR,
					FIELD_PREFIX + 'Partner__c',
					'A Partner is required on a Channel Quote.'
				)
			);
		}
	}

	/** A discount justification picklist selection requires a written explanation. */
	@TestVisible
	private static void ruleDiscountJustificationRequired(Quote q, List<RuleMessage> results) {
		if (
			String.isNotBlank(q.ELV_Pricing_Discount_Justification__c) &&
			String.isBlank(q.ELV_Pricing_Discount_Explanation__c)
		) {
			results.add(
				new RuleMessage(
					q.Id,
					LEVEL_ERROR,
					FIELD_PREFIX + 'Pricing_Discount_Explanation__c',
					'Provide a pricing discount explanation to support the selected justification.'
				)
			);
		}
	}

	/** Partner-led deployment requires a deployment partner to be named. */
	@TestVisible
	private static void rulePartnerDeploymentRequiresPartner(Quote q, List<RuleMessage> results) {
		if (q.ELV_Deployment_Method__c == 'Partner' && q.ELV_Deployment_Partner__c == null) {
			results.add(
				new RuleMessage(
					q.Id,
					LEVEL_WARNING,
					FIELD_PREFIX + 'Deployment_Partner__c',
					'Deployment Method is Partner but no Deployment Partner is named.'
				)
			);
		}
	}

	/**
	 * Deletes the messages this class owns for the supplied Quotes and inserts the
	 * current outcome. Deletion is scoped by FIELD_PREFIX so Nue's own messages survive.
	 */
	@TestVisible
	private static void syncMessages(Set<Id> quoteIds, List<RuleMessage> outcomes) {
		String prefixLike = FIELD_PREFIX + '%';

		List<Ruby__Message__c> existing = [
			SELECT Id
			FROM Ruby__Message__c
			WHERE Ruby__Quote__c IN :quoteIds AND Ruby__Field__c LIKE :prefixLike
		];

		if (!existing.isEmpty()) {
			delete existing;
		}

		// De-duplicate on Quote + Level + Field so each rule owns exactly one message.
		Map<String, Ruby__Message__c> toInsert = new Map<String, Ruby__Message__c>();
		for (RuleMessage rm : outcomes) {
			String key = rm.quoteId + '|' + rm.level + '|' + rm.field;

			toInsert.put(
				key,
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
	 * Returns the blocking messages (Error and Warning) for a Quote, ignoring Info.
	 * Used by the Submit for Approval controller.
	 */
	public static List<Ruby__Message__c> getBlockingMessages(Id quoteId) {
		return [
			SELECT Id, Ruby__Level__c, Ruby__Field__c, Ruby__Message__c
			FROM Ruby__Message__c
			WHERE Ruby__Quote__c = :quoteId AND Ruby__Level__c IN (:LEVEL_ERROR, :LEVEL_WARNING)
			ORDER BY Ruby__Level__c, Ruby__Field__c
		];
	}
}