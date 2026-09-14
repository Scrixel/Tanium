@isTest
private class CustomAssetEditTest {
	private static RecordType ConsumerAccrt = [
		SELECT Id
		FROM RecordType
		WHERE SObjectType = 'Account' AND DeveloperName = 'Client'
	];
	static void CreateRecords() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'LeadTriggerHandler' }
		);
	}

	static testMethod void testcustomAssetEdit() {
		CreateRecords();

		PageReference pageRef = Page.CustomAssetEdit;
		Test.setCurrentPageReference(pageRef);

		Account acc = new Account();
		acc.Name = 'test';
		acc.Total_Addressable_Seats__c = 5;
		acc.RecordTypeId = ConsumerAccrt.Id;
		acc.Active__c = 'Active';
		acc.Type = 'Prospect';

		insert acc;

		List<Product_Type__c> lsPro = new List<Product_Type__c>();
		lsPro.add(new Product_Type__c(Name = 'Authoring'));
		lsPro.add(new Product_Type__c(Name = 'Client & Serve'));
		lsPro.add(new Product_Type__c(Name = 'Connect/API'));
		lsPro.add(new Product_Type__c(Name = 'IOC Detect'));
		lsPro.add(new Product_Type__c(Name = 'IR'));
		lsPro.add(new Product_Type__c(Name = 'Patch'));
		insert lsPro;

		ApexPages.CurrentPage().getparameters().put('retURL', acc.Id);

		Asset asset = new Asset();
		asset.Name = 'RI';
		asset.AccountId = acc.Id;
		asset.Quantity__c = 5;
		insert asset;

		ApexPages.StandardController sc = new ApexPages.standardController(asset);
		CustomAssetEdit cus = new CustomAssetEdit(sc);
		CustomAssetEdit.ProductWrapper cusPro = new CustomAssetEdit.ProductWrapper(
			new Product_Type__c(Name = 'Patch')
		);

		cus.lstProductWrapper[0].selected = true;
		cus.getRecordName();
		cus.strQty = '234';
		cus.save();

		for (Asset a : [SELECT Id, Name, Quantity__c, AccountId FROM Asset WHERE AccountId = :acc.Id]) {
			System.assertEquals(a.Quantity__c, 234);
		}

		// TO DO: implement unit test
	}
}