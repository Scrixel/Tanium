/**
 * @Business: RoscoScheduleTest Test methods for class RoscoSchedule
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId    ModifiedDate   	Description
 * SS-7277      2024-02-23      Jason's last changes linked to ticket SCLOUD-723 plus layout changes by Tanium Dev Team
 * SS-11173     2025-07-10      Changed field from Severity__c to Severity_Community__c 
 * SS-9790      2025-07-18      Remove unit test for method that is no longer used
 */
@IsTest
private class RoscoScheduleTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
		Id supportCaseRecTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated'].Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Account> accounts = new List<Account>();
			Account account = TestFactory.buildAccount('roscoapextestingd');
			account.slack_channel_id__c = 'TESTCASE';
			account.Type = 'Customer';
			account.Segment__c = 'Enterprise';
			account.Country_Exception_Approved__c = true;
			accounts.add(account);
			Account account2 = TestFactory.buildAccount('unit_setToSCIfMMOppWon2');
			account2.slack_channel_id__c = 'TESTCASE';
			account2.Type = 'Customer';
			account2.Segment__c = 'Enterprise';
			account2.Support_Model__c = 'Support Center (Japan Bypass)';
			account2.Country_Exception_Approved__c = true;
			accounts.add(account2);
			insert accounts;
			List<Contact> contacts = new List<Contact>();
			contacts.add(TestFactory.buildContact(accounts[0].Id));
			Contact contact2 = TestFactory.buildContact(accounts[0].Id);
			contact2.Email.replace(contact2.Email.substringBefore('@'), 'contact2');
			contacts.add(contact2);
			insert contacts;
			List<Opportunity> opps = new List<Opportunity>();
			Opportunity opp1 = TestFactory.buildOpportunity(
				'roscoapextest',
				Date.today(),
				Utility.PROSPECTING,
				accounts[0].Id
			);
			Opportunity opp2 = TestFactory.buildOpportunity(
				'roscoapextest',
				Date.today(),
				Utility.CLOSED_WON,
				accounts[1].Id
			);
			opps.add(opp2);
			insert opps;
			Case caseRecord = new Case(RecordTypeId = supportCaseRecTypeId);
			caseRecord.ContactId = contacts[0].Id;
			caseRecord.Accountid = accounts[0].Id;
			caseRecord.Subject = 'ROSCOTESTCASE';
			caseRecord.Severity_Community__c = '3';
			caseRecord.Type = 'Incident';
			caseRecord.Reason = 'New problem';
			caseRecord.Origin = 'Email';
			caseRecord.SuppliedEmail = '99@outlook.com';
			insert caseRecord;
			List<Rosco_domain__c> roscoDomains = new List<Rosco_domain__c>();
			roscoDomains.add(
				new Rosco_domain__c(
					Name = 'roscolab.com',
					Account__c = accounts[0].Id,
					user_automation__c = 'Support KB'
				)
			);
			roscoDomains.add(
				new Rosco_domain__c(
					Name = 'roscolab2.com',
					Account__c = accounts[0].Id,
					user_automation__c = 'Support Case'
				)
			);
			insert roscoDomains;
			List<User> users = new List<User>();
			users.add(
				new User(
					Email = 'roscoapextest@roscolab.com',
					FirstName = 'Test',
					LastName = 'ApexUser',
					Username = 'roscoapextest@roscolab.com.roscotestschedule',
					ContactId = contacts[0].Id,
					Alias = 'testals',
					CommunityNickname = 'testcommnickname',
					TimeZoneSidKey = 'America/Los_Angeles',
					LocaleSidKey = 'en_US',
					EmailEncodingKey = 'ISO-8859-1',
					ProfileId = profileId,
					LanguageLocaleKey = 'en_US'
				)
			);
			users.add(
				new User(
					Email = 'roscoapextest@roscolab2.com',
					FirstName = 'Test',
					LastName = 'ApexUser',
					Username = 'roscoapextest@roscolab2.com.roscotestschedule',
					ContactId = contacts[1].Id,
					Alias = 'testals2',
					CommunityNickname = 'testcommnickname2',
					TimeZoneSidKey = 'America/Los_Angeles',
					LocaleSidKey = 'en_US',
					EmailEncodingKey = 'ISO-8859-1',
					ProfileId = profileId,
					LanguageLocaleKey = 'en_US'
				)
			);
			insert users;
		}
	}

	@IsTest
	static void test() {
		Test.setMock(HttpCalloutMock.class, new MockCallout());
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			SchedulableContext ctx;
			RoscoSchedule rs2 = new RoscoSchedule();
			rs2.action = 'all';
			rs2.execute(ctx);
			RoscoSchedule rs3 = new RoscoSchedule();
			rs3.action = 'setSupportModel';
			rs3.execute(ctx);
			RoscoSchedule rs4 = new RoscoSchedule();
			rs4.action = 'nagCaseContact';
			rs4.execute(ctx);
			RoscoSchedule rs5 = new RoscoSchedule();
			rs5.action = 'closedSolvedCases';
			rs5.execute(ctx);
			RoscoSchedule rs6 = new RoscoSchedule();
			rs6.action = 'manageCmtyUsers';
			rs6.execute(ctx);
			RoscoSchedule.qCallOut callout = new RoscoSchedule.qCallOut('url', 'method', 'body');
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_manageCmtyUsersPromoteAccount() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoSchedule.manageCmtyUsersPromoteAccount(RoscoSchedule.getRoscoDomains());
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_closedSolvedCases() {
		Test.setMock(HttpCalloutMock.class, new MockCallout());
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoSchedule.closedSolvedCases();
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_descalateCases() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoSchedule.deEscalateCases();
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_manageAPINotificationsGroup() {
		String soql =
			'SELECT Id ' +
			'FROM CollaborationGroup ' +
			'WHERE Name = \'Tanium API Notifications\' ';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			List<CollaborationGroup> groups = Database.query(soql);
			if (groups.isEmpty()) {
				CollaborationGroup newCg = new CollaborationGroup();
				newCg.CanHaveGuests = false;
				newCg.CollaborationType = 'Private';
				newCg.Description = 'This group is where Tanium will notify verified customers and partners about changes, deprecations, and new features in the Tanium APIs.';
				newCg.Name = 'Tanium API Notifications2';
				newCg.NetworkId = '0DB0e000000CaezGAC';
				insert newCg;
			}
			RoscoSchedule.manageAPINotificationsGroup();
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_manageCmtyUsers() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoSchedule.manageCmtyUsers();
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_setToSCIfMMOppWon() {
		Test.setMock(HttpCalloutMock.class, new MockCallout());
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoSchedule.setToSCIfMMOppWon();
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_setToSCIfMMOppWon2() {
		Test.setMock(HttpCalloutMock.class, new MockCallout());
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoSchedule.setToSCIfMMOppWon2();
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_setToPartnerSCIfKimbleDone() {
		Test.setMock(HttpCalloutMock.class, new MockCallout());
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoSchedule.setToPartnerSCIfKimbleDone();
			Test.stopTest();
		}
	}

	@IsTest
	static void unit_nagCaseContact() {
		Test.setMock(HttpCalloutMock.class, new MockCallout());
		Account account = [SELECT Id FROM Account LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.Customer_Community_URL__c = 'https://support.tanium.com';
			insert cmSetting;
			RoscoSchedule.nagCaseContact();
			cmSetting.rosco_nag_mail_limit_accountids__c = '\'' + String.valueOf(account.Id) + '\'';
			upsert cmSetting;
			RoscoSchedule.nagCaseContact();
			cmSetting.rosco_nag_mail_test_mode__c = 'false';
			upsert cmSetting;
			RoscoSchedule.nagCaseContact();
			Test.stopTest();
		}
	}

	public class MockCallout implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest request) {
			HttpResponse res = new HttpResponse();
			res.setBody('{"text":"value"}');
			res.setStatusCode(200);
			return res;
		}
	}

	@IsTest
	static void test_unit_qCallOut() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Test.startTest();
		RoscoSchedule.qCallOut testCallout = new RoscoSchedule.qCallOut('testURL', 'GET', 'TestBODY');
		Id jobId1 = System.enqueueJob(testCallout);
		Test.stopTest();

		Assert.isNotNull(jobId1);
	}
}