/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test utility class for trac
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * Modified   ModifiedDate   Description
 * SS-12676   2026-03-25     Deleted depreciated fields (dollars_per_seat__c, Commitment_Duration_Months__c, License_Rev_to_Partner__c)
 * SS-13176   2026-05-27    Removed deprecated Level field references from Sales_Heirarchy__c
 */

@isTest
public without sharing class trac_TestUtils {
	public static final Id PRICEBOOKID = Test.getStandardPricebookId();
	public static final String BILLING_CITY = 'Burnaby';
	public static final String BILLING_COUNTRY = 'Canada';
	public static final String SYSADMIN_PROFILE = 'Tanium System Administrator';
	public static final String USER_ROLE = 'East: GHE';

	private static Map<String, Profile> profileMapByName = new Map<String, Profile>();
	private static Map<String, UserRole> userRoleMapByName = new Map<String, UserRole>();

	static {
		// Set up the Profile Map
		List<Profile> profiles = [SELECT Id, Name FROM Profile];
		for (Profile p : profiles) {
			profileMapByName.put(p.Name, p);
		}

		List<UserRole> userRoles = [SELECT Id, Name FROM UserRole];
		for (UserRole u : userRoles) {
			userRoleMapByName.put(u.Name, u);
		}
	}

	public static void createHierarchy() {
		List<Sales_Heirarchy__c> lstSH = new List<Sales_Heirarchy__c>();
		UserRole userRole = userRoleMapByName.get(USER_ROLE);
		lstSH.add(
			new Sales_Heirarchy__c(
				Role__c = userRole.Name
			)
		);

		insert lstSH;
	}

	public static Account buildAccount(String testAccountName) {
		Account testAccount = new Account(
			Name = testAccountName,
			AccountNumber = '' + DateTime.now().getTime() + Math.round(Math.random() * 100),
			BillingStreet = Math.round(Math.random() * 100) + ' Production Way',
			BillingCity = BILLING_CITY,
			BillingCountry = BILLING_COUNTRY
		);
		return testAccount;
	}

	public static Opportunity buildOpportunity(String name, String stage, Id accountId) {
		Opportunity testOpportunity = new Opportunity(
			Name = name,
			StageName = stage,
			pricebook2Id = PRICEBOOKID,
			CloseDate = Date.newInstance(2015, 6, 30),
			AccountId = accountId,
			Type = 'New',
			Amount = 90000,
			First_Interaction_Date__c = System.today(),
			seats__c = 30000,
			Commit__c = 10.00
		);
		return testOpportunity;
	}

	public static Legal_Entity__c buildLegalEntity(String name) {
		Legal_Entity__c testLegalEntity = new Legal_Entity__c(Name = name);
		return testLegalEntity;
	}

	public static Contracting_Entity__c buildContractingEntity(String country, Id legalEntityId) {
		Contracting_Entity__c testConEntity = new Contracting_Entity__c(
			Country__c = country,
			Legal_Entity__c = legalEntityId
		);
		return testConEntity;
	}

	public static SBQQ__Quote__c buildQuote(
		Id testOppId,
		Id testAccountId,
		String status,
		String quoteType
	) {
		SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
			SBQQ__StartDate__c = Date.today(),
			SBQQ__EndDate__c = Date.today().addDays(30),
			SBQQ__Opportunity2__c = testOppId,
			SBQQ__PriceBook__c = PRICEBOOKID,
			SBQQ__Account__c = testAccountId,
			SBQQ__Status__c = status,
			SBQQ__Type__c = quoteType,
			SBQQ__SubscriptionTerm__c = 30
		);
		return testQuote;
	}

	public static User buildUser(String uAlias, String uEmail, String uUsername, String uLastname) {
		Profile p = profileMapByName.get(SYSADMIN_PROFILE);
		UserRole ur = userRoleMapByName.get(USER_ROLE);
		User aUser = null;

		System.debug(p);

		// IsPortalEnabled
		if (p != null)
			aUser = new User(
				alias = uAlias,
				email = uEmail,
				emailencodingkey = 'UTF-8',
				firstname = 'Test',
				lastname = uLastname,
				languagelocalekey = 'en_US',
				localesidkey = 'en_US',
				profileid = p.Id,
				country = 'United States',
				timezonesidkey = 'America/Los_Angeles',
				username = uUsername + DateTime.now().getTime(),
				userrole = ur
			);
		return aUser;
	}

	public static Product2 buildProduct(String name, String description, String category) {
		Product2 product = new Product2(
			IsActive = true,
			Name = name,
			Description = description,
			Product_Category__c = category
		);
		return product;
	}

	public static PriceBookEntry buildPriceBookEntry(Id productId, Integer price) {
		PriceBookEntry testPbe = new PricebookEntry(
			IsActive = true,
			Pricebook2Id = PRICEBOOKID,
			Product2Id = productId,
			UnitPrice = price,
			UseStandardPrice = false
		);
		return testPbe;
	}

	public static OpportunityLineItem buildOppLineItem(
		Id oppId,
		Id pbeId,
		Id quoteLineId,
		Decimal qty,
		Decimal price
	) {
		OpportunityLineItem oli = new OpportunityLineItem(
			OpportunityId = oppId,
			SBQQ__QuoteLine__c = quoteLineId,
			PricebookEntryId = pbeId,
			Quantity = qty,
			ServiceDate = Date.newInstance(2016, 6, 24),
			TotalPrice = price
		);
		return oli;
	}

	public static Billing_Schedule__c buildBillingSchedule(
		Id oppId,
		Id quoteId,
		Date testDate,
		Decimal total
	) {
		Billing_Schedule__c bill = new Billing_Schedule__c(
			Opportunity__c = oppId,
			Quote__c = quoteId,
			Billing_Date__c = testDate,
			Billing_Amount__c = total,
			Invoice_Date__c = testDate
		);
		return bill;
	}

	public static Contract buildContract(String name, Double arv, Id accId, Integer term) {
		Contract contract = new Contract(
			Name = name,
			AccountId = accId,
			ContractTerm = term,
			TRAC_ARV_Contract__c = arv
		);
		return contract;
	}

	public static SBQQ__QuoteLine__c buildQuoteLine(Id quoteId, Id prodId, Integer qty) {
		SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
			SBQQ__Quote__c = quoteId,
			SBQQ__Product__c = prodId,
			SBQQ__Quantity__c = qty
		);
		return quoteLine;
	}

	public static SBQQ__Subscription__c buildSubscription(
		Id prodId,
		Id contractId,
		Id quoteLineId,
		Double multiplier
	) {
		SBQQ__Subscription__c subscription = new SBQQ__Subscription__c(
			SBQQ__Product__c = prodId,
			SBQQ__Contract__c = contractId,
			SBQQ__QuoteLine__c = quoteLineId,
			SBQQ__ProrateMultiplier__c = multiplier,
			SBQQ__NetPrice__c = 10.00,
			SBQQ__Quantity__c = 10
		);
		return subscription;
	}

	public static void insertTriggerManagementSettings() {
	}
}