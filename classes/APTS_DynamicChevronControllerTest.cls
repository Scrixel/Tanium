@isTest
public class APTS_DynamicChevronControllerTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account testAccount = TestFactory.buildAccount('Test Account');
			testAccount.Country_Exception_Approved__c = true;
			insert testAccount;

			Apttus__APTS_Agreement__c apttusAgreement = TestFactory.buildApttusAgreement(testAccount.Id);
			insert apttusAgreement;

			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				Utility.PROSPECTING,
				testAccount.Id
			);
			insert oppty;

			Lead testLead = TestFactory.buildLead(
				'Test',
				'Lead',
				'test' +
				Math.random() +
				'@tanium.com',
				'Test Company'
			);
			insert testLead;
		}

	}

	@isTest
	static void integrationTest_DynamicChevronController_WhenAgreement_SetsJSONString() {
		Apttus__APTS_Agreement__c agreement = [SELECT Id FROM Apttus__APTS_Agreement__c LIMIT 1];
		APTS_DynamicChevronController chevronController;

		Test.startTest();
		System.runAs(TestFactory.getQuoteUnlockDealDeskUser()) {
			ApexPages.StandardController agreementController = new ApexPages.StandardController(
				agreement
			);
			chevronController = new APTS_DynamicChevronController(agreementController);
		}
		Test.stopTest();

		System.assertNotEquals(null, chevronController.longLabelJSON);
		System.assertNotEquals(null, chevronController.shortLabelJSON);
	}

	@isTest
	static void integrationTest_DynamicChevronController_WhenOpportunity_SetsJSONString() {
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		APTS_DynamicChevronController chevronController;

		Test.startTest();
		System.runAs(TestFactory.getQuoteUnlockDealDeskUser()) {
			ApexPages.StandardController opportunityController = new ApexPages.StandardController(
				opportunity
			);
			chevronController = new APTS_DynamicChevronController(opportunityController);
		}
		Test.stopTest();

		System.assertNotEquals(null, chevronController.longLabelJSON);
		System.assertNotEquals(null, chevronController.shortLabelJSON);
	}

	@isTest
	static void generateLongLabels_WhenValidRecordIdProvided_ReturnsListOfLabels() {
		Apttus__APTS_Agreement__c agreement = [SELECT Id FROM Apttus__APTS_Agreement__c LIMIT 1];
		List<String> resultLabels;

		Test.startTest();
		System.runAs(TestFactory.getQuoteUnlockDealDeskUser()) {
			resultLabels = APTS_DynamicChevronController.generateLongLabels(agreement.Id);
		}
		Test.stopTest();

		System.assertNotEquals(
			null,
			APTS_DynamicChevronController.objectPicklistFieldMap.get('Apttus__APTS_Agreement__c'),
			'The object is included and valid'
		);
		System.assert(!resultLabels.isEmpty(), 'A list of labels generated for valid object');
	}

	@isTest
	static void generateLongLabels_WhenInvalidRecordIdProvided_ReturnsEmptyList() {
		Lead testLead = [SELECT Id FROM Lead LIMIT 1];

		List<String> resultLabels;

		Test.startTest();
		System.runAs(TestFactory.getQuoteUnlockDealDeskUser()) {
			resultLabels = APTS_DynamicChevronController.generateLongLabels(testLead.Id);
		}
		Test.stopTest();

		System.assertEquals(
			null,
			APTS_DynamicChevronController.objectPicklistFieldMap.get('Lead'),
			'The object is not included and not valid'
		);
		System.assert(resultLabels.isEmpty(), 'No labels are generated for invalid object');
	}

	@isTest
	static void generateShortLabels_WhenLongLabelsProvided_ReturnsTheSameNumberOfShortLabels() {
		List<String> longLabels = new List<String>{
			'Extra  Spaces',
			'   LeadingTrailingSpaces    ',
			' Test Three Words',
			' % 455 && 5'
		};
		List<String> shortLabels;

		Test.startTest();
		System.runAs(TestFactory.getQuoteUnlockDealDeskUser()) {
			shortLabels = APTS_DynamicChevronController.generateShortLabels(longLabels);
		}
		Test.stopTest();

		System.assertEquals(shortLabels.size(), longLabels.size());
	}
}