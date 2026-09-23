/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for the Utility class
 * @Date: 2020-01-18
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7985   2024-05-14    Updated test class
 * SS-8749   2024-07-24    Updated test class
 * SS-9451   2024-10-22    Updated test class
 * SS-9838	 2024-12-24    Added test mthod for getChangedFields()
 * SS-7124	 2024-02-03    Added test method testGetInstance_ifUrlPassed_returnsInstance
 * SS-9432	 2025-03-01    Added test method testIsClosedOpp_WhenOppStageIsClosedWon_ReturnTrue
 * SS-10515  2025-05-21    Changed Hardcoded CA and WA to California and Washington
 * SS-11659  2025-09-12    Added test method testGetInstanceSettingValue_WhenValidType_ReturnValue
 * SS-11875  2025-10-31    Added test methods testBuildEmailUsingTemplate_Always_ReturnEmailMessage, testGetNoReplyFromEmailId_Always_ReturnReplyFromEmailId
 * SS-13234  2026-06-04    Added test method for getNoReplyFromEmailId
 * SS-13423  2026-06-23    Added test method for isUser
 * SS-13500  2026-07-27    Remove deprecated fields for project kondo group 2 contact
 * SS-13636  2026-09-11    Added test method for new stage constants
 * SS-13216  2026-09-21    Updated class name and added test methods
 */
@IsTest
private class UtilityTest {
	private static User dealsDeskUser;

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('test');
			account.BillingCity = 'Emeryville';
			account.BillingCountry = 'United States';
			account.BillingPostalCode = '94608';
			account.BillingState = 'California';
			account.BillingStreet = '2200 Powell Street';
			insert account;
		}
	}

	@IsTest
	static void addProtocolToURL_WhenURLIsNull_ReturnEmptyString() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.addProtocolToURL(null);
			Test.stopTest();

			Assert.areEqual('', actual);
		}
	}

	@IsTest
	static void addProtocolToURL_WhenURLHasProtocol_ReturnSameString() {
		String testURL = 'https://www.google.com';
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.addProtocolToURL(testURL);
			Test.stopTest();

			Assert.areEqual(testURL, actual);
		}
	}

	@IsTest
	static void addProtocolToURL_WhenURLDoesNotHaveProtocol_ReturnURLWithProtocol() {
		String testURL = 'www.google.com';
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.addProtocolToURL(testURL);
			Test.stopTest();

			Assert.areEqual('https://www.google.com', actual);
		}
	}

	@IsTest
	static void addProtocolToURL_WhenURLHasHTTPOnlyProtocol_ReturnURLWithHTTPSProtocol() {
		String testURL = 'http://www.google.com';
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.addProtocolToURL(testURL);
			Test.stopTest();

			Assert.areEqual('https://www.google.com', actual);
		}
	}

	@IsTest
	static void safeString_WhenStringNull_ReturnEmptyString() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.safeString(null);
			Test.stopTest();

			Assert.areEqual('', actual);
		}
	}

	@IsTest
	static void safeString_WhenStringNotEmpty_ReturnSameString() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.safeString('test');
			Test.stopTest();

			Assert.areEqual('test', actual);
		}
	}

	@IsTest
	static void shortenString_WhenStringNull_ReturnEmptyString() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.shortenString(null, 10);
			Test.stopTest();

			Assert.areEqual('', actual);
		}
	}

	@IsTest
	static void shortenString_WhenStringWithSpacesLongerThanMaxLength_ReturnStringShorterThanMaxLength() {
		String actual = 'This is a long string';
		Integer maxLength = 15;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			actual = Utility.shortenString(actual, 15);
			Test.stopTest();

			Assert.areEqual(
				'This is a long',
				actual,
				'Resulting string with spaces is shorter than maxLength, removed words after last space'
			);
		}
	}

	@IsTest
	static void shortenString_WhenStringWithoutSpacesLongerThanMaxLength_ReturnStringShorterThanMaxLength() {
		String actual = 'This-is-a-long-string';
		Integer maxLength = 15;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			actual = Utility.shortenString(actual, 15);
			Test.stopTest();

			Assert.areEqual(
				'This-is-a-long-',
				actual,
				'Resulting string is shorter than maxLength, cuts the string exactly to maxLength'
			);
			Assert.areEqual(
				maxLength,
				actual.length(),
				'Resulting string without spaces is the length of maxLength '
			);
		}
	}

	@IsTest
	static void addressToString_WhenAddressNull_ReturnEmptyString() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.addressToString(null);
			Test.stopTest();

			Assert.areEqual('', actual);
		}
	}

	@IsTest
	static void addressToString_WhenCompleteAddressProvided_ReturnAddressInStringFormat() {
		Account account = [SELECT Id, BillingAddress FROM Account LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.addressToString(account.BillingAddress);
			Test.stopTest();

			Assert.areEqual('2200 Powell Street Emeryville, California 94608 United States', actual);
		}
	}

	@IsTest
	static void addressToString_WhenIncompleteAddressProvided_ReturnAddressInStringFormat() {
		Account account = [SELECT Id, BillingAddress FROM Account LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.addressToString(account.BillingAddress);
			Test.stopTest();

			Assert.areEqual(true, actual.contains('Emeryville, California 94608 United States'));
		}
	}

	@IsTest
	static void truncateString_WhenStringGreaterThanMaxLength_ReturnTruncatedString() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.truncateString('test1', 4);
			Test.stopTest();

			Assert.areEqual('test', actual);
		}
	}

	@IsTest
	static void truncateString_WhenStringSameOrLessThanMaxLength_ReturnSameString() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.truncateString('test', 4);
			Test.stopTest();

			Assert.areEqual('test', actual);
		}
	}

	@IsTest
	static void truncateString_WhenStringNull_ReturnSameString() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String actual = Utility.addressToString(null);
			Test.stopTest();

			Assert.areEqual('', actual);
		}
	}

	@IsTest
	static void getRecordTypeIdByAPIName_WhenObjectUsingStringAndRecordTypeNameExist_ReturnRecordTypeId() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Id actual = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			Test.stopTest();

			Assert.areNotEqual(null, actual);
		}
	}

	@IsTest
	static void getRecordTypeIdByAPIName_WhenObjectUsingSObjectAndRecordTypeNameExist_ReturnRecordTypeId() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Account testAccount = new Account();
			Id actual = Utility.getRecordTypeIdByAPIName(testAccount, 'Partner');
			Test.stopTest();

			Assert.areNotEqual(null, actual);
		}
	}

	@IsTest
	static void getRecordTypeIdByAPIName_WhenObjectUsingSObjectTypeAndRecordTypeNameExist_ReturnRecordTypeId() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Account testAccount = new Account();
			Id actual = Utility.getRecordTypeIdByAPIName(testAccount.getSObjectType(), 'Partner');
			Test.stopTest();

			Assert.areNotEqual(null, actual);
		}
	}

	@IsTest
	static void getRecordTypeIdByAPIName_WhenObjectDoesNotExist_ThrowsExceptionWithObjectApiName() {
		String errorMessage;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				Utility.getRecordTypeIdByAPIName('AccountTest', 'Partner');
			} catch (Exception error) {
				errorMessage = error.getMessage();
			}
			Test.stopTest();

			Assert.areEqual('AccountTest' + Utility.OBJECT_NOT_FOUND_ERROR, errorMessage);
		}
	}

	@IsTest
	static void getRecordTypeIdByAPIName_WhenRecordTypeNameDoesNotExistUsingStringObject_ThrowsExceptionWithRecordTypeApiName() {
		String errorMessage;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				Id actual = Utility.getRecordTypeIdByAPIName('Account', 'PartnerTest');
			} catch (Exception error) {
				errorMessage = error.getMessage();
			}
			Test.stopTest();

			Assert.areEqual('PartnerTest' + Utility.RECORDTYPE_NOT_FOUND_ERROR, errorMessage);
		}
	}

	@IsTest
	static void getRecordTypeIdByAPIName_WhenRecordTypeNameDoesNotExistUsingSObject_ThrowsExceptionWithRecordTypeApiName() {
		String errorMessage;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				Account testAccount = new Account();
				Id actual = Utility.getRecordTypeIdByAPIName(testAccount, 'PartnerTest');
			} catch (Exception error) {
				errorMessage = error.getMessage();
			}
			Test.stopTest();

			Assert.areEqual('PartnerTest' + Utility.RECORDTYPE_NOT_FOUND_ERROR, errorMessage);
		}
	}

	@IsTest
	static void getRecordTypeIdByAPIName_WhenRecordTypeNameDoesNotExistUsingSObjectType_ThrowsExceptionWithRecordTypeApiName() {
		String errorMessage;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				Account testAccount = new Account();
				Id actual = Utility.getRecordTypeIdByAPIName(
					testAccount.getSObjectType(),
					'PartnerTest'
				);
			} catch (Exception error) {
				errorMessage = error.getMessage();
			}
			Test.stopTest();

			Assert.areEqual('PartnerTest' + Utility.RECORDTYPE_NOT_FOUND_ERROR, errorMessage);
		}
	}

	@IsTest
	static void getProfileId_WhenNameFound_PopulatesProfileIdMap() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Utility.getAdminUserProfileId();
			Utility.getSuperUserProfileId();
			Utility.getTaniumDealsDeskProfileId();
			Utility.getAPIOnlyIntegrationAdminProfileId();
			Utility.getTaniumStandardUserProfileId();

			Test.stopTest();

			for (String profileName : Utility.profileIdMap.keySet()) {
				String profileId = Utility.profileIdMap.get(profileName);

				System.assert(String.isNotBlank(profileId));
			}
		}
	}

	@IsTest
	static void getProfileId_WhenNameNotFound_ThrowsExceptionWithName() {
		String profileName = 'Invalid Profile Name';
		String errorMessage;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				Utility.getProfileId(profileName);
			} catch (Exception error) {
				errorMessage = error.getMessage();
			}
			Test.stopTest();

			System.assert(errorMessage.contains(profileName));
		}
	}

	@IsTest
	static void getUserRoleId_WhenNameFound_PopulatesUserRoleIdMap() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Utility.getCorporateRoleId();
			Test.stopTest();

			for (String userRoleName : Utility.userRoleIdMap.keySet()) {
				String userRoleId = Utility.userRoleIdMap.get(userRoleName);
				System.assert(String.isNotBlank(userRoleId));
			}
		}
	}

	@IsTest
	static void getUserRoleId_WhenNameNotFound_ThrowsExceptionWithName() {
		String userRoleName = 'Invalid Role Name';
		String errorMessage;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				Utility.getUserRoleId(userRoleName);
			} catch (Exception error) {
				errorMessage = error.getMessage();
			}
			Test.stopTest();

			System.assert(errorMessage.contains(userRoleName));
		}
	}

	@IsTest
	static void getAllHiddenFeatures_whenFound_ReturnsAllRecords() {
		List<HiddenFeatures__mdt> featuresForSomeMetadataType = new List<HiddenFeatures__mdt>();
		System.runAs(TestUserFactory.getAdminUser()) {
			HiddenFeatures__mdt classA = TestFactory.buildHiddenFeature('ClassA');
			classA.MetadataType__c = 'Some metadata type';
			classA.isActive__c = 'True';

			HiddenFeatures__mdt classB = TestFactory.buildHiddenFeature('ClassB');
			classB.MetadataType__c = 'Some metadata type';
			classB.isActive__c = 'True';

			Utility.getAllHiddenFeatures();
			Utility.hiddenFeaturesByMetadataType.put(
				'Some metadata type',
				new List<HiddenFeatures__mdt>{ classA, classB }
			);
			Utility.hiddenFeaturesByDeveloperName.put('ClassA', classA);
			Utility.hiddenFeaturesByDeveloperName.put('ClassB', classB);
			Test.startTest();
			Map<String, HiddenFeatures__mdt> allFeatures = Utility.getAllHiddenFeatures();
			Test.stopTest();
			Assert.areEqual(
				true,
				Utility.hiddenFeaturesByDeveloperName.size() >= 2,
				'ClassA and ClassB'
			);
			Assert.areEqual(
				true,
				Utility.hiddenFeaturesByMetadataType.size() >= 1,
				'Some metadata type'
			);
			Assert.areEqual(allFeatures.size(), Utility.hiddenFeaturesByDeveloperName.size());
		}
	}

	@IsTest
	static void getAllHiddenFeaturesByMetadataType_whenFound_ReturnsAllRecords() {
		List<HiddenFeatures__mdt> featuresForSomeMetadataType = new List<HiddenFeatures__mdt>();
		System.runAs(TestUserFactory.getAdminUser()) {
			HiddenFeatures__mdt classA = TestFactory.buildHiddenFeature('ClassA');
			classA.MetadataType__c = 'Some metadata type';
			classA.isActive__c = 'True';

			HiddenFeatures__mdt classB = TestFactory.buildHiddenFeature('ClassB');
			classB.MetadataType__c = 'Some metadata type';
			classB.isActive__c = 'True';

			Utility.getAllHiddenFeatures();
			Utility.hiddenFeaturesByMetadataType.put(
				'Some metadata type',
				new List<HiddenFeatures__mdt>{ classA, classB }
			);
			Test.startTest();
			featuresForSomeMetadataType = Utility.getHiddenFeaturesByMetadataType(
				'Some metadata type'
			);
			Test.stopTest();
			Assert.areEqual(true, featuresForSomeMetadataType.contains(classA));
			Assert.areEqual(true, featuresForSomeMetadataType.contains(classB));
		}
	}

	@IsTest
	static void getHiddenFeatureWrapper_whenTrueOrFalse_ReturnsValueAccurately() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Utility.getAllHiddenFeatures();
			HiddenFeatures__mdt classA = TestFactory.buildHiddenFeature('ClassA');
			classA.MetadataType__c = 'Some Metadata Type';
			classA.isActive__c = 'True';
			HiddenFeatures__mdt classB = TestFactory.buildHiddenFeature('ClassB');
			classB.MetadataType__c = 'Some Metadata Type';
			classB.isActive__c = 'False';
			Utility.hiddenFeaturesByDeveloperName.put('ClassA', classA);
			Utility.hiddenFeaturesByDeveloperName.put('ClassB', classB);
			Test.startTest();
			Assert.areEqual(true, Utility.getHiddenFeatureWrapper('ClassA').isHidden);
			Assert.areEqual(false, Utility.getHiddenFeatureWrapper('ClassB').isHidden);
			Assert.areEqual(false, Utility.getHiddenFeatureWrapper('ClassC').isHidden);
			Test.stopTest();
		}
	}

	@IsTest
	static void getSOQLForHiddenFeature_whenTrueOrFalse_ReturnsValueAccurately() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Utility.getAllHiddenFeatures();
			HiddenFeatures__mdt classA = TestFactory.buildHiddenFeature('ClassA');
			classA.MetadataType__c = 'Some Metadata Type';
			classA.isActive__c = 'True';
			classA.SOQL__c = 'Condition for class A';

			HiddenFeatures__mdt classB = TestFactory.buildHiddenFeature('ClassB');
			classB.MetadataType__c = 'Some Metadata Type';
			classB.isActive__c = 'False';
			classB.SOQL__c = 'Condition for class B';

			HiddenFeatures__mdt classC = TestFactory.buildHiddenFeature('ClassC');
			classC.MetadataType__c = 'Some Metadata Type';
			classC.isActive__c = 'True';
			classC.SOQL__c = null;

			Utility.hiddenFeaturesByDeveloperName.put('ClassA', classA);
			Utility.hiddenFeaturesByDeveloperName.put('ClassB', classB);
			Utility.hiddenFeaturesByDeveloperName.put('ClassC', classB);

			Test.startTest();
			Assert.areEqual('Condition for class A', Utility.getSOQLForHiddenFeature('ClassA'));
			Assert.areEqual('', Utility.getSOQLForHiddenFeature('ClassB'));
			Assert.areEqual('', Utility.getSOQLForHiddenFeature('ClassC'));
			Assert.areEqual('', Utility.getSOQLForHiddenFeature('ClassD'));
			Test.stopTest();
		}
	}

	@IsTest
	static void isSandbox_Always_ReturnsBoolean() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Boolean expectedOrgType = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
			Test.startTest();
			Boolean actual = Utility.isSandbox();
			Test.stopTest();
			Assert.areEqual(expectedOrgType, actual, 'The Org Type results should match');
		}
	}

	@IsTest
	static void testIsTaniumCustomTriggerDisabled_ifFalse_triggerIsRun() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Assert.areEqual(false, Utility.isTaniumCustomTriggerDisabled('AccountTriggerHandler'));
		}
	}

	@IsTest
	static void testIsTaniumCustomTriggerDisabled_ifAll_triggerIsNotRun() {
		User user;
		System.runAs(TestUserFactory.getAdminUser()) {
			user = [
				SELECT Id, DisableTaniumCustomTriggers__c
				FROM User
				WHERE Id = :UserInfo.getUserId()
			];
			user.DisableTaniumCustomTriggers__c = 'All';
			update user;
			Utility.runningUser = user;
		}
		System.runAs(user) {
			Assert.areEqual(
				true,
				Utility.isTaniumCustomTriggerDisabled('AccountSupportRequestTriggerHandler')
			);
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('AccountTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('AgreementTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('AttachmentTriggerHandler'));
			Assert.areEqual(
				true,
				Utility.isTaniumCustomTriggerDisabled('BillingScheduleTriggerHandler')
			);
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('ContactTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('InvoiceTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('LeadTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('OpportunityTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('OrderTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('POCRequestTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('QuoteCPQTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('QuoteLineTriggerHandler'));
			Assert.areEqual(true, Utility.isTaniumCustomTriggerDisabled('UserTriggerHandler'));
		}
	}

	@IsTest
	static void testGetHiddenFeaturesByDeveloperName_ifExist_returnsAllHiddenFeatures() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Utility.getAllHiddenFeatures();
			HiddenFeatures__mdt classA = TestFactory.buildHiddenFeature('ClassA');
			classA.MetadataType__c = 'Some Metadata Type';
			classA.isActive__c = 'True';
			classA.SOQL__c = 'Condition for class A';
			Utility.hiddenFeaturesByDeveloperName.put('ClassA', classA);
			Test.startTest();
			Assert.areEqual(classA, Utility.getHiddenFeaturesByDeveloperName('ClassA'));
			Test.stopTest();
		}
	}

	@IsTest
	static void testActivateHiddenFeature_ifExist_returnsTrue() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Utility.getAllHiddenFeatures();
			HiddenFeatures__mdt classA = TestFactory.buildHiddenFeature('ClassA');
			classA.MetadataType__c = 'Some Metadata Type';
			classA.isActive__c = 'False';
			classA.SOQL__c = 'Condition for class A';
			Utility.hiddenFeaturesByDeveloperName.put('ClassA', classA);
			Test.startTest();
			Assert.areEqual('True', Utility.activateHiddenFeature('ClassA').isActive__c);
			Test.stopTest();
		}
	}

	@IsTest
	static void testDeactivateHiddenFeature_ifExist_returnsTrue() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Utility.getAllHiddenFeatures();
			HiddenFeatures__mdt classA = TestFactory.buildHiddenFeature('ClassA');
			classA.MetadataType__c = 'Some Metadata Type';
			classA.isActive__c = 'True';
			classA.SOQL__c = 'Condition for class A';
			Utility.hiddenFeaturesByDeveloperName.put('ClassA', classA);
			Test.startTest();
			Assert.areEqual('False', Utility.deactivateHiddenFeature('ClassA').isActive__c);
			Test.stopTest();
		}
	}

	@IsTest
	static void testFireUpdateOnObject_ifSuccessful_updatesRecords() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct;
			acct = TestFactory.buildAccount('UtilityFireUpdateTest');
			insert acct;
			Test.startTest();
			acct.Name = 'UtilityFireUpdateTest1';
			Utility.fireUpdateOnObject(new List<Account>{ acct }, null, true);
			Test.stopTest();
			acct = [SELECT Name FROM Account WHERE Name = 'UtilityFireUpdateTest1'];
			Assert.areEqual(
				'UtilityFireUpdateTest1',
				acct.Name,
				'Acct name was updated by fireUpdate'
			);
		}
	}

	@IsTest
	static void testFireUpdateOnObject_ifFails_catchesExceptionReturnsSaveresults() {
		Account acct;
		System.runAs(TestUserFactory.getAdminUser()) {
			acct = TestFactory.buildAccount('UtilityFireUpdateTest');
			acct.Type = 'Protected';
			insert acct;
		}
		System.runAs(UtilityTest.getDealsDeskUser()) {
			Test.startTest();
			try {
				acct.Name = 'UtilityFireUpdateTest1';
				Utility.fireUpdateOnObject(new List<Account>{ acct }, null, true);
			} catch (DMLException e) {
				Assert.areEqual(true, e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
			}
			Test.stopTest();
		}
	}

	@IsTest
	static void testFireInsertOnObject_ifSuccessful_returnsSaveresults() {
		List<Database.SaveResult> saveResults;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Account acct = TestFactory.buildAccount('UtilityFireUpdateTest');
			saveResults = Utility.fireInsertOnObject(new List<Account>{ acct }, null, true);
			Test.stopTest();
			Assert.areEqual(1, saveResults.size());
		}
	}

	@IsTest
	static void testFireInsertOnObject_ifFails_catchesExceptionReturnsSaveresults() {
		List<Database.SaveResult> saveResults;
		Account acct;
		System.runAs(TestUserFactory.getAdminUser()) {
			acct = TestFactory.buildAccount('UtilityFireInsertTest');
			acct.LID__LinkedIn_Company_Id__c = 'ABC';
		}
		System.runAs(UtilityTest.getDealsDeskUser()) {
			Test.startTest();
			try {
				saveResults = Utility.fireInsertOnObject(new List<Account>{ acct }, null, true);
			} catch (Exception e) {
				Assert.areEqual(true, e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
			}
			Test.stopTest();
		}
		Assert.areEqual(null, saveResults);
	}

	@IsTest
	static void testFireDeleteOnObject_ifSuccessful_returnsSaveresults() {
		List<Database.DeleteResult> deleteResults;
		Account acct;
		System.runAs(TestUserFactory.getAdminUser()) {
			acct = TestFactory.buildAccount('UtilityFireDeleteTest');
			insert acct;
		}
		System.runAs(UtilityTest.getDealsDeskUser()) {
			Test.startTest();
			deleteResults = Utility.fireDeleteOnObject(new List<Account>{ acct }, null, true);
			Test.stopTest();
		}
		Assert.areEqual(1, deleteResults.size());
	}

	@IsTest
	static void testFireDeleteOnObject_ifFails_catchesExceptionReturnsSaveresults() {
		List<Database.DeleteResult> deleteResults;
		Account acct;
		System.runAs(TestUserFactory.getAdminUser()) {
			acct = TestFactory.buildAccount('UtilityFireDeleteTest');
			acct.Type = 'Protected';
			insert acct;
		}
		System.runAs(UtilityTest.getDealsDeskUser()) {
			Test.startTest();
			try {
				deleteResults = Utility.fireDeleteOnObject(new List<Account>{ acct }, null, true);
			} catch (Exception e) {
				Assert.areEqual(true, e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
			}
			Test.stopTest();
		}
		Assert.areEqual(1, deleteResults.size());
	}

	@IsTest
	static void testGetFormattedString_ifNumberIsPassed_returnsFormattedStringForThatNumber() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Assert.areEqual('first', Utility.getFormattedString(1));
			Assert.areEqual('second', Utility.getFormattedString(2));
			Assert.areEqual('third', Utility.getFormattedString(3));
			Assert.areEqual(null, Utility.getFormattedString(0));
		}
	}

	@IsTest
	static void testGetActivePricebooksMap_Always_ReturnsMap() {
		Map<Id, Pricebook2> pricebookMap = null;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			pricebookMap = Utility.getActivePricebooksMap();
			Test.stopTest();
		}
		Assert.isNotNull(pricebookMap);
	}

	@IsTest
	static void testIsFutureMethodAllowed_WhenSyncTransaction_ReturnTrue() {
		Boolean isAllowed = null;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			isAllowed = Utility.isFutureMethodAllowed();
			Test.stopTest();
		}
		Assert.isTrue(isAllowed);
	}

	@IsTest
	static void isValidRedirectUrl_WhenValid_ReturnTrue() {
		String validRedirectUrl = '/endpoint-security-community-group';
		Test.startTest();
		Boolean result = Utility.isValidRedirectUrl(validRedirectUrl);
		Test.stopTest();

		Assert.isTrue(result, 'Return should be TRUE');
	}

	@IsTest
	static void isValidRedirectUrl_WhenInvalid_ReturnFalse() {
		String invalidRedirectUrl = 'https://google.com';
		Test.startTest();
		Boolean result = Utility.isValidRedirectUrl(invalidRedirectUrl);
		Assert.isFalse(result, 'Return should be FALSE');

		invalidRedirectUrl = '//@google.com';
		result = Utility.isValidRedirectUrl(invalidRedirectUrl);
		Assert.isFalse(result, 'Return should be FALSE');
		Test.stopTest();
	}

	@IsTest
	static void testIsQueue_WhenUser_ReturnFalse() {
		Boolean isQueue = true;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			isQueue = Utility.isQueue(UserInfo.getUserId());
			Test.stopTest();
		}

		Assert.isFalse(isQueue);
	}

	@IsTest
	static void testGetServiceChannelId_WhenCaseObject_ReturnServiceChannelId() {
		Id serviceChannelId = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			serviceChannelId = Utility.getServiceChannelId('Case');
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetQueueId_WhenValidQueueName_ReturnQueueId() {
		Id queueId = null;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			queueId = Utility.getQueueId('Service Cloud Tanium');
			Test.stopTest();
		}

		Assert.isTrue(queueId != null);
	}

	@IsTest
	static void test_getDependentPicklistValues() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<String, List<String>> dependencies = Utility.getDependentPicklistValues(
				'Case',
				'Component__c',
				'Sub_Component__c'
			);
			Test.stopTest();

			Assert.isFalse(dependencies.isEmpty());
		}
	}

	private static User getDealsDeskUser() {
		if (UtilityTest.dealsDeskUser == null) {
			for (User user : [SELECT Id FROM User WHERE Alias = 'CustTrig' LIMIT 1]) {
				UtilityTest.dealsDeskUser = user;
				return UtilityTest.dealsDeskUser;
			}
			User dealsDeskUser = TestFactory.buildUser(
				'Test',
				'TestCustomTriggers@tanium.com',
				'CustTrig',
				Utility.getTaniumDealsDeskProfileId(),
				Utility.getCorporateRoleId()
			);
			dealsDeskUser.DisableTaniumCustomTriggers__c =
				'BillingScheduleTriggerHandler;' +
				'InvoiceTriggerHandler;' +
				'LeadTriggerHandler; ' +
				'OpportunityTriggerHandler;' +
				'OrderTriggerHandler;' +
				'POCRequestTriggerHandler;' +
				'QuoteCPQTriggerHandler;' +
				'UserTriggerHandler';
			dealsDeskUser.Account_Admin__c = true;
			insert dealsDeskUser;
			UtilityTest.dealsDeskUser = dealsDeskUser;
		}
		return UtilityTest.dealsDeskUser;
	}

	@IsTest
	static void testGetNetworkId_WhenValidNetworkName_ReturnId() {
		Id networkId = null;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			networkId = Utility.getNetworkId('Tanium Customer Community');
			Test.stopTest();
		}
		Assert.isTrue(networkId != null);
	}

	@IsTest
	static void testIsCase_WhenRecordIsCaseId_ReturnTrue() {
		Boolean isCase = false;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			isCase = Utility.isCase('500RK00000EJemVYAT');
			Test.stopTest();
		}

		Assert.isTrue(isCase);
	}

	@IsTest
	static void testIsUser_WhenRecordIsUserId_ReturnTrue() {
		Boolean isUser = false;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			isUser = Utility.isUser('005RK00000EJemVYAT');
			Test.stopTest();
		}

		Assert.isTrue(isUser);
	}

	@IsTest
	static void testGetChangedFields_WhenFieldsChanged_ReturnsAPINamesOfFieldsChanged() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
			Set<String> acctFieldSet = schemaMap.get('Account').getDescribe().fields.getMap().keySet();
			acctFieldSet.remove('ispriorityrecord');
			Account acctBefore = TestFactory.buildAccount('test1');
			acctBefore.BillingCity = 'Emeryville';
			acctBefore.BillingCountry = 'United States';
			acctBefore.BillingPostalCode = '78901';
			acctBefore.BillingState = 'California';
			acctBefore.BillingStreet = '500 Lincoln Street';
			insert acctBefore;
			Account acctAfter = TestFactory.buildAccount('test2');
			acctAfter.BillingCity = 'Washington';
			acctAfter.BillingCountry = 'United States';
			acctAfter.BillingPostalCode = '12345';
			acctAfter.BillingState = 'Washington';
			acctAfter.BillingStreet = '100 Cornelle Street';
			insert acctAfter;
			Set<String> fieldsChanged = Utility.getChangedFields(acctBefore, acctAfter, acctFieldSet);
			Assert.areEqual(true, fieldsChanged.contains('billingcity'), 'changed to Washington');
			Assert.areEqual(true, fieldsChanged.contains('billingpostalcode'), 'changed to 12345');
			Assert.areEqual(true, fieldsChanged.contains('billingstate'), 'changed to WA');
			Assert.areEqual(
				true,
				fieldsChanged.contains('billingstreet'),
				'changed to 100 Cornelle Street'
			);
			Assert.areEqual(false, fieldsChanged.contains('billingcountry'), 'remains United States');
			Assert.areEqual(true, fieldsChanged.contains('name'), 'both accts have different names');
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetInstance_ifUrlPassed_returnsInstance() {
		Url prodUrl = new Url('https://tanium.lightning.force.com');
		Url buildSandbox = new Url('https://tanium--build.sandbox.lightning.force.com/');
		Url uatSandbox = new Url('https://tanium--uat.sandbox.lightning.force.com/');
		Url partialSandbox = new Url('https://tanium--partial.sandbox.lightning.force.com/');
		Assert.areEqual(
			true,
			Utility.getInstance(prodUrl).equals('Production') ||
			Utility.getInstance(prodUrl).equals('Developer')
		);
		Assert.areEqual(
			true,
			Utility.getInstance(buildSandbox).equals('Production') ||
			Utility.getInstance(buildSandbox).equals('Build')
		);
		Assert.areEqual(
			true,
			Utility.getInstance(uatSandbox).equals('Production') ||
			Utility.getInstance(uatSandbox).equals('UAT')
		);
		Assert.areEqual(
			true,
			Utility.getInstance(partialSandbox).equals('Production') ||
			Utility.getInstance(partialSandbox).equals('Developer')
		);
	}

	@IsTest
	static void testIsClosedOpp_WhenOppStageIsClosedWon_ReturnTrue() {
		Test.startTest();
		Boolean isClosed = Utility.isClosedOpp(Utility.CLOSED_WON);
		Test.stopTest();

		Assert.isTrue(isClosed);
	}

	@IsTest
	static void testGetInstanceSettingValue_WhenValidType_ReturnValue() {
		String instanceSettingValue = null;
		Test.startTest();
		instanceSettingValue = Utility.getInstanceSettingValue('TestClassKey');
		Test.stopTest();

		Assert.isNotNull(instanceSettingValue);
	}

	@IsTest
	static void testBuildEmailUsingTemplate_Always_ReturnEmailMessage() {
		Messaging.SingleEmailMessage email = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			email = Utility.buildEmailUsingTemplate(
				null,
				new List<String>{ 'first.last@corp.io' },
				null,
				null,
				false,
				null
			);
			Test.stopTest();
		}

		Assert.isNotNull(email);
	}

	@IsTest
	static void testGetEmailTemplateId_WhenInValidTemplateName_ReturnNull() {
		Id emailTemplateId = UserInfo.getUserId();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			emailTemplateId = Utility.getEmailTemplateId('InvalidTemplateName');
			Test.stopTest();
		}

		Assert.isNull(emailTemplateId);
	}

	@IsTest
	static void testGetNoReplyFromEmailId_Always_ReturnReplyFromEmailId() {
		Id noReplyFromEmailId = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			noReplyFromEmailId = Utility.getNoReplyFromEmailId();
			Test.stopTest();
		}

		Assert.isNotNull(noReplyFromEmailId);
	}

	@IsTest
	static void testGetUserIdToUserManagerId_Always_ReturnUserIdToUserManagerIdMap() {
		Map<Id, Id> userIdToManagerIdMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			userIdToManagerIdMap = Utility.getUserIdToUserManagerId(
				new List<Id>{ UserInfo.getUserId() }
			);
			Test.stopTest();
		}

		Assert.isNotNull(userIdToManagerIdMap);
		Assert.isTrue(userIdToManagerIdMap.size() > 0);
	}

	@IsTest
	static void testStageConstants_Always_ReturnStagePicklistLiterals() {
		Assert.areEqual('Account Assessment', Utility.ACCOUNT_ASSESSMENT, 'Account Assessment stage');
		Assert.areEqual('Customer Engaged', Utility.CUSTOMER_ENGAGED, 'Customer Engaged stage');
		Assert.areEqual('Proposal Sent', Utility.PROPOSAL_SENT, 'Proposal Sent stage');
		Assert.areEqual('Commit', Utility.COMMIT_STAGE, 'Commit stage');
		Assert.areEqual('Order Drafted', Utility.ORDER_DRAFTED, 'Order Drafted stage');
		Assert.areEqual(
			'Waiting for Signature',
			Utility.WAITING_FOR_SIGNATURE,
			'Waiting for Signature stage matches the picklist casing'
		);
	}

	@IsTest
	static void testStageNumberConstants_Always_ReturnStageFormulaNumbers() {
		Assert.areEqual(10, Utility.PROSPECTING_STAGE_NUMBER, 'Prospecting stage number');
		Assert.areEqual(130, Utility.COMMIT_STAGE_NUMBER, 'Commit stage number');
		Assert.areEqual(
			170,
			Utility.SIGNED_PAPERWORK_RECEIVED_STAGE_NUMBER,
			'Signed - Paperwork received stage number'
		);
	}
}