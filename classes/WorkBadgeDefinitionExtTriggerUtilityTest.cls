/*
 * @DATE: 2024-09-07
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Test methods for class WorkBadgeDefinitionExtTriggerUtility
 * RequestId  ModifiedDate  Comment
 * SS-8303    2024-09-07    Created the test class
 * SS-9838    2025-01-16    Updated the test class
 */
@IsTest
private class WorkBadgeDefinitionExtTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		WorkBadgeDefinition workBadgeDefinition = new WorkBadgeDefinition();
		workBadgeDefinition.Name = 'Thanks';
		workBadgeDefinition.Description = 'Thanks';
		workBadgeDefinition.IsActive = true;
		workBadgeDefinition.ImageUrl =
			URL.getOrgDomainURL().toExternalForm() + '/img/rypple/Thanks.png';

		WorkBadgeDefinition workBadgeDefinitionSales = new WorkBadgeDefinition();
		workBadgeDefinitionSales.Name = 'Sales';
		workBadgeDefinitionSales.Description = 'Sales';
		workBadgeDefinitionSales.IsActive = true;
		workBadgeDefinitionSales.ImageUrl =
			URL.getOrgDomainURL().toExternalForm() + '/img/rypple/Sales.png';

		insert new List<WorkBadgeDefinition>{ workBadgeDefinition, workBadgeDefinitionSales };

		WorkBadgeDefinitionExtension__c workBadgeDefinitionExtension = new WorkBadgeDefinitionExtension__c();
		workBadgeDefinitionExtension.Name = 'Thanks';
		workBadgeDefinitionExtension.Reputation_Points__c = 1;
		insert workBadgeDefinitionExtension;
	}

	@IsTest
	static void testGetWorkBadgeNameDefinitionMap_Always_ReturnWorkBadgeNameDefinitionMap() {
		Map<String, WorkBadgeDefinition> workBadgeNameDefinitionMap = new Map<String, WorkBadgeDefinition>();
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			workBadgeNameDefinitionMap = WorkBadgeDefinitionExtTriggerUtility.getWorkBadgeNameDefinitionMap();
			Test.stopTest();
		}

		Assert.isFalse(workBadgeNameDefinitionMap.isEmpty());
	}

	@IsTest
	static void testValidateBadges_WhenThereIsNoExistingBadge_ThrowValidationErrorOnInsert() {
		Boolean exceptionThrown = false;
		Test.startTest();
		try {
			WorkBadgeDefinitionExtension__c workBadgeDefinitionExtension = new WorkBadgeDefinitionExtension__c();
			workBadgeDefinitionExtension.Name = 'RockStar';
			workBadgeDefinitionExtension.Reputation_Points__c = 1;
			insert workBadgeDefinitionExtension;
		} catch (Exception e) {
			exceptionThrown = true;
			String message = e.getMessage();
			Assert.isTrue(message.contains('Badge doesn\'t exist'));
		}
		Test.stopTest();

		Assert.isTrue(exceptionThrown, 'Exception should be thrown.');
	}

	@IsTest
	static void testValidateBadges_WhenThereIsNoExistingBadge_ThrowValidationErrorOnUpdate() {
		Boolean exceptionThrown = false;
		Test.startTest();
		try {
			WorkBadgeDefinitionExtension__c existingWorkBadgeDefinitionExtension = [
				SELECT Id
				FROM WorkBadgeDefinitionExtension__c
				LIMIT 1
			];
			existingWorkBadgeDefinitionExtension.Name = 'GoldStar';
			existingWorkBadgeDefinitionExtension.Reputation_Points__c = 1;
			update existingWorkBadgeDefinitionExtension;
		} catch (Exception e) {
			exceptionThrown = true;
			String message = e.getMessage();
			Assert.isTrue(message.contains('Badge doesn\'t exist'));
		}
		Test.stopTest();

		Assert.isTrue(exceptionThrown, 'Exception should be thrown.');
	}

	@IsTest
	static void testValidateBadges_WhenThereIsExistingBadge_ThrowValidationError() {
		Boolean exceptionThrown = false;
		Test.startTest();
		try {
			WorkBadgeDefinitionExtension__c workBadgeDefinitionExtension = new WorkBadgeDefinitionExtension__c();
			workBadgeDefinitionExtension.Name = 'Thanks';
			workBadgeDefinitionExtension.Reputation_Points__c = 1;
			insert workBadgeDefinitionExtension;
		} catch (Exception e) {
			exceptionThrown = true;
			String message = e.getMessage();
			Assert.isTrue(message.contains('Badge already exist'));
		}
		Test.stopTest();

		Assert.isTrue(exceptionThrown, 'Exception should be thrown.');
	}

	@IsTest
	static void testSetSourceId_WhenBadgeDefinitionIsCreated_SourceIdIsPopulated() {
		WorkBadgeDefinition workBadgeDefinition = [
			SELECT Id
			FROM WorkBadgeDefinition
			WHERE Name = 'Thanks'
		];
		WorkBadgeDefinitionExtension__c workBadgeDefinitionExtensionRec = [
			SELECT SourceId__c
			FROM WorkBadgeDefinitionExtension__c
			WHERE Name = 'Thanks'
		];
		Assert.areEqual(workBadgeDefinition.Id, workBadgeDefinitionExtensionRec.SourceId__c);
	}
}