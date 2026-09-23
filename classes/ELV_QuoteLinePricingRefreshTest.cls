@IsTest
private class ELV_QuoteLinePricingRefreshTest {
	@IsTest
	static void reconcilePricingRefreshRequiredClearsWhenDistributorDiscountIsNullButDiscountIsCurrent() {
		QuoteLineItem line = new QuoteLineItem(
			Ruby__LineType__c = 'LineItem',
			ELV_Customer_Discount__c = -50.4043127111376,
			ELV_PartnerDiscount__c = 60,
			ELV_DistributorDiscount__c = null,
			Ruby__Discount__c = 39.83827,
			ELV_Pricing_Refresh_Required__c = true
		);

		ELV_QuoteLineTriggerUtility.reconcilePricingRefreshRequired(
			new List<QuoteLineItem>{ line }
		);

		Assert.isFalse(line.ELV_Pricing_Refresh_Required__c);
	}

	@IsTest
	static void reconcilePricingRefreshRequiredSetsTrueWhenCompoundedDiscountIsStale() {
		QuoteLineItem line = new QuoteLineItem(
			Ruby__LineType__c = 'LineItem',
			ELV_Customer_Discount__c = -50.4043127111376,
			ELV_PartnerDiscount__c = 60,
			ELV_DistributorDiscount__c = null,
			Ruby__Discount__c = 60,
			ELV_Pricing_Refresh_Required__c = false
		);

		ELV_QuoteLineTriggerUtility.reconcilePricingRefreshRequired(
			new List<QuoteLineItem>{ line }
		);

		Assert.isTrue(line.ELV_Pricing_Refresh_Required__c);
	}

	@IsTest
	static void customCalculationClearTreatsNullDistributorDiscountAsSettledWhenDiscountIsCurrent() {
		QuoteLineItem line = new QuoteLineItem(
			ELV_Customer_Discount__c = -50.4043127111376,
			ELV_PartnerDiscount__c = 60,
			ELV_DistributorDiscount__c = null,
			Ruby__Discount__c = 39.83827
		);

		Assert.isFalse(ELV_CustomCalculationClearQueueable.isUnsettled(line));
	}

	@IsTest
	static void customCalculationClearTreatsStaleCompoundedDiscountAsUnsettled() {
		QuoteLineItem line = new QuoteLineItem(
			ELV_Customer_Discount__c = -50.4043127111376,
			ELV_PartnerDiscount__c = 60,
			ELV_DistributorDiscount__c = null,
			Ruby__Discount__c = 60
		);

		Assert.isTrue(ELV_CustomCalculationClearQueueable.isUnsettled(line));
	}
}