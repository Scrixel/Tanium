@IsTest
private class ELV_QuoteLineProductGroupStampTest {
	@IsTest
	static void stampProductGroupUsesLineProductGroupWhenOriginalProductIsBlank() {
		Product2 product = createProduct('Software', null);
		QuoteLineItem line = new QuoteLineItem(
			Product2Id = product.Id,
			ELV_Product_Group__c = 'Previous'
		);

		ELV_QuoteLineTriggerUtility.stampProductGroup(
			new List<QuoteLineItem>{ line },
			null
		);

		Assert.areEqual('Software', line.ELV_Product_Group__c);
	}

	@IsTest
	static void stampProductGroupUsesOriginalProductGroupWhenOriginalProductIsPopulated() {
		Product2 originalProduct = createProduct('ESR', null);
		Product2 configuredProduct = createProduct('Software', originalProduct.Id);
		QuoteLineItem line = new QuoteLineItem(Product2Id = configuredProduct.Id);

		ELV_QuoteLineTriggerUtility.stampProductGroup(
			new List<QuoteLineItem>{ line },
			null
		);

		Assert.areEqual('ESR', line.ELV_Product_Group__c);
	}

	@IsTest
	static void stampProductGroupClearsValueWhenProductIsBlank() {
		QuoteLineItem line = new QuoteLineItem(ELV_Product_Group__c = 'Software');

		ELV_QuoteLineTriggerUtility.stampProductGroup(
			new List<QuoteLineItem>{ line },
			null
		);

		Assert.areEqual(null, line.ELV_Product_Group__c);
	}

	@IsTest
	static void productChangeDetectionIncludesFormulaInputsOnly() {
		Product2 unchangedProduct = createProduct('Software', null);
		Product2 groupChangedProduct = createProduct('Software', null);
		Product2 originalProduct = createProduct('ESR', null);
		Product2 originalChangedProduct = createProduct('Software', null);

		Map<Id, Product2> oldMap = new Map<Id, Product2>{
			unchangedProduct.Id => unchangedProduct.clone(true, false, false, false),
			groupChangedProduct.Id => groupChangedProduct.clone(true, false, false, false),
			originalChangedProduct.Id => originalChangedProduct.clone(
				true,
				false,
				false,
				false
			)
		};

		groupChangedProduct.Product_Group__c = 'ESR';
		originalChangedProduct.Ruby__OriginalProduct__c = originalProduct.Id;

		Set<Id> changedProductIds = ELV_ProductGroupStampService.getProductsWithChangedFormulaInputs(
			new List<Product2>{
				unchangedProduct,
				groupChangedProduct,
				originalChangedProduct
			},
			oldMap
		);

		Assert.isFalse(changedProductIds.contains(unchangedProduct.Id));
		Assert.isTrue(changedProductIds.contains(groupChangedProduct.Id));
		Assert.isTrue(changedProductIds.contains(originalChangedProduct.Id));
	}

	private static Product2 createProduct(String productGroup, Id originalProductId) {
		Product2 product = new Product2(
			Name = 'Product ' + productGroup + ' ' + String.valueOf(Crypto.getRandomInteger()),
			Family = 'None',
			IsActive = true,
			Product_Group__c = productGroup,
			Ruby__OriginalProduct__c = originalProductId
		);
		insert product;
		return product;
	}
}