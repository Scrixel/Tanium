/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Utility class for the Product2 object
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12364   2026-01-23    Created the class
 * SS-12818   2026-03-18    Removed unnecessary methods and updated getProductIdToProductModuleNames
 */

public with sharing class ProductUtility {
	public static Map<Id, Set<String>> getProductIdToProductModuleNames(Set<Id> productIds) {
		Map<Id, Set<String>> productIdToProductModuleNames = new Map<Id, Set<String>>();

		for (Product_Module__c productModule : [
			SELECT Id, Product__c, Module__r.Name
			FROM Product_Module__c
			WHERE Product__c IN :productIds AND Exclude_from_quoted_module__c = FALSE
		]) {
			if (!productIdToProductModuleNames.containsKey(productModule.Product__c)) {
				productIdToProductModuleNames.put(productModule.Product__c, new Set<String>());
			}
			productIdToProductModuleNames.get(productModule.Product__c)
				.add(productModule.Module__r.Name);
		}
		return productIdToProductModuleNames;
	}
}