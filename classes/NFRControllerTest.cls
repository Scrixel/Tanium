/**
 * @Business: Test class for NFRController class
 * @Date: 2019-04-01
 * @Author: Cumulus Vision
 * @Request: TAN-762
 * Modified  ModifiedDate   Description
 * TAN-762   2019-04-01     Initial development
 */

@isTest
public class NFRControllerTest {
	@testSetup
	static void createTestData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'LeadTriggerHandler' }
		);
	}

	static testMethod void testNFRRecordCreation() {
		Test.startTest();

		PageReference pageRef = Page.NFR;
		Test.setCurrentPage(pageRef);

		// Instantiate a new controller
		NFRController cnt = new NFRController();

		// Assign Values to controller
		cnt.newNFR.Partner_Legal_Name__c = 'Test';
		cnt.newNFR.Requester_Type__c = 'Not a current Tanium Partner';
		cnt.newNFR.Partner_Type__c = 'Reseller';
		cnt.newNFR.NFR_Type__c = 'New';
		cnt.newNFR.NFR_Use_Case_Type__c = 'Integration Creation Request';
		cnt.newNFR.Number_of_Endpoints__c = 1;
		cnt.newNFR.Duration_Months__c = '5';

		// Check Submitt
		cnt.save();

		Test.stopTest();

		// Assert whether record created successfully or not
		System.assertEquals(false, cnt.isNFRNotCreated);
	}

	static testMethod void testNFRRecordFailure() {
		Test.startTest();

		PageReference pageRef = Page.NFR;
		Test.setCurrentPage(pageRef);

		// Instantiate a new controller
		NFRController cnt = new NFRController();

		// Assign Values to controller
		cnt.newNFR.Partner_Legal_Name__c = 'Test';
		cnt.newNFR.Requester_Type__c = 'Not a current Tanium Partner';
		cnt.newNFR.Partner_Type__c = 'Test Partner Type - FAKE';
		cnt.newNFR.NFR_Type__c = 'New';
		cnt.newNFR.NFR_Use_Case_Type__c = 'Integration Creation Request';
		cnt.newNFR.Number_of_Endpoints__c = 1;
		cnt.newNFR.Duration_Months__c = '5';

		// Check Submitt
		cnt.save();

		Test.stopTest();

		// Assert whether record created successfully or not
		System.assertEquals(true, cnt.isNFRNotCreated);
	}
}