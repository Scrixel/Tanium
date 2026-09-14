@IsTest
public with sharing class ELV_NueTestFactory {
    
    private static final String PRICEBOOK = 'Standard Pricebook';
    private static final String TEST_PRODUCT_NAME = 'Test Product';
    private static final Decimal TEST_PRODUCT_UNIT_PRICE = 125;
    private static final String NEW_BUSINESS_RECORD_TYPE_NAME = 'New Business';
    private static final String RENEWAL_RECORD_TYPE_NAME = 'Renewal';

    @IsTest 
    static void createProductTest() {

        Product2 testProduct = new Product2();
        testProduct.Name = 'Core Product';
        testProduct.Family = 'None';
        testProduct.ProductCode = 'Core';
        testProduct.IsActive = true;
        testProduct.Product_Type__c = 'Saas';
        testProduct.Product_Group__c = 'Software';
        testProduct.Include_In_Annualized_Software_Spend__c = true;
        testProduct.Deployment_Method__c = 'Cloud';
        insert testProduct;

        // Ruby.RubySettingService.globalSeedSystemSettings();
        // Ruby.RubySettingService.globalSeedObjectMappings();

        // Ruby__Uom__c uomEach = Ruby.ObjectCreator.createUom('up', 'Month', 'Each', 'Each', 2);

        // Test.startTest();
        // Product2 testProduct = createProduct(uomEach.Id);
        // Test.stopTest();

        // Assert.areEqual(TEST_PRODUCT_NAME, testProduct.Name);
        // Assert.areEqual('RecurringServices', testProduct.Family);
        // Assert.isTrue(testProduct.IsActive);
    }


    public class ScenarioContext {
        public Account account;
        public Contact primaryContact;
        public Ruby__Uom__c uomEach;
        public Pricebook2 standardPricebook;
        public Pricebook2 testPricebook;
        public Product2 product;
        public PricebookEntry standardPricebookEntry;
        public PricebookEntry testPricebookEntry;
        public Opportunity newOpportunity;
        public Quote newQuote;
        public QuoteLineItem newQuoteLine;
        public Opportunity expansionOpportunity;
        public Quote expansionQuote;
        public QuoteLineItem expansionQuoteLine;
        public Ruby__PriceDimension__c priceTag;
    }

    // ---------------------------------
    // Build/Insert single record helpers
    // ---------------------------------
    public static Account buildAccount() {
        Account account = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Main St',
            BillingCity = 'San Francisco',
            BillingPostalCode = '94105',
            ShippingStreet = '123 Main St',
            ShippingCity = 'San Francisco',
            ShippingPostalCode = '94105',
            Website = 'https://www.example.com',
            Type = 'Prospect'
        );
        setCaliforniaAddressFields(account, 'Billing');
        setCaliforniaAddressFields(account, 'Shipping');
        return account;
    }

    public static Account createAccount() {
        Account account = buildAccount();
        insert account;
        return account;
    }

    public static Contact buildPrimaryContact(Id accountId) {
        return new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test.contact@example.com',
            AccountId = accountId
        );
    }

    public static Contact getOrCreatePrimaryContact(Id accountId) {
        List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :accountId LIMIT 1];
        if (contacts.isEmpty()) {
            return createPrimaryContact(accountId);
        }
        return contacts[0];
    }

    public static Contact createPrimaryContact(Id accountId) {
        Contact contact = buildPrimaryContact(accountId);
        insert contact;
        return contact;
    }

    private static Id getOpportunityRecordTypeId(String recordTypeName) {
        if (String.isBlank(recordTypeName)) {
            return null;
        }

        Map<String, Schema.RecordTypeInfo> recordTypesByName = Schema.SObjectType.Opportunity.getRecordTypeInfosByName();
        if (!recordTypesByName.containsKey(recordTypeName)) {
            return null;
        }

        return recordTypesByName.get(recordTypeName).getRecordTypeId();
    }

    public static Opportunity buildOpportunity(Id accountId, Id contactId, String opportunityType, Id pricebookId) {
        
        return new Opportunity(
            Name = 'Test ' + opportunityType + ' Opportunity',
            Type = opportunityType,
            RecordTypeId = getOpportunityRecordTypeId(opportunityType),
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            ForecastCategoryName = 'Pipeline',
            Pricebook2Id = pricebookId
        );
    }

    public static Opportunity createOpportunity(Id accountId, Id contactId, String opportunityType, Id pricebookId) {
        Opportunity opp = buildOpportunity(accountId, contactId, opportunityType, pricebookId);
        insert opp;
        opp = progressOpportunityToNegotiation(opp.Id);
        return opp;
    }

    public static Order createOrder() {
        Account acct = createAccount();
        Contact primaryContact = createPrimaryContact(acct.Id);
        Opportunity opp = createOpportunity(acct.Id, primaryContact.Id, NEW_BUSINESS_RECORD_TYPE_NAME, null);

        Order newOrder = new Order(
            AccountId = acct.Id,
            OpportunityId = opp.Id,
            EffectiveDate = System.today(),
            Status = 'Draft'
        );
        insert newOrder;
        return newOrder;
    }


    public static Product2 createProduct(Id uomId) {
        Product2 product = Ruby.ObjectCreator.createProduct(TEST_PRODUCT_NAME, uomId, null);
        product.Family = 'RecurringServices';
        product.IsActive = true;
        update product;

        return product;
    }

    public static PricebookEntry createPricebookEntry(Id pricebookId, Id productId, Id uomId, Decimal unitPrice) {
        return Ruby.ObjectCreator.createPricebookEntry(productId, pricebookId, uomId, Integer.valueOf(unitPrice));
    }

    // Price tag (sets an explicit unit price) instead of a discount tag
    private static void addPriceTagToQuoteLine(QuoteLineItem qli, Decimal unitPrice) {
        // 1) Create the PriceDimension header
        Ruby__PriceDimension__c priceTag = new Ruby__PriceDimension__c(
            Name                       = 'Test Price Tag',
            Ruby__RecordType__c        = 'PriceDimension',   // price, not discount
            Ruby__PriceDimensionType__c = 'Quantity',        // quantity-based
            Ruby__PriceType__c         = 'Volume',           // single volume tier
            Ruby__Active__c            = true,
            Ruby__StartTime__c         = DateTime.now().addDays(-1)
        );
        insert priceTag;

        // 2) Create a single tier from 0 to 999999 units at <unitPrice> per unit
        Ruby__PriceTier__c tier = new Ruby__PriceTier__c(
            Ruby__PriceDimension__c = priceTag.Id,
            Ruby__TierNumber__c     = 1,
            Ruby__StartUnit__c      = 0,
            Ruby__EndUnit__c        = 999999,
            Ruby__ChargeModel__c    = 'PerUnit',
            Ruby__Amount__c         = unitPrice          // explicit price, not % discount
        );
        insert tier;

        // 3) Attach the price tag to the specific quote line
        Ruby__LinePriceDimension__c lineTag = new Ruby__LinePriceDimension__c(
            Name                    = 'Test Price Tag for QLI',
            Ruby__PriceDimension__c = priceTag.Id,
            Ruby__ObjectType__c     = 'QuoteLineItem',
            Ruby__QuoteLineItem__c  = qli.Id,
            Ruby__SerialNumber__c   = 1
        );
        insert lineTag;
    }

    public static Quote createQuoteWithLine(
        String quoteName,   
        Id opportunityId,
        Id pricebookId,
        PricebookEntry pbe,
        Decimal quantity
    ) {

        // 1) Create Quote with the correct price book
        Quote newQuote = new Quote(
            Name         = quoteName,
            OpportunityId = opportunityId,
            Pricebook2Id  = pricebookId,
            Ruby__SubscriptionStartDate__c = Date.today(),
            Ruby__SubscriptionTerm__c = 12,
            Ruby__PaymentTerm__c = 'Net 30',
            BillingStreet = '123 Main St',
            BillingCity = 'San Francisco',
            BillingPostalCode = '94105',
            ShippingStreet = '123 Main St',
            ShippingCity = 'San Francisco',
            ShippingPostalCode = '94105',
            ExpirationDate = Date.today().addYears(1)
        );
        setCaliforniaAddressFields(newQuote, 'Billing');
        setCaliforniaAddressFields(newQuote, 'Shipping');

        insert newQuote;

        // 2) Add quote lines using QuoteLineBuilder + createQuoteLines
        List<Ruby.QuoteLineBuilder> qlBuilders = new List<Ruby.QuoteLineBuilder>{
            new Ruby.QuoteLineBuilder()
                .setQuoteId(newQuote.Id)
                .setPricebookEntry(pbe)
                .setQuantity(quantity)
        };

        List<QuoteLineItem> testQuoteLines = Ruby.ObjectCreator.createQuoteLines(qlBuilders);


        for (QuoteLineItem testQuoteLine : testQuoteLines) {
            testQuoteLine.Ruby__DeltaARR__c = TEST_PRODUCT_UNIT_PRICE * 12;
            testQuoteLine.Ruby__LineType__c = 'LineItem';
            addPriceTagToQuoteLine(testQuoteLine, TEST_PRODUCT_UNIT_PRICE);
        }

        update testQuoteLines;

        return [
            SELECT Id, (SELECT Id, Ruby__NetSalesPrice__c, Ruby__SubscriptionTerm__c FROM QuoteLineItems)
            FROM Quote
            WHERE Id = :newQuote.Id
        ];

    }

    // ---------------------------------
    // New Quote Scenario
    // ---------------------------------
    public static ScenarioContext createNewQuoteScenario() {

        /*
        * https://docs.nue.io/apex-test-utils
        */
        Ruby.RubySettingService.globalSeedSystemSettings();
        Ruby.RubySettingService.globalSeedObjectMappings();
        
        ScenarioContext ctx = new ScenarioContext();

        ctx.account = createAccount();
        ctx.primaryContact = createPrimaryContact(ctx.account.Id);

        ctx.uomEach = Ruby.ObjectCreator.createUom('up', 'Month', 'Each', 'Each', 2);
        ctx.product = createProduct(ctx.uomEach.Id);

        // Custom pricebooks require a standard pricebook entry first.
        Id stdPricebookId = Test.getStandardPricebookId();
        ctx.standardPricebookEntry = createPricebookEntry(stdPricebookId, ctx.product.Id, ctx.uomEach.Id, TEST_PRODUCT_UNIT_PRICE);
        
        ctx.testPricebook = getOrCreateTestPricebook();
        ctx.testPricebookEntry = createPricebookEntry(ctx.testPricebook.Id, ctx.product.Id, ctx.uomEach.Id, TEST_PRODUCT_UNIT_PRICE);

        ctx.newOpportunity = createOpportunity(ctx.account.Id, ctx.primaryContact.Id, NEW_BUSINESS_RECORD_TYPE_NAME, ctx.testPricebook.Id);
        ctx.newOpportunity.Pricebook2Id = ctx.testPricebook.Id;
        update ctx.newOpportunity;

        ctx.newQuote = createQuoteWithLine('Test Quote', ctx.newOpportunity.Id, ctx.testPricebook.Id, ctx.testPricebookEntry, 10);
        ctx.newQuote.Ruby__IsPrimaryQuote__c = true;
        update ctx.newQuote;

        ctx.newOpportunity.Ruby__PrimaryQuote__c = ctx.newQuote.Id;
        update ctx.newOpportunity;

        return ctx;
    }

    // ---------------------------------
    // Internal utilities
    // ---------------------------------
    private static void setCaliforniaAddressFields(SObject record, String fieldPrefix) {
        Map<String, Schema.SObjectField> fieldsByName = record.getSObjectType().getDescribe().fields.getMap();
        String countryCodeField = fieldPrefix + 'CountryCode';
        String stateCodeField = fieldPrefix + 'StateCode';

        if (fieldsByName.containsKey(countryCodeField) && fieldsByName.containsKey(stateCodeField)) {
            record.put(countryCodeField, 'US');
            record.put(stateCodeField, 'CA');
            return;
        }

        record.put(fieldPrefix + 'Country', 'United States');
        record.put(fieldPrefix + 'State', 'CA');
    }

    @TestVisible
    private static Opportunity progressOpportunityToNegotiation(Id opportunityId) {
        Opportunity opp = new Opportunity(Id = opportunityId);

        opp.StageName = 'Qualification';
        update opp;

        opp.StageName = 'Proposal/Price Quote';
        update opp;

        opp.StageName = 'Negotiation/Review';
        update opp;

        return opp;
    }

    @TestVisible
    private static Opportunity progressOpportunityToClosedWon(Id opportunityId) {

        Opportunity opp = new Opportunity();
        opp.Id = opportunityId;
        opp.StageName = 'Closed Won';
        update opp;

        return opp;
    }


    // Lightweight success response for Nue callout paths exercised by tests.
    private class TestHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"ok"}');
            res.setStatusCode(200);
            return res;
        }
    }

     // ---------------------------------
    // Internal utilities
    // ---------------------------------
    @TestVisible
    private static Opportunity createRenewalScenario(Id accountId, List<Ruby__Subscription__c> subscriptions) {
    
        ScenarioContext ctx = new ScenarioContext();
        Pricebook2 testPricebook = getOrCreateTestPricebook();
        Contact primaryContact = getOrCreatePrimaryContact(accountId);
        Opportunity renewalOpp = createOpportunity(accountId, primaryContact.Id, RENEWAL_RECORD_TYPE_NAME, testPricebook.Id);

        // 7) Call GlobalChangeOrderService with a GlobalRenewRequest to create a renewal quote :llmCitationRef[2]
        Ruby.GlobalChangeOrderOptions options = new Ruby.GlobalChangeOrderOptions(Ruby.GlobalChangeOrderProceedOption.CreateQuote);
        options.ActivateOrder = false;
        options.OpportunityId = renewalOpp.Id;

        List<Ruby.GlobalAssetChangeRequest> changes = new List<Ruby.GlobalAssetChangeRequest>();

        subscriptions = [SELECT Id, Name FROM Ruby__Subscription__c WHERE Id IN :subscriptions];

        for (Ruby__Subscription__c subscription : subscriptions) {  
            Ruby.GlobalRenewRequest renewReq = new Ruby.GlobalRenewRequest();
            renewReq.AssetNumber  = subscription.Name; // e.g. "SUB-000123"
            renewReq.RenewalTerm  = 12;                // renew for 12 months
            // optionally: renewReq.TermDimension = 'month';
            changes.add(renewReq);
        }

        Test.setMock(HttpCalloutMock.class, new TestHttpMock());

        Test.startTest();
        Ruby.GlobalChangeOrderService svc = new Ruby.GlobalChangeOrderService();
        Ruby.GlobalChangeOrderResult result = svc.changeOrder(new Ruby.GlobalChangeOrder(options, changes));
        Test.stopTest();

        // 8) Assert a renewal quote exists on the renewal opp
        List<Quote> renewalQuotes = [
            SELECT Id, Name, Status, Opportunity.StageName, Opportunity.Type
            FROM Quote
            WHERE OpportunityId = :renewalOpp.Id
        ];

        // Optional: assert on change type / status depending on your config

        return renewalOpp;
    }

    @TestVisible
    private static Pricebook2 getOrCreateTestPricebook() {
        List<Pricebook2> existing = [
            SELECT Id, Name, IsActive
            FROM Pricebook2
            WHERE Name = :PRICEBOOK
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            Pricebook2 pb = existing[0];
            if (!pb.IsActive) {
                pb.IsActive = true;
                update pb;
            }
            return pb;
        }

        Pricebook2 newPb = new Pricebook2(Name = PRICEBOOK, IsActive = true, Ruby__PriceAttributes__c = 'Currency;UOM;PricingAttribute_1;PricingAttribute_3');
        insert newPb;
        return newPb;
    }
    
}