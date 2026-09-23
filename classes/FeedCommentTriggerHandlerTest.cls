/*
 * @DATE: 2018-06-09
 * @AUTHOR: Cumulus Vision
 * @REQUEST: TAN-546
 * @BUSINESS: Test class for the FeedCommentTriggerHandler

 * RequestId    ModifiedDate    Comment
 * TAN-546      2018-06-09      Initial Development
 * TAN-802      2019-09-10      Updated code to create Account and assign it to Case
 * SS-9463 		2024-11-20      Move build methods to TestFactory
 * SS-11173     2025-07-10      Changed field from Severity__c to Severity_Community__c
 */
@IsTest
public class FeedCommentTriggerHandlerTest {
	private static User communityUser;
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
		TriggerHandler.bypass(new List<String>{ 'ContactTriggerHandler' });
		User userObj;
		Account accountObj;
		Contact contactObj1, contactObj2;
		System.runAs(TestUserFactory.getAdminUser()) {
			accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';
			insert accountObj;
			contactObj1 = new Contact(
				Email = 'roscoapextest@roscolab.com',
				FirstName = 'Contact',
				LastName = 'Test1',
				AccountId = null
			);
			contactObj2 = new Contact(
				Email = 'roscoapextest@tanium.com',
				FirstName = 'Contact',
				LastName = 'Test2',
				AccountId = null
			);
			insert new List<Contact>{ contactObj1, contactObj2 };

			Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

			communityUser = new User(
				Email = 'communityUser@taniumTest.com',
				FirstName = 'Test',
				LastName = 'ApexUser',
				Username = 'communityUser@taniumTest.com',
				Alias = 'jrj413',
				CommunityNickname = 'jrj413',
				TimeZoneSidKey = 'America/Los_Angeles',
				LocaleSidKey = 'en_US',
				EmailEncodingKey = 'ISO-8859-1',
				ProfileId = profileId,
				LanguageLocaleKey = 'en_US'
			);
			insert communityUser;
		}

		System.runAs(getCommunityUser()) {
			Case caseObj = new Case(
				ContactId = contactObj1.id,
				accountid = accountObj.id,
				ownerid = communityUser.id,
				subject = 'ROSCOTESTCASE',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				suppliedEmail = '99@outlook.com',
				LatestPublicCommentHTML__c = '<html>hello</html>',
				status = 'On Hold'
			);
			insert caseObj;

			// Create Feed Item
			FeedItem newFeedItem = TestFactory.buildFeedItem(caseObj.Id);
			newFeedItem.Visibility = 'AllUsers';
			newFeedItem.Body = 'Test FeedItem Body';
			insert newFeedItem;

			// Create Feed Comment
			FeedComment newFeedComment = TestFactory.buildFeedComment(newFeedItem.Id);
			newFeedComment.CommentBody = 'Test';
			newFeedComment.CommentType = 'TextComment';
			newFeedComment.Status = 'Published';
			insert newFeedComment;
		}
	}

	@isTest
	static void testRoscoCaseProcesses_whenFeedCommentPublished_updatesLastCustomerResponseDateAccurately() {
		Case updatedCaseObj;
		System.runAs(TestUserFactory.getAdminUser()) {
			updatedCaseObj = [SELECT Id, Last_Customer_Response_Date__c FROM Case LIMIT 1];
		}
		System.runAs(getCommunityUser()) {
			// Create Feed Item
			FeedItem feedItem = [SELECT Id FROM FeedItem WHERE ParentId = :updatedCaseObj.Id];

			// Create Feed Comment
			FeedComment newFeedComment = TestFactory.buildFeedComment(feedItem.Id);
			newFeedComment.CommentBody = 'Test 1 comment';
			newFeedComment.CommentType = 'TextComment';
			newFeedComment.Status = 'Published';
			insert newFeedComment;
			updatedCaseObj = [SELECT Id, Last_Customer_Response_Date__c FROM Case LIMIT 1];
			System.assertEquals(Date.today(), updatedCaseObj.Last_Customer_Response_Date__c.date());

			FeedComment existingFeedComment = [SELECT Id FROM FeedComment WHERE Id = :newFeedComment.Id];
			existingFeedComment.CommentBody = 'Test 2 comment';
			update existingFeedComment;
			updatedCaseObj = [SELECT Id, Last_Customer_Response_Date__c FROM Case LIMIT 1];
			System.assertEquals(Date.today(), updatedCaseObj.Last_Customer_Response_Date__c.date());
		}
	}

	@isTest
	static void testSetCaseStatus_whenCaseCreated_setsCaseStatusAccurately() {
		Case updatedCaseObj;
		System.runAs(getCommunityUser()) {
			// Retrieve Case - which is eligible to update LatestPublicComment__c due to RecordType of Support
			updatedCaseObj = [SELECT Id, Status FROM Case LIMIT 1];
			System.assertEquals(
				CaseTriggerUtilityWithoutSharing.IN_PROGRESS_TROUBLESHOOTING,
				updatedCaseObj.Status,
				'case status updated via code'
			);
			updatedCaseObj.Status = 'On Hold';
			update updatedCaseObj;
			updatedCaseObj = [SELECT Id, Status FROM Case LIMIT 1];
			System.assertEquals('On Hold', updatedCaseObj.Status, 'case status updated manually by user');
		}
		System.runAs(getCommunityUser()) {
			FeedItem feedItem = [SELECT Id FROM FeedItem WHERE ParentId = :updatedCaseObj.Id];
			FeedComment newFeedComment = new FeedComment(
				FeedItemId = feedItem.Id,
				CommentBody = 'test comment body 3'
			);
			insert newFeedComment;
			updatedCaseObj = [SELECT Id, Status FROM Case LIMIT 1];
			System.assertEquals(
				CaseTriggerUtilityWithoutSharing.IN_PROGRESS_TROUBLESHOOTING,
				updatedCaseObj.Status,
				'case status updated via code when feed comment published'
			);
		}
	}

	@isTest
	static void testprocessFeedComment_whenFeedCommentPushished_setsLatestPublicCommentHTMLAccurately() {
		System.runAs(TestUserFactory.getAdminUser()) {
			// Retrive Case - which is eligible to update LatestPublicComment__c due to RecordType of Support
			Case updatedCaseObj = [SELECT Id, LatestPublicCommentHTML__c FROM Case LIMIT 1];
			FeedComment feedcomment = [SELECT CommentBody FROM FeedComment LIMIT 1];
			System.assertEquals(
				feedcomment.CommentBody,
				updatedCaseObj.LatestPublicCommentHTML__c,
				'case public comment updated with customers latest text feed comment'
			);
		}
	}

	static User getCommunityUser() {
		if (FeedCommentTriggerHandlerTest.communityUser == null) {
			return ([SELECT Id FROM User WHERE Email = 'communityUser@taniumTest.com' LIMIT 1]);
		}
		return FeedCommentTriggerHandlerTest.communityUser;
	}
}