/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Testclass for RoscoCoverage
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-10660   2025-05-01    Updated test class
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the test class
 */
@IsTest
private class RoscoCoverageTest {
	private static void createBlock(String blockStart) {
		String blockType = 'Ad Hoc';
		String blockGroup = 'Unassigned';

		List<Map<String, String>> blockPeople = new List<Map<String, String>>();
		Map<String, String> p1 = new Map<String, String>();
		p1.put('enabled', 'true');
		p1.put('group', 'Triage');
		p1.put('mobile', '1234567890');
		p1.put('name', 'tamfoo');
		p1.put('pod', 'podfoo');
		blockPeople.add(p1);
		Map<String, String> p2 = new Map<String, String>();
		p2.put('enabled', 'true');
		p2.put('group', 'Triage');
		p2.put('mobile', '9876543210');
		p2.put('name', 'tamfoo2');
		p2.put('pod', 'podfoo');
		blockPeople.add(p2);
		Map<String, String> p3 = new Map<String, String>();
		p3.put('enabled', 'true');
		p3.put('group', 'Triage');
		p3.put('mobile', '9876543210');
		p3.put('name', 'jason.johnson.rosco');
		p3.put('pod', 'podfoo');
		blockPeople.add(p3);

		String blockComment = 'ROSCOTESTCASE';
		String blockLength = '3';

		RoscoCoverage.saveBlock(
			blockStart,
			blockType,
			blockGroup,
			blockPeople,
			blockComment,
			blockLength,
			'true',
			'true',
			blockStart,
			'Standard',
			'Ad Hoc',
			'Field TAM'
		);
	}

	private static void createBlock2(String blockStart) {
		String blockType = 'Ad Hoc';
		String blockGroup = 'Unassigned';

		List<Map<String, String>> blockPeople = new List<Map<String, String>>();

		String blockComment = 'ROSCOTESTCASE';
		String blockLength = '3';

		RoscoCoverage.saveBlock(
			blockStart,
			blockType,
			blockGroup,
			blockPeople,
			blockComment,
			blockLength,
			'true',
			null,
			blockStart,
			'Non Standard (help needed)',
			null,
			'Field TAM'
		);
	}

	@isTest
	static void test_Unit_convertPeopleJsonToObject() {
		List<Map<String, String>> aList = new List<Map<String, String>>();

		Map<String, String> person = new Map<String, String>();
		person.put('foo', 'bar');
		alist.add(person);

		JSONGenerator gen = JSON.createGenerator(true);
		gen.writeStartObject();
		gen.writeObjectField('people', aList);
		gen.writeEndObject();
		List<Map<String, String>> test = RoscoCoverage.convertPeopleJsonToObject(gen.getAsString());
	}

	@isTest
	static void test_Unit_deleteBlock() {
		Datetime now = datetime.now();
		now = now.addHours(-1);
		String blockStart = now.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\'');

		createBlock(blockStart);
		RoscoCoverage.deleteBlock(blockStart, 'Field TAM');
	}

	@isTest
	static void test_Unit_getAccountSlackName() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('testAccount');
			accountObj.slack_channel_id__c = 'CH87S4VUJ';
			insert accountObj;

			Rosco_Account__c ra = new Rosco_Account__c(
				name = 'roscoapextestingd',
				account__c = accountObj.Id
			);
			insert ra;

			RoscoCoverage.getAccountSlackName(accountObj.Id);
		}
	}

	@isTest
	static void test_Unit_getBlockLength() {
		Datetime now = datetime.now();
		createBlock(now.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));
		Datetime hourago = now.addHours(-1);
		createBlock(hourago.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));

		RoscoCoverage.getBlockLength(
			hourago.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''),
			'Field TAM'
		);
	}

	@isTest
	static void test_Unit_getBlocks() {
		Datetime now = datetime.now();
		now = now.addHours(1);
		createBlock(now.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));
		now = now.addHours(1);
		createBlock2(now.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));

		Datetime q1 = DateTime.newInstance(2021, 2, 2, 0, 0, 0);
		createBlock(q1.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));

		Datetime q2 = DateTime.newInstance(2021, 5, 2, 0, 0, 0);
		createBlock(q2.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));

		Datetime q3 = DateTime.newInstance(2021, 8, 2, 0, 0, 0);
		createBlock(q3.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));

		Datetime q4 = DateTime.newInstance(2021, 11, 1, 0, 0, 0);
		createBlock(q4.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));

		Datetime qX = DateTime.newInstance(2021, 11, 10, 0, 0, 0);
		createBlock2(qX.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\''));

		RoscoCoverage.getBlocks('90', 'All Types', 'All Pods', 'Field TAM');
		RoscoCoverage.getBlocks('Q1FY21', 'All Types', 'All Pods', 'Field TAM');
		RoscoCoverage.getBlocks('Q2FY21', 'All Types', 'All Pods', 'Field TAM');
		RoscoCoverage.getBlocks('Q3FY21', 'All Types', 'All Pods', 'Field TAM');
		RoscoCoverage.getBlocks('Q4FY21', 'All Types', 'All Pods', 'Field TAM');
		RoscoCoverage.getBlocks('FY21', 'All Types', 'All Pods', 'Field TAM');

		Datetime dang = DateTime.newInstance(2021, 11, 11, 0, 0, 0);
		Rosco_Coverage__c block = new Rosco_Coverage__c();
		block.Block_start__c = (DateTime) JSON.deserialize(
			'"' + dang.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\'') + '"',
			DateTime.class
		);
		block.Type__c = 'Standard';
		block.Assigned_Group__c = 'East';
		block.Comment__c = '';
		block.Pager__c = 'true';
		block.Flag__c = 'false';
		block.Assigned_People__c = null;
		block.Schedule_Type__c = 'Field TAM';
		insert block;
		RoscoCoverage.getBlocks('FY21', 'All Types', 'All Pods', 'Field TAM');

		RoscoCoverage.getBlocksAvailable('Field TAM');
	}

	@isTest
	static void test_Unit_getPeople() {
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj0 = new User(
			Email = 'roscoapextest0@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser',
			Username = 'roscoapextest0@roscolab.com',
			Alias = 'testals0',
			CommunityNickname = 'testcommnickname0',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);
		insert userObj0;

		rosco_people__c rp0 = new rosco_people__c(
			name = 'rl1',
			user__c = userObj0.Id,
			pod__c = 'Central',
			mobile__c = '15550001111'
		);
		insert rp0;

		RoscoCoverage.getPeople();
	}

	@isTest(SeeAllData=true)
	static void getAccountSlackName() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('testAccount');
			accountObj.slack_channel_id__c = 'CH87S4VUJ';

			insert accountObj;

			Rosco_Account__c ra = new Rosco_Account__c(
				name = 'roscoapextestingd',
				account__c = accountObj.Id
			);
			insert ra;

			RoscoCoverage.getAccountSlackName(accountObj.Id);
		}
	}

	@isTest(SeeAllData=true)
	static void getBlockLengthTest() {
		String ret = RoscoCoverage.getBlockLength('2021-02-01T02:00:00.000Z', 'Field TAM');
	}

	@isTest(SeeAllData=true)
	static void getBlocksTest() {
		List<Map<String, String>> ret = RoscoCoverage.getBlocks(
			'90',
			'Standard',
			'All Pods',
			'Field TAM'
		);
		ret = RoscoCoverage.getBlocks('90', 'Flagged', 'All Pods', 'Field TAM');
		ret = RoscoCoverage.getBlocks('90', 'Non Standard (help needed)', 'All Pods', 'Field TAM');
		ret = RoscoCoverage.getBlocks('Q1FY21', 'All Types', 'All Pods', 'Field TAM');
		ret = RoscoCoverage.getBlocks('Q2FY21', 'All Types', 'All Pods', 'Field TAM');
		ret = RoscoCoverage.getBlocks('Q3FY21', 'All Types', 'All Pods', 'Field TAM');
		ret = RoscoCoverage.getBlocks('Q4FY21', 'All Types', 'All Pods', 'Field TAM');
		ret = RoscoCoverage.getBlocks('FY21', 'Non Standard (help needed)', 'All Pods', 'Field TAM');
		ret = RoscoCoverage.getBlocks(
			'Q1FY22',
			'Non Standard (help needed)',
			'All Pods',
			'Field TAM'
		);
		ret = RoscoCoverage.getBlocks(
			'Q2FY22',
			'Non Standard (help needed)',
			'All Pods',
			'Field TAM'
		);
		ret = RoscoCoverage.getBlocks(
			'Q3FY22',
			'Non Standard (help needed)',
			'All Pods',
			'Field TAM'
		);
		ret = RoscoCoverage.getBlocks(
			'Q4FY22',
			'Non Standard (help needed)',
			'All Pods',
			'Field TAM'
		);
		ret = RoscoCoverage.getBlocks('FY22', 'Non Standard (help needed)', 'All Pods', 'Field TAM');
	}

	@isTest(SeeAllData=true)
	static void test_easyAction() {
		Datetime dang = DateTime.newInstance(2021, 11, 11, 0, 0, 0);
		Rosco_Coverage__c block = new Rosco_Coverage__c();
		block.Block_start__c = (DateTime) JSON.deserialize(
			'"' + dang.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\'') + '"',
			DateTime.class
		);
		block.Type__c = 'Standard';
		block.Assigned_Group__c = 'East';
		block.Comment__c = '';
		block.Pager__c = 'true';
		block.Flag__c = 'false';
		block.Assigned_People__c = '{ "people" : [ { "mobileValidated" : "true", "enabled" : "true", "group" : "Triage", "mobile" : "15551231234", "pod" : "East", "name" : "rosco.test" } ] }';
		block.Schedule_Type__c = 'Support Center';
		insert block;

		Map<String, String> ret = RoscoCoverage.easyAction('Support Center', 'replace', '1555123555');
		Map<String, String> ret2 = RoscoCoverage.easyAction('Support Center', 'add', '1555123555');
		Map<String, String> ret3 = RoscoCoverage.easyAction('Support Center', 'remove', '1555123555');

		RoscoCoverage.easyActionPeople('15551231234');
	}

	@isTest(SeeAllData=true)
	static void getBlockInfo() {
		Map<String, String> ret = RoscoCoverage.getBlockInfo('Support Center');

		Datetime dang = datetime.now();
		dang.addMinutes(-5);
		Rosco_Coverage__c block = new Rosco_Coverage__c();
		block.Block_start__c = (DateTime) JSON.deserialize(
			'"' + dang.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\'') + '"',
			DateTime.class
		);
		block.Type__c = 'Standard';
		block.Assigned_Group__c = 'East';
		block.Comment__c = '';
		block.Pager__c = 'true';
		block.Flag__c = 'false';
		block.Assigned_People__c = '{ "people" : [ { "mobileValidated" : "true", "enabled" : "true", "group" : "Triage", "mobile" : "15551231234", "pod" : "East", "name" : "rosco.test" } ] }';
		block.Schedule_Type__c = 'Support Center';
		insert block;
		Map<String, String> ret2 = RoscoCoverage.getBlockInfo('Support Center');
	}

	@isTest(SeeAllData=true)
	static void getBlocksAvailableTest() {
		List<Map<String, String>> ret = RoscoCoverage.getBlocksAvailable('Field TAM');
	}

	@isTest(SeeAllData=true)
	static void getPeopleOnCall() {
		Map<String, String> ret = RoscoCoverage.getPeopleOnCall('Field TAM');

		Datetime dang = datetime.now();
		dang.addMinutes(-5);
		Rosco_Coverage__c block = new Rosco_Coverage__c();
		block.Block_start__c = (DateTime) JSON.deserialize(
			'"' + dang.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\'') + '"',
			DateTime.class
		);
		block.Type__c = 'Standard';
		block.Assigned_Group__c = 'East';
		block.Comment__c = '';
		block.Pager__c = 'true';
		block.Flag__c = 'false';
		block.Assigned_People__c = '{ "people" : [ { "mobileValidated" : "true", "enabled" : "true", "group" : "Triage", "mobile" : "15551231234", "pod" : "East", "name" : "rosco.test" } ] }';
		block.Schedule_Type__c = 'Field TAM';
		insert block;

		Map<String, String> ret2 = RoscoCoverage.getPeopleOnCall('Field TAM');
	}

	@isTest(SeeAllData=true)
	static void getPeopleTest() {
		List<Map<String, String>> ret = RoscoCoverage.getPeople();
	}

	@isTest(SeeAllData=true)
	static void getTeamsTest() {
		List<String> ret = RoscoCoverage.getTeams();
	}

	@isTest(SeeAllData=true)
	static void getUserName() {
		String ret = RoscoCoverage.getUserName();
	}

	@isTest(SeeAllData=true)
	static void getUserPhone() {
		String ret = RoscoCoverage.getUserPhone();
	}

	@isTest(SeeAllData=true)
	static void getUserPod() {
		String ret = RoscoCoverage.getUserPod();
	}

	@isTest(SeeAllData=true)
	static void processCase() {
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj0 = new User(
			Email = 'roscoapextest0@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser',
			Username = 'roscoapextest0@roscolab.com',
			Alias = 'testals0',
			CommunityNickname = 'testcommnickname0',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);
		insert userObj0;
		User userObj1 = new User(
			Email = 'roscoapextest1@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser',
			Username = 'roscoapextest@roscolab.com',
			Alias = 'testals1',
			CommunityNickname = 'testcommnickname1',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);
		insert userObj1;
		User userObj2 = new User(
			Email = 'roscoapextest2@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser',
			Username = 'roscoapextest2@roscolab.com',
			Alias = 'testals2',
			CommunityNickname = 'testcommnickname2',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);
		insert userObj2;

		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';
			insert accountObj;

			rosco_people__c rp0 = new rosco_people__c(
				name = 'rl1',
				user__c = userObj0.Id,
				mobile__c = '15550001111'
			);
			insert rp0;

			rosco_people__c rp1 = new rosco_people__c(
				name = 'tam1',
				user__c = userObj1.Id,
				mobile__c = '15551112222',
				lead__c = userObj0.Id
			);
			insert rp1;

			rosco_people__c rp2 = new rosco_people__c(
				name = 'tam1',
				user__c = userObj2.Id,
				mobile__c = '15551112222',
				lead__c = userObj0.Id
			);
			insert rp2;

			Rosco_Account__c ra = new Rosco_Account__c(
				name = 'roscoapextestingd',
				account__c = accountObj.Id
			);
			insert ra;

			Contact contactObj = new Contact(
				Email = 'testuser99@roscolab.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = accountObj.Id
			);
			insert contactObj;

			Datetime now = datetime.now();
			now = now.addHours(-1);
			String blockStart = now.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\'');

			createBlock(blockStart);
			String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');
			Case caseObj = new Case(
				ContactId = contactObj.id,
				accountid = accountObj.id,
				ownerid = userObj0.id,
				subject = 'ROSCOTESTCASE',
				Severity_Community__c = '2',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				suppliedEmail = '99@outlook.com',
				status = 'On Hold',
				RecordTypeId = recordTypeId,
				Description = 'Hello WOrld'
			);
			insert caseObj;

			List<Case> cases = new List<Case>();
			cases.add(caseObj);
			RoscoCoverage.processCase(cases);
		}
	}

	@isTest(SeeAllData=true)
	static void saveBlockTest() {
		Datetime now = datetime.now();
		now = now.addHours(-1);
		String blockStart = now.formatGMT('yyyy-MM-dd\'T\'00:00:00.000\'Z\'');
		String blockType = 'Ad Hoc';
		String blockGroup = 'Unassigned';

		List<Map<String, String>> blockPeople = new List<Map<String, String>>();
		Map<String, String> p1 = new Map<String, String>();
		p1.put('enabled', 'true');
		p1.put('group', 'Triage');
		p1.put('mobile', '1234567890');
		p1.put('name', 'tamfoo');
		p1.put('pod', 'podfoo');
		blockPeople.add(p1);
		Map<String, String> p2 = new Map<String, String>();
		p2.put('enabled', 'true');
		p2.put('group', 'Triage');
		p2.put('mobile', '9876543210');
		p2.put('name', 'tamfoo2');
		p2.put('pod', 'podfoo');
		blockPeople.add(p2);
		Map<String, String> p3 = new Map<String, String>();
		p3.put('enabled', 'true');
		p3.put('group', 'Triage');
		p3.put('mobile', '9876543210');
		p3.put('name', 'jason.johnson.rosco');
		p3.put('pod', 'podfoo');
		blockPeople.add(p3);

		String blockComment = 'ROSCOTESTCASE';
		String blockLength = '3';
		Map<String, String> ret = RoscoCoverage.getPeopleOnCall('Field TAM');

		RoscoCoverage.saveBlock(
			blockStart,
			blockType,
			blockGroup,
			blockPeople,
			blockComment,
			blockLength,
			'true',
			'true',
			blockStart,
			'Standard',
			'Ad Hoc',
			'Field TAM'
		);
		Map<String, String> ret2 = RoscoCoverage.getPeopleOnCall('Field TAM');
		List<Map<String, String>> blockPeople2 = new List<Map<String, String>>();
		RoscoCoverage.saveBlock(
			blockStart,
			blockType,
			blockGroup,
			blockPeople,
			blockComment,
			blockLength,
			'true',
			'true',
			blockStart,
			'Standard',
			'Ad Hoc',
			'Field TAM'
		);
		Map<String, String> ret3 = RoscoCoverage.getPeopleOnCall('Field TAM');
		RoscoCoverage.deleteBlock(blockStart, 'Field TAM');
	}

	@isTest(SeeAllData=true)
	static void sendPageTest() {
		RoscoCoverage.sendPageNotificationToSlack(
			'15551235555',
			'ROSCOTESTCASE Tanium Support test page!',
			'Field TAM'
		);
	}

	@isTest(SeeAllData=true)
	static void updateRoscoPeopleTest() {
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj0 = new User(
			Email = 'roscoapextest0@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser',
			Username = 'roscoapextest0@roscolab.com',
			Alias = 'testals0',
			CommunityNickname = 'testcommnickname0',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);
		insert userObj0;

		rosco_people__c rp0 = new rosco_people__c(
			name = 'roscoapextest0@roscolab.com',
			user__c = userObj0.Id,
			mobile__c = '15550001111'
		);
		insert rp0;

		List<Map<String, String>> blockPeople = new List<Map<String, String>>();
		Map<String, String> p1 = new Map<String, String>();
		p1.put('enabled', 'true');
		p1.put('group', 'Triage');
		p1.put('mobile', '999999990');
		p1.put('name', 'roscoapextest0@roscolab.com');
		p1.put('pod', 'podfoo');
		blockPeople.add(p1);
		Map<String, String> p2 = new Map<String, String>();
		p2.put('enabled', 'true');
		p2.put('group', 'Triage');
		p2.put('mobile', '9876543210');
		p2.put('name', 'tamfoo2');
		p2.put('pod', 'podfoo');
		blockPeople.add(p2);

		RoscoCoverage.updateRoscoPeople(blockPeople);
		RoscoCoverage.updateRoscoPeople(blockPeople);
	}
}