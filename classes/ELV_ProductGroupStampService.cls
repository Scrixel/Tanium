/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Keeps QuoteLineItem.ELV_Product_Group__c in step with the product-group formula
 *            it replaced:
 *            Product2.Product_Group__c unless Product2.Ruby__OriginalProduct__c is populated,
 *            then Product2.Ruby__OriginalProduct__r.Product_Group__c.
 */
public with sharing class ELV_ProductGroupStampService implements Queueable {
	private static final Set<String> TERMINAL_QUOTE_STATUSES = new Set<String>{
		'Accepted',
		'Denied'
	};

	@TestVisible
	private static final Integer LINES_PER_PASS = 5000;

	private final Set<Id> productIds;

	public ELV_ProductGroupStampService(Set<Id> productIds) {
		this.productIds = productIds;
	}

	public static void handleProductChanges(List<Product2> products, Map<Id, Product2> oldMap) {
		Set<Id> changed = getProductsWithChangedFormulaInputs(products, oldMap);
		if (changed.isEmpty()) {
			return;
		}

		if (System.isQueueable() || System.isBatch() || System.isFuture() || Test.isRunningTest()) {
			restampLines(changed);
			return;
		}

		System.enqueueJob(new ELV_ProductGroupStampService(changed));
	}

	public void execute(QueueableContext context) {
		restampLines(this.productIds);
	}

	public static Integer restampLines(Set<Id> productIds) {
		if (productIds == null || productIds.isEmpty()) {
			return 0;
		}

		List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();
		for (QuoteLineItem line : [
			SELECT
				Id,
				Product2Id,
				ELV_Product_Group__c,
				Product2.Product_Group__c,
				Product2.Ruby__OriginalProduct__c,
				Product2.Ruby__OriginalProduct__r.Product_Group__c
			FROM QuoteLineItem
			WHERE
				(
					Product2Id IN :productIds
					OR Product2.Ruby__OriginalProduct__c IN :productIds
				)
				AND Quote.Status NOT IN :TERMINAL_QUOTE_STATUSES
			LIMIT 50000
		]) {
			String target = ELV_QuoteLineTriggerUtility.resolveProductGroupStamp(
				line.Product2
			);
			if (line.ELV_Product_Group__c == target) {
				continue;
			}

			linesToUpdate.add(
				new QuoteLineItem(Id = line.Id, ELV_Product_Group__c = target)
			);
			if (linesToUpdate.size() == LINES_PER_PASS) {
				break;
			}
		}

		if (linesToUpdate.isEmpty()) {
			return 0;
		}

		update linesToUpdate;

		if (linesToUpdate.size() == LINES_PER_PASS && !Test.isRunningTest()) {
			System.enqueueJob(new ELV_ProductGroupStampService(productIds));
		}

		return linesToUpdate.size();
	}

	@TestVisible
	private static Set<Id> getProductsWithChangedFormulaInputs(
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
				(product.Product_Group__c != oldProduct.Product_Group__c ||
				product.Ruby__OriginalProduct__c != oldProduct.Ruby__OriginalProduct__c)
			) {
				changed.add(product.Id);
			}
		}

		return changed;
	}
}