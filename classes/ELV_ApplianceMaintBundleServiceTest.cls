/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI-187. Coverage for ELV_ApplianceMaintenanceBundleService.
 *
 *   Uses whatever 2 of the 8 in-scope SKUs exist as Product2/PricebookEntry
 *   records in the running org (queried, not hardcoded Ids) - the 8 SKUs
 *   themselves are assumed to already exist per TNCI-187's approved scope.
 */
@IsTest(SeeAllData=true)
private class ELV_ApplianceMaintBundleServiceTest {
	private static final String HARDWARE_SKU = 'TAN-S-330-CP';
	private static final String MAINTENANCE_SKU = 'TAN-S-SUM';

	@IsTest
	static void insertingHardwareLineAutoAddsLockedMaintenanceLine() {
		TestData data = setup();

		Test.startTest();
		insert new QuoteLineItem(
			QuoteId = data.quote.Id,
			Product2Id = data.hardwareProduct.Id,
			PricebookEntryId = data.hardwarePbe.Id,
			Quantity = 1,
			UnitPrice = 1000
		);
		Test.stopTest();

		List<QuoteLineItem> maintenanceLines = [
			SELECT Id, Quantity, ELV_Auto_Added_Maintenance__c, ELV_Auto_Added_From_Line__c,
				Ruby__ParentId__c, Ruby__RootId__c, ELV_Bundled_Product__c, Ruby__ProductOption__c
			FROM QuoteLineItem
			WHERE QuoteId = :data.quote.Id
			AND Product2Id = :data.maintenanceProduct.Id
		];
		System.assertEquals(1, maintenanceLines.size(), 'Expected exactly one auto-added maintenance line.');
		System.assertEquals(true, maintenanceLines[0].ELV_Auto_Added_Maintenance__c);
		System.assertEquals(1, maintenanceLines[0].Quantity);
		System.assertNotEquals(null, maintenanceLines[0].ELV_Auto_Added_From_Line__c);

		List<QuoteLineItem> hardwareLines = [
			SELECT Id
			FROM QuoteLineItem
			WHERE QuoteId = :data.quote.Id
			AND Product2Id = :data.hardwareProduct.Id
		];
		System.assertEquals(1, hardwareLines.size());
		System.assertEquals(
			true,
			maintenanceLines[0].ELV_Bundled_Product__c,
			'Maintenance line must be flagged as a bundled child so the Quote Line Editor nests it.'
		);
		System.assertEquals(
			hardwareLines[0].Id,
			maintenanceLines[0].Ruby__ParentId__c,
			'Maintenance line must point Ruby__ParentId__c at its hardware line.'
		);
		System.assertEquals(
			hardwareLines[0].Id,
			maintenanceLines[0].Ruby__RootId__c,
			'Maintenance line must point Ruby__RootId__c at its hardware line.'
		);
		System.assertNotEquals(
			null,
			maintenanceLines[0].Ruby__ProductOption__c,
			'Maintenance line should reference the existing static Product Option config for this pairing.'
		);
	}

	@IsTest
	static void editingLockedMaintenanceLineDirectlyFails() {
		TestData data = setup();
		QuoteLineItem maintenanceLine = insertHardwareAndGetMaintenanceLine(data);

		maintenanceLine.Quantity = 2;
		Database.SaveResult result = Database.update(maintenanceLine, false);

		System.assertEquals(false, result.isSuccess());
		System.assert(
			result.getErrors()[0].getMessage().contains('cannot be edited directly'),
			result.getErrors()[0].getMessage()
		);
	}

	@IsTest
	static void deletingLockedMaintenanceLineDirectlyFails() {
		TestData data = setup();
		QuoteLineItem maintenanceLine = insertHardwareAndGetMaintenanceLine(data);

		Database.DeleteResult result = Database.delete(maintenanceLine, false);

		System.assertEquals(false, result.isSuccess());
		System.assert(
			result.getErrors()[0].getMessage().contains('cannot be removed directly'),
			result.getErrors()[0].getMessage()
		);
	}

	@IsTest
	static void deletingHardwareLineCascadeDeletesMaintenanceLine() {
		TestData data = setup();

		QuoteLineItem hardwareLine = new QuoteLineItem(
			QuoteId = data.quote.Id,
			Product2Id = data.hardwareProduct.Id,
			PricebookEntryId = data.hardwarePbe.Id,
			Quantity = 1,
			UnitPrice = 1000
		);
		insert hardwareLine;

		delete hardwareLine;

		List<QuoteLineItem> remainingMaintenanceLines = [
			SELECT Id
			FROM QuoteLineItem
			WHERE QuoteId = :data.quote.Id
			AND Product2Id = :data.maintenanceProduct.Id
		];
		System.assertEquals(0, remainingMaintenanceLines.size());
	}

	private static QuoteLineItem insertHardwareAndGetMaintenanceLine(TestData data) {
		insert new QuoteLineItem(
			QuoteId = data.quote.Id,
			Product2Id = data.hardwareProduct.Id,
			PricebookEntryId = data.hardwarePbe.Id,
			Quantity = 1,
			UnitPrice = 1000
		);

		return [
			SELECT Id, Quantity, Product2Id
			FROM QuoteLineItem
			WHERE QuoteId = :data.quote.Id
			AND Product2Id = :data.maintenanceProduct.Id
			LIMIT 1
		];
	}

	private class TestData {
		Product2 hardwareProduct;
		Product2 maintenanceProduct;
		PricebookEntry hardwarePbe;
		Quote quote;
	}

	private static TestData setup() {
		TestData data = new TestData();

		data.hardwareProduct = [SELECT Id FROM Product2 WHERE ProductCode = :HARDWARE_SKU LIMIT 1];
		data.maintenanceProduct = [
			SELECT Id
			FROM Product2
			WHERE ProductCode = :MAINTENANCE_SKU
			LIMIT 1
		];

		Id standardPricebookId = Test.getStandardPricebookId();
		data.hardwarePbe = [
			SELECT Id
			FROM PricebookEntry
			WHERE Product2Id = :data.hardwareProduct.Id
			AND Pricebook2Id = :standardPricebookId
			LIMIT 1
		];

		Account account = new Account(Name = 'TNCI-187 Test Account');
		insert account;

		Opportunity opportunity = new Opportunity(
			Name = 'TNCI-187 Test Opportunity',
			AccountId = account.Id,
			StageName = 'Prospecting',
			CloseDate = Date.today().addDays(30)
		);
		insert opportunity;

		// The Quote must carry the same pricebook as the PricebookEntry used on its lines.
		data.quote = new Quote(
			Name = 'TNCI-187 Test Quote',
			OpportunityId = opportunity.Id,
			Pricebook2Id = standardPricebookId
		);
		insert data.quote;

		return data;
	}
}