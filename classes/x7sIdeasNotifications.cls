/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasNotifications {
	// Class variables
	// -------------------------
	@TestVisible
	private static Map<String, Messaging.SingleEmailMessage> templateEmailMap;

	// Public methods
	// -------------------------

	// idea - status change - url
	public static void ideaStatusChange(Set<Id> ideaIds) {
		// Check if the template is valid
		x7sIdeasCommon settings = new x7sIdeasCommon('', false);

		if (String.isBlank(settings.emailIdeaStatusTemplate) || String.isBlank(settings.orgWideFromEmailAddress)) {
			System.debug('Idea Status change: Email template not specified or org wide email not defined - check the Ideas Settings CMT record.');
			return;
		}

		System.debug('x7sIdeasNotifications - ideaStatusChange');

		List<x7sIdeasNotifyModel> notifications = new List<x7sIdeasNotifyModel>();

		String senderId = getOrgWideSenderEmailId(settings.orgWideFromEmailAddress);
		if (String.isBlank(senderId)) {
			System.debug('Idea Status change: Org Wide From Email address not found');
			return;
		}

		List<Id> recordIds = new List<Id>();
		//String   ideaDetailUrl = x7sIdeasUtility.getCommunityUrl();

		try {
			List<Idea> ideas = [SELECT Id,Title,Status FROM Idea WHERE Id IN :ideaIds];
			for (Idea idea : ideas) {
				notifications.add(new x7sIdeasNotifyModel(idea.Id, idea.Title, idea.Status, '', idea.Id));
				recordIds.add(idea.Id);
			}

		}
		catch (Exception ex) {
			System.debug('ideaStatusChange() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());
			return;
		}

		Map<x7sIdeasNotifyModel, List<User>> ideaIdSubscriberIdMap = getIdeaSubscriberMap(notifications, recordIds);
		String templateName = settings.emailIdeaStatusTemplate;

		// Send the map and template name over to our helper to work on sending these e-mails
		sendEmailNotification(ideaIdSubscriberIdMap, templateName, senderId);
	}

	// idea - new comment
	public static void ideaNewComment(Set<Id> ideaCommentIds) {
		// Check if the template is valid
		x7sIdeasCommon settings = new x7sIdeasCommon('', false);

		if (String.isBlank(settings.emailIdeaCommentTemplate) || String.isBlank(settings.orgWideFromEmailAddress)) {
			System.debug('Idea new comment: Email template not specified or org wide email not defined - check the Ideas Settings CMT record.');
			return;
		}

		List<x7sIdeasNotifyModel> notifications = new List<x7sIdeasNotifyModel>();

		String senderId = getOrgWideSenderEmailId(settings.orgWideFromEmailAddress);
		if (String.isBlank(senderId)) {
			System.debug('Idea new comment: Org Wide From Email address not found');
			return;
		}

		List<Id> recordIds = new List<Id>();
		//String              ideaDetailUrl = x7sIdeasUtility.getCommunityUrl();
		try {
			List<IdeaComment> ideaComments = [SELECT CommentBody, IdeaId, Idea.Title, CreatorName FROM IdeaComment WHERE Id IN :ideaCommentIds];

			for (IdeaComment comment : ideaComments) {
				x7sIdeasNotifyModel notification = new x7sIdeasNotifyModel(comment.IdeaId, comment.Idea.Title, comment.CreatorName, comment.CommentBody, comment.IdeaId);
				notification.Dump('New Idea comment');

				notifications.add(notification);
				recordIds.add(comment.IdeaId);
			}
		}
		catch (Exception ex) {
			System.debug('ideaNewComment() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());return;
		}

		Map<x7sIdeasNotifyModel, List<User>> ideaIdSubscriberIdMap = getIdeaSubscriberMap(notifications, recordIds);
		String templateName = settings.emailIdeaCommentTemplate;

		sendEmailNotification(ideaIdSubscriberIdMap, templateName, senderId);
	}

	@TestVisible
	private static Map<x7sIdeasNotifyModel, List<User>> getIdeaSubscriberMap(List<x7sIdeasNotifyModel> ideas, List<Id> recordIds) {
		Map<x7sIdeasNotifyModel, List<User>> ideaSubscriberMap = new Map<x7sIdeasNotifyModel, List<User>>();
		List<Id> userIds = new List<Id>();
		try {
			List<X7S_Ideas_Subscription__c> subscriberIds = [SELECT SubscriberId__c FROM X7S_Ideas_Subscription__c WHERE ParentId__c IN :recordIds LIMIT 1000];

			for (X7S_Ideas_Subscription__c subscriber : subscriberIds) {
				userIds.add(subscriber.SubscriberId__c);
			}

			List<User> subscribedUsers = [SELECT FirstName,LastName,CommunityNickname FROM User WHERE Id IN :userIds];

			for (x7sIdeasNotifyModel idea : ideas) {
				ideaSubscriberMap.put(idea, subscribedUsers);
			}
		}
		catch (Exception ex) { System.debug('getIdeaSubscriberMap() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());return ideaSubscriberMap; }
		System.debug('getIdeaSubscriberMap subscriber map: ' + ideaSubscriberMap);

		return ideaSubscriberMap;
	}

	@TestVisible
	private static void sendEmailNotification(Map<x7sIdeasNotifyModel, List<User>> subscribers, String templateName, String senderId) {
		System.debug('sendEmailNotification subscribers: ' + subscribers);

		// Set up the list to store all the e-mails we need to send
		List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();

		try {
			if (templateName != '' && subscribers.size() > 0 && x7sIdeasUtility.emailTurnedOn() == true) {
				List<EmailTemplate> emailTemplate = [SELECT Id FROM EmailTemplate WHERE EmailTemplate.DeveloperName = :templateName LIMIT 1];
				EmailTemplate template;

				if (emailTemplate.size() > 0) {
					// below query cannot be run WITH_SECURITY_ENFORCED without breaking the ability to send emails in response to community members activity.
					template = [SELECT Id, Subject, HtmlValue, Body, DeveloperName FROM EmailTemplate WHERE Id = :emailTemplate[0].Id]; //NOSONAR
				}

				if (template.Id != null) {
					for (x7sIdeasNotifyModel record : subscribers.keySet()) {
						System.debug(record);

						for (User subscriber : subscribers.get(record)) {
							Messaging.SingleEmailMessage mail = generateEmail(record, subscriber, template, senderId);
							messageList.add(mail);
						}
					}
				}
			}
		}
		catch (Exception ex) {
			System.debug('sendEmailNotification() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());
		}

		//Send List of emails
		try {
			Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);

			//Debug message to verify email was sent
			System.debug('sendEmailNotification - results:');
			for (Messaging.SendEmailResult result : results) {
				System.debug('  result : ' + result.isSuccess());

				if (!result.isSuccess()) {
					for (Messaging.SendEmailError error : result.getErrors()) { System.debug('    error: ' + error.message); }
				}
			}
		}
		catch (System.EmailException ex) {
			System.debug('System.EmailException error: ' + ex.getMessage()) ;
		}
	}

	// NOTE: this method is used in a loop - NO QUERIES
	// Replaced the recordUrl with the Idea ID so that the Admin can enter the Idea detail URL for the specific site
	// in the email template
	@TestVisible
	private static Messaging.SingleEmailMessage generateEmail(x7sIdeasNotifyModel record, User recipient, EmailTemplate emailTemplate, String senderId) {
		Map<String, String> tokenReplacementMap = new Map<String, String>();
		Messaging.SingleEmailMessage templateMail = getTemplateEmailMap(recipient.Id).get(emailTemplate.DeveloperName);

		String htmlBody = templateMail.getHtmlBody();
		String plainTextBody = templateMail.getPlainTextBody();
		String subject = templateMail.getSubject();

		tokenReplacementMap.put('\\{#userName\\}',getRecipientName(recipient));
		tokenReplacementMap.put('\\{#fullName\\}', (String.isNotBlank(record.name) ? recipient.FirstName + ' ' + recipient.LastName : ''));
		tokenReplacementMap.put('\\{#recordName\\}', (String.isNotBlank(record.name) ? record.name : ''));
		tokenReplacementMap.put('\\{#recordContext\\}', (String.isNotBlank(record.context) ? record.context : ''));
		tokenReplacementMap.put('\\{#recordContext2\\}', (String.isNotBlank(record.detail) ? record.detail : ''));
		tokenReplacementMap.put('\\{#recordLink\\}', (String.isNotBlank(record.url) ? record.url : ''));

		//System.debug('generateEmail Token Set: ' + tokenReplacementMap);
		for (String key : tokenReplacementMap.keySet()) {
			System.debug('Replacing key: ' + key);
			String value = (String.isNotBlank(tokenReplacementMap.get(key)) ? tokenReplacementMap.get(key) : '');

			htmlBody = htmlBody.replaceAll(key, value);
			plainTextBody = plainTextBody.replaceAll(key, value);
			subject = subject.replaceAll(key, value);
		}

		if (htmlBody.contains('<![CDATA[')) {
			htmlBody = htmlBody.substring(htmlBody.indexOf('<![CDATA[') + 9); htmlBody = htmlBody.substring(0, htmlBody.indexOf(']]>'));
		}
		System.debug('htmlBody: ' + htmlBody);

		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

		mail.setOrgWideEmailAddressId(senderId);
		mail.setTargetObjectId(recipient.Id);
		mail.setUseSignature(false);
		mail.setBccSender(false);
		mail.setSaveAsActivity(false);
		mail.setSubject(subject);
		mail.setHtmlBody(htmlBody);
		mail.setPlainTextBody(plainTextBody);

		System.debug('created email: ' + mail);
		return mail;
	}

	@TestVisible
	private static Map<String, Messaging.SingleEmailMessage> getTemplateEmailMap(String whoId) {
		if (templateEmailMap == null) {
			List<String> developerNames = new List<String>();
			List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
			for (EmailTemplate myTemplate : [
				SELECT Id, DeveloperName, HtmlValue, Body, Subject
				FROM EmailTemplate
				WHERE DeveloperName IN (
					'X7S_Ideas_New_Comment_Notification',
					'X7S_Ideas_Status_Change_Notification'
				)
			]) {
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setUseSignature(false);
				mail.setSaveAsActivity(false);
				mail.setTargetObjectId(whoId);
				mail.setTemplateId(myTemplate.Id);

				mails.add(mail);
				developerNames.add(myTemplate.DeveloperName);
			}

			Messaging.reserveSingleEmailCapacity(mails.size());

			Savepoint sp = Database.setSavepoint();
			Messaging.sendEmail(mails);
			Database.rollback(sp);

			templateEmailMap = new Map<String, Messaging.SingleEmailMessage>();
			for (Integer i = 0; i < mails.size(); i++) {
				templateEmailMap.put(developerNames[i], mails[i]);
			}
		}

		return templateEmailMap;
	}

	private static String getRecipientName(User recipient) {
		String recipientName = recipient.FirstName;

		try {
			X7S_Ideas_Setting__mdt ideaSetting = X7S_Ideas_Setting__mdt.getInstance('Default');
			if (ideaSetting.Use_Nickname__c && x7sIdeasUtility.isNicknameDisplayEnabled()) { recipientName = recipient.CommunityNickname; }

		} catch (Exception ex) { System.debug('Default 7S Idea Setting not found: ' + ex.getMessage()); }

		return recipientName;
	}

	private static String getOrgWideSenderEmailId(String returnEmail) {
		String emailId = '';
		System.debug('Getting org wide sender email address');
		try {
			// below query cannot be run WITH_SECURITY_ENFORCED without breaking the ability to send emails in response to community members activity.
			OrgWideEmailAddress orgWideEmail = [SELECT Id, DisplayName, Address FROM OrgWideEmailAddress WHERE Address LIKE :returnEmail LIMIT 1]; //NOSONAR
			if (orgWideEmail != null) {
				emailId = orgWideEmail.Id;
			}
		}
		catch (System.QueryException ex) {
			System.debug('QueryException - Failed to query OrgWideEmailAddress - users cannot be notified: ' + ex.getMessage());
		}
		catch (DmlException ex) {
			System.debug('DmlException - Failed to query OrgWideEmailAddress - users cannot be notified: ' + ex.getMessage());
		}

		return emailId;
	}

}