/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036. Keeps QuoteLineItem.ELV_Product_Exclude_from_ARR__c in
 *            step with Product2.Exclude_from_ARR__c.
 *
 *            The line stamp is written in the quote line before-contexts, so it is correct at
 *            the moment the line is saved. Flipping the flag on the product afterwards touches
 *            no quote line, and the stamps would go stale silently - which is exactly the
 *            failure mode the Day 1 stamp already demonstrated. This closes it.
 *
 *            One product can reach many thousands of lines, so the work is handed to a
 *            queueable unless the transaction is already asynchronous.
 *
 *            Scope is deliberately narrow: quotes in a terminal status are left alone, because
 *            reclassifying a product should not retroactively move ARR on a quote the customer
 *            has already accepted or rejected. Whether a presented quote should be re-stamped
 *            is a business decision, not a code one.
 */
public with sharing class ELV_ProductARRStampService implements Queueable {
	/** Quotes past the point where ARR may still legitimately move. */
	private static final Set<String> TERMINAL_QUOTE_STATUSES = new Set<String>{
		'Accepted',
		'Denied'
	};

	/** Above this many lines in one pass the work is chained rather than finished inline. */
	@TestVisible
	private static final Integer LINES_PER_PASS = 5000;

	private final Set<Id> productIds;

	public ELV_ProductARRStampService(Set<Id> productIds) {
		this.productIds = productIds;
	}

	/** Trigger entry point. After update on Product2. */
	public static void handleProductChanges(List<Product2> products, Map<Id, Product2> oldMap) {
		Set<Id> changed = getProductsWithChangedExclusion(products, oldMap);
		if (changed.isEmpty()) {
			return;
		}

		// Already async, or in a context where enqueueing is not allowed: do the work here.
		if (System.isQueueable() || System.isBatch() || System.isFuture() || Test.isRunningTest()) {
			restampLines(changed);
			return;
		}

		System.enqueueJob(new ELV_ProductARRStampService(changed));
	}

	public void execute(QueueableContext context) {
		restampLines(this.productIds);
	}

	/**
	 * Re-stamps every open quote line whose stored flag disagrees with its product. The
	 * comparison is done in SOQL, so a no-op change costs one query and no DML.
	 */
	public static Integer restampLines(Set<Id> productIds) {
		if (productIds == null || productIds.isEmpty()) {
			return 0;
		}

		Map<Id, Boolean> excludeByProductId = new Map<Id, Boolean>();
		for (Product2 product : [
			SELECT Id, Exclude_from_ARR__c
			FROM Product2
			WHERE Id IN :productIds
		]) {
			excludeByProductId.put(product.Id, product.Exclude_from_ARR__c == true);
		}

		List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();
		for (QuoteLineItem line : [
			SELECT Id, Product2Id, ELV_Product_Exclude_from_ARR__c
			FROM QuoteLineItem
			WHERE
				Product2Id IN :productIds
				AND Quote.Status NOT IN :TERMINAL_QUOTE_STATUSES
			LIMIT 50000
		]) {
			Boolean target = excludeByProductId.get(line.Product2Id) == true;
			if (line.ELV_Product_Exclude_from_ARR__c == target) {
				continue;
			}

			linesToUpdate.add(
				new QuoteLineItem(Id = line.Id, ELV_Product_Exclude_from_ARR__c = target)
			);
			if (linesToUpdate.size() == LINES_PER_PASS) {
				break;
			}
		}

		if (linesToUpdate.isEmpty()) {
			return 0;
		}

		update linesToUpdate;

		// A full pass means there may be more behind it; chain rather than raise the limit.
		if (linesToUpdate.size() == LINES_PER_PASS && !Test.isRunningTest()) {
			System.enqueueJob(new ELV_ProductARRStampService(productIds));
		}

		return linesToUpdate.size();
	}

	@TestVisible
	private static Set<Id> getProductsWithChangedExclusion(
		List<Product2> products,
		Map<Id, Product2> oldMap
	) {
		Set<Id> changed = new Set<Id>();
		if (products == null || products.isEmpty()) {
			return changed;
		}

		for (Product2 product : products) {
			Product2 oldProduct = oldMap == null ? null : oldMap.get(product.Id);
			if (
				oldProduct != null &&
				product.Exclude_from_ARR__c != oldProduct.Exclude_from_ARR__c
			) {
				changed.add(product.Id);
			}
		}

		return changed;
	}
}