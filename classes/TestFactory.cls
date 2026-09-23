/**
 *  Copyright (c) 2025 Tanium
 *
 * @BUSINESS: Test factory class to create test data, custom setting, trigger management etc.
 * @Date: 2018-12-18
 * @AUTHOR: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7240    2024-01-18    Add buildAccountSupportRequest method
 * SS-7583    2024-03-21    Removing BoomiRestService code references
 * SS-7719    2024-05-30    Add buildCase, buildEmailMessage, buildRoscoPeople, buildTAMTeam
 * SS-8999    2024-09-12    Add buildDealReg
 * SS-8788    2024-09-13    Added buildContract method
 * SS-8175    2024-10-23    Added buildFeedItem method
 * SS-9463    2024-11-21    Added buildFeedComment method
 * SS-9339    2024-12-16    Added getTaniumSalesUser method
 * SS-10736   2025-07-05    Use new Verification object and new Account fields
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-11659   2025-09-13    Added buildPrivateKey
 * SS-11202   2025-10-31    Remove CSHealthMetric object dependencies for deprecation
 * SS-7266    2025-11-24    Deleted TestDataFactory class, had to make adjustments accordingly, updated method buildAccount to use default country and state
 * SS-12185   2025-12-09    Added buildRoscoAccount method
 * SS-12077   2026-01-13    Added buildAccountEntitlement, buildNFR, buildSubscription,
 *                          buildPOCRequest, buildPOCModule, buildServerDeployment
 * SS-12676   2026-03-25    Deleted depreciated fields (Dollars_per_seat__c)
 * SS-13190   2026-05-11    Deleted Quote and QuoteLine object references
 * SS-13497   2026-07-07    Remove deprecated fields for project kondo group 2
 * SS-13885   2026-08-20    Added buildRuby.. and other supporting methods
 */
@IsTest
public class TestFactory {
	public static String DEFAULT_COUNTRY = 'United States';
	public static String DEFAULT_COUNTRY_CODE = 'US';
	public static String DEFAULT_STATE = 'California';
	public static String DEFAULT_STATE_CODE = 'CA';
	public static Id STANDARD_PRICEBOOK_ID = Test.getStandardpricebookId();
	public List<Account> accounts;
	public List<String> pricebookNameList;
	public List<Pricebook2> pricebookList;
	public Map<String, Pricebook2> pricebookNameMap;
	public Legal_Entity__c legalEntity;
	public Map<String, List<Product2>> pricebookProductMap;
	public Map<String, Account> accountNameMap;
	public List<Pricebook_Assignments__mdt> testFactoryPricebooks;

	private static final Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

	private static final Map<String, String> defaultPicklistValue = new Map<String, String>();

	private static final Map<String, Map<String, Schema.SObjectField>> fieldMapCache = new Map<String, Map<String, Schema.SObjectField>>();

	public static Map<String, Schema.SObjectField> fieldMapFor(String objectType) {
		Map<String, Schema.SObjectField> fieldMap = null;
		String normalizedObjectType = objectType.toLowerCase();

		if (fieldMapCache.containsKey(normalizedObjectType)) {
			fieldMap = fieldMapCache.get(normalizedObjectType);
		} else {
			fieldMap = globalDescribe.get(objectType).getDescribe().fields.getMap();
			// Cache it for next use
			fieldMapCache.put(normalizedObjectType, fieldMap);
		}
		return fieldMap;
	}

	private static SObject createSObject(String objectName) {
		return createSObject(objectName, 1);
	}

	private static SObject createSObject(String objectName, Integer counter) {
		Schema.sObjectType token = globalDescribe.get(objectName);
		if (token == null) {
			throw new SObjectException('Unsupported ObjectName ' + objectName);
		}

		SObject obj = token.newSObject();
		for (Schema.SObjectField field : fieldMapFor(objectName).values()) {
			setFieldValue(obj, field, counter);
		}
		return obj;
	}

	private static List<SObject> createSObjects(String objectType, Integer numberOfObjects) {
		List<SObject> sObjectList = new List<SObject>();
		for (Integer i = 0; i < numberOfObjects; i++) {
			sObjectList.add(createSObject(objectType, i));
		}
		return sObjectList;
	}

	private static void setFieldValue(SObject obj, Schema.SObjectField field, Integer counter) {
		Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

		if (
			fieldDescribe.isCreateable() &&
			!fieldDescribe.isNillable() &&
			!fieldDescribe.isDefaultedOnCreate() &&
			!fieldDescribe.isAutoNumber()
		) {
			if (fieldDescribe.getName().endsWith('Country')) {
				obj.put(field, DEFAULT_COUNTRY);
			} else if (fieldDescribe.getName().endsWith('State')) {
				obj.put(field, DEFAULT_STATE);
			} else if (fieldDescribe.getName().endsWith('CountryCode')) {
				obj.put(field, DEFAULT_COUNTRY_CODE);
			} else if (fieldDescribe.getName().endsWith('StateCode')) {
				obj.put(field, DEFAULT_STATE_CODE);
			} else if (fieldDescribe.getType() == Schema.DisplayType.base64) {
				obj.put(field, blob.valueOf(counter.format()));
			} else if (fieldDescribe.getType() == Schema.DisplayType.Boolean) {
				obj.put(field, false);
			} else if (fieldDescribe.getType() == Schema.DisplayType.Combobox) {
				obj.put(field, counter.format());
			} else if (fieldDescribe.getType() == Schema.DisplayType.Currency) {
				obj.put(field, counter);
			} else if (fieldDescribe.getType() == Schema.DisplayType.Date) {
				obj.put(field, Date.today());
			} else if (fieldDescribe.getType() == Schema.DisplayType.DateTime) {
				obj.put(field, DateTime.now());
			} else if (fieldDescribe.getType() == Schema.DisplayType.Double) {
				obj.put(field, counter);
			} else if (fieldDescribe.getType() == Schema.DisplayType.Email) {
				obj.put(field, 'test' + counter.format() + '@test.com');
			} else if (fieldDescribe.getType() == Schema.DisplayType.EncryptedString) {
				obj.put(field, 's');
			} else if (fieldDescribe.getType() == Schema.DisplayType.Id) {
				// DO NOTHING FOR ID FIELD
			} else if (fieldDescribe.getType() == Schema.DisplayType.Integer) {
				obj.put(field, counter);
			} else if (fieldDescribe.getType() == Schema.DisplayType.MultiPicklist) {
				obj.put(field, getDefaultPicklistValue(obj, fieldDescribe));
			} else if (fieldDescribe.getType() == Schema.DisplayType.Percent) {
				obj.put(field, counter);
			} else if (fieldDescribe.getType() == Schema.DisplayType.Phone) {
				obj.put(field, '123-456-7890');
			} else if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
				obj.put(field, getDefaultPicklistValue(obj, fieldDescribe));
			} else if (
				fieldDescribe.getName() == 'CommunityNickname' &&
				fieldDescribe.getType() == Schema.DisplayType.String
			) {
				obj.put(field, 'test' + string.valueof(math.roundtolong(math.random() * 1000000)));
			} else if (
				fieldDescribe.getName() == 'UserName' &&
				fieldDescribe.getType() == Schema.DisplayType.String
			) {
				obj.put(
					field,
					'test' +
					String.valueof(Userinfo.getOrganizationId()) +
					String.valueof(math.roundtolong(math.random() * 1000000)) +
					String.valueof(Datetime.now()).replace('-', '').replace(':', '').replace(' ', '') +
					'@test.com'
				); // was a@a.com
			} else if (fieldDescribe.getType() == Schema.DisplayType.String) {
				obj.put(field, counter.format());
			} else if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
				// DO NOTHING WIHT LOOKUP / MASTER-DETAIL RELATIONSHIP FIELDS
			} else if (fieldDescribe.getType() == Schema.DisplayType.TextArea) {
				obj.put(field, counter.format());
			} else if (fieldDescribe.getType() == Schema.DisplayType.Time) {
				obj.put(field, Time.newInstance(0, 0, 0, 0));
			} else if (fieldDescribe.getType() == Schema.DisplayType.URL) {
				obj.put(field, 'http://test' + counter + '.com');
			} else {
				System.debug('Unhandled field type ' + fieldDescribe.getType());
			}
		}
	}

	static String getDefaultPicklistValue(SObject obj, Schema.DescribeFieldResult fieldDescribe) {
		String key = obj.getSObjectType() + '.' + fieldDescribe.getName();

		if (!defaultPicklistValue.containsKey(key)) {
			List<Schema.PicklistEntry> entries = fieldDescribe.getPicklistValues();
			String value = entries.size() > 0 ? entries[0].getValue() : null;
			defaultPicklistValue.put(key, value);
		}
		return defaultPicklistValue.get(key);
	}

	public static void activateTriggers(List<String> triggerList) {
	}

	public static void deactivateTriggers(List<String> triggerList) {
	}
	public class ProductWrapper {
		String pricebookName;
		List<Product2> products;
		List<PricebookEntry> pricebookEntries;
		public ProductWrapper(String pbName, List<Test_Factory_Product_Base_SKU__mdt> skuMetadata) {
			pricebookEntries = new List<PricebookEntry>();
			pricebookName = pbName;
			products = new List<Product2>();
			List<string> skuList = new List<String>();
			for (Test_Factory_Product_Base_SKU__mdt testFactorySku : skuMetadata) {
				skuList.add(testFactorySku.SKU__c);
			}
			for (Integer i = 0; i < skuList.size(); i++) {
				Product2 eachProduct = TestFactory.buildProduct(
					'Product ' + i,
					String.valueOf(Math.random())
				);
				eachProduct.Family = 'Hardware';
				products.add(eachProduct);
			}
			insert products;
		}
	}

	public Map<String, Object> getFieldMapWithOverride(
		Map<String, Object> baseFieldMap,
		Map<String, Object> fieldMapOverride
	) {
		for (String fieldMap : fieldMapOverride.keySet()) {
			if (!baseFieldMap.containsKey(fieldMap)) {
				baseFieldMap.put(fieldMap, fieldMapOverride.get(fieldMap));
			}
		}
		return baseFieldMap;
	}

	public static Account buildAccount(String name) {
		Account act = (Account) TestFactory.createSObject('Account');
		act.Name = name;
		act.Type = 'Analyst';
		act.Country_Restrictions__c = 'Unrestricted';
		act.Country_Exception_Approved__c = true;
		act.Active__c = 'Active';
		act.HQ_State__c = DEFAULT_STATE;
		act.HQ_Zip__c = '94101';
		act.HQ_City__c = 'San Francisco';
		act.HQ_Country__c = DEFAULT_COUNTRY;
		act.Industry = 'Construction';
		act.Total_Addressable_Seats__c = 100000;
		act.Segment__c = 'Undetermined';
		act.Commission__c = 5;
		act.NumberOfEmployees = 10;
		act.Active_Account__c = true;
		return act;
	}

	public static Account buildAccount(String name, String accountType) {
		Account act = TestFactory.buildAccount(name);
		act.Type = accountType;
		return act;
	}

	public static Opportunity buildOpportunity(
		String name,
		Date closeDate,
		String stage,
		Id accountId
	) {
		Opportunity oppo;
		oppo = (Opportunity) TestFactory.createSObject('Opportunity');
		oppo.Name = name;
		oppo.CloseDate = closeDate;
		oppo.StageName = stage;
		oppo.AccountId = accountId;
		oppo.Seats__c = 100;
		oppo.Amount = 100;
		oppo.Commit__c = 10;
		oppo.Upside__c = 50;
		oppo.Type = 'New';
		oppo.Pricebook2Id = STANDARD_PRICEBOOK_ID;
		oppo.Probability = 0;
		return oppo;
	}

	public static SBQQ__Quote__c buildSBQQ_Quote(
		Id oppoId,
		Id accountId,
		String status,
		String type,
		Date startDate,
		Date endDate,
		String pricebookId
	) {
		SBQQ__Quote__c quote = (SBQQ__Quote__c) TestFactory.createSObject('SBQQ__Quote__c');
		quote.SBQQ__Opportunity2__c = oppoId;
		quote.SBQQ__Account__c = accountId;
		quote.SBQQ__Status__c = (String.isBlank(status)) ? 'Accepted' : status;
		quote.SBQQ__Type__c = (String.isBlank(type)) ? 'Quote' : type;
		quote.SBQQ__StartDate__c = (startDate != null) ? startDate : System.today();
		quote.SBQQ__EndDate__c = (endDate != null) ? endDate : System.today().addDays(30);
		quote.SBQQ__PriceBook__c = (String.isBlank(pricebookId))
			? TestFactory.STANDARD_PRICEBOOK_ID
			: pricebookId;
		quote.SBQQ__Introduction__c = 'Test';
		quote.SBQQ__SubscriptionTerm__c = 5;
		quote.Quantity_Config__c = 1;
		quote.Discount_Config__c = 5;
		return quote;
	}

    public static Quote buildQuote(String name, Id opportunityId, Date startDate, Date endDate) {
		Quote quote = (Quote) TestFactory.createSObject('Quote');
		quote.Name = name;
		quote.OpportunityId = opportunityId;
		quote.Pricebook2Id = TestFactory.STANDARD_PRICEBOOK_ID;
		quote.ELV_Type__c = 'Quote';
		quote.Ruby__SubscriptionStartDate__c = startDate ?? System.today();
		quote.Ruby__SubscriptionEndDate__c = endDate ?? System.today().addDays(30);
		quote.Ruby__SubscriptionTerm__c = 30;
		quote.Ruby__IsPrimaryQuote__c = true;
		return quote;
	}

	public static Quote buildQuote(
		Id oppoId,
		String status,
		String type,
		Date startDate,
		Date endDate,
		String pricebookId
	) {
		Quote quote = (Quote) TestFactory.createSObject('Quote');
		quote.OpportunityId = oppoId;
		quote.Status = (String.isBlank(status)) ? 'Accepted' : status;
		quote.ELV_Type__c = (String.isBlank(type)) ? 'Quote' : type;
		quote.Ruby__SubscriptionStartDate__c = (startDate != null) ? startDate : System.today();
		quote.Ruby__SubscriptionEndDate__c = (endDate != null) ? endDate : System.today().addDays(30);
		quote.Pricebook2Id = (String.isBlank(pricebookId))
			? TestFactory.STANDARD_PRICEBOOK_ID
			: pricebookId;
		quote.Ruby__EmailMessage__c = 'Test';
		quote.Ruby__SubscriptionTerm__c = 5;
		return quote;
	}

	public static Product2 buildProduct(String name, String productCode) {
		Product2 prod = (Product2) TestFactory.createSObject('Product2');
		prod.Name = name;
		prod.ProductCode = productCode;
		prod.IsActive = true;
		prod.Family = 'None';
		return prod;
	}

	public static Product_Module__c buildProductModule(Id productId, Id moduleId) {
		return new Product_Module__c(Product__c = productId, Module__c = moduleId);
	}

	public static PricebookEntry buildPricebookEntry(
		String productId,
		Decimal unitPrice,
		String pricebookId
	) {
		PricebookEntry pbEntry = (PricebookEntry) TestFactory.createSObject('PricebookEntry');
		pbEntry.Product2Id = productId;
		pbEntry.UnitPrice = unitPrice;
		pbEntry.Pricebook2Id = (String.isNotBlank(pricebookId))
			? pricebookId
			: TestFactory.STANDARD_PRICEBOOK_ID;
		pbEntry.IsActive = true;
		return pbEntry;
	}

	public static SBQQ__QuoteLine__c buildSBQQ_QuoteLine(Id quoteId, Id productId, Integer qty) {
		SBQQ__QuoteLine__c ql = (SBQQ__QuoteLine__c) TestFactory.createSObject('SBQQ__QuoteLine__c');
		ql.SBQQ__Quote__c = quoteId;
		ql.SBQQ__Product__c = productId;
		ql.SBQQ__Quantity__c = qty;
		return ql;
	}

	public static SBQQ__QuoteLine__c buildSBQQ_QuoteLine(
		Id quoteId,
		Id productId,
		Integer qty,
		Date billingDate1,
		Date billingDate2,
		Date billingDate3
	) {
		SBQQ__QuoteLine__c ql = TestFactory.buildSBQQ_QuoteLine(quoteId, productId, qty);
		return ql;
	}

    public static QuoteLineItem buildQuoteLineItem(
		Id quoteId,
		Integer qty,
		Decimal unitPrice,
		Id pricebookEntryId
	) {
		QuoteLineItem lineItem = (QuoteLineItem) TestFactory.createSObject('QuoteLineItem');
		lineItem.QuoteId = quoteId;
		lineItem.Quantity = qty;
		lineItem.UnitPrice = unitPrice;
		lineItem.PricebookEntryId = pricebookEntryId;
		return lineItem;
	}

	public static OpportunityLineItem buildOpportunityLineItem(
		Id oppoId,
		Integer qty,
		Decimal totalPrice,
		Id pricebookEntryId
	) {
		OpportunityLineItem lineItem = (OpportunityLineItem) TestFactory.createSObject(
			'OpportunityLineItem'
		);
		lineItem.OpportunityId = oppoId;
		lineItem.Quantity = qty;
		lineItem.TotalPrice = totalPrice;
		lineItem.PricebookEntryId = pricebookEntryId;
		return lineItem;
	}

	public static Opportunity_Partners__c buildOpportunityPartner(
		Id oppoId,
		Id partnerAccountId,
		Decimal commissionPercentage
	) {
		Opportunity_Partners__c oppoPartner = (Opportunity_Partners__c) TestFactory.createSObject(
			'Opportunity_Partners__c'
		);
		oppoPartner.Opportunity__c = oppoId;
		oppoPartner.Account__c = partnerAccountId;
		oppoPartner.Partner_Commission__c = commissionPercentage;
		return oppoPartner;
	}

    public static Opportunity_Server_deployment__c buildOppServerDep(
		Id accountId,
		Id opportunityId,
		Id serverDeploymentId,
		Id quoteLineItemId,
		Decimal quantity
	) {
		return new Opportunity_Server_deployment__c(
			Account__c = accountId,
			Opportunity__c = opportunityId,
			Server_Deployment__c = serverDeploymentId,
			ELV_QuoteLineItem__c = quoteLineItemId,
			ELV_AllocationQuantity__c = quantity
		);
	}

	public static Lead buildLead(String firstName, String lastName, String email, String company) {
		return TestFactory.buildLead(firstName, lastName, email, company, 'New');
	}

	public static Lead buildLead(
		String firstName,
		String lastName,
		String email,
		String company,
		String status
	) {
		Lead leadObj = (Lead) TestFactory.createSObject('Lead');
		leadObj.FirstName = firstName;
		leadObj.LastName = lastName;
		leadObj.Email = email;
		leadObj.Company = company;
		leadObj.Status = status;
		leadObj.Country = 'United States';
		return leadObj;
	}

	public static Billing_Schedule__c buildBillingSchedule(Id opportunityId) {
		Billing_Schedule__c billingSchedule = new Billing_Schedule__c(Opportunity__c = opportunityId);
		return billingSchedule;
	}

	public static Invoice__c buildInvoice(Id opportunityId) {
		Invoice__c invoice = new Invoice__c(Opportunity__c = opportunityId);
		return invoice;
	}

	public static HiddenFeatures__mdt buildHiddenFeature(String label) {
		HiddenFeatures__mdt feature = new HiddenFeatures__mdt(Label = label, DeveloperName = label);
		return feature;
	}

	public static HiddenFeatures__mdt buildActiveHiddenFeature(String label) {
		HiddenFeatures__mdt feature = new HiddenFeatures__mdt(Label = label, DeveloperName = label);
		feature.isActive__c = 'True';
		return feature;
	}

	public static HiddenFeatures__mdt buildInactiveHiddenFeature(String label) {
		HiddenFeatures__mdt feature = new HiddenFeatures__mdt(Label = label, DeveloperName = label);
		feature.isActive__c = 'False';
		return feature;
	}

	public static User buildUser(String lastName, String email, String alias, Id profileId) {
		return TestUserFactory.createUser(lastName, email, alias, profileId, null);
	}

	public static User buildUser(
		String lastName,
		String email,
		String alias,
		Id profileId,
		Id userRoleId
	) {
		return TestUserFactory.createUser(lastName, email, alias, profileId, userRoleId);
	}

	public static User getAutomationAdminUser() {
		return TestUserFactory.createAutomationAdminUser(false);
	}

	public static User getAutomationAdminUser(Boolean insertUser) {
		return TestUserFactory.createAutomationAdminUser(insertUser);
	}

	public static User getTaniumAdminUser() {
		return TestUserFactory.createTaniumAdminUser(false);
	}

	public static User getTaniumAdminUser(Boolean insertUser) {
		return TestUserFactory.createTaniumAdminUser(insertUser);
	}

	public static User getQuoteUnlockDealDeskUser() {
		return TestUserFactory.createDealDeskUser();
	}

	public static User getSalesOpsUser() {
		return TestUserFactory.createSalesOpsUser();
	}

	public static User getTaniumSalesUser() {
		return TestUserFactory.createTaniumStandardUser();
	}

	public static Contact buildContact(Id accountId) {
		Contact myContact = (Contact) TestFactory.createSObject('Contact');
		myContact.FirstName = 'Test' + accountId;
		myContact.LastName = 'Test' + accountId;
		myContact.AccountId = accountId;
		myContact.Title = 'Title Test';
		myContact.Email = 'contact@' + accountId + '.com';
		return myContact;
	}

	public static Account_Next_Step__c buildAccountNextStep(Id accountId) {
		Account_Next_Step__c accountNextStep = (Account_Next_Step__c) TestFactory.createSObject(
			'Account_Next_Step__c'
		);
		accountNextStep.Account__c = accountId;
		accountNextStep.RecordTypeId = Utility.getRecordTypeIdByAPIName(
			'Account_Next_Step__c',
			'CSM_Next_Steps'
		);
		return accountNextStep;
	}

	public static Apttus__APTS_Agreement__c buildApttusAgreement(Id accountId) {
		Apttus__APTS_Agreement__c apttusAgreement = (Apttus__APTS_Agreement__c) TestFactory.createSObject(
			'Apttus__APTS_Agreement__c'
		);
		apttusAgreement.Name = 'Binding Contract';
		apttusAgreement.Apttus__Account__c = accountId;
		apttusAgreement.Apttus__Contract_End_Date__c = Date.today().addYears(24);
		apttusAgreement.Apttus__Status_Category__c = 'Request';
		apttusAgreement.Apttus__Status__c = 'Request';
		return apttusAgreement;
	}

	public static POC_Request__c buildPOCRequest(Opportunity opportunity) {
		POC_Request__c pocRequest = (POC_Request__c) TestFactory.createSObject('POC_Request__c');
		pocRequest.Name = 'Test POC';
		pocRequest.POC_Type__c = 'New';
		pocRequest.License_Type__c = 'Lab';
		pocRequest.Server_Names__c = 'Test';
		pocRequest.Business_Justification__c = 'Test';
		pocRequest.Account_Owner_1__c = UserInfo.getUserId();
		pocRequest.Trace__c = true;
		pocRequest.Patch__c = true;
		pocRequest.Discover__c = true;
		pocRequest.Quantity__c = 100;
		pocRequest.Opportunity__c = opportunity.Id;
		pocRequest.Deployment_Country__c = 'United States';
		pocRequest.Tanium_Infrastructure__c = 'On-Prem';
		pocRequest.Account__c = opportunity.AccountId;
		pocRequest.Start_Date__c = System.today() + 30;
		pocRequest.Duration__c = 30;
		pocRequest.License_Version_6_5_or_7_x__c = '6.5';
		pocRequest.Asset__c = true;
		pocRequest.Comply__c = true;
		pocRequest.Map__c = true;
		pocRequest.Protect__c = true;
		pocRequest.Threat_Response__c = true;
		pocRequest.IOCD__c = true;
		pocRequest.Integrity_Monitor__c = true;
		pocRequest.Core__c = true;
		pocRequest.Reveal__c = true;
		pocRequest.Deploy__c = true;
		pocRequest.Enforce__c = true;
		pocRequest.Chronicle__c = true;
		pocRequest.Performance__c = true;
		pocRequest.IR__c = true;
		pocRequest.Primary_Solution_Area__c = 'Unlisted';
		pocRequest.TAN_320_S_Copper_Quantity__c = '10';
		pocRequest.TAN_320_S_Fiber_Quantity__c = '10';
		pocRequest.TAN_420_M_Fiber_Quantity__c = '10';
		pocRequest.TAN_420_M_Copper_Quantity__c = '10';
		pocRequest.TAN_220_DEV_Copper_Quantity__c = '10';
		pocRequest.TAN_220_DEV_Fiber_Quantity__c = '10';
		pocRequest.TAN_720_L_Fiber_Quantity__c = '10';
		pocRequest.TAN_720_L_Copper_Quantity__c = '10';
		pocRequest.TAN_920_XL_Copper_Quantity__c = '10';
		pocRequest.TAN_920_XL_Fiber_Quantity__c = '10';
		pocRequest.TAN_VIRTUAL_Quantity__c = '10';
		pocRequest.TAN_CLOUD_Quantity__c = '10';
		pocRequest.TAN_L_730_CP_Quantity__c = '10';
		pocRequest.TAN_L_735_FB_Quantity__c = '10';
		pocRequest.TAN_M_430_CP_Quantity__c = '10';
		pocRequest.TAN_M_435_FB_Quantity__c = '10';
		pocRequest.TAN_S_330_CP_Quantity__c = '10';
		pocRequest.TAN_S_335_FB_Quantity__c = '10';
		pocRequest.TAN_XL_930_CP_Quantity__c = '10';
		pocRequest.TAN_XL_935_FB_Quantity__c = '10';
		return pocRequest;
	}

	public static Apttus__Agreement_Clause__c buildClause(
		String name,
		String action,
		Id agreementId
	) {
		return new Apttus__Agreement_Clause__c(
			Apttus__Clause__c = name,
			Apttus__Action__c = action,
			Apttus__Agreement__c = agreementId
		);
	}

	public static Account_Support_Request__c buildAccountSupportRequest(
		Id accountId,
		Id opportunityId,
		String status,
		Id recordTypeId
	) {
		Account_Support_Request__c accSupportRequest = (Account_Support_Request__c) TestFactory.createSObject(
			'Account_Support_Request__c'
		);
		accSupportRequest.Account__c = accountId;
		accSupportRequest.Opportunity__c = opportunityId;
		accSupportRequest.Status__c = status;
		accSupportRequest.RecordTypeId = recordTypeId;
		return accSupportRequest;
	}

	public static Account_Support_Request__c buildAccountSupportRequest(Id accountId) {
		return new Account_Support_Request__c(
			RecordTypeId = Utility.getRecordTypeIdByAPIName(
				'Account_Support_Request__c',
				'Restricted_Country_Exception'
			),
			Account__c = accountId,
			Status__c = 'Draft',
			Exception_Country__c = 'United States'
		);
	}

	public static Country_For_Export__c buildCountryForExport(
		String countryName,
		String countryCode
	) {
		return new Country_For_Export__c(
			Name = countryName,
			Country_Code__c = countryCode,
			License_Approved__c = false
		);
	}

	public static Case buildCase(Id accountId) {
		Contact myContact = TestFactory.buildContact(accountId);
		Case myCase = TestFactory.buildCase(accountId, myContact.Id);
		return myCase;
	}

	public static Case buildCase(Id accountId, Id contactId) {
		return new Case(
			AccountId = accountId,
			ContactId = contactId,
			Subject = 'ROSCOTESTCASE',
			Severity_Community__c = '3',
			Type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			SuppliedEmail = '99@outlook.com',
			LatestPublicCommentHTML__c = '<html>hello</html>',
			Component__c = 'Other',
			Status = 'On Hold'
		);
	}

	public static Contract buildContract(Id accountId, Id oppId, Id primaryQuoteId) {
		Contract contract = new Contract(
			Name = 'Contract 1',
			AccountId = accountId,
			ContractTerm = 12,
			StartDate = Date.today().addYears(1),
			SBQQ__Opportunity__c = oppId,
			SBQQ__Quote__c = primaryQuoteId
		);
		return contract;
	}

	public static Attachment buildAttachment(Id parentId) {
		Attachment myAttachment = (Attachment) TestFactory.createSObject('Attachment');
		myAttachment.Name = 'Test attachment';
		myAttachment.ParentId = parentId;
		return myAttachment;
	}

	public static EmailMessage buildEmailMessage(String subject, Id parentId, Id relatedToId) {
		return new EmailMessage(
			FromAddress = 'rosco@roscolab.com',
			FromName = 'Rosco',
			HtmlBody = subject,
			ParentId = parentId,
			RelatedToId = relatedToId,
			Subject = subject,
			TextBody = subject,
			ToAddress = 'rosco@roscolab.com'
		);
	}

	public static rosco_people__c buildRoscoPeople(String name, Id contactId, Id userId) {
		return new rosco_people__c(
			Name = name,
			contact__c = contactId,
			user__c = userId,
			pod__c = 'Support Center',
			primary_sme__c = 'SME-Patch',
			secondary_sme__c = 'SME-Map'
		);
	}

	public static TAM_Team__c buildTAMTeam(String name, String slackChannelId) {
		return new TAM_Team__c(
			Name = name,
			Slack_Ticket_Channel_ID__c = slackChannelId,
			Slack_Escalation_Channel_ID__c = slackChannelId
		);
	}

	public static Deal_Registration__c buildDealReg(
		String firstName,
		String lastName,
		String email,
		String company
	) {
		return new Deal_Registration__c(
			FirstName__c = firstName,
			LastName__c = lastName,
			Email__c = email,
			Company_Name__c = company
		);
	}

	public static FeedItem buildFeedItem(Id parentId) {
		return new FeedItem(Body = 'Test Body', ParentId = parentId);
	}

	public static FeedComment buildFeedComment(Id feedItemId) {
		return new FeedComment(CommentBody = 'Test Body', FeedItemId = feedItemId);
	}

	public static Verification__c buildVerification(Id accountId, String type, Date expirationDate) {
		return new Verification__c(
			Partner_Account__c = accountId,
			Type__c = type,
			Expiration_Date__c = expirationDate,
			Issue_Date__c = Date.today(),
			Approval_Level__c = 'Fully Verified'
		);
	}

	public static List<Verification__c> buildVerifications(
		Id accountId,
		List<String> types,
		Date expirationDate
	) {
		List<Verification__c> verifications = new List<Verification__c>();
		for (String type : types) {
			verifications.add(buildVerification(accountId, type, expirationDate));
		}
		return verifications;
	}

	public static Private_Key__c buildPrivateKey() {
		Private_Key__c privateKey = new Private_Key__c();
		privateKey.Key__c = '1234567890123456';
		privateKey.Feature__c = 'TestClassKey';
		privateKey.IsActive__c = true;
		privateKey.Description__c = 'Key for test class';
		return privateKey;
	}

	public static Rosco_Account__c buildRoscoAccount(String name, Id accountId) {
		return new Rosco_Account__c(
			Name = name,
			Account__c = accountId,
			Triage_Flash__c = 'testtriageflash',
			Account_Flash__c = 'testaccountflash'
		);
	}

	public static Account_Entitlements__c buildAccountEntitlement(
		Id accountId,
		String type,
		Id moduleId,
		Decimal quantity
	) {
		return new Account_Entitlements__c(
			Account__c = accountId,
			Type__c = type,
			Module__c = moduleId,
			Start_Date__c = Date.today(),
			End_Date__c = Date.today().addMonths(6),
			Quantity_Purchased__c = quantity
		);
	}

	public static NFR__c buildNFR(Id accountId, String products) {
		return new NFR__c(
			Account__c = accountId,
			NFR_Issued_Date__c = Date.today(),
			NFR_Expiration_Date__c = Date.today().addMonths(2),
			Select_Tanium_Product__c = products,
			Duration_Months__c = '2',
			Number_of_Endpoints__c = 1000,
			Status__c = 'New'
		);
	}

	public static SBQQ__Subscription__c buildSubscription(
		Id accountId,
		Id productId,
		Decimal quantity,
		Id quoteLineId
	) {
		return new SBQQ__Subscription__c(
			SBQQ__Account__c = accountId,
			SBQQ__Product__c = productId,
			SBQQ__Quantity__c = quantity,
			SBQQ__SubscriptionStartDate__c = Date.today(),
			SBQQ__SubscriptionEndDate__c = Date.today().addMonths(12),
			Exclude_from_Seats_Roll_up__c = false,
			SBQQ__QuoteLine__c = quoteLineId
		);
	}

    public static Ruby__UOM__c buildRubyUOM(
		String name,
		Decimal scale,
        String termDimension
	) {
		return new Ruby__UOM__c(
			Name = name,
            Ruby__DecimalScale__c = scale,
            Ruby__TermDimension__c = termDimension,
            Ruby__Active__c = true
		);
	}

	public static Ruby__Subscription__c buildRubySubscription(
		Id accountId,
		Id productId,
		Decimal quantity,
		Id quoteLineId,
        Id uomId,
        Id pricebookEntryId
	) {
		return new Ruby__Subscription__c(
			Ruby__Customer__c = accountId,
			Ruby__Product__c = productId,
			Ruby__Quantity__c = quantity,
            Ruby__TodaysQuantity__c = quantity,
			Ruby__SubscriptionStartDate__c = Date.today(),
			Ruby__SubscriptionEndDate__c = Date.today().addMonths(12),
			ELV_Exclude_from_Seats_Roll_up__c = false,
			ELV_QuoteLine__c = quoteLineId,
            Ruby__UOM__c = uomId,
            Ruby__PriceBookEntry__c = pricebookEntryId,
            Ruby__SubscriptionVersion__c = 1,
            Ruby__ActualSubscriptionTerm__c = 12,
            Ruby__TaxAmount__c = 0,
            Ruby__TotalAmount__c = 100,
            Ruby__TotalPrice__c = 100
		);
	}

	public static POC_Request__c buildPOCRequest(
		Id accountId,
		Id oppId,
		Id recordTypeId,
		Id serverDeploymentId
	) {
		return new POC_Request__c(
			Account__c = accountId,
			Opportunity__c = oppId,
			RecordTypeId = recordTypeId,
			Tanium_Infrastructure__c = 'Tanium as a Service',
			Server_Deployment__c = serverDeploymentId,
			Start_Date__c = Date.today(),
			Duration__c = 60,
			Quantity__c = 2500,
			Primary_Solution_Area__c = 'Asset & Discovery'
		);
	}

	public static POC_Module__c buildPOCModule(Id accountId, Id pocRequestId, Id moduleId) {
		return new POC_Module__c(
			Account__c = accountId,
			POC_Request__c = pocRequestId,
			Module__c = moduleId,
			UniqueId__c = String.valueOf(pocRequestId) + String.valueOf(moduleId)
		);
	}

	public static Server_Deployment__c buildServerDeployment(String name, Id accountId) {
		return new Server_Deployment__c(
			Name = name,
			Account__c = accountId,
			Type__c = 'Production',
			Status__c = 'Active',
			Cloud_Provider__c = 'AWS',
			Server_Device_Type__c = 'Tanium as a Service'
		);
	}

	public static POC_Request_Solution_and_Module_Map__c buildPOCRequestSolutionAndModuleMap(
		String name,
		String pocFieldLabel,
		Id productCloudId,
		Id productOnPremId,
		Id moduleId
	) {
		return new POC_Request_Solution_and_Module_Map__c(
			Name = name,
			POC_Field_Label__c = pocFieldLabel,
			Product_Cloud__c = productCloudId,
			Product_On_Prem__c = productOnPremId,
			Module__c = moduleId
		);
	}

    public static void seedRubySettings() {
		Type rubyTestHelperType = Type.forName('Ruby_TestHelper');

		if (rubyTestHelperType != null) {
			((Callable) rubyTestHelperType.newInstance()).call('seed', null);
		}
	}
}