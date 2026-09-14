/**
 * @Business: Controller class for the QuoteRequest page
 * @Authors: Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-11140   2025-07-10    Created the controller
 * SS-11835   2025-10-08    Removed methods getDistributorIds, getDistributorPicklistValues
 * SS-12279   2025-12-18    Added method getDeploymentProviderPicklistValues
 */
public without sharing class QuoteRequestController {
	@AuraEnabled(cacheable=false)
	public static Boolean isValidDealRegId(String dealRegId) {
		List<Deal_Registration__c> dealRegistrations = [
			SELECT Id
			FROM Deal_Registration__c
			WHERE
				Id = :dealRegId
				AND Mapped_Opportunity__c != NULL
				AND or_Opp_Reg_Status__c = 'Approved'
		];
		return !dealRegistrations.isEmpty();
	}

	@AuraEnabled(cacheable=false)
	public static Boolean isValidAccountId(String accountId) {
		List<Account> accounts = [
			SELECT Id
			FROM Account
			WHERE Id = :accountId
		];
		return !accounts.isEmpty();
	}

	@AuraEnabled(cacheable=false)
	public static Deal_Registration__c getDealReg(Id dealRegId) {
		Deal_Registration__c dealReqistration;
		try {
			dealReqistration = [
				SELECT
					Id,
					OwnerId,
					Zift_Lead_Partner__c,
					Zift_Lead_Partner__r.Name,
					Account__c,
					EndCustomerAccount1__c,
					Distributor__c,
					Distributor__r.Name,
					Countries__c
				FROM Deal_Registration__c
				WHERE Id = :dealRegId
			];
		} catch (Exception e) {
			throw new AuraHandledException('Error ' + e.getMessage());
		}
		return dealReqistration;
	}

	@AuraEnabled(cacheable=false)
	public static UserAccountInfo getUserAccountInfo(Id accountId) {
		return populateUserAccountInfo(accountId);
	}

	private static UserAccountInfo populateUserAccountInfo(Id accountId) {
		UserAccountInfo userAccountInfo = new UserAccountInfo();
		Account userAccount = [
			SELECT Id, Name, Support_Verified__c
			FROM Account
			WHERE Id = :accountId
		];

		userAccountInfo.id = userAccount.Id;
		userAccountInfo.name = userAccount.Name;
		userAccountInfo.supportVerified = userAccount.Support_Verified__c;

		Map<String, Address__c> addressTypeToAddress = getAddressTypeToAddress(userAccount.Id);
		if (addressTypeToAddress.containsKey('billing')) {
			userAccountInfo.billingAttention = addressTypeToAddress.get('billing').Attention__c;
			userAccountInfo.billingStreet = addressTypeToAddress.get('billing').Address_1__c;
			userAccountInfo.billingCity = addressTypeToAddress.get('billing').City__c;
			userAccountInfo.billingState = addressTypeToAddress.get('billing').State__c;
			userAccountInfo.billingZipCode = addressTypeToAddress.get('billing').Zip_Code__c;
			userAccountInfo.billingCountry = addressTypeToAddress.get('billing').Country__c;
		}
		if (addressTypeToAddress.containsKey('shipping')) {
			userAccountInfo.shippingAttention = addressTypeToAddress.get('shipping').Attention__c;
			userAccountInfo.shippingStreet = addressTypeToAddress.get('shipping').Address_1__c;
			userAccountInfo.shippingCity = addressTypeToAddress.get('shipping').City__c;
			userAccountInfo.shippingState = addressTypeToAddress.get('shipping').State__c;
			userAccountInfo.shippingZipCode = addressTypeToAddress.get('shipping').Zip_Code__c;
			userAccountInfo.shippingCountry = addressTypeToAddress.get('shipping').Country__c;
		}
		return userAccountInfo;
	}

	@AuraEnabled(cacheable=false)
	public static Id getQuoteRequestId(Id dealRegId) {
		Id quoteRequestId = null;
		Datetime threeMinutesAgo = System.now().addMinutes(-3);
		try {
			quoteRequestId = [
				SELECT Id
				FROM Quote_Request__c
				WHERE
					Deal_Registration__c = :dealRegId
					AND Quote_Request_Product_Count__c = 0
					AND CreatedDate >= :threeMinutesAgo
				LIMIT 1
			]
			.Id;
		} catch (Exception e) {
			quoteRequestId = null;
		}
		return quoteRequestId;
	}

	@AuraEnabled(cacheable=false)
	public static List<Quote_Request__c> getExistingQuoteRequests(Id dealRegId) {
		return [
			SELECT Id, Submitter_Role__c, Multi_Tier_Transaction__c, Distributor_Email__c
			FROM Quote_Request__c
			WHERE Deal_Registration__c = :dealRegId
			ORDER BY CreatedDate DESC
		];
	}

	@AuraEnabled(cacheable=false)
	public static Integer getQuoteRequestProductsCount(Id quoteRequestId) {
		List<AggregateResult> quoteRequestProductsResults = [
			SELECT COUNT(Id) productCount
			FROM Quote_Request_Products__c
			WHERE Quote_Request__c = :quoteRequestId
		];
		return (Integer) quoteRequestProductsResults[0].get('productCount');
	}

	@AuraEnabled(cacheable=true)
	public static List<Map<String, String>> getDeploymentProviderPicklistValues() {
		List<Map<String, String>> pickListValues = new List<Map<String, String>>();
		Map<String, String> pickListValue;

		List<Account> deploymentProviders = [
			SELECT
				Id,
				Name,
				HQ_Country__c,
				Cloud_Deployment_Verified__c,
				On_Prem_Deployment_Verified__c
			FROM Account
			WHERE
				RecordType.DeveloperName = 'Partner'
				AND (Cloud_Deployment_Verified__c = TRUE
				OR On_Prem_Deployment_Verified__c = TRUE)
			ORDER BY Name
		];

		for (Account deploymentProvider : deploymentProviders) {
			pickListValue = new Map<String, String>();
			pickListValue.put('label', deploymentProvider.Name);
			pickListValue.put('value', deploymentProvider.Id);
			pickListValue.put(
				'cloudDeploymentVerified',
				String.valueOf(deploymentProvider.Cloud_Deployment_Verified__c)
			);
			pickListValue.put(
				'onPremDeploymentVerified',
				String.valueOf(deploymentProvider.On_Prem_Deployment_Verified__c)
			);
			pickListValue.put('hqCountry', deploymentProvider.HQ_Country__c);
			pickListValues.add(pickListValue);
		}
		return pickListValues;
	}

	@AuraEnabled(cacheable=false)
	public static EnhancedReturnType submitInsertQuoteRequestPlatformEvent(
		String wrapperSerialized
	) {
		QuoteRequestWrapper quoteRequestWrapper = (QuoteRequestWrapper) JSON.deserialize(
			wrapperSerialized,
			QuoteRequestWrapper.class
		);

		QuoteRequest_Event__e quoteRequestEvent = new QuoteRequest_Event__e();
		quoteRequestEvent.AdditionalComments__c = quoteRequestWrapper.additionalComments;
		quoteRequestEvent.BillingAttention__c = quoteRequestWrapper.billingAttention;
		quoteRequestEvent.BillingCity__c = quoteRequestWrapper.billingCity;
		quoteRequestEvent.BillingCountry__c = quoteRequestWrapper.billingCountry;
		quoteRequestEvent.BillingProvince__c = quoteRequestWrapper.billingProvince;
		quoteRequestEvent.BillingStreet__c = quoteRequestWrapper.billingStreet;
		quoteRequestEvent.BillingZipCode__c = quoteRequestWrapper.billingZipCode;
		quoteRequestEvent.CustomerId__c = quoteRequestWrapper.customerId;
		quoteRequestEvent.DealRegId__c = quoteRequestWrapper.dealRegId;
		quoteRequestEvent.dealRegOwnerId__c = quoteRequestWrapper.dealRegOwnerId;
		quoteRequestEvent.DeploymentProviderId__c = quoteRequestWrapper.deploymentProviderId;
		quoteRequestEvent.DeploymentType__c = quoteRequestWrapper.deploymentType;
		quoteRequestEvent.DistributorEmail__c = quoteRequestWrapper.distributorEmail;
		quoteRequestEvent.DownstreamPartnerId__c = quoteRequestWrapper.downstreamPartnerId;
		quoteRequestEvent.MultiTierTransaction__c = quoteRequestWrapper.multiTierTransaction;
		quoteRequestEvent.PartnerId__c = quoteRequestWrapper.partnerId;
		quoteRequestEvent.PartnerContactEmail__c = quoteRequestWrapper.partnerContactEmail;
		quoteRequestEvent.ShippingAttention__c = quoteRequestWrapper.shippingAttention;
		quoteRequestEvent.ShippingCity__c = quoteRequestWrapper.shippingCity;
		quoteRequestEvent.ShippingCountry__c = quoteRequestWrapper.shippingCountry;
		quoteRequestEvent.ShippingProvince__c = quoteRequestWrapper.shippingProvince;
		quoteRequestEvent.ShippingStreet__c = quoteRequestWrapper.shippingStreet;
		quoteRequestEvent.ShippingZipCode__c = quoteRequestWrapper.shippingZipCode;
		quoteRequestEvent.SolutionsSelected__c = quoteRequestWrapper.solutionsSelected;
		quoteRequestEvent.SubscriptionTerm__c = quoteRequestWrapper.subscriptionTerm;
		quoteRequestEvent.SubmitterRole__c = quoteRequestWrapper.submitterRole;
		quoteRequestEvent.SupportProviderId__c = quoteRequestWrapper.supportProviderId;
		quoteRequestEvent.DML_Operation__c = 'INSERT';

		return submitQuoteRequestPlatformEvent(quoteRequestEvent);
	}

	@AuraEnabled(cacheable=false)
	public static EnhancedReturnType submitUpdateQuoteRequestPlatformEvent(Id quoteRequestId) {
		QuoteRequest_Event__e quoteRequestEvent = new QuoteRequest_Event__e();
		quoteRequestEvent.QuoteRequestId__c = quoteRequestId;
		quoteRequestEvent.SyncWithZift__c = true;
		quoteRequestEvent.CreateQuote__c = true;
		quoteRequestEvent.DML_Operation__c = 'UPDATE';
		return submitQuoteRequestPlatformEvent(quoteRequestEvent);
	}

	private static EnhancedReturnType submitQuoteRequestPlatformEvent(
		QuoteRequest_Event__e quoteRequestEvent
	) {
		EnhancedReturnType rt = new EnhancedReturnType(true);
		Database.SaveResult result = EventBus.publish(quoteRequestEvent);
		if (!result.isSuccess()) {
			rt.retResult = false;
			rt.retData = result.getErrors()[0].getMessage();
			Logger.error(
					'QuoteRequest_Event__e - ' + result.getId() + ' - ' + rt.retData + ' - FAILURE'
				)
				.addTag('apex')
				.addTag('platform-event');
			Logger.saveLog();
		}
		return rt;
	}

	@AuraEnabled(cacheable=false)
	public static EnhancedReturnType submitQuoteRequestProductPlatformEvent(
		String wrapperSerialized
	) {
		EnhancedReturnType rt = new EnhancedReturnType(true);
		List<QuoteRequestProductWrapper> quoteRequestProductsWrapper = (List<QuoteRequestProductWrapper>) JSON.deserialize(
			wrapperSerialized,
			List<QuoteRequestProductWrapper>.class
		);
		List<QuoteRequest_Product_Event__e> quoteRequestProductEvents = new List<QuoteRequest_Product_Event__e>();
		QuoteRequest_Product_Event__e quoteRequestProductEvent;

		for (QuoteRequestProductWrapper quoteRequestProductWrapper : quoteRequestProductsWrapper) {
			quoteRequestProductEvent = new QuoteRequest_Product_Event__e();
			quoteRequestProductEvent.QuoteRequestId__c = quoteRequestProductWrapper.quoteRequestId;
			quoteRequestProductEvent.DealRegId__c = quoteRequestProductWrapper.dealRegId;
			quoteRequestProductEvent.ProductId__c = quoteRequestProductWrapper.productId;
			quoteRequestProductEvent.SubscriptionTerm__c = quoteRequestProductWrapper.subscriptionTerm;
			quoteRequestProductEvent.Quantity__c = quoteRequestProductWrapper.quantity;
			quoteRequestProductEvents.add(quoteRequestProductEvent);
		}
		List<Database.SaveResult> results = EventBus.publish(quoteRequestProductEvents);
		for (Database.SaveResult result : results) {
			if (!result.isSuccess()) {
				rt.retResult = false;
				rt.retData = result.getErrors()[0].getMessage();
				Logger.error(
						'QuoteRequest_Product_Event__e - ' +
							result.getId() +
							' - ' +
							rt.retData +
							' - FAILURE'
					)
					.addTag('apex')
					.addTag('platform-event');
			}
			Logger.saveLog();
		}
		return rt;
	}

	public static Map<String, Address__c> getAddressTypeToAddress(Id accountId) {
		Map<String, Address__c> addressTypeToAddress = new Map<String, Address__c>();
		for (Address__c address : [
			SELECT
				Id,
				Address_1__c,
				Attention__c,
				City__c,
				Country__c,
				Default_Billing__c,
				Default_Shipping__c,
				State__c,
				Zip_Code__c
			FROM Address__c
			WHERE Account__c = :accountId AND (Default_Billing__c = TRUE OR Default_Shipping__c = TRUE)
		]) {
			if (address.Default_Billing__c) {
				addressTypeToAddress.put('billing', address);
			}
			if (address.Default_Shipping__c) {
				addressTypeToAddress.put('shipping', address);
			}
		}
		return addressTypeToAddress;
	}

	public class QuoteRequestWrapper {
		@AuraEnabled
		public Id dealRegId { get; set; }
		@AuraEnabled
		public Id dealRegOwnerId { get; set; }
		@AuraEnabled
		public Id partnerId { get; set; }
		@AuraEnabled
		public Id downstreamPartnerId { get; set; }
		@AuraEnabled
		public Id customerId { get; set; }
		@AuraEnabled
		public String submitterRole { get; set; }
		@AuraEnabled
		public Boolean multiTierTransaction { get; set; }
		@AuraEnabled
		public Decimal subscriptionTerm { get; set; }
		@AuraEnabled
		public Id supportProviderId { get; set; }
		@AuraEnabled
		public Id deploymentProviderId { get; set; }
		@AuraEnabled
		public String partnerContactEmail { get; set; }
		@AuraEnabled
		public String distributorEmail { get; set; }
		@AuraEnabled
		public String billingAttention { get; set; }
		@AuraEnabled
		public String billingStreet { get; set; }
		@AuraEnabled
		public String billingCity { get; set; }
		@AuraEnabled
		public String billingProvince { get; set; }
		@AuraEnabled
		public String billingZipCode { get; set; }
		@AuraEnabled
		public String billingCountry { get; set; }
		@AuraEnabled
		public String shippingAttention { get; set; }
		@AuraEnabled
		public String shippingStreet { get; set; }
		@AuraEnabled
		public String shippingCity { get; set; }
		@AuraEnabled
		public String shippingProvince { get; set; }
		@AuraEnabled
		public String shippingZipCode { get; set; }
		@AuraEnabled
		public String shippingCountry { get; set; }
		@AuraEnabled
		public String additionalComments { get; set; }
		@AuraEnabled
		public String deploymentType { get; set; }
		@AuraEnabled
		public String solutionsSelected { get; set; }
	}

	public class QuoteRequestProductWrapper {
		@AuraEnabled
		public Id quoteRequestId { get; set; }
		@AuraEnabled
		public Id dealRegId { get; set; }
		@AuraEnabled
		public String productId { get; set; }
		@AuraEnabled
		public Decimal subscriptionTerm { get; set; }
		@AuraEnabled
		public Decimal quantity { get; set; }
	}

	public class UserAccountInfo {
		@AuraEnabled
		public Id id { get; set; }
		@AuraEnabled
		public String name { get; set; }
		@AuraEnabled
		public Boolean supportVerified { get; set; }
		@AuraEnabled
		public String billingAttention { get; set; }
		@AuraEnabled
		public String shippingAttention { get; set; }
		@AuraEnabled
		public String billingStreet { get; set; }
		@AuraEnabled
		public String shippingStreet { get; set; }
		@AuraEnabled
		public String billingCity { get; set; }
		@AuraEnabled
		public String shippingCity { get; set; }
		@AuraEnabled
		public String billingCountry { get; set; }
		@AuraEnabled
		public String shippingCountry { get; set; }
		@AuraEnabled
		public String billingState { get; set; }
		@AuraEnabled
		public String shippingState { get; set; }
		@AuraEnabled
		public String billingZipCode { get; set; }
		@AuraEnabled
		public String shippingZipCode { get; set; }
	}
}