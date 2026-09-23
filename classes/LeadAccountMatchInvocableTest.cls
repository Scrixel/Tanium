/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for the LeadAccountMatchInvocable class
 * @Date: 2018-10-31
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * TAN-697    2018-10-31    Initial Development
 * TAN-798    2019-08-10    Fixed test class failure and TestFactory methods to optimize the code
 * TAN-791    2019-08-08    Added test method to assert Lead Assignment functionality
 * TAN-799    2019-08-15    Updated test method, Used HQ_State__c & Countries__c in Lead.Owner re-assignment functionality
 * TAN-789    2019-09-24    Updated code to populate Lead.Country and Lead.State fields.
 * TAN-789    2019-09-30    Updated code to increase coverage.
 * SS-13048   2026-04-14    Rewrote test class to use makeData method and Assert class
 * SS-13497   2026-07-07    Remove deprecated fields for project kondo group 2
 * SS-13499   2026-07-08    Removed Matched_Contact__c reference
 */
@IsTest
private class LeadAccountMatchInvocableTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
		Group q1;
		Group q2;
		QueuesObject qs1;
		QueuesObject qs2;

		System.runAs(TestUserFactory.getAdminUser()) {
			q1 = new Group(Name = 'CA Lead Queue #TAN-791-1', Type = 'Queue');
			q2 = new Group(Name = 'MNC Queue #TAN-799-1', Type = 'Queue');
			insert new List<Group>{ q1, q2 };

			qs1 = new QueueSObject(QueueId = q1.Id, SobjectType = 'Lead');
			qs2 = new QueueSObject(QueueId = q2.Id, SobjectType = 'Lead');
			insert new List<QueuesObject>{ qs1, qs2 };

			Account account = TestFactory.buildAccount('Test Account');
			account.Total_Addressable_Seats__c = 100000;
			account.Commission__c = 5;
			account.Domain__c = 'mail.com,yahoo.com';
			account.Country_Restrictions__c = 'Unrestricted';
			insert account;

			Contact contact = TestFactory.buildContact(account.Id);
			insert contact;

			List<Lead> leads = new List<Lead>();
			Lead suspect = TestFactory.buildLead(
				'Suspect',
				'Lead0',
				'suspect@mail.com',
				'Test Account',
				'New'
			);
			leads.add(suspect);

			Lead mQualified = TestFactory.buildLead(
				'Unqualified',
				'Lead1',
				'unqualified@mail.com',
				'Test Account',
				'New'
			);
			leads.add(mQualified);

			Lead matchEmail = TestFactory.buildLead(
				'Qualified',
				'Lead2',
				'qualified@mail.com',
				'Test Account',
				'New'
			);
			leads.add(matchEmail);

			Lead matchName = TestFactory.buildLead(
				'Unqualified2',
				'Lead3',
				null,
				'Test Account',
				'New'
			);
			leads.add(matchName);

			Lead testLead = TestFactory.buildLead(
				'Unqualified',
				'Lead4',
				'qualified@mail.com',
				'Test Account',
				'New'
			);
			leads.add(testLead);

			insert leads;
		}

		User currentUser = new User(Id = UserInfo.getUserId());
		System.runAs(currentUser) {
			SDR_Mapping__c sdrMap1 = buildSDRMapping(
				q1.Id,
				q1.Name,
				'CA',
				'United States',
				UserInfo.getUserId()
			);
			SDR_Mapping__c sdrMap2 = buildSDRMapping(
				q2.Id,
				q2.Name,
				null,
				'India',
				UserInfo.getUserId()
			);
			SDR_Mapping__c sdrMap3 = buildSDRMapping(
				q1.Id,
				q1.Name,
				'',
				'United States',
				UserInfo.getUserId()
			);
			SDR_Mapping__c sdrMap4 = buildSDRMapping(q1.Id, q1.Name, 'SK', 'Canada', null);
			insert new List<SDR_Mapping__c>{ sdrMap1, sdrMap2, sdrMap3, sdrMap4 };
		}
	}

	@IsTest
	static void testBuildLeadToMatchingAccountMap_WhenX_DoY() {
		Map<Id, Lead> leadMap = new Map<Id, Lead>(
			[SELECT Id, LastName, Email, Company, IsConverted, Account__c, RecordTypeId FROM Lead]
		);
		Account account = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			LeadAccountMatchInvocable.buildLeadToMatchingAccountMap(leadMap.values());
			Test.stopTest();
		}

		List<Lead> updatedLeads = [
			SELECT Id, LastName, OwnerId, Account__c, Status
			FROM Lead
			WHERE Id IN :leadMap.keySet()
			ORDER BY LastName ASC
		];

		Assert.areEqual('Lead0', updatedLeads[0].LastName);
		Assert.areEqual(account.Id, updatedLeads[0].Account__c);
		Assert.areEqual('Lead1', updatedLeads[1].LastName);
		Assert.areEqual(account.Id, updatedLeads[1].Account__c);
		Assert.areEqual('Lead2', updatedLeads[2].LastName);
		Assert.areEqual(account.Id, updatedLeads[2].Account__c);
	}

	static SDR_Mapping__c buildSDRMapping(
		String queueId,
		String queueName,
		String state,
		String country,
		String ownerId
	) {
		return new SDR_Mapping__c(
			Queue_ID__c = queueId,
			Queue_Name__c = queueName,
			SDR_Owner__c = ownerId,
			State_Province__c = state,
			Country__c = country
		);
	}
}