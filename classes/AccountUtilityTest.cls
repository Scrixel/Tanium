/**
 * Copyright (c) 2026 Tanium
 *
 * @DATE: 2026-03-04
 * @AUTHORS: Tanium Dev Team
 * @BUSINESS: Test class for AccountUtility
 * RequestId  ModifiedDate  Description
 * SS-12691   2026-03-04    Initial development
 */
@IsTest
private class AccountUtilityTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
		Id partnerAccountRecTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account federalAccount = TestFactory.buildAccount('Test Federal Account');
			federalAccount.Geo__c = 'USPS Federal';
			federalAccount.Region__c = 'US Federal';

			Account account = TestFactory.buildAccount('Test Account');
			account.Sync_with_Zift__c = true;
			account.Total_Addressable_Seats__c = 100;
			account.Territory_Changed_Date__c = System.today().addDays(-1);

			Account partnerAccount = TestFactory.buildAccount('Test Partner Account');
			partnerAccount.RecordTypeId = partnerAccountRecTypeId;

			insert new List<Account>{ federalAccount, account, partnerAccount };
		}
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsEqualAndValueIsUsFederalAndFieldTypeIsString_ReturnTrue() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c, Geo__c
			FROM Account
			WHERE Name = 'Test Federal Account'
			LIMIT 1
		];
		Account_Segment_Mapping__mdt accountSegmentMapping = [
			SELECT Id, Label, DeveloperName, Order__c, Field__c, Operator__c, Value__c, Segment__c
			FROM Account_Segment_Mapping__mdt
			WHERE DeveloperName = 'US_Federal'
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('equals', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			true,
			result,
			'Result should be true because account.Region__c and metadata value__c have same value US Federal and operator is equals'
		);
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsGreaterOrEqualAndValueIsUsFederalAndFieldTypeIsString_ReturnTrue() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c, Geo__c
			FROM Account
			WHERE Name = 'Test Federal Account'
			LIMIT 1
		];
		Account_Segment_Mapping__mdt accountSegmentMapping = [
			SELECT Id, Label, DeveloperName, Order__c, Field__c, Operator__c, Value__c, Segment__c
			FROM Account_Segment_Mapping__mdt
			WHERE DeveloperName = 'US_Federal'
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('greater or equal', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			true,
			result,
			'Result should be true because account.Region__c is US Federal and metadata value__c is US Federal and operator is greater or equal'
		);
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsLessOrEqualAndValueIsNullAndFieldTypeIsString_ReturnTrue() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c, Geo__c
			FROM Account
			WHERE Name = 'Test Federal Account'
			LIMIT 1
		];
		Account_Segment_Mapping__mdt accountSegmentMapping = [
			SELECT Id, Label, DeveloperName, Order__c, Field__c, Operator__c, Value__c, Segment__c
			FROM Account_Segment_Mapping__mdt
			WHERE DeveloperName = 'US_Federal'
			LIMIT 1
		];

		account.Geo__c = null;
		account.Region__c = null;
		accountSegmentMapping.Value__c = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('less or equal', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			true,
			result,
			'Result should be true because account.Region__c is null and metadata value__c is null and operator is less or equal'
		);
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsEqualAndValueIsTrueAndFieldTypeIsBoolean_ReturnTrue() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c, Geo__c, Sync_with_Zift__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];

		Account_Segment_Mapping__mdt accountSegmentMapping = new Account_Segment_Mapping__mdt(
			Label = 'Sync with Zift',
			DeveloperName = 'Sync_with_Zift',
			Order__c = 10,
			Field__c = 'Sync_with_Zift__c',
			Operator__c = 'equals',
			Value__c = 'true',
			Segment__c = 'Undetermined'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('equals', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			true,
			result,
			'Result should be true because account.Sync_with_Zift and metadata value__c have same value true and operator is equals'
		);
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsEqualAndValueIsNullAndFieldTypeIsBoolean_ReturnTrue() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c, Geo__c, Sync_with_Zift__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];
		account.Sync_with_Zift__c = null;

		Account_Segment_Mapping__mdt accountSegmentMapping = new Account_Segment_Mapping__mdt(
			Label = 'Sync with Zift',
			DeveloperName = 'Sync_with_Zift',
			Order__c = 10,
			Field__c = 'Sync_with_Zift__c',
			Operator__c = 'equals',
			Value__c = null,
			Segment__c = 'Undetermined'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('equals', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			true,
			result,
			'Result should be true because account.Sync_with_Zift and metadata value__c have same value true and operator is equals'
		);
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsNotEqualAndValueIsZeroAndFieldTypeIsBoolean_ReturnTrue() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c, Geo__c, Sync_with_Zift__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];
		account.Sync_with_Zift__c = true;

		Account_Segment_Mapping__mdt accountSegmentMapping = new Account_Segment_Mapping__mdt(
			Label = 'Sync with Zift',
			DeveloperName = 'Sync_with_Zift',
			Order__c = 10,
			Field__c = 'Sync_with_Zift__c',
			Operator__c = 'not equal to',
			Value__c = '0',
			Segment__c = 'Undetermined'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('not equal to', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			true,
			result,
			'Result should be true because account.Sync_with_Zift is true and metadata value__c is 0 and operator is not equal to'
		);
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsLessOrEqualAndValueIsOneHundredAndFieldTypeIsDecimal_ReturnsTrue() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];
		Account_Segment_Mapping__mdt accountSegmentMapping = [
			SELECT Id, Label, DeveloperName, Order__c, Field__c, Operator__c, Value__c, Segment__c
			FROM Account_Segment_Mapping__mdt
			WHERE DeveloperName = 'Commercial'
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('less or equal', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			true,
			result,
			'Result should be true because account.Region__c and metadata value__c have same value US Federal and operator is equals'
		);
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsGreaterOrEqualAndValueIsYesterdayAndFieldTypeIsDate_ReturnsTrue() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c, Geo__c, Territory_Changed_Date__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];

		Account_Segment_Mapping__mdt accountSegmentMapping = new Account_Segment_Mapping__mdt(
			Label = 'Territory Changed Date',
			DeveloperName = 'Territory_Changed_Date',
			Order__c = 10,
			Field__c = 'Territory_Changed_Date__c',
			Operator__c = 'greater or equal',
			Value__c = System.today().addDays(-1).toString(),
			Segment__c = 'Undetermined'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('greater or equal', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			true,
			result,
			'Result should be true because account.Territory_Changed_Date__c is yesterday and metadata value__c is yesterday and operator is greater or equal'
		);
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsEqualAndValueIsTodayAndFieldTypeIsDate_ReturnFalse() {
		Boolean result;
		Account account = [
			SELECT Id, Region__c, Sales_Ops_Derived_EP__c, Geo__c, Territory_Changed_Date__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];

		Account_Segment_Mapping__mdt accountSegmentMapping = new Account_Segment_Mapping__mdt(
			Label = 'Territory Changed Date',
			DeveloperName = 'Territory_Changed_Date',
			Order__c = 10,
			Field__c = 'Territory_Changed_Date__c',
			Operator__c = 'greater or equal',
			Value__c = 'today',
			Segment__c = 'Undetermined'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountUtility.evaluate('equal', accountSegmentMapping, account);
			Test.stopTest();
		}
		Assert.areEqual(
			false,
			result,
			'Result should be false because account.Territory_Changed_Date__c is not today and metadata value__c is today and operator is equal'
		);
	}

	/*
	@IsTest
	static void testEvaluate_WhenOperatorIsGreaterThanAndFieldTypeIsDate_ReturnsCorrectResult() {
		Boolean result;
		Date testDate = System.today().addDays(1);
		String valueToCompare = String.valueOf(testDate);
		Account acc = [SELECT Id, Name, PartnerAgreementDate__c FROM Account LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			acc.PartnerAgreementDate__c = System.today();
			update acc;
			result = AccountTriggerUtility.evaluateDate(
				'greater than',
				acc.get('PartnerAgreementDate__c'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using greater than operator, should return false');
			result = AccountTriggerUtility.evaluateDate(
				'less or equal',
				acc.get('PartnerAgreementDate__c'),
				valueToCompare
			);
			Assert.areEqual(true, result, 'Using less or equal operator, should return true');

			result = AccountTriggerUtility.evaluateDate(
				'greater or equal',
				acc.get('PartnerAgreementDate__c'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using greater or equal operator, should return false');

			valueToCompare = 'tomorrow';
			result = AccountTriggerUtility.evaluateDate(
				'equals',
				acc.get('PartnerAgreementDate__c'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using equal operator, should return false');

			valueToCompare = 'yesterday';
			result = AccountTriggerUtility.evaluateDate(
				'not equal to',
				acc.get('PartnerAgreementDate__c'),
				valueToCompare
			);
			Assert.areEqual(true, result, 'Using not equal to operator, should return true');

			valueToCompare = 'today';
			result = AccountTriggerUtility.evaluateDate(
				'less than',
				acc.get('PartnerAgreementDate__c'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using less than operator, should return false');
			Test.stopTest();
		}
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsEqualsAndFieldTypeIsDecimal_ReturnsCorrectResult() {
		Boolean result;
		Account acc = [SELECT Id, Name, Sales_Ops_Derived_EP__c FROM Account LIMIT 1];
		String valueToCompare = '500';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountTriggerUtility.evaluateDecimal(
				'equals',
				acc.get('Sales_Ops_Derived_EP__c'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using equal, method should return false');

			result = AccountTriggerUtility.evaluateDecimal(
				'not equal to',
				acc.get('Sales_Ops_Derived_EP__c'),
				valueToCompare
			);
			Assert.areEqual(true, result, 'Using not equal to, method should return true');

			result = AccountTriggerUtility.evaluateDecimal(
				'less than',
				acc.get('Sales_Ops_Derived_EP__c'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using less than, method should return false');

			result = AccountTriggerUtility.evaluateDecimal(
				'greater than',
				acc.get('Sales_Ops_Derived_EP__c'),
				valueToCompare
			);
			Assert.areEqual(true, result, 'Using greater than, method should return true');

			result = AccountTriggerUtility.evaluateDecimal(
				'less or equal',
				acc.get('Sales_Ops_Derived_EP__c'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using less or equal, method should return false');

			result = AccountTriggerUtility.evaluateDecimal(
				'greater or equal',
				acc.get('Sales_Ops_Derived_EP__c'),
				valueToCompare
			);
			Assert.areEqual(true, result, 'Using greater or equal, method should return true');
			Test.stopTest();
		}
	}

	@IsTest
	static void testEvaluate_WhenOperatorIsEqualsAndFieldTypeIsString_ReturnsCorrectResult() {
		Boolean result;
		Account acc = [SELECT Id, Name, Tax_Reg_Number__c FROM Account LIMIT 1];
		String valueToCompare = 'Test Account';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = AccountTriggerUtility.evaluateString('equals', acc.get('Name'), valueToCompare);
			Assert.areEqual(true, result, 'Using equal, method should return true');

			result = AccountTriggerUtility.evaluateString(
				'not equal to',
				acc.get('Name'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using not equal to, method should return false');

			result = AccountTriggerUtility.evaluateString(
				'less than',
				acc.get('Name'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using less than, method should return false');

			result = AccountTriggerUtility.evaluateString(
				'greater than',
				acc.get('Name'),
				valueToCompare
			);
			Assert.areEqual(false, result, 'Using greater than, method should return false');

			result = AccountTriggerUtility.evaluateString(
				'less or equal',
				acc.get('Name'),
				valueToCompare
			);
			Assert.areEqual(true, result, 'Using less or equal, method should return true');

			result = AccountTriggerUtility.evaluateString(
				'greater or equal',
				acc.get('Name'),
				valueToCompare
			);
			Assert.areEqual(true, result, 'Using greater or equal, method should return true');
			Test.stopTest();
		}
	}*/
}