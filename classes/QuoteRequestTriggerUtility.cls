/**
 * @Business: Utility class to support QuoteRequest_Event platform event functionality
 * @Date: 2025-07-24
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11140   2025-07-24    Created the Utility class
 * SS-12876   2026-04-01    Added method processQuoteRequestProducts, removed method updateQuoteRequest
 */
public with sharing class QuoteRequestTriggerUtility {
	public static void processQuoteRequestEvent(List<QuoteRequest_Event__e> quoteRequestEvents) {
		List<QuoteRequest_Event__e> insertQuoteRequestEvents = new List<QuoteRequest_Event__e>();

		for (QuoteRequest_Event__e quoteRequestEvent : quoteRequestEvents) {
			if (quoteRequestEvent.DML_Operation__c == 'INSERT') {
				insertQuoteRequestEvents.add(quoteRequestEvent);
			}
		}

		if (!insertQuoteRequestEvents.isEmpty()) {
			insertQuoteRequest(insertQuoteRequestEvents);
		}
	}

	public static void insertQuoteRequest(List<QuoteRequest_Event__e> quoteRequestEvents) {
		List<Quote_Request__c> quoteRequests = new List<Quote_Request__c>();
		Quote_Request__c quoteRequest;

		for (QuoteRequest_Event__e quoteRequestEvent : quoteRequestEvents) {
			quoteRequest = new Quote_Request__c();
			quoteRequest.Additional_Comments__c = quoteRequestEvent.AdditionalComments__c;
			quoteRequest.Bill_To_Attn__c = quoteRequestEvent.BillingAttention__c;
			quoteRequest.BillingCity__c = quoteRequestEvent.BillingCity__c;
			quoteRequest.BillingCountry__c = quoteRequestEvent.BillingCountry__c;
			quoteRequest.BillingPostalCode__c = quoteRequestEvent.BillingZipCode__c;
			quoteRequest.BillingState__c = quoteRequestEvent.BillingProvince__c;
			quoteRequest.BillingStreet__c = quoteRequestEvent.BillingStreet__c;
			quoteRequest.Deal_Registration__c = quoteRequestEvent.DealRegId__c;
			quoteRequest.Deployment_Provider__c = quoteRequestEvent.DeploymentProviderId__c;
			quoteRequest.Deployment_Type__c = quoteRequestEvent.DeploymentType__c;
			quoteRequest.Distributor_Email__c = quoteRequestEvent.DistributorEmail__c;
			quoteRequest.Downstream_Partner__c = quoteRequestEvent.DownstreamPartnerId__c;
			quoteRequest.Multi_Tier_Transaction__c = quoteRequestEvent.MultiTierTransaction__c;
			quoteRequest.Number_of_Endpoints__c = quoteRequestEvent.NumberofEndpoints__c;
			quoteRequest.Partner_Email__c = quoteRequestEvent.PartnerContactEmail__c;
			quoteRequest.Partner__c = quoteRequestEvent.PartnerId__c;
			quoteRequest.Ship_To_Attn__c = quoteRequestEvent.ShippingAttention__c;
			quoteRequest.ShippingCity__c = quoteRequestEvent.ShippingCity__c;
			quoteRequest.ShippingCountry__c = quoteRequestEvent.ShippingCountry__c;
			quoteRequest.ShippingPostalCode__c = quoteRequestEvent.ShippingZipCode__c;
			quoteRequest.ShippingState__c = quoteRequestEvent.ShippingProvince__c;
			quoteRequest.ShippingStreet__c = quoteRequestEvent.ShippingStreet__c;
			quoteRequest.Solutions_Selected__c = quoteRequestEvent.SolutionsSelected__c;
			quoteRequest.Submitter_Role__c = quoteRequestEvent.SubmitterRole__c;
			quoteRequest.Subscription_Term__c = quoteRequestEvent.SubscriptionTerm__c;
			quoteRequest.Support_Provider__c = quoteRequestEvent.SupportProviderId__c;
			quoteRequest.Tanium_Sales_Rep__c = quoteRequestEvent.DealRegOwnerId__c;
			quoteRequests.add(quoteRequest);
		}

		try {
			insert quoteRequests;
		} catch (Exception e) {
			Logger.Error('QuoteRequestTriggerUtility.insertQuoteRequest ERRORS', e);
			Logger.saveLog();
		}
	}

	public static void processQuoteRequestProductEvent(
		List<QuoteRequest_Product_Event__e> quoteRequestProductEvents
	) {
		List<Quote_Request_Products__c> quoteRequestProducts = new List<Quote_Request_Products__c>();
		Quote_Request_Products__c quoteRequestProduct;

		for (QuoteRequest_Product_Event__e quoteRequestProductEvent : quoteRequestProductEvents) {
			quoteRequestProduct = new Quote_Request_Products__c();
			quoteRequestProduct.Quote_Request__c = quoteRequestProductEvent.QuoteRequestId__c;
			quoteRequestProduct.Product__c = quoteRequestProductEvent.ProductId__c;
			quoteRequestProduct.Quantity__c = quoteRequestProductEvent.Quantity__c;
			quoteRequestProduct.Term__c = quoteRequestProductEvent.SubscriptionTerm__c;
			quoteRequestProducts.add(quoteRequestProduct);
		}

		try {
			insert quoteRequestProducts;
		} catch (Exception e) {
			Logger.Error('QuoteRequestTriggerUtility.processQuoteRequestProductEvent ERRORS', e);
			Logger.saveLog();
		}
	}

	public static void processQuoteRequestProducts(
		List<Quote_Request_Products__c> quoteRequestProducts
	) {
		List<Quote_Request__c> quoteRequests = new List<Quote_Request__c>();
		Quote_Request__c quoteRequest;

		Set<Id> quoteRequestIds = new Set<Id>();
		for (Quote_Request_Products__c quoteRequestProduct : quoteRequestProducts) {
			quoteRequestIds.add(quoteRequestProduct.Quote_Request__c);
		}

		for (Id quoteRequestId : quoteRequestIds) {
			quoteRequest = new Quote_Request__c(Id = quoteRequestId);
			quoteRequest.Sync_to_Zift__c = true;
			quoteRequest.Create_Quote__c = true;
			quoteRequests.add(quoteRequest);
		}

		List<Database.SaveResult> saveResults = Database.update(quoteRequests, false);
		Logger.logDatabaseErrors(
			LoggingLevel.ERROR,
			'QuoteRequestTriggerUtility.processQuoteRequestProducts ERRORS',
			saveResults
		);
		Logger.saveLog();
	}
}