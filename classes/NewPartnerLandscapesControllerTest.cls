/**
 * @BUSINESS: Test class for NewPartnerLandscapesController.cls.
 * @DATE: 2019-09-20
 * @AUTHOR: Cumulus Vision
 *
 * Modified  ModifiedDate   Description
 * TAN-811   2019-09-23     Initial Development
 */
@IsTest
public with sharing class NewPartnerLandscapesControllerTest {
	@TestSetup
	static void makeData() {
		Account account = new Account(Name = 'test account');
		insert account;

		Partner_Landscape__c partnerLandscape = new Partner_Landscape__c(
			Account__c = account.Id,
			Partner_Type__c = 'Other Partners',
			Partner__c = 'test'
		);
		insert partnerLandscape;
	}

	@IsTest
	static void insertPartnerLandscapesTest() {
		PageReference pageReference = Page.NewPartnerLandscapes;
		Test.setCurrentPage(pageReference);

		Account account = [SELECT Id FROM Account LIMIT 1];
		ApexPages.currentPage().getParameters().put('id', account.Id);

		NewPartnerLandscapesController controller = new NewPartnerLandscapesController();

		List<Partner_Landscape_Type__mdt> plTypeList = [
			SELECT Id, MasterLabel, (SELECT Id, MasterLabel FROM Partner_Landscape_Partners__r)
			FROM Partner_Landscape_Type__mdt
		];

		for (Partner_Landscape_Type__mdt plType : [
			SELECT Id, MasterLabel, (SELECT Id, MasterLabel FROM Partner_Landscape_Partners__r)
			FROM Partner_Landscape_Type__mdt
		]) {
			if (!controller.mapPartnerLandscapeTypeToSelPartner.containsKey(plType.MasterLabel)) {
				controller.mapPartnerLandscapeTypeToSelPartner.put(plType.MasterLabel, new List<String>{});
			}
			for (Partner_Landscape_Partner__mdt plPartner : plType.Partner_Landscape_Partners__r) {
				controller.mapPartnerLandscapeTypeToSelPartner.get(plType.MasterLabel)
					.add(plPartner.MasterLabel);
			}
		}

		Test.startTest();
		controller.insertPartnerLandscapes();
		Test.stopTest();

		List<Partner_Landscape__c> partnerLandscapeList = [SELECT Id FROM Partner_Landscape__c];
		// 1 pre-existing record + 14 created via functionality = 15 Partner_Landscape__c records are expected.
		//        System.assertEquals(15, partnerLandscapeList.size());
	}

	@IsTest
	static void negativeTest1() {
		PageReference pageReference = Page.NewPartnerLandscapes;
		Test.setCurrentPage(pageReference);
		NewPartnerLandscapesController controller = new NewPartnerLandscapesController();

		Test.startTest();
		controller.insertPartnerLandscapes();
		Test.stopTest();
	}

	@IsTest
	static void negativeTest2() {
		PageReference pageReference = Page.NewPartnerLandscapes;
		Test.setCurrentPage(pageReference);
		NewPartnerLandscapesController controller = new NewPartnerLandscapesController();

		Account account = [SELECT Id FROM Account LIMIT 1];
		ApexPages.currentPage().getParameters().put('id', account.Id);

		Test.startTest();
		Boolean isVAlidAccount = controller.isValidAccount;
		Test.stopTest();
	}

	@IsTest
	static void insertOtherPartnerLandscapesTest() {
		PageReference pageReference = Page.NewPartnerLandscapes;
		Test.setCurrentPage(pageReference);

		Account account = [SELECT Id FROM Account LIMIT 1];
		System.debug(account);

		ApexPages.currentPage().getParameters().put('id', account.Id);

		NewPartnerLandscapesController controller = new NewPartnerLandscapesController();
		controller.otherPartnerLandscape.Partner_Type__c = 'Other Partners';
		controller.otherPartnerLandscape.Partner__c = 'test';

		Test.startTest();
		controller.insertOtherPartnerLandscape();
		Test.stopTest();

		List<Partner_Landscape__c> partnerLandscapeList = [SELECT Id FROM Partner_Landscape__c];
		// 1 pre-existing record + 1 created via functionality = 2 Partner_Landscape__c records are expected.
		//System.assertEquals(2, partnerLandscapeList.size());
	}

	@IsTest
	static void negativeTest3() {
		PageReference pageReference = Page.NewPartnerLandscapes;
		Test.setCurrentPage(pageReference);

		Account account = [SELECT Id FROM Account LIMIT 1];
		ApexPages.currentPage().getParameters().put('id', account.Id);

		NewPartnerLandscapesController controller = new NewPartnerLandscapesController();

		Test.startTest();
		controller.insertOtherPartnerLandscape();
		Test.stopTest();
	}

	@IsTest
	static void negativeTest4() {
		PageReference pageReference = Page.NewPartnerLandscapes;
		Test.setCurrentPage(pageReference);

		Account account = [SELECT Id FROM Account LIMIT 1];
		ApexPages.currentPage().getParameters().put('id', account.Id);

		NewPartnerLandscapesController controller = new NewPartnerLandscapesController();

		Test.startTest();
		controller.insertPartnerLandscapes();
		Test.stopTest();
	}
}