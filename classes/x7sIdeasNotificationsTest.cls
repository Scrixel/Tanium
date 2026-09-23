/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
@IsTest
public with sharing class x7sIdeasNotificationsTest {
	public static List<Community> currCommunity;
	public static Idea awesomeIdea;
	public static Network currNetwork;
	public static List<Idea> currIdeaList;
	private static final String TestIdeaName = 'test_X7__1';
	private static String strNetworkId {
		get {
			return [SELECT Id FROM Network LIMIT 1][0].Id;
		}
	}

	@IsTest
	static void testSendEmail() {
		x7sIdeasNotifyModel nm = new x7sIdeasNotifyModel(
			'0123456789012345',
			'test model',
			'test context',
			'test details',
			'test url'
		);
		List<User> users = [
			SELECT Id, FirstName, LastName, Email, CommunityNickname
			FROM User
			WHERE Id = :UserInfo.getUserId()
		];
		Map<x7sIdeasNotifyModel, List<User>> subscribers = new Map<x7sIdeasNotifyModel, List<User>>();
		subscribers.put(nm, users);

		User recipient = [
			SELECT Id, FirstName, LastName, Email, CommunityNickname
			FROM User
			WHERE Id = :UserInfo.getUserId()
		];
		EmailTemplate template = [
			SELECT Id, Subject, HtmlValue, Body, DeveloperName
			FROM EmailTemplate
			WHERE DeveloperName = :'X7S_Ideas_Status_Change_Notification'
		];
		x7sIdeasNotifications.sendEmailNotification(
			subscribers,
			'X7S_Ideas_Status_Change_Notification',
			UserInfo.getUserId()
		);
		x7sIdeasNotifications.getTemplateEmailMap(UserInfo.getUserId());
		Messaging.SingleEmailMessage newEmail = x7sIdeasNotifications.generateEmail(
			nm,
			recipient,
			template,
			UserInfo.getUserId()
		);
		System.assertNotEquals(null, newEmail);
	}

	@IsTest
	static void testIdeaComment() {
		testSetupQuery(false);

		x7sIdeasNotifyModel nm = new x7sIdeasNotifyModel(
			'0123456789012345',
			'test model',
			'test context',
			'test details',
			'test url'
		);
		List<Idea> ideaList = new List<Idea>();
		Idea currIdea = new Idea(Title = TestIdeaName, CommunityId = currCommunity[0].Id);
		ideaList.add(currIdea);
		insert ideaList;

		IdeaComment ic = new IdeaComment(IdeaId = ideaList[0].Id, CommentBody = 'Test Comment');
		insert ic;

		Set<Id> commentIds = new Set<Id>();
		commentIds.add(ic.Id);
		x7sIdeasNotifications.ideaNewComment(commentIds);
		X7S_Ideas_Subscription__c subscription = new X7S_Ideas_Subscription__c(
			NetworkId__c = strNetworkId,
			ParentId__c = ideaList[0].Id,
			SubscriberId__c = UserInfo.getUserId()
		);
		insert subscription;

		List<x7sIdeasNotifyModel> ideas = new List<x7sIdeasNotifyModel>();
		List<Id> recordIds = new List<Id>();
		ideas.add(nm);
		recordIds.add(subscription.Id);
		Map<x7sIdeasNotifyModel, List<User>> userMap = x7sIdeasNotifications.getIdeaSubscriberMap(
			ideas,
			recordIds
		);
		System.assertNotEquals(null, userMap);
	}

	static void testSetupQuery(Boolean queryData) {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdeaList = [SELECT Id FROM Idea WHERE Title = 'test_X7__1' ORDER BY CreatedDate DESC];
		if (queryData) {
			awesomeIdea = [SELECT Id FROM Idea WHERE Title = 'test is awesome'];
		}
	}
}