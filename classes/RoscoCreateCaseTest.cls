@isTest
public with sharing class RoscoCreateCaseTest {
	static void CreateRecords() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	@isTest(SeeAllData=false)
	static void TestIt() {
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Account accountObj = TestFactory.buildAccount('roscoapextestingd');
		accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.NumberOfEmployees = 1;
		insert accountObj;

		Contact contactObj = new Contact(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj;
		Contact contactObj2 = new Contact(
			Email = 'roscoapextest@tanium.com',
			FirstName = 'Test2',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj2;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj = TestFactory.buildUser(
			'ApexUser',
			'roscoapextest@roscolab.com',
			'roscoapextest@roscolab.com',
			profileId
		);
		userObj.Email = 'roscoapextest@roscolab.com';
		userObj.FirstName = 'Test';
		userObj.LastName = 'ApexUser';
		userObj.Username = 'roscoapextest@roscolab.com';
		userObj.Alias = 'afdsa';
		userObj.CommunityNickname = 'asfdasf';
		userObj.TimeZoneSidKey = 'America/Los_Angeles';
		userObj.LocaleSidKey = 'en_US';
		userObj.EmailEncodingKey = 'ISO-8859-1';
		userObj.ProfileId = profileId;
		userObj.LanguageLocaleKey = 'en_US';
		insert userObj;

		Map<String, Object> caseinfo = new Map<String, Object>();
		caseinfo.put('accountId', accountObj.Id);
		caseinfo.put('componentversion', '123');
		caseinfo.put('case_component', 'Other');
		caseinfo.put('contactId', contactObj.Id);
		caseinfo.put('jira', '1');
		caseinfo.put('ownerId', userObj.Id);
		caseinfo.put('severity', '3.0');
		caseinfo.put('status', 'On Hold');
		caseinfo.put('status_details', '');
		caseinfo.put('subject', 'ROSCOTESTCASE');
		caseinfo.put('tags', 'tag1');
		caseinfo.put('case_type', 'Incident');
		caseinfo.put('richtext', 'blah');
		caseinfo.put('description', 'blah');

		caseinfo.put('ccrstring', 'rosco1@tanium.com;rosco2@tanium.com');

		List<String> ccnodelete = new List<String>();
		ccnodelete.add('rosco1@tanium.com');

		RoscoCreateCase.createCase(caseinfo, ccnodelete);
	}

	@isTest(SeeAllData=false)
	static void TestIt2() {
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Account accountObj = TestFactory.buildAccount('roscoapextestingd');
		accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.NumberOfEmployees = 1;
		insert accountObj;

		Contact contactObj = new Contact(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj;
		Contact contactObj2 = new Contact(
			Email = 'roscoapextest@tanium.com',
			FirstName = 'Test2',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj2;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj = TestFactory.buildUser(
			'ApexUser',
			'roscoapextest@roscolab.com',
			'roscoapextest@roscolab.com',
			profileId
		);
		userObj.Email = 'roscoapextest@roscolab.com';
		userObj.FirstName = 'Test';
		userObj.LastName = 'ApexUser';
		userObj.Username = 'roscoapextest@roscolab.com';
		userObj.Alias = 'afdsa';
		userObj.CommunityNickname = 'asfdasf';
		userObj.TimeZoneSidKey = 'America/Los_Angeles';
		userObj.LocaleSidKey = 'en_US';
		userObj.EmailEncodingKey = 'ISO-8859-1';
		userObj.ProfileId = profileId;
		userObj.LanguageLocaleKey = 'en_US';
		insert userObj;

		Map<String, Object> caseinfo = new Map<String, Object>();
		caseinfo.put('accountId', accountObj.Id);
		caseinfo.put('componentversion', '123');
		caseinfo.put('case_component', 'Other');
		caseinfo.put('contactId', contactObj.Id);
		caseinfo.put('jira', '1');
		caseinfo.put('ownerId', userObj.Id);
		caseinfo.put('severity', '3.0');
		caseinfo.put('status', 'On Hold');
		caseinfo.put('status_details', '');
		caseinfo.put('subject', 'ROSCOTESTCASE');
		caseinfo.put('tags', 'tag1');
		caseinfo.put('case_type', 'Incident');
		caseinfo.put('richtext', 'blah');
		caseinfo.put('description', 'blah');

		caseinfo.put('ccrstring', 'rosco1@tanium.com;rosco2@tanium.com');

		List<String> ccnodelete = new List<String>();
		ccnodelete.add('rosco1@tanium.com');

		RoscoCreateCase.createCase(caseinfo, ccnodelete);

		caseinfo.put('isFedCase', 'true');
		RoscoCreateCase.createCase(caseinfo, ccnodelete);
		caseinfo.put('isFedCase', 'false');

		caseinfo.put('isCaseTypeInternal', 'true');
		caseinfo.put('case_type', 'TAM Assignment');
		caseinfo.put('contactId', '1');
		caseinfo.put('accountId', '1');
		caseinfo.put('pod', 'East');
		caseinfo.put('preferredTAMEmail', 'roscoapextest@tanium.com');
		caseinfo.put('optionalTime', 'foo');
		//RoscoCreateCase.createCase(caseinfo, ccnodelete);

		caseinfo.put('case_type', 'SME Engagement');
		caseinfo.put('escteam', 'SME-Other');
		RoscoCreateCase.createCase(caseinfo, ccnodelete);

		RoscoCreateCase.getFedPlaceholderAccountId();
	}

	@isTest(SeeAllData=false)
	static void TestIt3() {
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Account accountObj = TestFactory.buildAccount('roscoapextestingd');
		accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.NumberOfEmployees = 1;
		insert accountObj;

		Contact contactObj = new Contact(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj;
		Contact contactObj2 = new Contact(
			Email = 'roscoapextest@tanium.com',
			FirstName = 'Test2',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj2;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj = TestFactory.buildUser(
			'ApexUser',
			'roscoapextest@roscolab.com',
			'roscoapextest@roscolab.com',
			profileId
		);
		userObj.Email = 'roscoapextest@roscolab.com';
		userObj.FirstName = 'Test';
		userObj.LastName = 'ApexUser';
		userObj.Username = 'roscoapextest@roscolab.com';
		userObj.Alias = 'afdsa';
		userObj.CommunityNickname = 'asfdasf';
		userObj.TimeZoneSidKey = 'America/Los_Angeles';
		userObj.LocaleSidKey = 'en_US';
		userObj.EmailEncodingKey = 'ISO-8859-1';
		userObj.ProfileId = profileId;
		userObj.LanguageLocaleKey = 'en_US';
		insert userObj;

		Map<String, Object> caseinfo = new Map<String, Object>();
		caseinfo.put('accountId', accountObj.Id);
		caseinfo.put('componentversion', '123');
		caseinfo.put('case_component', 'Other');
		caseinfo.put('contactId', contactObj.Id);
		caseinfo.put('jira', '1');
		caseinfo.put('ownerId', userObj.Id);
		caseinfo.put('severity', '3.0');
		caseinfo.put('status', 'On Hold');
		caseinfo.put('status_details', '');
		caseinfo.put('subject', 'ROSCOTESTCASE');
		caseinfo.put('tags', 'tag1');
		caseinfo.put('case_type', 'Incident');
		caseinfo.put('richtext', 'blah');
		caseinfo.put('description', 'blah');

		caseinfo.put('ccrstring', 'rosco1@tanium.com;rosco2@tanium.com');

		List<String> ccnodelete = new List<String>();
		ccnodelete.add('rosco1@tanium.com');

		RoscoCreateCase.createCase(caseinfo, ccnodelete);

		caseinfo.put('isFedCase', 'true');
		RoscoCreateCase.createCase(caseinfo, ccnodelete);
		caseinfo.put('isFedCase', 'false');

		caseinfo.put('isCaseTypeInternal', 'true');
		caseinfo.put('case_type', 'TAM Assignment');
		caseinfo.put('contactId', '1');
		caseinfo.put('accountId', '1');
		caseinfo.put('pod', 'East');
		caseinfo.put('preferredTAMEmail', 'roscoapextest@tanium.com');
		caseinfo.put('optionalTime', 'foo');
		//RoscoCreateCase.createCase(caseinfo, ccnodelete);

		caseinfo.put('case_type', 'SME Engagement');
		caseinfo.put('escteam', 'SME-Other');
		//RoscoCreateCase.createCase(caseinfo, ccnodelete);
	}

	@isTest(SeeAllData=true)
	static void TestIt99() {
		Map<String, Object> init = RoscoCreateCase.getInitInfo();
	}

	@isTest(SeeAllData=false)
	static void TestInternalCase() {
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Account accountObj = TestFactory.buildAccount('roscoapextestingd');
		accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.NumberOfEmployees = 1;
		insert accountObj;

		Contact contactObj = new Contact(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj;
		Contact contactObj2 = new Contact(
			Email = 'roscoapextest@tanium.com',
			FirstName = 'Test2',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj2;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj = TestFactory.buildUser(
			'ApexUser',
			'roscoapextest@roscolab.com',
			'roscoapextest@roscolab.com',
			profileId
		);
		userObj.Email = 'roscoapextest@roscolab.com';
		userObj.FirstName = 'Test';
		userObj.LastName = 'ApexUser';
		userObj.Username = 'roscoapextest@roscolab.com';
		userObj.Alias = 'afdsa';
		userObj.CommunityNickname = 'asfdasf';
		userObj.TimeZoneSidKey = 'America/Los_Angeles';
		userObj.LocaleSidKey = 'en_US';
		userObj.EmailEncodingKey = 'ISO-8859-1';
		userObj.ProfileId = profileId;
		userObj.LanguageLocaleKey = 'en_US';
		insert userObj;

		Map<String, Object> caseinfo = new Map<String, Object>();
		caseinfo.put('isCaseTypeInternal', 'true');
		caseinfo.put('accountId', accountObj.Id);
		caseinfo.put('componentversion', '123');
		caseinfo.put('case_component', 'Other');
		caseinfo.put('contactId', contactObj.Id);
		caseinfo.put('jira', '1');
		caseinfo.put('ownerId', userObj.Id);
		caseinfo.put('severity', '3.0');
		caseinfo.put('status', 'On Hold');
		caseinfo.put('status_details', '');
		caseinfo.put('subject', 'ROSCOTESTCASE');
		caseinfo.put('tags', 'tag1');
		caseinfo.put('case_type', 'Incident');
		caseinfo.put('richtext', 'blah');
		caseinfo.put('description', 'blah');

		caseinfo.put('ccrstring', 'rosco1@tanium.com;rosco2@tanium.com');

		List<String> ccnodelete = new List<String>();
		ccnodelete.add('rosco1@tanium.com');

		RoscoCreateCase.createCase(caseinfo, ccnodelete);
	}

	public class mockCallout implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest request) {
			HttpResponse res = new HttpResponse();
			res.setBody('{"text":"value"}');
			res.setStatusCode(200);
			return res;
		}
	}
}