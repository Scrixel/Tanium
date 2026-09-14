/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 *
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class CustomAssetNewTest {
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

	static testMethod void myUnitTest() {
		// TO DO: implement unit test
		CreateRecords();

		PageReference pageRef = Page.CustomAssetNew;
		Test.setCurrentPageReference(pageRef);

		//first create an account
		Account acc = new Account(Name = 'Test Acc 0001');
		insert acc;

		Contact con = new Contact(LastName = 'TestConact 0001', AccountID = acc.id);
		insert con;

		Asset as1 = new Asset(Name = 'Test Asset 0001', ContactID = con.id, AccountId = acc.id);
		insert as1;

		List<Product_Type__c> lsPro = new List<Product_Type__c>();
		lsPro.add(new Product_Type__c(Name = 'Authoring'));
		lsPro.add(new Product_Type__c(Name = 'Client & Serve'));
		lsPro.add(new Product_Type__c(Name = 'Connect/API'));
		lsPro.add(new Product_Type__c(Name = 'IOC Detect'));
		lsPro.add(new Product_Type__c(Name = 'IR'));
		lsPro.add(new Product_Type__c(Name = 'Patch'));
		insert lsPro;

		//set parameter for the page
		ApexPages.currentPage().getParameters().put('acc_id', acc.id);

		CustomAssetNew can = new CustomAssetNew(new ApexPages.StandardController(as1));
		CustomAssetNew.ProductWrapper product1 = new CustomAssetNew.ProductWrapper(
			new Product_Type__c(Name = 'Patch')
		);

		can.lstProductWrapper[0].selected = true;
		can.getRecordName();
		can.strQty = '5';
		can.save();
	}
}