/**
 * @Business: Test class for QuoteRequestController
 * @Authors: Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-11140   2025-07-10    Created the test class
 * SS-11835   2025-10-08    Removed test methods linked to methods getDistributorIds, getDistributorPicklistValues
 * SS-12279   2025-12-18    Added test method testGetDeploymentProviderPicklistValues_Always_ReturnDeploymentProviderPicklistValues
 */
@IsTest
private class QuoteRequestControllerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'DealRegistrationTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account distributorAccount = TestFactory.buildAccount('Distributor Account');
			distributorAccount.Type = 'Distributor';
			distributorAccount.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			distributorAccount.Cloud_Deployment_Verified__c = true;
			distributorAccount.On_Prem_Deployment_Verified__c = true;
			insert distributorAccount;

			Account resellerAccount = TestFactory.buildAccount('Reseller Account');
			resellerAccount.Type = 'Reseller';
			resellerAccount.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			insert resellerAccount;

			Address__c billToAddress = new Address__c(Account__c = resellerAccount.Id);
			billToAddress.Attention__c = 'Billing Dept';
			billToAddress.Address_1__c = '123 Street';
			billToAddress.City__c = 'Miami';
			billToAddress.State__c = 'Florida';
			billToAddress.Country__c = 'United States';
			billToAddress.Zip_Code__c = '33145';
			billToAddress.Default_Billing__c = true;
			insert billToAddress;

			Address__c shipToAddress = new Address__c(Account__c = resellerAccount.Id);
			shipToAddress.Attention__c = 'Shipping Dept';
			shipToAddress.Address_1__c = '123 Street';
			shipToAddress.City__c = 'Miami';
			shipToAddress.State__c = 'Florida';
			shipToAddress.Country__c = 'United States';
			shipToAddress.Zip_Code__c = '33145';
			shipToAddress.Default_Shipping__c = true;
			insert shipToAddress;

			Opportunity opp = TestFactory.buildOpportunity(
				'Reseller Opportunity',
				System.today().addDays(120),
				'New',
				resellerAccount.Id
			);
			insert opp;

			Deal_Registration__c dealRegistration = TestFactory.buildDealReg(
				'First',
				'Last',
				'first.last@testcompany.io',
				'Test Company'
			);
			dealRegistration.Mapped_Opportunity__c = opp.Id;
			dealRegistration.or_New_Opp_Reg__c = true;
			dealRegistration.or_Create_Opportunity_upon_Approval__c = true;
			dealRegistration.or_Opportunity_Registration__c = 'Partner Sourced';
			dealRegistration.or_Opp_Reg_Status__c = 'Approved';
			insert dealRegistration;

			Quote_Request__c quoteRequest = new Quote_Request__c();
			quoteRequest.Deal_Registration__c = dealRegistration.Id;
			quoteRequest.Submitter_Role__c = 'Distributor';
			quoteRequest.Multi_Tier_Transaction__c = false;
			quoteRequest.Subscription_Term__c = 12;
			quoteRequest.Partner_Email__c = 'partner@email.com';
			insert quoteRequest;
		}
	}

	@IsTest
	static void testIsValidDealRegId_WhenValidDealregId_ReturnsTrue() {
		Deal_Registration__c dealRegistration = [SELECT Id FROM Deal_Registration__c LIMIT 1];
		Boolean validDealRegId;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			validDealRegId = QuoteRequestController.isValidDealRegId(dealRegistration.Id);
			Test.stopTest();
		}

		Assert.isTrue(validDealRegId == true);
	}

	@IsTest
	static void testIsValidAccountId_WhenInvalidAccountId_ReturnsFalse() {
		Boolean validAccountId;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			validAccountId = QuoteRequestController.isValidAccountId(UserInfo.getUserId());
			Test.stopTest();
		}

		Assert.isTrue(validAccountId == false);
	}

	@IsTest
	static void testGetDealReg_WhenValidDealregId_ReturnDealRegistration() {
		Id dealRegistrationId = [SELECT Id FROM Deal_Registration__c LIMIT 1].Id;
		Deal_Registration__c dealRegistration = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			dealRegistration = QuoteRequestController.getDealReg(dealRegistrationId);
			Test.stopTest();
		}

		Assert.isTrue(dealRegistration != null);
	}

	@IsTest
	static void testGetUserAccountInfo_WhenValidAccountId_ReturnUserAccountInformation() {
		Account resellerAccount = [SELECT Id FROM Account WHERE Type = 'Reseller' LIMIT 1];
		QuoteRequestController.UserAccountInfo userAccountInfo = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			userAccountInfo = QuoteRequestController.getUserAccountInfo(resellerAccount.Id);
			Test.stopTest();
		}

		Assert.isTrue(userAccountInfo != null);
	}

	@IsTest
	static void testSubmitInsertQuoteRequestPlatformEvent_Always_ReturnSuccess() {
		Deal_Registration__c dealRegistration = [
			SELECT Id, Zift_Lead_Partner__c, Account__c
			FROM Deal_Registration__c
			LIMIT 1
		];
		EnhancedReturnType rt;
		QuoteRequestController.QuoteRequestWrapper quoteRequestWrapper = new QuoteRequestController.QuoteRequestWrapper();
		quoteRequestWrapper.dealRegId = dealRegistration.Id;
		quoteRequestWrapper.partnerId = dealRegistration.Zift_Lead_Partner__c;
		quoteRequestWrapper.customerId = dealRegistration.Account__c;
		quoteRequestWrapper.multiTierTransaction = true;
		quoteRequestWrapper.subscriptionTerm = 12;
		quoteRequestWrapper.partnerContactEmail = 'partner.contact@partnercorp.io';
		quoteRequestWrapper.distributorEmail = 'distruibutor@partnercorp.io';
		quoteRequestWrapper.billingStreet = '123 Billing St';
		quoteRequestWrapper.billingCity = 'Billing City';
		quoteRequestWrapper.billingProvince = 'Billing Province';
		quoteRequestWrapper.billingZipCode = '12345';
		quoteRequestWrapper.billingCountry = 'United States';
		quoteRequestWrapper.shippingStreet = '123 Shipping St';
		quoteRequestWrapper.shippingCity = 'Shipping City';
		quoteRequestWrapper.shippingProvince = 'Shipping Province';
		quoteRequestWrapper.shippingZipCode = '54321';
		quoteRequestWrapper.shippingCountry = 'United States';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = QuoteRequestController.submitInsertQuoteRequestPlatformEvent(
				JSON.serialize(quoteRequestWrapper)
			);
			Test.stopTest();
		}

		Assert.isTrue(rt.retResult);
	}

	@IsTest
	static void testSubmitUpdateQuoteRequestPlatformEvent_Always_ReturnSuccess() {
		Quote_Request__c quoteRequest = [SELECT Id FROM Quote_Request__c LIMIT 1];
		EnhancedReturnType rt;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = QuoteRequestController.submitUpdateQuoteRequestPlatformEvent(quoteRequest.Id);
			Test.stopTest();
		}

		Assert.isTrue(rt.retResult);
	}

	@IsTest
	static void testSubmitQuoteRequestProductPlatformEvent_Always_ReturnSuccess() {
		Deal_Registration__c dealRegistration = [
			SELECT Id, Zift_Lead_Partner__c, Account__c
			FROM Deal_Registration__c
			LIMIT 1
		];
		EnhancedReturnType rt;
		List<QuoteRequestController.QuoteRequestProductWrapper> quoteRequestProductsWrapper = new List<QuoteRequestController.QuoteRequestProductWrapper>();
		QuoteRequestController.QuoteRequestProductWrapper quoteRequestProductWrapper = new QuoteRequestController.QuoteRequestProductWrapper();
		quoteRequestProductWrapper.dealRegId = dealRegistration.Id;
		quoteRequestProductWrapper.productId = null;
		quoteRequestProductWrapper.quantity = 500;
		quoteRequestProductWrapper.subscriptionTerm = 12;
		quoteRequestProductsWrapper.add(quoteRequestProductWrapper);
		quoteRequestProductWrapper = new QuoteRequestController.QuoteRequestProductWrapper();
		quoteRequestProductWrapper.dealRegId = dealRegistration.Id;
		quoteRequestProductWrapper.productId = null;
		quoteRequestProductWrapper.quantity = 500;
		quoteRequestProductWrapper.subscriptionTerm = 12;
		quoteRequestProductsWrapper.add(quoteRequestProductWrapper);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = QuoteRequestController.submitQuoteRequestProductPlatformEvent(
				JSON.serialize(quoteRequestProductsWrapper)
			);
			Test.stopTest();
		}

		Assert.isTrue(rt.retResult);
	}

	@IsTest
	static void testGetQuoteRequestId_WhenInvalidDealRegId_ReturnNull() {
		Id quoteRequestId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			quoteRequestId = QuoteRequestController.getQuoteRequestId(UserInfo.getUserId());
			Test.stopTest();
		}
		Assert.isTrue(quoteRequestId == null);
	}

	@IsTest
	static void testGetQuoteRequestProductsCount_WhenNoProducts_ReturnZero() {
		Integer quoteRequestProductsCount;
		Quote_Request__c quoteRequest = [SELECT Id FROM Quote_Request__c LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			quoteRequestProductsCount = QuoteRequestController.getQuoteRequestProductsCount(
				quoteRequest.Id
			);
			Test.stopTest();
		}
		Assert.isTrue(quoteRequestProductsCount == 0);
	}

	@IsTest
	static void testGetExistingQuoteRequests_WhenOneExistingQuoteRequest_ReturnOneRecord() {
		Deal_Registration__c dealRegistration = [
			SELECT Id
			FROM Deal_Registration__c
			LIMIT 1
		];
		Quote_Request__c[] quoteRequests;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			quoteRequests = QuoteRequestController.getExistingQuoteRequests(dealRegistration.Id);
			Test.stopTest();
		}
		Assert.isTrue(quoteRequests.size() == 1);
	}

	@IsTest
	static void testGetDeploymentProviderPicklistValues_Always_ReturnDeploymentProviderPicklistValues() {
		List<Map<String, String>> deploymentProviderPicklistValues;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			deploymentProviderPicklistValues = QuoteRequestController.getDeploymentProviderPicklistValues();
			Test.stopTest();
		}
		Assert.isFalse(deploymentProviderPicklistValues.isEmpty());
	}
}