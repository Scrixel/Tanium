/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoTag
 * @Date: 8/4/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-9601    2024-11-01    Updated test class
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the test class
 */

@IsTest
private class RoscoTagTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
		Id supportCaseRecTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('roscoapextestingd');
			account.slack_channel_id__c = 'TESTCASE';
			insert account;

			Contact contact = TestFactory.buildContact(account.Id);
			insert contact;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today(),
				Utility.PROSPECTING,
				account.Id
			);
			insert opp;

			Case supportCase = TestFactory.buildCase(account.Id, contact.Id);
			supportCase.RecordTypeId = supportCaseRecTypeId;
			supportCase.Opportunity__c = opp.Id;
			insert supportCase;

			Knowledge__kav knowledgeArticle = new Knowledge__kav(
				Title = 'Knowledge Title',
				Summary = 'Knowledge Summary',
				Urlname = 'Knowledge Title'.normalizeSpace().replaceAll(' ', '-')
			);
			insert knowledgeArticle;

			Knowledge__ka article = [SELECT Id FROM Knowledge__ka LIMIT 1];

			CaseArticle caseArticle = new CaseArticle(
				CaseId = supportCase.Id,
				KnowledgeArticleId = article.Id
			);
			insert caseArticle;

			Rosco_Tag__c jiraTag = new Rosco_Tag__c(
				Name = 'foo',
				type__c = 'Jira',
				description__c = 'Description1'
			);
			Rosco_Tag__c otherTag = new Rosco_Tag__c(
				Name = 'foo2',
				type__c = 'Solution Object (SO)',
				description__c = 'Description1'
			);
			insert new List<Rosco_Tag__c>{ jiraTag, otherTag };

			Jira_Issue__c jiraIssue = new Jira_Issue__c(Name = 'Title1', Issue_Key__c = 'Title1');
			insert jiraIssue;
		}
	}

	@IsTest
	static void testRemoveAttachedKB_WhenRemoveArticleId_ReturnEmptyResult() {
		Case[] cases = [SELECT Id FROM Case];
		Opportunity[] opps = [SELECT Id FROM Opportunity];
		Knowledge__ka knowledgeArticle = [SELECT Id FROM Knowledge__ka LIMIT 1];
		List<Map<String, String>> resultMapList;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoTag.attachArticlesReferenced(cases[0].Id);
			RoscoTag.getAttachedArticles(cases[0].Id);
			resultMapList = RoscoTag.removeAttachedKB(cases[0].Id, knowledgeArticle.Id);
			Test.stopTest();
		}
		Assert.isTrue(resultMapList.isEmpty());
	}

	@IsTest
	static void testInitRoscoTags_WhenCaseWithOpportunity_ReturnMapWithOpportunityId() {
		Case[] cases = [SELECT Id FROM Case];
		Opportunity[] opps = [SELECT Id FROM Opportunity];
		Map<String, String> resultMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultMap = RoscoTag.initRoscoTags(cases[0].Id);
			Test.stopTest();
		}
		Assert.isTrue(resultMap.get('caseOpportunityId') == opps[0].Id);
	}

	@IsTest
	static void testGetCaseAccountOpportunities_WhenCaseWithOpportunity_ReturnMapWithOpportunityName() {
		Case[] cases = [SELECT Id FROM Case];
		Opportunity[] opps = [SELECT Id, Name FROM Opportunity];
		List<Map<String, String>> resultMapList;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultMapList = RoscoTag.getCaseAccountOpportunities(cases[0].Id);
			Test.stopTest();
		}
		Assert.isTrue(resultMapList[0].get('label') == opps[0].Name);
	}

	@IsTest
	static void testGetExistingCaseMaps_WhenNoExistingTagMaps_ReturnEmptyResult() {
		Case[] cases = [SELECT Id FROM Case];
		Map<String, Rosco_Tag_Map__c> roscoTagMapMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			roscoTagMapMap = RoscoTag.getExistingCaseMaps(cases[0].Id);
			Test.stopTest();
		}
		Assert.isTrue(roscoTagMapMap.isEmpty());
	}

	@IsTest
	static void testGetExistingCaseTags_WhenExistingTagName_ReturnTag() {
		List<String> tagList = new List<String>{ 'foo' };
		Map<String, Rosco_Tag__c> roscoTagMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			roscoTagMap = RoscoTag.getExistingCaseTags(tagList);
			Test.stopTest();
		}

		Assert.isTrue(roscoTagMap.get('foo').Name == 'foo');
	}

	@IsTest
	static void testGetJiraIssueSFId_WhenJiraIssue_ReturnJiraIssueId() {
		List<String> tagList = new List<String>{ 'Title1' };
		Map<String, String> resultMap;
		Id jiraIssueId = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultMap = RoscoTag.getJiraIssueSFId(tagList);
			try {
				jiraIssueId = (Id) resultMap.get('Title1');
			} catch (Exception e) {
				jiraIssueId = null;
			}
			Test.stopTest();
		}

		Assert.isTrue(jiraIssueId != null);
	}

	@IsTest
	static void testGetModuleOptions_Always_ReturnModulesOptions() {
		List<Map<String, String>> resultMapList;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultMapList = RoscoTag.getModuleOptions();
			Test.stopTest();
		}

		Assert.isFalse(resultMapList.isEmpty());
	}

	@IsTest
	static void testGetTagsCase_WhenCaseWitTags_ReturnTags() {
		Case[] cases = [SELECT Id FROM Case];
		String resultStr;
		List<Map<String, String>> resultMapList;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultStr = RoscoTag.getTagsCase(cases[0].Id);
			resultMapList = RoscoTag.getTagsCase2(cases[0].Id);
			Test.stopTest();
		}

		Assert.isFalse(resultMapList.isEmpty());
	}

	@IsTest
	static void testGetJiraLookup_WhenJiraIssueExists_ReturnJiraIssue() {
		Case[] cases = [SELECT Id FROM Case];
		List<Map<String, String>> resultMapList1;
		List<Map<String, String>> resultMapList2;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultMapList1 = RoscoTag.getJiraLookup('', 'foo', cases[0].Id);
			resultMapList2 = RoscoTag.getJiraLookup('foo', '', cases[0].Id);
			Test.stopTest();
		}

		Assert.isTrue(!resultMapList1.isEmpty() && !resultMapList2.isEmpty());
	}

	@IsTest
	static void testGetTagLookup_WhenTagExists_ReturnTag() {
		Case[] cases = [SELECT Id FROM Case];
		List<Map<String, String>> resultMapList1;
		List<Map<String, String>> resultMapList2;
		Map<String, Map<String, String>> resultMapMap; // :-)

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultMapList1 = RoscoTag.getTagLookup('', 'foo', cases[0].Id);
			resultMapList2 = RoscoTag.getTagLookup('foo', '', cases[0].Id);
			Test.stopTest();
		}

		Assert.isTrue(!resultMapList1.isEmpty() && !resultMapList2.isEmpty());
	}

	@IsTest
	static void testGetTagMapInfo_WhenNoTagMapData_ReturnEmptyResult() {
		Case[] cases = [SELECT Id FROM Case];
		Map<String, Map<String, String>> resultMapMap; // :-)

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultMapMap = RoscoTag.getTagMapInfo(cases[0].Id);
			Test.stopTest();
		}

		Assert.isTrue(resultMapMap.isEmpty());
	}

	@IsTest
	static void testSaveTags_WhenSaveTags_ReturnSavedTags() {
		Case[] cases = [SELECT Id FROM Case];
		Opportunity[] opps = [SELECT Id, Name FROM Opportunity];
		List<Map<String, String>> tags = createTags(cases[0].Id, opps[0].Id);
		List<Map<String, String>> resultMapList;
		List<Map<String, String>> resultMapList1;
		List<Map<String, String>> resultMapList2;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			resultMapList = RoscoTag.saveNewIndividualTag(
				cases[0].Id,
				'Legacy (String)',
				'Foo',
				'descript',
				'solution1',
				opps[0].Id,
				'Risk',
				'comment',
				'Platform'
			);
			resultMapList = RoscoTag.saveNewIndividualTag(
				cases[0].Id,
				'Legacy (String)',
				'Foo',
				'descript',
				'solution1',
				null,
				'Risk',
				'comment',
				'Platform'
			);
			resultMapList1 = RoscoTag.saveTags(cases[0].Id, tags);
			resultMapList2 = RoscoTag.saveTags2(cases[0].Id, tags);
			Test.stopTest();
		}

		Assert.isTrue(
			!resultMapList.isEmpty() && !resultMapList1.isEmpty() && !resultMapList2.isEmpty()
		);
	}
	static List<Map<String, String>> createTags(Id caseId, Id oppId) {
		List<Map<String, String>> tags = new List<Map<String, String>>();
		Map<String, String> tag = new Map<String, String>();
		tag.put('Id', caseId);
		tag.put('Title', 'Title1');
		tag.put('Type', 'JIRA');
		tag.put('Description', 'Description1');
		tag.put('Solution', 'Solution1');
		tag.put('OpportunityId', String.valueOf(oppId));
		tag.put('Impact', 'Risk');
		tag.put('Comment', 'Comment1');
		tags.add(tag);
		return tags;
	}
}