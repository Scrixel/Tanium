/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Stamps Subscription-derived rollup fields onto the standard Quote so the Nue
 *            Line Editor UI Plugin can reference them, because the plugin cannot issue SOQL.
 *
 *            Field list, aggregation, and SKU sets are transcribed from
 *            CPQ_Product_Rules_Grouped > "Quote Fields (Apex-stamped)".
 *            Callable from the Quote trigger and from a button (accepts and returns Quotes).
 *
 *            GENERATED from the workbook - if the workbook changes, regenerate rather
 *            than hand-editing the SPECS block.
 */
public with sharing class ELV_QuoteRollupHelper {
	private enum Aggregation {
		SUM,
		MAX
	}

	/** "Active" is the confirmed Ruby__Status__c value for a live subscription. */
	@TestVisible
	private static final String STATUS_ACTIVE = 'Active';

	/** One stamped Quote field and the Subscription population that feeds it. */
	@TestVisible
	private class Spec {
		public String targetField;
		public Aggregation agg;
		public Set<String> skus;
		public String flagField;

		public Spec(String targetField, Aggregation agg, Set<String> skus) {
			this.targetField = targetField;
			this.agg = agg;
			this.skus = skus;
		}

		public Spec(String targetField, Aggregation agg, String flagField) {
			this.targetField = targetField;
			this.agg = agg;
			this.flagField = flagField;
		}

		public Boolean matches(Ruby__Subscription__c s) {
			if (flagField != null) {
				return s.get(flagField) == true;
			}
			return skus != null && skus.contains(s.Ruby__TodaysSKU__c);
		}
	}

	@TestVisible
	private static final List<Spec> SPECS = new List<Spec>();

	static {
		SPECS.add(new Spec('ELV_SubCount_AEM_Core_OnPrem_Sub__c', Aggregation.SUM, new Set<String>{ 'ELV-TAN-CORE-PLUS-S', 'ELV-TAN-CORE-STND-S' }));
		SPECS.add(new Spec('ELV_SubCount_AEM_Core_Plus_Std_Sub__c', Aggregation.SUM, new Set<String>{ 'ELV-TAN-CORE-PLUS-CLOUD', 'ELV-TAN-CORE-STND-CLOUD', 'ELV-TAN-CORE-PLUS-CLOUDGOV-US', 'ELV-TAN-CORE-STND-CLOUDGOV-US' }));
		SPECS.add(new Spec('ELV_SubMaxEndDate_CoreOT_Cloud__c', Aggregation.MAX, new Set<String>{ 'ELV-TAN-CORE-OT-CLOUD' }));
		SPECS.add(new Spec('ELV_SubCount_Req_for_Prov_Cloud__c', Aggregation.SUM, 'ELV_Required_for_Provision_Cloud__c'));
		SPECS.add(new Spec('ELV_SubCount_Req_for_Prov_Gov_Cloud__c', Aggregation.SUM, 'ELV_Required_for_Provision_Gov_Cloud__c'));
		SPECS.add(new Spec('ELV_SubCount_Req_for_Prov_Sub__c', Aggregation.SUM, 'ELV_Required_for_Provision_Subscription__c'));
		SPECS.add(new Spec('ELV_SubCount_TAN_CORE_OT_CLOUD__c', Aggregation.SUM, new Set<String>{ 'ELV-TAN-CORE-OT-CLOUD' }));
		SPECS.add(new Spec('ELV_SubMaxEndDate_TAN_SUPP_EXTENDED24x7__c', Aggregation.MAX, new Set<String>{ 'ELV-TAN-SUPP-EXTENDED24x7' }));
		SPECS.add(new Spec('ELV_SubMaxEndDate_Tanium_Threat_Response__c', Aggregation.MAX, new Set<String>{ 'ELV-TAN-TR-TAAS', 'ELV-TAN-IRESP-S', 'ELV-TAN-TR-CLOUDGOV-US', 'ELV-TAN-TR-S', 'ELV-TAN-ENT-CLOUD', 'ELV-TAN-IR-X-S', 'ELV-TAN-IR-X-TAAS', 'ELV-TAN-IRESP-CLOUDGOV-US', 'ELV-TAN-IRESP-CLOUD' }));
		SPECS.add(new Spec('ELV_SubCount_Tanium_Threat_Response__c', Aggregation.SUM, new Set<String>{ 'ELV-TAN-TR-TAAS', 'ELV-TAN-IRESP-S', 'ELV-TAN-TR-CLOUDGOV-US', 'ELV-TAN-TR-S', 'ELV-TAN-ENT-CLOUD', 'ELV-TAN-IR-X-S', 'ELV-TAN-IR-X-TAAS', 'ELV-TAN-IRESP-CLOUDGOV-US', 'ELV-TAN-IRESP-CLOUD' }));
	}

	/**
	 * Stamps every rollup field in memory. Performs no DML, so it is safe in before-insert.
	 */
	public static List<Quote> stampSubscriptionRollups(List<Quote> quotes) {
		if (quotes == null || quotes.isEmpty()) {
			return quotes;
		}

		Set<Id> accountIds = new Set<Id>();
		for (Quote q : quotes) {
			if (q.AccountId != null) {
				accountIds.add(q.AccountId);
			}
		}

		// accountId -> targetField -> aggregated value
		Map<Id, Map<String, Object>> byAccount = aggregate(accountIds);

		for (Quote q : quotes) {
			Map<String, Object> vals = (q.AccountId == null) ? null : byAccount.get(q.AccountId);

			for (Spec sp : SPECS) {
				Object v = (vals == null) ? null : vals.get(sp.targetField);

				if (sp.agg == Aggregation.SUM) {
					q.put(sp.targetField, (v == null) ? 0 : (Decimal) v);
				} else {
					q.put(sp.targetField, (Date) v);
				}
			}
		}

		return quotes;
	}

	/**
	 * Re-stamps and persists. Used by the Submit for Approval controller, where the
	 * refreshed values must survive the transaction.
	 */
	public static List<Quote> refreshAndSave(Set<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return new List<Quote>();
		}

		List<String> fields = new List<String>{ 'Id', 'AccountId' };
		for (Spec sp : SPECS) {
			fields.add(sp.targetField);
		}

		String soql =
			'SELECT ' + String.join(fields, ', ') + ' FROM Quote WHERE Id IN :quoteIds';

		List<Quote> quotes = (List<Quote>) Database.query(soql);

		stampSubscriptionRollups(quotes);

		// Update a SPARSE copy carrying only Id and the stamped fields.
		//
		// Updating the fully queried record fails with "Operation failed due to fields
		// being inaccessible on Sobject Quote" - the Nue managed trigger validates access
		// across every populated field, and Quote carries managed and formula fields the
		// running user cannot write. Sending only what we changed avoids that entirely,
		// keeps the DML payload minimal, and removes any risk of clobbering a concurrent
		// edit to a field this class does not own.
		List<Quote> toUpdate = new List<Quote>();
		for (Quote q : quotes) {
			Quote sparse = new Quote(Id = q.Id);

			for (Spec sp : SPECS) {
				sparse.put(sp.targetField, q.get(sp.targetField));
			}

			toUpdate.add(sparse);
		}

		if (!toUpdate.isEmpty()) {
			update toUpdate;
		}

		return quotes;
	}

	/**
	 * Single query across every SKU and flag any spec cares about, aggregated in memory.
	 * One query regardless of how many specs exist, so adding workbook rows costs no SOQL.
	 */
	@TestVisible
	private static Map<Id, Map<String, Object>> aggregate(Set<Id> accountIds) {
		Map<Id, Map<String, Object>> byAccount = new Map<Id, Map<String, Object>>();

		if (accountIds == null || accountIds.isEmpty()) {
			return byAccount;
		}

		for (Ruby__Subscription__c s : [
			SELECT
				Ruby__Customer__c,
				Ruby__TodaysSKU__c,
				Ruby__Quantity__c,
				Ruby__SubscriptionEndDate__c,
				ELV_Required_for_Provision_Cloud__c,
				ELV_Required_for_Provision_Gov_Cloud__c,
				ELV_Required_for_Provision_Subscription__c
			FROM Ruby__Subscription__c
			WHERE Ruby__Customer__c IN :accountIds AND Ruby__Status__c = :STATUS_ACTIVE
		]) {
			if (!byAccount.containsKey(s.Ruby__Customer__c)) {
				byAccount.put(s.Ruby__Customer__c, new Map<String, Object>());
			}
			Map<String, Object> vals = byAccount.get(s.Ruby__Customer__c);

			for (Spec sp : SPECS) {
				if (!sp.matches(s)) {
					continue;
				}

				if (sp.agg == Aggregation.SUM) {
					Decimal running = (Decimal) vals.get(sp.targetField);
					Decimal qty = (s.Ruby__Quantity__c == null) ? 0 : s.Ruby__Quantity__c;
					vals.put(sp.targetField, ((running == null) ? 0 : running) + qty);
				} else {
					Date running = (Date) vals.get(sp.targetField);
					Date d = s.Ruby__SubscriptionEndDate__c;

					if (d != null && (running == null || d > running)) {
						vals.put(sp.targetField, d);
					}
				}
			}
		}

		return byAccount;
	}
}