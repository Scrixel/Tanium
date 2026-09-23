@IsTest
private class RoscoCaseContactRoleTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'UserTriggerHandler',
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'CaseTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Id communityProfileId = Utility.getProfileId('Tanium Customer Community Profile');

			List<User> users = new List<User>();
			users.add(TestUserFactory.createBasicUser('communityUser1', communityProfileId));
			users[0].UserRoleId = null;
			users[0].UserPermissionsKnowledgeUser = false;
			users[0].CommunityNickname = 'user1foo';
			users[0].Email = 'user1@testtanium.com';

			users.add(TestUserFactory.createBasicUser('communityUser2', communityProfileId));
			users[1].UserRoleId = null;
			users[1].UserPermissionsKnowledgeUser = false;
			users[1].CommunityNickname = 'user2foo';
			users[1].Email = 'user2@testtanium.com';

			users.add(TestUserFactory.createBasicUser('communityUser3', communityProfileId));
			users[2].UserRoleId = null;
			users[2].UserPermissionsKnowledgeUser = false;
			users[2].CommunityNickname = 'user3foo';
			users[2].Email = 'user3@testtanium.com';

			users.add(TestUserFactory.createBasicUser('ptamfoo', communityProfileId));
			users[3].UserRoleId = null;
			users[3].UserPermissionsKnowledgeUser = false;
			users[3].CommunityNickname = 'ptamfoo';
			users[3].Email = 'ptam@testtanium.com';

			users.add(TestUserFactory.createBasicUser('stamfoo', communityProfileId));
			users[4].UserRoleId = null;
			users[4].UserPermissionsKnowledgeUser = false;
			users[4].CommunityNickname = 'stamfoo';
			users[4].Email = 'stam@testtanium.com';
			insert users;

			List<Account> accounts = new List<Account>();
			accounts.add(TestFactory.buildAccount('testRoscoCaseContactRole'));
			accounts[0].Solution_Engineer_RVP__c = UserInfo.getUserId();
			accounts[0].TAM_Sales_SME__c = UserInfo.getUserId();
			accounts[0].Support_Model__c = 'Support Center (Japan Bypass)';

			accounts.add(TestFactory.buildAccount('cmSettingAccount'));
			insert accounts;

			List<Contact> contacts = new List<Contact>();
			contacts.add(TestFactory.buildContact(accounts[0].Id));
			contacts[0].FirstName = 'contac';
			contacts[0].LastName = 't';
			contacts[0].Email = 'contact@testtanium.com';

			contacts.add(TestFactory.buildContact(accounts[1].Id));
			insert contacts;

			Case tCase = TestFactory.buildCase(accounts[0].Id, contacts[0].Id);
			tCase.OwnerId = users[0].Id;
			insert tCase;

			CaseContactRole caseContactRole = new CaseContactRole(
				ContactId = contacts[0].Id,
				CasesId = tCase.Id
			);
			insert caseContactRole;

			List<Rosco_domain__c> domains = new List<Rosco_domain__c>();
			domains.add(
				new Rosco_domain__c(
					Name = 'outlook.com',
					user_automation__c = 'Support KB',
					Account__c = accounts[0].Id
				)
			);
			domains.add(
				new Rosco_domain__c(
					Name = 'testtanium.com',
					user_automation__c = 'Support KB',
					Account__c = accounts[0].Id
				)
			);
			domains.add(
				new Rosco_domain__c(
					Name = 'bar.com',
					user_automation__c = 'Support KB',
					Account__c = accounts[0].Id
				)
			);
			insert domains;

			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.Name = '';
			cmSetting.rosco_contactid_exclusion__c = contacts[1].Id;
			cmSetting.rosco_case_accountid__c = accounts[1].Id;
			cmSetting.rosco_case_sc_japan_email__c = 'testJananEmail@test.com';
			insert cmSetting;
		}
	}

	@IsTest
	static void testRoscoCaseContactRole_setCcrViaString() {
		Case[] cases = [SELECT Id FROM Case];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoCaseContactRole.initCaseContactRoles(cases);

			String ccr = RoscoCaseContactRole.getCCRString(cases[0].Id);
			List<Map<String, String>> tCaseDetails = RoscoCaseContactRole.setCcrViaString(
				'newaccount@outlook.com;contact@testtanium.com',
				String.valueOf(cases[0].Id)
			);
			List<Map<String, String>> lookup = RoscoCaseContactRole.getCCRLookup(
				'foo',
				'foo33333@outlook.com;j@testtanium.com',
				String.valueOf(cases[0].Id)
			);
			List<Map<String, String>> lookup2 = RoscoCaseContactRole.getCCRLookup(
				'',
				'foo33333@outlook.com;j@testtanium.com',
				String.valueOf(cases[0].Id)
			);
			List<Map<String, String>> lookup3 = RoscoCaseContactRole.getCCRLookup(
				'k@testtanium.com',
				'foo33333@outlook.com;j@testtanium.com',
				String.valueOf(cases[0].Id)
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void testRoscoCaseContactRole_getCCRNewCase() {
		Case testCase = [SELECT Id, ContactId, AccountId FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			List<String> cids = new List<String>();
			cids.add(testCase.ContactId);

			List<String> nodelete = new List<String>();
			nodelete.add(testCase.ContactId);

			RoscoCaseContactRole.getCCRNewCase(cids, testCase.AccountId, nodelete);
			Test.stopTest();
		}
	}

	@IsTest
	static void testRoscoCaseContactRole_getCCRLookup() {
		Case tCase = [SELECT Id, ContactId, AccountId FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			List<String> cids = new List<String>();
			cids.add(tCase.ContactId);

			List<String> nodelete = new List<String>();
			nodelete.add(tCase.ContactId);

			RoscoCaseContactRole.getCCRLookup('', '', String.valueOf(tCase.Id));
			RoscoCaseContactRole.getCCRLookup('foo', '', String.valueOf(tCase.Id));

			RoscoCaseContactRole.getCCRLookupNewCase('foo', '', String.valueOf(tCase.AccountId));
			RoscoCaseContactRole.getCCRLookupNewCase('', '', String.valueOf(tCase.AccountId));
			Test.stopTest();
		}
	}

	@IsTest
	static void testRoscoCaseContactRole_setCcrViaStringNewCase() {
		Case tCase = [SELECT Id, ContactId, AccountId FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			List<String> cids = new List<String>();
			cids.add(tCase.ContactId);

			List<String> nodelete = new List<String>();
			nodelete.add(tCase.ContactId);

			RoscoCaseContactRole.setCCRViaStringNewCase(
				'foo@bar.com;foo1@bar.com;contact@testtanium.com',
				tCase.AccountId,
				nodelete
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void testLogNebulaException() {
		try {
			Integer test = 1 / 0;
		} catch (Exception e) {
			RoscoCaseContactRole.logNebulaException('test', e);
		}
	}
}