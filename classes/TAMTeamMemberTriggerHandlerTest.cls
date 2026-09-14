@isTest
public with sharing class TAMTeamMemberTriggerHandlerTest {
	@isTest(SeeAllData=false)
	static void test1() {
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj = new User(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser',
			Username = 'roscoapextest@roscolab.com',
			Alias = 'xafds',
			CommunityNickname = 'asdfsaafd3',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);
		insert userObj;

		String teamSMETypeId = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_SME');
		TAM_Team__c smeTeam1 = new TAM_Team__c(
			Name = 'SME-Patch',
			recordTypeId = teamSMETypeId,
			Specialty_Group__c = null
		);
		insert smeTeam1;

		String memberSMETypeId = Utility.getRecordTypeIdByAPIName(
			'TAM_Team_Member__c',
			'Escalation_SME'
		);
		TAM_Team_Member__c smeMember = new TAM_Team_Member__c(
			recordTypeId = memberSMETypeId,
			Responsibility__c = 'Support Enabled',
			Slack_Name__c = 'foo.bar',
			TAM_Team__c = smeTeam1.Id,
			TAM__c = userObj.Id
		);
		insert smeMember;

		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';
			insert accountObj;

			Contact contactObj = new Contact(
				Email = 'roscoapextest@tanium.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = null
			);
			insert contactObj;

			String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');

			Case caseObj = new Case(
				ContactId = contactObj.id,
				accountid = accountObj.id,
				ownerid = userObj.id,
				subject = 'ROSCOTESTCASE',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				suppliedEmail = '99@outlook.com',
				LatestPublicCommentHTML__c = '<html>hello</html>',
				Component__c = 'Other',
				RecordTypeId = recordTypeId,
				SME_OwnerId__c = userObj.Id,
				status = 'In Progress - Troubleshooting'
			);
			insert caseObj;

			TAM_Team_Member__c member = [SELECT Id FROM TAM_Team_Member__c WHERE Id = :smeMember.Id];
			delete member;
		}

	}
}