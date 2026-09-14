/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoHighlight
 * @Date: 2026-05-27
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13176   2026-05-27    Removed Level_2__c references
 */
@IsTest
private class RoscoHighlightTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'UserTriggerHandler',
				'CaseTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			User testUser = TestUserFactory.createUser(
				'ApexUser',
				'roscoapextest@roscolab.com',
				'testx',
				Utility.getProfileId('Tanium System Administrator'),
				Utility.getCorporateRoleId()
			);
			Product2 product = TestFactory.buildProduct(
				'Tanium Support Center 24x7 - L1L4 - MidMarket',
				'PROD_TEST'
			);
			insert new List<SObject>{ testUser, product };

			Id pricebookId = Test.getStandardPricebookId();

			PricebookEntry pbEntry = TestFactory.buildPricebookEntry(product.Id, 10, pricebookId);
			insert pbEntry;

			Account acc = TestFactory.buildAccount('roscoapextestingd');
			acc.slack_channel_id__c = 'TESTCASE';
			acc.OwnerId = testUser.Id;
			acc.Type = 'Prospect';
			acc.Support_Model__c = 'Support Center';
			insert acc;

			Contact roscoContact = new Contact(
				Email = 'roscoapextest@roscolab.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = acc.Id
			);
			Contact taniumContact = new Contact(
				Email = 'roscoapextest@test.com',
				FirstName = 'Test2',
				LastName = 'Apex',
				AccountId = acc.Id
			);
			insert new List<SObject>{ roscoContact, taniumContact };

			Opportunity opp = TestFactory.buildOpportunity(
				'roscoapextest MidMarket Support L1 L2 L3 L4',
				System.today().addDays(30),
				Utility.PROSPECTING,
				acc.Id
			);
			opp.Pricebook2Id = pricebookId;
			insert opp;

			OpportunityLineItem oppLineItem = TestFactory.buildOpportunityLineItem(
				opp.Id,
				1,
				10,
				pbEntry.Id
			);
			insert oppLineItem;

			Case testCase = new Case(
				ContactId = roscoContact.Id,
				AccountId = acc.Id,
				Opportunity__c = opp.Id,
				OwnerId = testUser.Id,
				Subject = 'ROSCOTESTCASE',
				Severity_Community__c = '3',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				SuppliedEmail = '99@outlook.com',
				LatestPublicCommentHTML__c = '<html>hello</html>',
				Component__c = 'Other',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support'),
				Status = 'On Hold',
				Status_Details__c = 'Pending Development',
				ClosedDate = System.today().addDays(30)
			);
			insert testCase;

			CaseContactRole caseContact = new CaseContactRole(
				CasesId = testCase.Id,
				ContactId = roscoContact.Id,
				Role = 'Engaged SME'
			);

			rosco_people__c testPeople = new rosco_people__c(
				Name = 'roscoapextestingd',
				Contact__c = roscoContact.Id,
				User__c = testUser.Id,
				Pod__c = 'Central',
				Primary_sme__c = 'Patch',
				Secondary_sme__c = 'Map'
			);
			rosco_people__c testSME = new rosco_people__c(
				Name = 'slack.name',
				Contact__c = roscoContact.Id,
				User__c = testUser.Id,
				Pod__c = 'Central',
				Primary_sme__c = 'Patch',
				Secondary_sme__c = 'Map'
			);

			rosco_escalation_rbac__c rbac = new rosco_escalation_rbac__c(
				Name = '4',
				authorized__c = testUser.Id
			);

			TAM_Team__c team = new TAM_Team__c(
				Name = 'Patch',
				SME_Component_Name__c = 'Workbench-Patch',
				Slack_Ticket_Channel_ID__c = 'CCC66LTRT',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_SME')
			);

			Support_Partner__c supportPartner = new Support_Partner__c(
				Account_Supported__c = acc.Id,
				Partner_Role__c = 'Support'
			);

			Rosco_Account__c roscoAcc = new Rosco_Account__c(
				account__c = acc.Id,
				Name = 'SLACK',
				case_flash__c = 'CASE_FLASH',
				Case_Flash_Persist__c = 'CASE FLASH PERSIST'
			);

			Rosco_Time__c roscoTime = new Rosco_Time__c(
				Case__c = testCase.Id,
				Minutes__c = 10,
				User__c = UserInfo.getUserId(),
				LaborSubCategory__c = 'Support',
				LaborDate__c = System.today().addDays(10)
			);

			User testCommunityUser = TestUserFactory.createUser(
				'CommunityUser',
				'roscoapextest@roscoTest.com',
				'testy',
				Utility.getProfileId(RoscoHighlight.COMMUNITY_LOGIN_UNKNOWN_PROFILENAME),
				null
			);
			testCommunityUser.ContactId = roscoContact.Id;
			insert new List<SObject>{
				caseContact,
				testPeople,
				testSME,
				rbac,
				team,
				supportPartner,
				roscoAcc,
				roscoTime,
				testCommunityUser
			};
		}
	}

	@IsTest
	static void getHighlightInfo_AlwaysReturnCaseDetails() {
		Case testCase = [SELECT Id FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<String, String> highlightInfo = RoscoHighlight.getHighlightInfo(testCase.Id);
			Test.stopTest();

			Assert.isFalse(highlightInfo.isEmpty(), 'return should not be empty');
		}
	}

	@IsTest
	static void getCaseTime2_AlwaysReturnCaseTimeDetails() {
		Case testCase = [SELECT Id FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			List<Map<String, String>> caseTime = RoscoHighlight.getCaseTime2(testCase.Id);
			Test.stopTest();

			Assert.isFalse(caseTime.isEmpty(), 'return should not be empty');
			Assert.isTrue(String.isNotBlank(caseTime[0].get('User')));
		}
	}

	@IsTest
	static void getClosedCaseFlash_WhenClosedDateNotBlank_ReturnClosedCaseFlash() {
		String closedCaseFlash = '';
		Integer daysClosed = 0;

		System.runAs(TestUserFactory.getAdminUser()) {
			String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');

			Test.startTest();

			Case caseObjLess90 = new Case(
				subject = 'ROSCOTESTCASE',
				RecordTypeId = recordTypeId,
				ClosedDate = System.today().addDays(-1)
			);
			closedCaseFlash = RoscoHighlight.getClosedCaseFlash(caseObjLess90);
			daysClosed = caseObjLess90.ClosedDate?.Date().daysBetween(System.now().Date());

			Assert.isTrue(closedCaseFlash.contains(String.valueOf(daysClosed)));

			Case caseObjLess365 = new Case(
				subject = 'ROSCOTESTCASE',
				RecordTypeId = recordTypeId,
				ClosedDate = System.today().addDays(-91)
			);
			closedCaseFlash = RoscoHighlight.getClosedCaseFlash(caseObjLess365);
			daysClosed = caseObjLess365.ClosedDate?.Date().daysBetween(System.now().Date());

			Assert.isTrue(closedCaseFlash.contains(String.valueOf(daysClosed)));

			Case caseObjMore365 = new Case(
				subject = 'ROSCOTESTCASE',
				RecordTypeId = recordTypeId,
				ClosedDate = System.today().addDays(-366)
			);
			closedCaseFlash = RoscoHighlight.getClosedCaseFlash(caseObjMore365);
			daysClosed = caseObjMore365.ClosedDate?.Date().daysBetween(System.now().Date());

			Assert.isTrue(closedCaseFlash.contains(String.valueOf(daysClosed)));

			Test.stopTest();
		}
	}

	@IsTest
	static void getSecurityFlash_WhenAccountIsCommunity_ReturnUncategorizedMessage() {
		TriggerHandler.bypass('AccountTriggerHandler');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [SELECT Id, Name FROM Account LIMIT 1];
			acc.Name = 'Customer Community External Members Account';
			update acc;

			Case testCase = [
				SELECT Id, RecordType.Name, Account.Name, Contact.Account.Name
				FROM Case
				LIMIT 1
			];

			String securityFlash = RoscoHighlight.getSecurityFlash(testCase);

			Assert.isTrue(securityFlash.contains('uncategorized/placeholder account'));
		}
	}

	@IsTest
	static void getSecurityFlash_WhenAccountIsNotSameToContactAccount_ReturnDiffAccountMessage() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'CaseTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('TestAccount');
			insert acc;

			Case testCase = [
				SELECT Id, RecordType.Name, Account.Name, Contact.Account.Name, AccountId
				FROM Case
				LIMIT 1
			];
			testCase.AccountId = acc.Id;
			update testCase;

			Test.startTest();

			testCase = [
				SELECT Id, RecordType.Name, Account.Name, Contact.Account.Name, AccountId
				FROM Case
				LIMIT 1
			];

			String securityFlash = RoscoHighlight.getSecurityFlash(testCase);
			Test.stopTest();

			Assert.isTrue(securityFlash.contains('different than Case account'));
		}
	}

	@IsTest
	static void getSMETeams_AlwaysReturnEscalationSMETeams() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			List<Map<String, String>> smeTeams = RoscoHighlight.getSMETeams();
			Test.stopTest();
			Assert.isFalse(smeTeams.isEmpty(), 'Return should not be empty');
		}
	}

	@IsTest
	static void getUserRoleName_AlwaysReturnUserRoleName() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String userRole = RoscoHighlight.getUserRoleName();
			Test.stopTest();
			Assert.areEqual(userRole, 'Corporate');
		}
	}

	@IsTest
	static void removeTime_AlwaysDeleteRoscoTimeRecord() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id FROM Case LIMIT 1];
			Rosco_Time__c roscoTime = [SELECT Id, CreatedDate FROM Rosco_Time__c LIMIT 1];
			String createdDate = roscoTime.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

			Test.startTest();
			Map<String, String> newCaseTime = RoscoHighlight.removeTime(testCase.Id, createdDate);
			Test.stopTest();

			Assert.areEqual(
				'0',
				newCaseTime.get('case_time'),
				'No remaining rosco time record. case time should be 0'
			);
		}
	}

	@IsTest
	static void saveCase_AlwaysSetTheNewStatusAndStatusDetails() {
		TriggerHandler.bypass('AccountTriggerHandler');

		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id FROM Case LIMIT 1];
			Test.startTest();

			String sc = RoscoHighlight.saveCase(testCase.Id, 'In Progress - Troubleshooting');
			String sc2 = RoscoHighlight.saveCase(testCase.Id, 'Pending - Clarifying');
			String sc3 = RoscoHighlight.saveCase(testCase.Id, 'On Hold - --None--');
			String sc4 = RoscoHighlight.saveCase(testCase.Id, 'On Hold - Pending Development');
			String sc5 = RoscoHighlight.saveCase(testCase.Id, 'On Hold - Pending Release');
			String sc6 = RoscoHighlight.saveCase(testCase.Id, 'On Hold - Pending Installation');
			String sc7 = RoscoHighlight.saveCase(testCase.Id, 'On Hold - Pending Validation');
			String sc8 = RoscoHighlight.saveCase(testCase.Id, 'On Hold - Pending Review');
			String sc9 = RoscoHighlight.saveCase(testCase.Id, 'On Hold - External Party');
			Test.stopTest();

			testCase = [SELECT Id, Status, Status_Details__c FROM Case LIMIT 1];

			Assert.areEqual('On Hold', testCase.Status);
			Assert.areEqual('External Party', testCase.Status_Details__c);
		}
	}

	@IsTest
	static void saveTime_WhenMinutesDoesNotExceed1440_AlwaysCreateNewRoscoTimeRecord() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id FROM Case LIMIT 1];
			Datetime laborDateDT = DateTime.Now();
			String laborDate = laborDateDT.formatGMT('yyyy-MM-dd\'T\'00:00:000.000\'Z\'');

			Test.startTest();
			Map<String, String> saveTime = RoscoHighlight.saveTime(
				testCase.Id,
				'10',
				'Case Account Time',
				'Support',
				laborDate
			);
			Test.stopTest();

			Assert.areEqual('', saveTime.get('alert'), 'Successful saveTime does not return alert');
			Assert.areEqual('Successfully added 10 minutes.', saveTime.get('info'));
		}
	}

	@IsTest
	static void saveTime_WhenMinutesExceed1440_AlertMessage() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id FROM Case LIMIT 1];

			Datetime laborDateDT = DateTime.Now();
			String laborDate = laborDateDT.formatGMT('yyyy-MM-dd\'T\'00:00:000.000\'Z\'');

			Test.startTest();
			Map<String, String> saveTime = RoscoHighlight.saveTime(
				testCase.Id,
				'1480',
				'Case Account Time',
				'Support',
				laborDate
			);
			Test.stopTest();

			Assert.isTrue(
				saveTime.get('alert')
					.contains('A maximum of 1440 minutes (24 hr) can be logged in one day'),
				'saveTime return alert with maximum of 1440 minutes message.'
			);
		}
	}
}