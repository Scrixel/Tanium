/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Tests for OpportunityManageAllocationsController.
 * @Date:     2026-09-22
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate  Description
 * SS-13901   2026-09-22    Initial development
 */
@IsTest
private class OpportunityManageAllocationsCntrTest {
	private static final String STAGE_CLOSED = Utility.CLOSED_WON;
	private static final String STAGE_AT_LOCK_THRESHOLD = 'Signed - Paperwork received';

	private static final String PRODUCT_LICENSE = 'Test License Product';
	private static final String PRODUCT_USAGE = 'Test Usage Product';
	private static final String PRODUCT_UNTYPED = 'Test Untyped Product';
	private static final String PRODUCT_ZERO_QUANTITY = 'Test Zero Quantity Product';

	private static final Integer LICENSE_QUANTITY = 1000;
	private static final Integer USAGE_LINE_QUANTITY = 500;
	private static final Integer USAGE_POOL = 300;
	private static final Integer UNTYPED_QUANTITY = 250;
	private static final Integer ZERO_LINE_QUANTITY = 100;

	private static final Decimal UNIT_PRICE = 100;

	private static final Date TERM_START = Date.today();
	private static final Date TERM_END = Date.today().addYears(1);

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'UserTriggerHandler',
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'ELV_QuoteTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Product2> products = new List<Product2>{
				buildTypedProduct(PRODUCT_LICENSE, true, false, null),
				buildTypedProduct(PRODUCT_USAGE, false, true, USAGE_POOL),
				buildTypedProduct(PRODUCT_UNTYPED, false, false, null),
				buildTypedProduct(PRODUCT_ZERO_QUANTITY, true, false, 0)
			};
			insert products;

			List<Integer> lineQuantities = new List<Integer>{
				LICENSE_QUANTITY,
				USAGE_LINE_QUANTITY,
				UNTYPED_QUANTITY,
				ZERO_LINE_QUANTITY
			};

			Account account = TestFactory.buildAccount('Manage Allocations Test Account');
			account.Type = 'Prospect';
			insert account;

			insert new List<Server_Deployment__c>{
				TestFactory.buildServerDeployment('Test Deployment A', account.Id),
				TestFactory.buildServerDeployment('Test Deployment B', account.Id)
			};

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Manage Allocations Test Opportunity',
				Date.today().addDays(30),
				Utility.PROSPECTING,
				account.Id
			);
			insert opportunity;

			Quote quote = TestFactory.buildQuote(
				'Manage Allocations Test Quote',
				opportunity.Id,
				TERM_START,
				TERM_END
			);
			quote.Ruby__IsPrimaryQuote__c = true;
			quote.Ruby__PaymentTerm__c = 'Net 30';
			insert quote;

			List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
			for (Product2 product : products) {
				pricebookEntries.add(
					TestFactory.buildPricebookEntry(
						product.Id,
						UNIT_PRICE,
						Test.getStandardPricebookId()
					)
				);
			}
			insert pricebookEntries;

			List<QuoteLineItem> quoteLines = new List<QuoteLineItem>();
			QuoteLineItem quoteLine;
			for (Integer i = 0; i < products.size(); i++) {
				quoteLine = TestFactory.buildQuoteLineItem(
					quote.Id,
					lineQuantities[i],
					UNIT_PRICE,
					pricebookEntries[i].Id
				);
				quoteLine.Product2Id = products[i].Id;
				quoteLine.Ruby__SubscriptionStartDate__c = TERM_START;
				quoteLine.Ruby__SubscriptionEndDate__c = TERM_END;
				quoteLines.add(quoteLine);
			}
			insert quoteLines;

			opportunity.Ruby__PrimaryQuote__c = quote.Id;
			update opportunity;
		}
	}

	@IsTest
	static void testGetAllocationScreenData_WhenTwoActiveDeployments_ReturnsEditableScreen() {
		Opportunity opportunity = getOpportunity();

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.isTrue(data.isEditable, 'Two active production deployments should be editable');
		Assert.isNull(data.readOnlyReason, 'An editable screen has no read-only reason');
		Assert.areEqual(opportunity.AccountId, data.accountId, 'Account Id should be returned');
		Assert.areEqual(
			opportunity.Ruby__PrimaryQuote__c,
			data.primaryQuoteId,
			'Primary Quote Id should be returned'
		);
		Assert.isNotNull(data.opportunityName, 'Opportunity name should be returned');
		Assert.isNotNull(data.accountName, 'Account name should be returned');
		Assert.isNotNull(data.primaryQuoteName, 'Primary Quote name should be returned');
		Assert.areEqual(
			2,
			data.serverDeploymentOptions.size(),
			'Both active production deployments should be options'
		);
		Assert.areEqual(0, data.rows.size(), 'No allocations exist yet');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenBlankTypeOrZeroQuantity_ExcludesQuoteLineOptions() {
		Opportunity opportunity = getOpportunity();

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		List<String> labels = new List<String>();
		for (OpportunityManageAllocationsController.QuoteLineOption option : data.quoteLineOptions) {
			labels.add(option.label);
		}

		QuoteLineItem untypedLine = getQuoteLine(PRODUCT_UNTYPED);
		QuoteLineItem zeroLine = getQuoteLine(PRODUCT_ZERO_QUANTITY);

		Assert.isNull(
			findOption(data.quoteLineOptions, PRODUCT_UNTYPED),
			'A product deriving a blank type should be filtered out. Its type resolved to "' +
			untypedLine.ELV_Opportunity_Server_Deployment_Type__c +
			'"'
		);
		Assert.isNull(
			findOption(data.quoteLineOptions, PRODUCT_ZERO_QUANTITY),
			'A quote line with no allocatable quantity should be filtered out. Its usage quantity is ' +
			zeroLine.ELV_UsageQuantity__c +
			' and its pool resolved to ' +
			zeroLine.ELV_Opp_Server_Deployment_Quantity__c
		);
		Assert.isNotNull(
			findOption(data.quoteLineOptions, PRODUCT_LICENSE),
			'A License product should be an option'
		);
		Assert.isNotNull(
			findOption(data.quoteLineOptions, PRODUCT_USAGE),
			'A Usage product should be an option'
		);
		Assert.areEqual(
			2,
			data.quoteLineOptions.size(),
			'Only the License and Usage quote lines are allocatable. Options were: ' + labels
		);
	}

	@IsTest
	static void testGetAllocationScreenData_Always_ReturnsTypeFromQuoteLine() {
		Opportunity opportunity = getOpportunity();

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.areEqual(
			'License',
			findOption(data.quoteLineOptions, PRODUCT_LICENSE).derivedType,
			'A deployment-required product resolves License'
		);
		Assert.areEqual(
			'Usage',
			findOption(data.quoteLineOptions, PRODUCT_USAGE).derivedType,
			'A product with a usage model resolves Usage'
		);
	}

	@IsTest
	static void testGetAllocationScreenData_WhenUsageQuantitySet_ReturnsUsageQuantityAsPool() {
		Opportunity opportunity = getOpportunity();

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.areEqual(
			LICENSE_QUANTITY,
			findOption(data.quoteLineOptions, PRODUCT_LICENSE).quantity.intValue(),
			'With no usage quantity the pool is the line quantity'
		);
		QuoteLineItem usageLine = getQuoteLine(PRODUCT_USAGE);

		Assert.areEqual(
			USAGE_POOL,
			findOption(data.quoteLineOptions, PRODUCT_USAGE).quantity.intValue(),
			'With a usage quantity set the pool is that, not the line quantity. Stored usage quantity: ' +
			usageLine.ELV_UsageQuantity__c +
			', stored pool: ' +
			usageLine.ELV_Opp_Server_Deployment_Quantity__c
		);
	}

	@IsTest
	static void testGetAllocationScreenData_Always_ReturnsUsagePeriodLabel() {
		Opportunity opportunity = getOpportunity();

		QuoteLineItem usageLine = [
			SELECT Id, ELV_UsagePeriod__c
			FROM QuoteLineItem
			WHERE Product2.Name = :PRODUCT_USAGE
			LIMIT 1
		];

		Assert.isNotNull(
			usageLine.ELV_UsagePeriod__c,
			'Setup must leave a usage period on the quote line or this test proves nothing'
		);

		String expectedLabel = picklistLabel(
			QuoteLineItem.ELV_UsagePeriod__c,
			usageLine.ELV_UsagePeriod__c
		);

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.areEqual(
			expectedLabel,
			findOption(data.quoteLineOptions, PRODUCT_USAGE).usagePeriod,
			'Usage Period should be the picklist label, not the API value'
		);
		Assert.isTrue(
			String.isBlank(findOption(data.quoteLineOptions, PRODUCT_LICENSE).usagePeriod),
			'A quote line with no usage period stays blank'
		);
	}

	@IsTest
	static void testGetAllocationScreenData_Always_ReturnsSubscriptionTerm() {
		Opportunity opportunity = getOpportunity();

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		OpportunityManageAllocationsController.QuoteLineOption option = findOption(
			data.quoteLineOptions,
			PRODUCT_LICENSE
		);

		Assert.areEqual(TERM_START, option.startDate, 'Start date comes from the quote line');
		Assert.areEqual(TERM_END, option.endDate, 'End date comes from the quote line');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenIdIsNull_ThrowsException() {
		Boolean threw = false;

		Test.startTest();
		try {
			OpportunityManageAllocationsController.getAllocationScreenData(null);
		} catch (AuraHandledException e) {
			threw = true;
		}
		Test.stopTest();

		Assert.isTrue(threw, 'A null Id should be rejected rather than queried for');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenIdIsNotOpportunity_ThrowsException() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Boolean threw = false;

		Test.startTest();
		try {
			OpportunityManageAllocationsController.getAllocationScreenData(account.Id);
		} catch (AuraHandledException e) {
			threw = true;
		}
		Test.stopTest();

		Assert.isTrue(threw, 'An Id belonging to another object should be rejected');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenOpportunityNotFound_ThrowsException() {
		Opportunity opportunity = getOpportunity();
		Id missingId = opportunity.Id;
		System.runAs(TestUserFactory.getAdminUser()) {
			delete opportunity;
		}

		Boolean threw = false;

		Test.startTest();
		try {
			OpportunityManageAllocationsController.getAllocationScreenData(missingId);
		} catch (AuraHandledException e) {
			threw = true;
		}
		Test.stopTest();

		Assert.isTrue(threw, 'An Opportunity that cannot be found should be rejected');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenOpportunityClosed_ReturnsReadOnly() {
		Opportunity opportunity = getOpportunity();
		opportunity.StageName = STAGE_CLOSED;
		System.runAs(TestUserFactory.getAdminUser()) {
			update opportunity;
		}

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.isFalse(data.isEditable, 'A closed Opportunity cannot be edited');
		Assert.areEqual('CLOSED', data.readOnlyReason, 'Reason code drives the LWC message');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenStageAtLockThreshold_ReturnsReadOnly() {
		Opportunity opportunity = getOpportunity();
		opportunity.StageName = STAGE_AT_LOCK_THRESHOLD;
		System.runAs(TestUserFactory.getAdminUser()) {
			update opportunity;
		}

		Opportunity reloaded = [
			SELECT Id, IsClosed, StageNumber__c
			FROM Opportunity
			WHERE Id = :opportunity.Id
		];

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.isFalse(reloaded.IsClosed, 'This stage is open, so IsClosed cannot be what locks it');
		Assert.areEqual(170, reloaded.StageNumber__c.intValue(), 'This stage is the lock threshold');
		Assert.isFalse(data.isEditable, 'At or past the lock threshold the screen is read only');
		Assert.areEqual('CLOSED', data.readOnlyReason, 'Reason code drives the LWC message');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenStageBelowLockThreshold_ReturnsEditable() {
		Opportunity opportunity = getOpportunity();

		Opportunity reloaded = [
			SELECT Id, StageNumber__c
			FROM Opportunity
			WHERE Id = :opportunity.Id
		];

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.isTrue(reloaded.StageNumber__c < 170, 'Prospecting is below the lock threshold');
		Assert.isTrue(data.isEditable, 'Below the threshold the screen stays editable');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenOneDeployment_ReturnsEditable() {
		Opportunity opportunity = getOpportunity();
		System.runAs(TestUserFactory.getAdminUser()) {
			delete [SELECT Id FROM Server_Deployment__c LIMIT 1];
		}

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.isTrue(data.isEditable, 'One active production deployment is enough to allocate');
		Assert.isNull(data.readOnlyReason, 'An editable screen has no read-only reason');
		Assert.areEqual(
			1,
			data.serverDeploymentOptions.size(),
			'The remaining deployment should still be an option'
		);
	}

	@IsTest
	static void testGetAllocationScreenData_WhenNoDeployments_ReturnsReadOnly() {
		Opportunity opportunity = getOpportunity();
		System.runAs(TestUserFactory.getAdminUser()) {
			delete [SELECT Id FROM Server_Deployment__c];
		}

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.isFalse(data.isEditable, 'No deployments means nothing to allocate to');
		Assert.areEqual('NO_DEPLOYMENTS', data.readOnlyReason, 'Reason code drives the message');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenDeploymentNotActiveProduction_ExcludesDeploymentOptions() {
		Opportunity opportunity = getOpportunity();

		List<Server_Deployment__c> deployments = getDeployments();
		deployments[0].Status__c = 'Inactive';
		deployments[1].Type__c = 'Test';
		System.runAs(TestUserFactory.getAdminUser()) {
			update deployments;
		}

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.areEqual(
			0,
			data.serverDeploymentOptions.size(),
			'Neither an inactive nor a non-production deployment should be an option'
		);
	}

	@IsTest
	static void testGetAllocationScreenData_WhenNoPrimaryQuote_ReturnsNoQuoteLineOptions() {
		Opportunity opportunity = getOpportunity();
		opportunity.Ruby__PrimaryQuote__c = null;
		System.runAs(TestUserFactory.getAdminUser()) {
			update opportunity;
		}

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.isNull(data.primaryQuoteId, 'No Primary Quote to report');
		Assert.areEqual(0, data.quoteLineOptions.size(), 'No products to allocate');
		Assert.isTrue(data.isEditable, 'Still editable - the LWC shows a warning, not a lock');
	}

	@IsTest
	static void testSaveAllocations_WhenNewRows_InsertsAllocations() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();
		Id quoteLineId = getQuoteLineId(PRODUCT_LICENSE);

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, quoteLineId, deployments[0].Id, 600, false),
			buildRow('new-2', null, quoteLineId, deployments[1].Id, 400, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(2, response.successCount, 'Both rows fit within the quantity of 1,000');
		Assert.areEqual(0, response.failureCount, 'Neither row should be rejected');
		Assert.areEqual(2, response.savedRows.size(), 'Response carries the committed screen');

		List<Opportunity_Server_deployment__c> allocations = [
			SELECT
				Id,
				Account__c,
				Opportunity__c,
				ELV_QuoteLineItem__c,
				Server_Deployment__c,
				ELV_AllocationQuantity__c,
				ELV_Type__c
			FROM Opportunity_Server_deployment__c
		];

		Assert.areEqual(2, allocations.size(), 'Two records should exist');

		for (Opportunity_Server_deployment__c allocation : allocations) {
			Assert.areEqual(opportunity.Id, allocation.Opportunity__c, 'Opportunity is stamped');
			Assert.areEqual(opportunity.AccountId, allocation.Account__c, 'Account is stamped');
			Assert.areEqual(quoteLineId, allocation.ELV_QuoteLineItem__c, 'Quote line is stamped');
			Assert.isNotNull(allocation.Server_Deployment__c, 'Deployment is stamped');
			Assert.areEqual(
				'License',
				allocation.ELV_Type__c,
				'The formula should resolve Type from the quote line'
			);
		}
	}

	@IsTest
	static void testSaveAllocations_WhenUsageProduct_InsertsAllocation() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, getQuoteLineId(PRODUCT_USAGE), deployments[0].Id, 100, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(1, response.successCount, 'A Usage row should save');

		Opportunity_Server_deployment__c allocation = [
			SELECT Id, ELV_Type__c
			FROM Opportunity_Server_deployment__c
			LIMIT 1
		];

		Assert.areEqual('Usage', allocation.ELV_Type__c, 'The formula should resolve Usage');
	}

	@IsTest
	static void testSaveAllocations_WhenExistingRowEdited_UpdatesQuantity() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();
		Id quoteLineId = getQuoteLineId(PRODUCT_LICENSE);

		Opportunity_Server_deployment__c existing = insertAllocation(
			opportunity,
			quoteLineId,
			deployments[0].Id,
			10
		);

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('row-1', existing.Id, quoteLineId, deployments[0].Id, 750, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(1, response.successCount, 'The edit should commit');

		Opportunity_Server_deployment__c reloaded = [
			SELECT Id, ELV_AllocationQuantity__c
			FROM Opportunity_Server_deployment__c
			WHERE Id = :existing.Id
		];

		Assert.areEqual(
			750,
			reloaded.ELV_AllocationQuantity__c.intValue(),
			'Quantity should be updated'
		);
	}

	@IsTest
	static void testSaveAllocations_WhenRowMarkedForDeletion_DeletesAllocation() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();
		Id quoteLineId = getQuoteLineId(PRODUCT_LICENSE);

		Opportunity_Server_deployment__c existing = insertAllocation(
			opportunity,
			quoteLineId,
			deployments[0].Id,
			10
		);

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('row-1', existing.Id, quoteLineId, deployments[0].Id, 10, true)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(1, response.successCount, 'The delete should commit');
		Assert.areEqual(
			0,
			[SELECT COUNT() FROM Opportunity_Server_deployment__c],
			'The record should be gone'
		);
	}

	@IsTest
	static void testSaveAllocations_WhenUnsavedRowMarkedForDeletion_SkipsDml() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, getQuoteLineId(PRODUCT_LICENSE), deployments[0].Id, 10, true)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(0, response.successCount, 'Nothing was written');
		Assert.areEqual(0, response.failureCount, 'Nothing failed either');
		Assert.areEqual(
			0,
			[SELECT COUNT() FROM Opportunity_Server_deployment__c],
			'No record should have been created'
		);
	}

	@IsTest
	static void testSaveAllocations_WhenRowsExceedQuantity_RejectsRows() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();
		Id quoteLineId = getQuoteLineId(PRODUCT_LICENSE);

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, quoteLineId, deployments[0].Id, 800, false),
			buildRow('new-2', null, quoteLineId, deployments[1].Id, 400, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(0, response.successCount, 'Neither row should commit');
		Assert.areEqual(2, response.failureCount, 'Both rows share the blame for the overage');
		Assert.areEqual(
			0,
			[SELECT COUNT() FROM Opportunity_Server_deployment__c],
			'Nothing should be written'
		);

		for (OpportunityManageAllocationsController.RowResult result : response.results) {
			Assert.isFalse(result.success, 'Every result should be a failure');
			Assert.isTrue(
				result.message.contains('exceeds'),
				'The message should say what went wrong: ' + result.message
			);
		}
	}

	@IsTest
	static void testSaveAllocations_WhenUsageRowExceedsUsageQuantity_RejectsRow() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();
		Id quoteLineId = getQuoteLineId(PRODUCT_USAGE);

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, quoteLineId, deployments[0].Id, USAGE_POOL + 1, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(
			1,
			response.failureCount,
			'The usage quantity is the pool, not the larger line quantity'
		);
		Assert.areEqual(
			0,
			[SELECT COUNT() FROM Opportunity_Server_deployment__c],
			'Nothing should be written'
		);
	}

	@IsTest
	static void testSaveAllocations_WhenUsageRowMatchesUsageQuantity_InsertsAllocation() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, getQuoteLineId(PRODUCT_USAGE), deployments[0].Id, USAGE_POOL, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(1, response.successCount, 'Exactly the usage quantity fits');
		Assert.areEqual(0, response.failureCount, 'Filling the pool is not an overage');
	}

	@IsTest
	static void testSaveAllocations_WhenOneRowExceedsQuantity_CommitsRemainingRows() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, getQuoteLineId(PRODUCT_LICENSE), deployments[0].Id, 300, false),
			buildRow('new-2', null, getQuoteLineId(PRODUCT_USAGE), deployments[0].Id, 900, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(1, response.successCount, 'The row that fits should commit');
		Assert.areEqual(1, response.failureCount, 'The row that does not should be rejected');
		Assert.areEqual(
			1,
			[SELECT COUNT() FROM Opportunity_Server_deployment__c],
			'Only the good row should exist'
		);
	}

	@IsTest
	static void testSaveAllocations_WhenRewritingSameQuantity_CommitsRow() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();
		Id quoteLineId = getQuoteLineId(PRODUCT_LICENSE);

		Opportunity_Server_deployment__c existing = insertAllocation(
			opportunity,
			quoteLineId,
			deployments[0].Id,
			LICENSE_QUANTITY
		);

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('row-1', existing.Id, quoteLineId, deployments[0].Id, LICENSE_QUANTITY, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(1, response.successCount, 'Rewriting a row at the same total is valid');
		Assert.areEqual(0, response.failureCount, 'It must not collide with its own old value');
	}

	@IsTest
	static void testSaveAllocations_WhenRowHasNoQuoteLine_ReturnsRowResult() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, null, deployments[0].Id, 10, false)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(
			1,
			response.results.size(),
			'A row with no quote line still reports an outcome'
		);
	}

	@IsTest
	static void testSaveAllocations_WhenRecordAlreadyDeleted_ReturnsRowFailure() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();
		Id quoteLineId = getQuoteLineId(PRODUCT_LICENSE);

		Opportunity_Server_deployment__c existing = insertAllocation(
			opportunity,
			quoteLineId,
			deployments[0].Id,
			10
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			delete existing;
		}

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('row-1', existing.Id, quoteLineId, deployments[0].Id, 10, true)
		};

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = save(opportunity.Id, rows);
		Test.stopTest();

		Assert.areEqual(0, response.successCount, 'Deleting a deleted record cannot succeed');
		Assert.areEqual(1, response.failureCount, 'The row should report its own failure');
		Assert.isNotNull(response.results[0].message, 'A failed row carries the database message');
	}

	@IsTest
	static void testSaveAllocations_WhenOpportunityClosed_ThrowsException() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();

		List<Map<String, Object>> rows = new List<Map<String, Object>>{
			buildRow('new-1', null, getQuoteLineId(PRODUCT_LICENSE), deployments[0].Id, 10, false)
		};

		opportunity.StageName = STAGE_CLOSED;
		System.runAs(TestUserFactory.getAdminUser()) {
			update opportunity;
		}

		Boolean threw = false;

		Test.startTest();
		try {
			OpportunityManageAllocationsController.saveAllocations(opportunity.Id, toJson(rows));
		} catch (AuraHandledException e) {
			threw = true;
		}
		Test.stopTest();

		Assert.isTrue(threw, 'Saving against a closed Opportunity should be refused');
		Assert.areEqual(
			0,
			[SELECT COUNT() FROM Opportunity_Server_deployment__c],
			'Nothing should be written'
		);
	}

	@IsTest
	static void testSaveAllocations_WhenIdIsNull_ThrowsException() {
		Boolean threw = false;

		Test.startTest();
		try {
			OpportunityManageAllocationsController.saveAllocations(null, null);
		} catch (AuraHandledException e) {
			threw = true;
		}
		Test.stopTest();

		Assert.isTrue(threw, 'Saving without an Opportunity should be refused');
	}

	@IsTest
	static void testSaveAllocations_WhenNoRows_ReturnsCurrentScreen() {
		Opportunity opportunity = getOpportunity();

		Test.startTest();
		OpportunityManageAllocationsController.SaveResponse response = OpportunityManageAllocationsController.saveAllocations(
			opportunity.Id,
			null
		);
		Test.stopTest();

		Assert.areEqual(0, response.successCount, 'Nothing to save');
		Assert.areEqual(0, response.failureCount, 'Nothing to fail');
		Assert.areEqual(0, response.savedRows.size(), 'No allocations exist');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenAllocationExists_ReturnsRowWithFormulaValues() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();
		Id quoteLineId = getQuoteLineId(PRODUCT_LICENSE);

		insertAllocation(opportunity, quoteLineId, deployments[0].Id, 250);

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.areEqual(1, data.rows.size(), 'The saved allocation should be returned');

		OpportunityManageAllocationsController.AllocationRow row = data.rows[0];

		Assert.areEqual(quoteLineId, row.quoteLineItemId, 'Quote line Id round-trips');
		Assert.areEqual(PRODUCT_LICENSE, row.productName, 'Product name is resolved for display');
		Assert.areEqual(250, row.quantity.intValue(), 'Quantity round-trips');
		Assert.areEqual('License', row.type, 'Type comes from the formula on the record');
		Assert.areEqual(TERM_START, row.startDate, 'Start date comes from the formula');
		Assert.areEqual(TERM_END, row.endDate, 'End date comes from the formula');
		Assert.isNotNull(row.serverDeploymentName, 'Deployment name is resolved for display');
		Assert.isNotNull(row.recordId, 'Record Id is returned');
	}

	@IsTest
	static void testGetAllocationScreenData_WhenAllocationExists_ReturnsMatchingUsagePeriod() {
		Opportunity opportunity = getOpportunity();
		List<Server_Deployment__c> deployments = getDeployments();

		insertAllocation(opportunity, getQuoteLineId(PRODUCT_USAGE), deployments[0].Id, 25);

		Test.startTest();
		OpportunityManageAllocationsController.AllocationScreenData data = loadScreen(opportunity.Id);
		Test.stopTest();

		Assert.isNotNull(
			findOption(data.quoteLineOptions, PRODUCT_USAGE).usagePeriod,
			'Both sides being blank would make this comparison meaningless'
		);
		Assert.areEqual(
			findOption(data.quoteLineOptions, PRODUCT_USAGE).usagePeriod,
			data.rows[0].usagePeriod,
			'A saved row and a new row for the same product must show the same Usage Period'
		);
	}

	private static OpportunityManageAllocationsController.AllocationScreenData loadScreen(
		Id opportunityId
	) {
		return OpportunityManageAllocationsController.getAllocationScreenData(opportunityId);
	}

	private static OpportunityManageAllocationsController.SaveResponse save(
		Id opportunityId,
		List<Map<String, Object>> rows
	) {
		return OpportunityManageAllocationsController.saveAllocations(opportunityId, toJson(rows));
	}

	private static Product2 buildTypedProduct(
		String name,
		Boolean deploymentRequired,
		Boolean isUsage,
		Decimal usageQuantity
	) {
		Product2 product = TestFactory.buildProduct(name, name);
		product.Server_Deployment_Required__c = deploymentRequired;
		product.ELV_UsageQuantity__c = usageQuantity;

		if (isUsage) {
			product.ELV_UsageModel__c = firstPicklistValue(Product2.ELV_UsageModel__c);
			product.ELV_UsagePeriod__c = firstPicklistValue(Product2.ELV_UsagePeriod__c);
		}

		return product;
	}

	private static String firstPicklistValue(Schema.SObjectField field) {
		for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
			if (entry.isActive()) {
				return entry.getValue();
			}
		}

		return null;
	}

	private static String picklistLabel(Schema.SObjectField field, String apiValue) {
		for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
			if (entry.getValue() == apiValue) {
				return entry.getLabel();
			}
		}

		return apiValue;
	}

	private static Opportunity getOpportunity() {
		return [SELECT Id, AccountId, Ruby__PrimaryQuote__c FROM Opportunity LIMIT 1];
	}

	private static QuoteLineItem getQuoteLine(String productName) {
		return [
			SELECT
				Id,
				Quantity,
				ELV_UsageQuantity__c,
				ELV_UsagePeriod__c,
				ELV_Opportunity_Server_Deployment_Type__c,
				ELV_Opp_Server_Deployment_Quantity__c
			FROM QuoteLineItem
			WHERE Product2.Name = :productName
			LIMIT 1
		];
	}

	private static Id getQuoteLineId(String productName) {
		return [SELECT Id FROM QuoteLineItem WHERE Product2.Name = :productName LIMIT 1].Id;
	}

	private static List<Server_Deployment__c> getDeployments() {
		return [SELECT Id, Status__c, Type__c FROM Server_Deployment__c ORDER BY Name];
	}

	private static Opportunity_Server_deployment__c insertAllocation(
		Opportunity opportunity,
		Id quoteLineItemId,
		Id serverDeploymentId,
		Decimal quantity
	) {
		Opportunity_Server_deployment__c allocation = TestFactory.buildOppServerDep(
			opportunity.AccountId,
			opportunity.Id,
			serverDeploymentId,
			quoteLineItemId,
			quantity
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			insert allocation;
		}
		return allocation;
	}

	private static Map<String, Object> buildRow(
		String key,
		Id recordId,
		Id quoteLineItemId,
		Id serverDeploymentId,
		Decimal quantity,
		Boolean isMarkedForDeletion
	) {
		return new Map<String, Object>{
			'key' => key,
			'recordId' => recordId,
			'quoteLineItemId' => quoteLineItemId,
			'serverDeploymentId' => serverDeploymentId,
			'quantity' => quantity,
			'isMarkedForDeletion' => isMarkedForDeletion
		};
	}

	private static String toJson(List<Map<String, Object>> rows) {
		return JSON.serialize(rows);
	}

	private static OpportunityManageAllocationsController.QuoteLineOption findOption(
		List<OpportunityManageAllocationsController.QuoteLineOption> options,
		String label
	) {
		for (OpportunityManageAllocationsController.QuoteLineOption option : options) {
			if (option.label == label) {
				return option;
			}
		}

		return null;
	}
}