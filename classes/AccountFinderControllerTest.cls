@isTest
public with sharing class AccountFinderControllerTest {
	@TestSetup
	static void makeData() {
		List<Account> accountLst = new List<Account>();
		Account account, parentAccount;
		parentAccount = TestFactory.buildAccount('I am Parent');
		insert parentAccount;

		Id recordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Client');
		account = TestFactory.buildAccount('Test');
		account.ParentId = parentAccount.Id;
		account.RecordTypeId = recordTypeId;
		account.Industry = 'Insurance';
		accountLst.add(account);
		account = TestFactory.buildAccount('Tanium');
		accountLst.add(account);
		insert accountLst;
	}

	static testMethod void testGetSearchAcctResults_whenSearchCriteriaMatch_returnsRecords() {
		List<Id> fixedSearchResultsForTest = new List<Id>();
		List<Id> fixedSearchResultsForTanium = new List<Id>();

		User salesOpsUser = TestFactory.buildUser(
			'Sales Ops',
			'salesOps@tanium.com',
			'salesOps',
			Utility.getSuperUserProfileId(),
			Utility.getCorporateRoleId()
		);
		insert salesOpsUser;
		List<Account> accounts = [SELECT Id FROM Account WHERE Name LIKE '%Test%'];
		System.assertEquals(1, accounts.size());
		fixedSearchResultsForTest.add(accounts[0].Id);
		accounts = [SELECT Id FROM Account WHERE Name LIKE '%Tanium%'];
		System.assertEquals(1, accounts.size());
		fixedSearchResultsForTanium.add(accounts[0].Id);
		System.runAs(salesOpsUser) {
			Test.startTest();
			Test.setFixedSearchResults(fixedSearchResultsForTest);
			List<AccountFinderController.AccountData> accountLst = AccountFinderController.getSearchAcctResults(
				'Test'
			);
			Test.stopTest();
			System.assertEquals(
				1,
				accountLst.size(),
				'Database returns 1 that match makeData() in acct name criteria'
			);
			System.assertEquals(true, accountLst[0].name.contains('Test'));
			System.assertEquals(true, accountLst[0].parentName.equals('I am Parent'));
			System.assertNotEquals(null, accountLst[0].ownerName);
			System.assertEquals(true, accountLst[0].accountType.equals('Client'));
			System.assertEquals(true, accountLst[0].industry.equals('Insurance'));
			System.assertEquals(0, accountLst[0].numberOfOpenOpps);

			Test.setFixedSearchResults(fixedSearchResultsForTanium);
			accountLst = AccountFinderController.getSearchAcctResults('Tanium');
			System.assertEquals(
				1,
				accountLst.size(),
				'Database returns 2 that match makeData() in acct name criteria'
			);
			System.assertEquals(true, accountLst[0].name.contains('Tanium'));
			System.assertEquals(true, String.isBlank(accountLst[0].parentName));
			System.assertNotEquals(null, accountLst[0].ownerName);
		}
	}

	static testMethod void testGetSearchAcctResults_whenSearchCriteriaDontMatch_returnsNoRecords() {
		List<Id> fixedSearchResults = new List<Id>();
		User salesOpsUser = TestFactory.buildUser(
			'Sales Ops',
			'salesOps@tanium.com',
			'salesOps',
			Utility.getSuperUserProfileId(),
			Utility.getCorporateRoleId()
		);
		insert salesOpsUser;
		List<Account> accounts = [SELECT Id FROM Account WHERE Name LIKE '%Test%'];
		System.assertEquals(1, accounts.size());

		System.runAs(salesOpsUser) {
			Test.startTest();
			Test.setFixedSearchResults(fixedSearchResults);
			List<AccountFinderController.AccountData> accountLst = AccountFinderController.getSearchAcctResults(
				'Developer'
			);
			Test.stopTest();
			System.assertEquals(0, accountLst.size(), 'No accounts have developer string in them');
		}
	}
}