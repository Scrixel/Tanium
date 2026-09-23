/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoHomePage
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12400   2026-01-22    Removed Primary_Contact__c field from class and best practice updates
 * SS-12607   2026-02-12    Remove TAM profile references and best practice updates
 * SS-13497   2026-07-07    Remove deprecated fields for project kondo group 2
 */
@IsTest
private class RoscoHomePageTest {
	private static String email = 'testclass@roscolab.com';
	private static String accName = 'testAccountRoscoA';
	private static String conEmail = 'testContactRoscoA@foo.invalid';
	private static String oppName = 'testOpportunityRoscoA';
	private static String caseName = 'testCaseRoscoA';

	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Contact conLoggedInUser = new Contact(
				Email = UserInfo.getUserEmail(),
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = null
			);
			insert conLoggedInUser;

			Account acc = TestFactory.buildAccount(accName);
			acc.slack_channel_id__c = 'TESTCASE';
			acc.Country_Exception_Approved__c = true;
			insert acc;

			Contact con = new Contact(
				Email = conEmail,
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = acc.Id
			);
			insert con;

			Opportunity opp = TestFactory.buildOpportunity(
				oppName,
				System.today() + 30,
				'Discovery',
				acc.Id
			);
			insert opp;

			String recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			Case caseRec = new Case(
				AccountId = acc.Id,
				OwnerId = UserInfo.getUserId(),
				ContactId = con.Id,
				Subject = caseName,
				Severity_Community__c = '3',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				RecordTypeId = recordTypeId,
				SuppliedEmail = '99@outlook.com',
				Status = 'On Hold'
			);
			insert caseRec;
		}
	}

	@IsTest
	static void testInitRoscoHomePageAccounts_Always_ReturnRoscoHomePageAccounts() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoHomePage.initRoscoHomePageAccounts();
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetAcct_Always_ReturnRoscoHomePageAccounts() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoHomePage.getAcct();
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetAssociatedObjects_Always_ReturnSuccessAccounts() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Account accountObjZ = TestFactory.buildAccount('foo');
			accountObjZ.Country_Exception_Approved__c = true;
			insert accountObjZ;

			Datetime now = datetime.now();
			Rosco_Time__c accountTime = new Rosco_Time__c(
				User__c = UserInfo.getUserId(),
				Minutes__c = 15,
				LaborCategory__c = 'Other Account Time',
				LaborSubCategory__c = 'General',
				LaborDate__c = now,
				Account__c = accountObjZ.Id
			);
			insert accountTime;

			List<Map<String, String>> objects = new List<Map<String, String>>();
			Map<String, String> jsonArgObj = new Map<String, String>();

			jsonArgObj.put('startIteration', '45');

			objects = RoscoHomePage.getAssociatedObjects(JSON.serialize(jsonArgObj));
			Boolean test1 = false;
			for (Map<String, String> o : objects) {
				if (o.get('Id') == accountObjZ.Id) {
					test1 = true;
				}
			}
			Assert.isTrue(test1);
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetAssociatedObjects_Always_ReturnSuccessOpportunities() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Account accountObjZ = TestFactory.buildAccount('foo');
			accountObjZ.Country_Exception_Approved__c = true;
			insert accountObjZ;

			Contact contactLoggedInUser = [
				SELECT Id
				FROM Contact
				WHERE Email = :UserInfo.getUserEmail()
			];

			Opportunity opportunityObjZ = new Opportunity(
				Name = oppName,
				AccountId = accountObjZ.id,
				StageName = 'Discovery',
				Amount = 1000,
				seats__c = 1000,
				CloseDate = system.today() + 30
			);
			insert opportunityObjZ;

			Datetime now = datetime.now();
			Rosco_Time__c opportunityTime = new Rosco_Time__c(
				User__c = UserInfo.getUserId(),
				Minutes__c = 15,
				LaborCategory__c = 'Presales Activity',
				LaborSubCategory__c = 'Foo',
				LaborDate__c = now,
				Opportunity__c = opportunityObjZ.Id,
				Account__c = accountObjZ.Id
			);
			insert opportunityTime;

			List<Map<String, String>> objects = new List<Map<String, String>>();
			Map<String, String> jsonArgObj = new Map<String, String>();

			jsonArgObj.put('startIteration', '45');

			objects = RoscoHomePage.getAssociatedObjects(JSON.serialize(jsonArgObj));
			Boolean test1 = false;
			for (Map<String, String> o : objects) {
				if (o.get('Id') == opportunityObjZ.Id) {
					test1 = true;
				}
			}
			Assert.isTrue(test1);
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetAssociatedObjects_Always_ReturnSuccessCases() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			List<Map<String, String>> objects = new List<Map<String, String>>();
			Map<String, String> jsonArgObj = new Map<String, String>();

			Case caseA = [SELECT Id, OwnerId FROM Case WHERE Subject = :caseName];

			jsonArgObj.put('startIteration', '45');

			objects = RoscoHomePage.getAssociatedObjects(JSON.serialize(jsonArgObj));
			Boolean test1 = false;
			for (Map<String, String> o : objects) {
				if (o.get('Id') == caseA.Id) {
					test1 = true;
				}
			}
			Assert.isTrue(test1);
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetAssociatedObjects_Always_ReturnSuccessCases2() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountA = [SELECT Id, Name FROM Account WHERE Name = :accName];
			Contact contactA = [SELECT Id FROM Contact WHERE Email = :conEmail];

			String recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			Case caseObjZ = new Case(
				accountid = accountA.id,
				contactid = contactA.Id,
				subject = 'foo',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				RecordTypeId = recordTypeId,
				suppliedEmail = '99@outlook.com',
				status = 'On Hold'
			);
			insert caseObjZ;

			Datetime now = datetime.now();
			Rosco_Time__c caseTime = new Rosco_Time__c(
				User__c = UserInfo.getUserId(),
				Minutes__c = 15,
				LaborCategory__c = 'Presales Activity',
				LaborSubCategory__c = 'Foo',
				LaborDate__c = now,
				Case__c = caseObjZ.Id
			);
			insert caseTime;

			List<Map<String, String>> objects = new List<Map<String, String>>();
			Map<String, String> jsonArgObj = new Map<String, String>();

			jsonArgObj.put('startIteration', '45');

			objects = RoscoHomePage.getAssociatedObjects(JSON.serialize(jsonArgObj));
			Boolean test1 = false;
			for (Map<String, String> o : objects) {
				if (o.get('Id') == caseObjZ.Id) {
					test1 = true;
				}
			}
			Assert.isTrue(test1);
		}
	}

	@IsTest
	static void testGetAssociatedObjects_Always_ReturnSuccessCases3() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountA = [SELECT Id, Name FROM Account WHERE Name = :accName];
			Contact contactA = [SELECT Id FROM Contact WHERE Email = :conEmail];

			String recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			Case caseObjZ = new Case(
				accountid = accountA.id,
				contactid = contactA.Id,
				subject = 'test_getAssociatedObjects_Case',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				RecordTypeId = recordTypeId,
				suppliedEmail = '99@outlook.com',
				status = 'On Hold'
			);
			insert caseObjZ;

			List<Map<String, String>> objects = new List<Map<String, String>>();
			Map<String, String> jsonArgObj = new Map<String, String>();

			jsonArgObj.put('startIteration', '45');

			objects = RoscoHomePage.getAssociatedObjects(JSON.serialize(jsonArgObj));
			Boolean test1 = false;
			for (Map<String, String> o : objects) {
				if (o.get('Id') == caseObjZ.Id) {
					test1 = true;
				}
			}
			Assert.isTrue(test1);
		}
	}

	@IsTest
	static void testGetAssociatedObjects_Always_ReturnSuccessCasesSME() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountA = [SELECT Id, Name FROM Account WHERE Name = :accName];
			Contact contactA = [SELECT Id FROM Contact WHERE Email = :conEmail];

			String recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			Case caseObjZ = new Case(
				accountid = accountA.id,
				contactid = contactA.Id,
				subject = 'test_getAssociatedObjects_Case',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				RecordTypeId = recordTypeId,
				suppliedEmail = '99@outlook.com',
				status = 'On Hold'
			);
			insert caseObjZ;

			Contact contactLoggedInUser = [
				SELECT Id
				FROM Contact
				WHERE Email = :UserInfo.getUserEmail()
			];

			CaseContactRole ccr = new CaseContactRole(
				CasesId = caseObjZ.Id,
				ContactId = contactLoggedInUser.Id,
				Role = 'Engaged SME'
			);
			insert ccr;

			List<Map<String, String>> objects = new List<Map<String, String>>();
			Map<String, String> jsonArgObj = new Map<String, String>();

			jsonArgObj.put('startIteration', '45');

			objects = RoscoHomePage.getAssociatedObjects(JSON.serialize(jsonArgObj));
			Boolean test1 = false;
			for (Map<String, String> o : objects) {
				if (o.get('Id') == caseObjZ.Id) {
					if (o.get('I\'m an engaged SME') == 'true') {
						test1 = true;
					}
				}
			}
			Assert.isTrue(test1);
		}
	}

	@IsTest
	static void testGetAssociatedObjects_Always_ReturnSuccessCasesPost() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountA = [SELECT Id, Name FROM Account WHERE Name = :accName];
			Contact contactA = [SELECT Id FROM Contact WHERE Email = :conEmail];

			String recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			Case caseObjZ = new Case(
				accountid = accountA.id,
				contactid = contactA.Id,
				subject = 'test_getAssociatedObjects_Case',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				RecordTypeId = recordTypeId,
				suppliedEmail = '99@outlook.com',
				status = 'On Hold'
			);
			insert caseObjZ;
		}

		Case caseObjZ = [SELECT Id FROM Case WHERE Subject = 'test_getAssociatedObjects_Case'];

		FeedItem newPost = new FeedItem(
			ParentId = caseObjZ.Id,
			Body = 'foo',
			Visibility = 'InternalUsers',
			IsRichText = false
		);
		insert newPost;

		FeedComment newComment = new FeedComment(
			FeedItemId = newPost.Id,
			CommentBody = 'ROSCOTESTCASE-Tanium',
			CommentType = 'TextComment'
		);
		insert newComment;

		List<Map<String, String>> objects = new List<Map<String, String>>();
		Map<String, String> jsonArgObj = new Map<String, String>();

		jsonArgObj.put('startIteration', '45');

		objects = RoscoHomePage.getAssociatedObjects(JSON.serialize(jsonArgObj));
		Boolean test1 = false;
		Boolean test2 = false;
		for (Map<String, String> o : objects) {
			if (o.get('Id') == caseObjZ.Id) {
				if (o.get('I\'ve posted to case recently') == 'true') {
					test1 = true;
				}
				if (o.get('I\'ve commented on case recently') == 'true') {
					test2 = true;
				}
			}
		}
		Assert.isTrue(test1);
		Assert.isTrue(test2);
	}

	@IsTest
	static void testGetAssociatedObjects_Always_ReturnSuccessCasesEmail() {
		Case caseA = [SELECT Id FROM Case WHERE Subject = :caseName];

		EmailMessage newEmail = new EmailMessage(
			ParentId = caseA.Id,
			RelatedToId = caseA.Id,
			Incoming = false,
			FromAddress = UserInfo.getUserEmail()
		);
		insert newEmail;

		List<Map<String, String>> objects = new List<Map<String, String>>();
		Map<String, String> jsonArgObj = new Map<String, String>();

		jsonArgObj.put('startIteration', '45');

		objects = RoscoHomePage.getAssociatedObjects(JSON.serialize(jsonArgObj));
		Boolean test1 = false;
		for (Map<String, String> o : objects) {
			if (o.get('Id') == caseA.Id) {
				if (o.get('I\'ve emailed within case case recently') == 'true') {
					test1 = true;
				}
			}
		}
		Assert.isTrue(test1);
	}

	@IsTest
	static void testGetAssociatedObjectsCaseOwner_Always_ReturnSuccess() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Case caseA = [SELECT Id, Subject FROM Case WHERE Subject = :caseName];

			Map<String, Map<String, String>> objects = RoscoHomePage.getAssociatedObjectsCaseOwner();
			Map<String, String> obj = objects.get(caseA.Id);

			Assert.isTrue(objects.containsKey(caseA.Id));
			Assert.isTrue(obj.get('isOwner') == 'true');
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetAssociatedObjectsCaseCc_Always_ReturnSuccess() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<String, Map<String, String>> objects = new Map<String, Map<String, String>>();
			Map<String, String> obj = new Map<String, String>();

			Case caseA = [SELECT Id, Subject FROM Case WHERE Subject = :caseName];
			Contact contactLoggedInUser = [
				SELECT Id
				FROM Contact
				WHERE Email = :UserInfo.getUserEmail()
			];

			objects = RoscoHomePage.getAssociatedObjectsCaseCc('');
			Assert.isTrue(objects.containsKey(caseA.Id));
			obj = objects.get(caseA.Id);
			Assert.isTrue(obj.get('isCaseCc') == 'true');
			Assert.isTrue(obj.get('isEngagedSME') == 'false');

			CaseContactRole ccr = [
				SELECT Id, Role
				FROM CaseContactRole
				WHERE CasesId = :caseA.Id AND ContactId = :contactLoggedInUser.Id
			];
			ccr.Role = 'Engaged SME';
			update ccr;
			objects = RoscoHomePage.getAssociatedObjectsCaseCc(UserInfo.getUserEmail());
			Assert.isTrue(objects.containsKey(caseA.Id));
			obj = objects.get(caseA.Id);
			Assert.isTrue(obj.get('isCaseCc') == 'true');
			Assert.isTrue(obj.get('isEngagedSME') == 'true');
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetAssociatedObjectsCasePost_Always_ReturnSuccess() {
		Map<String, Map<String, String>> objects = new Map<String, Map<String, String>>();
		Map<String, String> obj = new Map<String, String>();

		Case caseA = [SELECT Id, Subject FROM Case WHERE Subject = :caseName];

		objects = RoscoHomePage.getAssociatedObjectsCasePost('45');
		Assert.isFalse(objects.containsKey(caseA.Id));

		FeedItem newPost = new FeedItem(
			ParentId = caseA.Id,
			Body = 'foo',
			Visibility = 'InternalUsers',
			IsRichText = false
		);
		insert newPost;

		objects = RoscoHomePage.getAssociatedObjectsCasePost('45');
		Assert.isTrue(objects.containsKey(caseA.Id));
		obj = objects.get(caseA.Id);
		Assert.isTrue(obj.get('isCasePost') == 'true');

		objects = RoscoHomePage.getAssociatedObjectsCaseComment('45');
		Assert.isFalse(objects.containsKey(caseA.Id));

		FeedComment fc = new FeedComment(
			FeedItemId = newPost.Id,
			CommentBody = 'ROSCOTESTCASE-Tanium',
			CommentType = 'TextComment'
		);
		insert fc;

		objects = RoscoHomePage.getAssociatedObjectsCaseComment('45');
		Assert.isTrue(objects.containsKey(caseA.Id));
		obj = objects.get(caseA.Id);
		Assert.isTrue(obj.get('isCaseComment') == 'true');
	}

	@IsTest
	static void testGetAssociatedObjectsLabor_Always_ReturnSuccess() {
		Map<String, Map<String, String>> objects = new Map<String, Map<String, String>>();
		Map<String, String> obj = new Map<String, String>();

		Account accountA = [SELECT Id, Name FROM Account WHERE Name = :accName];

		objects = RoscoHomePage.getAssociatedObjectsLabor('45');
		Assert.isTrue(objects.size() == 0);

		Datetime now = datetime.now();
		Rosco_Time__c accountTime = new Rosco_Time__c(
			User__c = UserInfo.getUserId(),
			Minutes__c = 15,
			LaborCategory__c = 'Other Account Time',
			LaborSubCategory__c = 'General',
			LaborDate__c = now,
			Account__c = accountA.Id
		);
		insert accountTime;

		objects = RoscoHomePage.getAssociatedObjectsLabor('45');
		Assert.isTrue(objects.containsKey(accountA.Id));
		obj = objects.get(accountA.Id);
		Assert.isTrue(obj.get('isRecent') == 'true');
		Assert.areEqual('Account', obj.get('Item Type'));
		Assert.areEqual(accountA.Id, obj.get('Id'));
		Assert.areEqual(accountA.Name, obj.get('Account Name'));
		Assert.areEqual('None', obj.get('Opportunity ID'));
		Assert.areEqual('15', obj.get('Labor Tally'));
		Assert.areEqual(String.valueOf(now), obj.get('Labor Date'));
		Assert.areEqual(String.valueOf(now.dateGmt()), obj.get('Labor Date GMT'));
		Assert.areEqual('0', obj.get('LaborDateAge'));

		Rosco_Time__c accountTime2 = new Rosco_Time__c(
			User__c = UserInfo.getUserId(),
			Minutes__c = 15,
			LaborCategory__c = 'Other Account Time',
			LaborSubCategory__c = 'General',
			LaborDate__c = now.addDays(-1),
			Account__c = accountA.Id
		);
		insert accountTime2;

		Rosco_Time__c accountTime3 = new Rosco_Time__c(
			User__c = UserInfo.getUserId(),
			Minutes__c = 15,
			LaborCategory__c = 'Other Account Time',
			LaborSubCategory__c = 'General',
			LaborDate__c = datetime.now().addDays(-46),
			Account__c = accountA.Id
		);
		insert accountTime3;
		objects = RoscoHomePage.getAssociatedObjectsLabor('45');
		obj = objects.get(accountA.Id);
		Assert.areEqual('30', obj.get('Labor Tally'));

		Opportunity opportunityA = [
			SELECT Id, Name
			FROM Opportunity
			WHERE AccountId = :accountA.Id AND Name = :oppName
		];

		Rosco_Time__c opportunityTime = new Rosco_Time__c(
			User__c = UserInfo.getUserId(),
			Minutes__c = 15,
			LaborCategory__c = 'PreSales Activity',
			LaborSubCategory__c = 'Foo',
			LaborDate__c = now,
			Account__c = accountA.Id,
			Opportunity__c = opportunityA.Id
		);
		insert opportunityTime;
		objects = RoscoHomePage.getAssociatedObjectsLabor('45');
		Assert.isTrue(objects.containsKey(opportunityA.Id));
		obj = objects.get(opportunityA.Id);
		Assert.isTrue(obj.get('isRecent') == 'true');
		Assert.areEqual('Opportunity', obj.get('Item Type'));
		Assert.areEqual(opportunityA.Id, obj.get('Id'));
		Assert.areEqual(opportunityA.Id, obj.get('Opportunity ID'));
		Assert.areEqual('15', obj.get('Labor Tally'));
		Assert.areEqual(String.valueOf(now), obj.get('Labor Date'));
		Assert.areEqual(String.valueOf(now.dateGmt()), obj.get('Labor Date GMT'));
		Assert.areEqual('0', obj.get('LaborDateAge'));

		Rosco_Time__c opportunityTime2 = new Rosco_Time__c(
			User__c = UserInfo.getUserId(),
			Minutes__c = 15,
			LaborCategory__c = 'PreSales Activity',
			LaborSubCategory__c = 'Foo',
			LaborDate__c = now.addDays(-1),
			Account__c = accountA.Id,
			Opportunity__c = opportunityA.Id
		);
		insert opportunityTime2;

		objects = RoscoHomePage.getAssociatedObjectsLabor('45');
		obj = objects.get(opportunityA.Id);
		Assert.areEqual('30', obj.get('Labor Tally'));

		Case caseA = [SELECT Id, Subject FROM Case WHERE Subject = :caseName];

		Rosco_Time__c caseTime = new Rosco_Time__c(
			User__c = UserInfo.getUserId(),
			Minutes__c = 15,
			LaborCategory__c = 'Support',
			LaborSubCategory__c = 'Foo',
			LaborDate__c = now,
			Account__c = accountA.Id,
			Case__c = caseA.Id
		);
		insert caseTime;

		objects = RoscoHomePage.getAssociatedObjectsLabor('45');
		Assert.isTrue(objects.containsKey(caseA.Id));

		obj = objects.get(caseA.Id);
		Assert.isTrue(obj.get('isRecent') == 'true');
		Assert.areEqual('Case', obj.get('Item Type'));
		Assert.areEqual(caseA.Id, obj.get('Id'));
		Assert.areEqual(caseA.Subject, obj.get('Name/Subject'));
		Assert.areEqual('None', obj.get('Opportunity ID'));
		Assert.areEqual('15', obj.get('Labor Tally'));
		Assert.areEqual(String.valueOf(now), obj.get('Labor Date'));
		Assert.areEqual(String.valueOf(now.dateGmt()), obj.get('Labor Date GMT'));
		Assert.areEqual('0', obj.get('LaborDateAge'));
		Rosco_Time__c caseTime2 = new Rosco_Time__c(
			User__c = UserInfo.getUserId(),
			Minutes__c = 15,
			LaborCategory__c = 'Case',
			LaborSubCategory__c = 'Foo',
			LaborDate__c = now.addDays(-1),
			Account__c = accountA.Id,
			Case__c = caseA.Id
		);
		insert caseTime2;

		objects = RoscoHomePage.getAssociatedObjectsLabor('45');
		obj = objects.get(caseA.Id);
		Assert.areEqual('30', obj.get('Labor Tally'));
	}

	@IsTest
	static void testGetCaseObjects_Always_ReturnSuccess4() {
		List<Map<String, String>> objects = new List<Map<String, String>>();
		Map<String, String> jsonArgObj = new Map<String, String>();

		Case caseA = [SELECT Id, OwnerId FROM Case WHERE Subject = :caseName];

		jsonArgObj.put('cursor', '00000000');
		jsonArgObj.put('columnIterator', 'CaseNumber');
		jsonArgObj.put('startIteration', '45');
		jsonArgObj.put('batchSize', '100');

		objects = RoscoHomePage.getCaseObjects(JSON.serialize(jsonArgObj));
		Boolean test1 = false;
		for (Map<String, String> o : objects) {
			if (o.get('Id') == caseA.Id) {
				test1 = true;
			}
		}
		Assert.isTrue(test1);
	}

	@IsTest
	static void testGetGroupObjects_Always_ReturnSuccess() {
		String teamSpecialityTypeId = Utility.getRecordTypeIdByAPIName(
			'TAM_Team__c',
			'Escalation_Speciality_Group'
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			TAM_Team__c specialityTeam = new TAM_Team__c(
				Name = 'Speciality1',
				recordTypeId = teamSpecialityTypeId
			);
			insert specialityTeam;

			String teamSMETypeId = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_SME');
			TAM_Team__c smeTeam = new TAM_Team__c(
				Name = 'SME-1',
				recordTypeId = teamSMETypeId,
				Specialty_Group__c = specialityTeam.Id
			);
			insert smeTeam;
			TAM_Team__c smeTeam2 = new TAM_Team__c(
				Name = 'SME-2',
				recordTypeId = teamSMETypeId,
				Specialty_Group__c = specialityTeam.Id
			);
			insert smeTeam2;

			String teamPodTypeId = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_Pod');
			TAM_Team__c podTeam = new TAM_Team__c(
				Name = 'Pod-1',
				recordTypeId = teamPodTypeId,
				Leader__c = UserInfo.getUserId()
			);
			insert podTeam;

			String memberSMETypeId = Utility.getRecordTypeIdByAPIName(
				'TAM_Team_Member__c',
				'Escalation_SME'
			);
			TAM_Team_Member__c smeMember = new TAM_Team_Member__c(
				recordTypeId = memberSMETypeId,
				Responsibility__c = 'Support Enabled',
				Slack_Name__c = 'foo.bar',
				TAM_Team__c = smeTeam.Id,
				TAM__c = UserInfo.getUserId()
			);
			insert smeMember;
			TAM_Team_Member__c smeMember2 = new TAM_Team_Member__c(
				recordTypeId = memberSMETypeId,
				Responsibility__c = 'Support Enabled',
				Slack_Name__c = 'foo.bar',
				TAM_Team__c = smeTeam2.Id,
				TAM__c = UserInfo.getUserId()
			);
			insert smeMember2;

			RoscoHomePage.getGroupObjects(true);
			Test.stopTest();
		}
	}

	@IsTest
	static void testGetCC_Always_ReturnSuccess() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';
			accountObj.Country_Exception_Approved__c = true;
			insert accountObj;

			Contact contactObj = new Contact(
				Email = 'roscoapextest@roscolab.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = null
			);
			insert contactObj;

			String recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			Case caseObj = new Case(
				accountid = accountObj.id,
				ownerid = UserInfo.getUserId(),
				contactid = contactObj.Id,
				subject = 'ROSCOTESTCASE:testing',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				RecordTypeId = recordTypeId,
				suppliedEmail = '99@outlook.com',
				status = 'On Hold'
			);
			insert caseObj;

			RoscoHomePage.getCc();
		}
	}

	@IsTest
	static void testGetOpp2_Always_ReturnSuccess() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';
			accountObj.Country_Exception_Approved__c = true;
			insert accountObj;

			Contact contactLoggedInUser = [
				SELECT Id
				FROM Contact
				WHERE Email = :UserInfo.getUserEmail()
			];

			Opportunity opportunityObj = new Opportunity(
				Name = 'Test Opp1',
				AccountId = accountObj.id,
				StageName = 'Discovery',
				Amount = 1000,
				seats__c = 1000,
				CloseDate = system.today() + 30
			);
			insert opportunityObj;

			RoscoHomePage.getOpp();
		}
	}

	@IsTest
	static void testGetRecent_Always_ReturnSuccess() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';
			accountObj.Country_Exception_Approved__c = true;
			insert accountObj;

			Contact contactObj = new Contact(
				Email = 'roscoapextest@roscolab.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = null
			);
			insert contactObj;

			String recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			Case caseObj = new Case(
				accountid = accountObj.id,
				contactId = contactObj.Id,
				ownerid = UserInfo.getUserId(),
				subject = 'ROSCOTESTCASE:testing',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				RecordTypeId = recordTypeId,
				suppliedEmail = '99@outlook.com',
				status = 'On Hold'
			);
			insert caseObj;

			Contact contactLoggedInUser = [
				SELECT Id
				FROM Contact
				WHERE Email = :UserInfo.getUserEmail()
			];
			Opportunity opportunityObj = new Opportunity(
				Name = 'Test Opp1',
				AccountId = accountObj.id,
				StageName = 'Discovery',
				Amount = 1000,
				seats__c = 1000,
				CloseDate = system.today() + 30
			);
			insert opportunityObj;

			Rosco_Time__c accountTime = new Rosco_Time__c(
				User__c = UserInfo.getUserId(),
				Minutes__c = 15,
				LaborCategory__c = 'Other Account Time',
				LaborSubCategory__c = 'General',
				LaborDate__c = datetime.now(),
				Account__c = accountObj.Id,
				Opportunity__c = opportunityObj.Id
			);
			insert accountTime;

			Rosco_Time__c caseTime = new Rosco_Time__c(
				User__c = UserInfo.getUserId(),
				Minutes__c = 15,
				LaborCategory__c = 'Other Account Time',
				LaborSubCategory__c = 'General',
				LaborDate__c = datetime.now(),
				Account__c = accountObj.Id,
				Case__c = caseObj.Id
			);
			insert caseTime;

			Rosco_Time__c oppTime = new Rosco_Time__c(
				User__c = UserInfo.getUserId(),
				Minutes__c = 15,
				LaborCategory__c = 'Other Account Time',
				LaborSubCategory__c = 'General',
				LaborDate__c = datetime.now(),
				Account__c = accountObj.Id,
				Opportunity__c = opportunityObj.Id
			);
			insert oppTime;

			RoscoHomePage.getRecent();
		}
	}

	@IsTest
	static void testGetRoscoTable_Always_ReturnSuccess() {
		Map<String, String> jsonArgObj = new Map<String, String>();

		jsonArgObj.put('provider', 'Items Associated with you');
		jsonArgObj.put('startIteration', '45');

		List<Map<String, String>> results = RoscoHomePage.getRoscoTable(JSON.serialize(jsonArgObj));
	}

	@IsTest
	static void testGetRoscoTableInit_Always_ReturnSuccess() {
		Map<String, String> jsonArgObj = new Map<String, String>();

		jsonArgObj.put('collectGroups', 'true');
		jsonArgObj.put('collectPermissionSets', 'true');

		Map<String, Map<String, String>> results = RoscoHomePage.getRoscoTableInit(
			JSON.serialize(jsonArgObj)
		);
	}

	@IsTest
	static void testNullOrEmpty_Always_ReturnSuccess() {
		RoscoHomePage.nullOrEmpty('foo');
	}
}