/**
 * @Business: Test class of SDRMappingEditController
 * @Date: 2019-08-08
 * @Author: Cumulus Vision
 * @Request: TAN-796
 * Modified  ModifiedDate   Description
 * TAN-796   2019-08-08     Initial development
 * TAN-799   2019-08-13     Updated test method for this task changes
 */

@isTest
public class SDRMappingEditControllerTest {
	@testSetup
	static void createTestData() {
		Group leadQueue = new Group(Name = 'CA Lead Queue #TAN-796-1', Type = 'Queue');
		insert leadQueue;

		QueuesObject qSObject = new QueueSObject(QueueId = leadQueue.Id, SobjectType = 'Lead');
		insert qSObject;
	}

	// TEST METHODS
	static testMethod void testPageForInsert() {
		Group leadQueue = [SELECT Id FROM Group WHERE Name = 'CA Lead Queue #TAN-796-1'];

		PageReference pageRef = Page.SDRMappingEdit;
		Test.setCurrentPage(pageRef);

		Test.startTest();

		ApexPages.StandardController stdCon = new ApexPages.StandardController(new SDR_Mapping__c());
		SDRMappingEditController con = new SDRMappingEditController(stdCon);
		con.getQueues();
		con.sdrMapping.Country__c = 'United States';
		con.sdrMapping.State_Province__c = 'CA';
		con.sdrMapping.Queue_ID__c = leadQueue.Id;
		con.save();

		Test.stopTest();

		// Assert the functionality
		List<SDR_Mapping__c> listMapping = [
			SELECT Id
			FROM SDR_Mapping__c
			WHERE Queue_ID__c = :leadQueue.Id
		];
		System.assertEquals(false, listMapping.isEmpty());
	}

	static testMethod void testPageForUpdate() {
		Group leadQueue = [SELECT Id FROM Group WHERE Name = 'CA Lead Queue #TAN-796-1'];

		SDR_Mapping__c sdrMap = new SDR_Mapping__c(
			Country__c = 'United States',
			State_Province__c = 'NY'
		);
		insert sdrMap;

		PageReference pageRef = Page.SDRMappingEdit;
		Test.setCurrentPage(pageRef);

		Test.startTest();

		ApexPages.StandardController stdCon = new ApexPages.StandardController(sdrMap);
		SDRMappingEditController con = new SDRMappingEditController(stdCon);
		con.getQueues();
		con.sdrMapping.Country__c = 'United States';
		con.sdrMapping.State_Province__c = 'CA';
		con.sdrMapping.Queue_ID__c = leadQueue.Id;
		con.save();

		Test.stopTest();

		// Assert the functionality
		List<SDR_Mapping__c> listMapping = [
			SELECT Id
			FROM SDR_Mapping__c
			WHERE Queue_ID__c = :leadQueue.Id
		];
		System.assertEquals(false, listMapping.isEmpty());
	}

	static testMethod void increaseCodeCoverage() {
		PageReference pageRef = Page.SDRMappingEdit;
		Test.setCurrentPage(pageRef);

		Test.startTest();

		ApexPages.StandardController stdCon = new ApexPages.StandardController(new SDR_Mapping__c());
		SDRMappingEditController con = new SDRMappingEditController(stdCon);
		con.sdrMapping.Country__c = 'United States';
		con.sdrMapping.State_Province__c = 'CA';
		con.sdrMapping.Queue_ID__c = null;
		con.save();

		con.sdrMapping.Country__c = 'United States';
		con.sdrMapping.State_Province__c = null;
		con.save();

		con.cancel();

		Test.stopTest();
	}
}