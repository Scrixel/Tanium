/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test methods for class CaseTriggerUtilityWithoutSharing
 * @Date: 2024-09-11
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-8744      2024-09-11       Created the test class
 * SS-9019      2024-09-18       Resolve tech debts
 * SS-9259      2024-10-25       Add test method for First Escalation Date
 * SS-9726      2024-12-05       Add test method for processFeedItem and processFeedComment
 * SS-9309      2024-01-07       Add test method for processFeedComment
 * SS-11173     2025-07-10       Changed field from Severity__c to Severity_Community__c
 * SS-11999     2025-11-03       Added test method for addFeedItemFilterFields and addFeedCommentFilterFields
 * SS-12298     2026-01-13       Updated addFeedItemFilterFields and addFeedCommentFilterFields with SeeAllData=true
 * SS-13423     2026-06-24       Added test method for handleCaseOwnerChange
 */
@IsTest
private class CaseTriggerUtilityWithoutSharingTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
		Id supportCaseRecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');

		System.runAs(TestUserFactory.getAdminUser()) {
			User standardUser = TestUserFactory.getStandardUser();
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			Contact contact = TestFactory.buildContact(account.Id);
			contact.Email = 'RoscoCaseProcesses@foo.com';
			contact.FirstName = 'RoscoCaseProcesse';
			contact.LastName = 'Foo';
			Contact standardUserContact = TestFactory.buildContact(account.Id);
			standardUserContact.Email = standardUser.Email;
			standardUserContact.FirstName = 'Standard';
			standardUserContact.LastName = 'User';
			insert new List<Contact>{ contact, standardUserContact };

			User roscoUser = TestUserFactory.createUser(
				'Testing',
				'RoscoCaseProcesses@foo.com',
				'rcpfed',
				Utility.getProfileId('Tanium Community Login Authenticated Case'),
				null
			);
			roscoUser.ContactId = contact.Id;
			insert roscoUser;

			Case supportCaseL1 = new Case(RecordTypeId = supportCaseRecordTypeId);
			supportCaseL1.Origin = 'Community';
			supportCaseL1.Severity_Community__c = '3';
			supportCaseL1.ContactId = contact.Id;
			supportCaseL1.AccountId = account.Id;
			supportCaseL1.Subject = 'Case Subject';
			supportCaseL1.Escalation_Tier__c = 'Level 1';

			Case supportCaseL2 = new Case(RecordTypeId = supportCaseRecordTypeId);
			supportCaseL2.Origin = 'Community';
			supportCaseL2.Severity_Community__c = '3';
			supportCaseL2.ContactId = contact.Id;
			supportCaseL2.AccountId = account.Id;
			supportCaseL2.Subject = 'Case Subject';
			supportCaseL2.Escalation_Tier__c = 'Level 2';

			Case supportCaseL3 = new Case(RecordTypeId = supportCaseRecordTypeId);
			supportCaseL3.Origin = 'Community';
			supportCaseL3.Severity_Community__c = '3';
			supportCaseL3.ContactId = contact.Id;
			supportCaseL3.AccountId = account.Id;
			supportCaseL3.Subject = 'Case Subject';
			supportCaseL3.Escalation_Tier__c = 'Level 3';

			Case supportCaseForRosco = new Case();
			supportCaseForRosco.RecordTypeId = RoscoUtility.getRecordTypeIdByAPIName(
				'Case',
				'Support'
			);
			supportCaseForRosco.Subject = 'ROSCOTESTCASE-RoscoCaseProcesses';
			supportCaseForRosco.ContactId = contact.Id;

			insert new List<Case>{ supportCaseL1, supportCaseL2, supportCaseL3, supportCaseForRosco };

			ContentVersion cv = new ContentVersion(
				ContentLocation = 'S',
				Title = 'Test Attachment',
				PathOnClient = 'Test Attachment.txt',
				VersionData = Blob.valueOf('Test Content2'),
				IsMajorVersion = true
			);
			insert cv;

			System.runAs(roscoUser) {
				FeedItem feedItemPublic = new FeedItem(
					ParentId = supportCaseForRosco.Id,
					Body = 'ROSCOTESTCASE-Customer',
					Visibility = 'AllUsers',
					IsRichText = true,
					NetworkScope = 'AllNetworks',
					Type = 'TextPost'
				);
				insert feedItemPublic;

				FeedComment feedCommentPublic = new FeedComment(
					FeedItemId = feedItemPublic.Id,
					CommentBody = 'ROSCOTESTCASE-Tanium',
					CommentType = 'TextComment',
					Status = 'Published'
				);
				insert feedCommentPublic;
			}

			FeedItem feedItemPrivate = new FeedItem(
				ParentId = supportCaseForRosco.Id,
				RelatedRecordId = cv.Id,
				Visibility = 'InternalUsers',
				IsRichText = false,
				NetworkScope = 'AllNetworks',
				Type = 'ContentPost',
				Title = 'Test Attachment'
			);
			FeedItem feedItemQuestion = new FeedItem(
				ParentId = roscoUser.Id,
				Body = 'Test FeedItem Community Question',
				Visibility = 'AllUsers',
				IsRichText = true,
				Title = 'Test FeedItem Community Question',
				NetworkScope = Constants.TANIUM_CUSTOMER_COMMUNITY_ID
			);
			insert new List<FeedItem>{ feedItemPrivate, feedItemQuestion };

			FeedComment feedCommentPrivate = new FeedComment(
				FeedItemId = feedItemPrivate.Id,
				RelatedRecordId = cv.Id,
				CommentBody = null,
				CommentType = 'ContentComment',
				Status = 'Published'
			);
			insert feedCommentPrivate;
		}
	}

	@IsTest
	static void testSetCaseStatus_WhenCommentIsAdded_MoveCaseToInProgress() {
		Case caseRec = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		Test.startTest();
		setCaseStatus(caseRec.Id, 'Pending - Clarifying');
		List<FeedComment> feedCommentRec = [
			SELECT ParentId, CommentType, Status, CreatedById
			FROM FeedComment
			WHERE CommentType = 'TextComment'
		];
		CaseTriggerUtilityWithoutSharing.setCaseStatus(null, null, feedCommentRec);
		Test.stopTest();

		Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :caseRec.Id LIMIT 1];
		Assert.areEqual('In Progress - Troubleshooting', updatedCase.Status);
	}

	@IsTest
	static void testSetCaseStatus_WhenFeedItemIsAdded_MoveCaseToInProgress() {
		Case caseRec = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		Test.startTest();
		setCaseStatus(caseRec.Id, 'Pending - Clarifying');
		List<FeedItem> feedItems = [
			SELECT Visibility, Type, Status, CreatedById, ParentId, Body, NetworkScope
			FROM FeedItem
			WHERE Type = 'TextPost'
		];
		CaseTriggerUtilityWithoutSharing.setCaseStatus(null, feedItems, null);
		Test.stopTest();

		Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :caseRec.Id LIMIT 1];
		Assert.areEqual('In Progress - Troubleshooting', updatedCase.Status);
	}

	@IsTest
	static void testProcessCommentFeedComment_WhenCommentIsAdded_UpdateCaseLatestComment() {
		Case caseRec = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		List<FeedComment> feedComments = [
			SELECT ParentId, CommentType, Status, CreatedById, FeedItemId, CommentBody, RelatedRecordId
			FROM FeedComment
			WHERE CommentType = 'TextComment'
		];

		Test.startTest();
		CaseTriggerUtilityWithoutSharing.processFeedComment(feedComments);
		Test.stopTest();

		Case updatedCase = [
			SELECT LatestPublicCommentHTML__c
			FROM Case
			WHERE Id = :caseRec.Id
			LIMIT 1
		];
		Assert.areEqual(feedComments[0].CommentBody, updatedCase.LatestPublicCommentHTML__c);
	}

	@IsTest
	static void testProcessCommentFeedComment_WhenCommentIsAddedWithNoCommentBody_UpdateCaseLatestCommentWithAttachmentTitle() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case caseRec = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
			List<FeedComment> feedComments = [
				SELECT
					ParentId,
					CommentType,
					Status,
					CreatedById,
					FeedItemId,
					CommentBody,
					RelatedRecordId
				FROM FeedComment
				WHERE CommentType = 'ContentComment'
			];
			ContentVersion cv = [SELECT Id, Title FROM ContentVersion WHERE Title = 'Test Attachment'];

			Test.startTest();
			CaseTriggerUtilityWithoutSharing.processFeedComment(feedComments);
			Test.stopTest();

			Case updatedCase = [
				SELECT LatestPrivateComment__c
				FROM Case
				WHERE Id = :caseRec.Id
				LIMIT 1
			];
			Assert.areEqual(cv.Title, updatedCase.LatestPrivateComment__c);
		}
	}

	@IsTest
	static void testProcessCommentFeedComment_WhenCommentIsAddedByTaniumAgent_UpdateLastResponseDate() {
		Case caseRec = [
			SELECT Id, Last_Response_Date__c
			FROM Case
			WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'
		];
		FeedItem feedItem = [SELECT Id FROM FeedItem WHERE Type = 'TextPost' LIMIT 1];

		Test.startTest();
		FeedComment feedComment = new FeedComment(
			FeedItemId = feedItem.Id,
			CommentBody = 'Test Body',
			CommentType = 'TextComment',
			Status = 'Published'
		);
		insert feedComment;

		feedComment = [
			SELECT Id, ParentId, CommentType, Status, CreatedById, FeedItemId, CommentBody
			FROM FeedComment
			WHERE Id = :feedComment.Id
		];
		CaseTriggerUtilityWithoutSharing.processFeedComment(new List<FeedComment>{ feedComment });
		Test.stopTest();

		Case updatedCase = [SELECT Last_Response_Date__c FROM Case WHERE Id = :caseRec.Id LIMIT 1];
		Assert.areNotEqual(caseRec.Last_Response_Date__c, updatedCase.Last_Response_Date__c);
	}

	@IsTest
	static void testProcessCommentFeedItem_WhenCommentsAdded_UpdateCasePrivateComment() {
		Case caseRec = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		List<FeedItem> feedItems = [
			SELECT Visibility, Type, Status, CreatedById, ParentId, Body
			FROM FeedItem
			WHERE Type = 'TextPost'
		];

		Test.startTest();
		CaseTriggerUtilityWithoutSharing.processFeedItem(feedItems);
		Test.stopTest();

		Case updatedCase = [
			SELECT LatestPublicCommentHTML__c
			FROM Case
			WHERE Id = :caseRec.Id
			LIMIT 1
		];
		Assert.areEqual(feedItems[0].Body, updatedCase.LatestPublicCommentHTML__c);
	}

	@IsTest
	static void testProcessCommentFeedItem_WhenCommentsAddedWithNoBoby_UpdateCasePrivateCommentWithAttachmentTitle() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case caseRec = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
			List<FeedItem> feedItems = [
				SELECT Visibility, Type, Status, CreatedById, ParentId, Body, Title
				FROM FeedItem
				WHERE Type = 'ContentPost'
			];
			ContentVersion cv = [SELECT Id, Title FROM ContentVersion WHERE Title = 'Test Attachment'];

			Test.startTest();
			CaseTriggerUtilityWithoutSharing.processFeedItem(feedItems);
			Test.stopTest();

			Case updatedCase = [
				SELECT LatestPrivateComment__c
				FROM Case
				WHERE Id = :caseRec.Id
				LIMIT 1
			];
			Assert.areEqual(cv.Title, updatedCase.LatestPrivateComment__c);
		}
	}

	static void setCaseStatus(String caseId, String status) {
		Case caseRec = [SELECT Id, Status FROM Case WHERE Id = :caseId];
		if (status == null) {
			caseRec.Status = null;
		} else {
			caseRec.Status = status;
		}
		update caseRec;
	}

	@IsTest
	static void testSetAssignedDate_WhenCaseIsCreated_AssignedDateIsPopulated() {
		Case caseRec = [SELECT First_Assigned_Date__c, CreatedDate, OwnerId FROM Case LIMIT 1];

		Test.startTest();
		CaseTriggerUtilityWithoutSharing.setAssignedDate(new List<Case>{ caseRec }, null);
		Test.stopTest();

		Case insertedCase = [
			SELECT CreatedDate, First_Assigned_Date__c
			FROM Case
			WHERE Id = :caseRec.Id
		];
		Assert.isNotNull(caseRec.First_Assigned_Date__c);
	}

	@IsTest
	static void testSetDeescalationDate_WhenCaseIsDeescalated_DeescalationDateIsPopulated() {
		Case caseRec = [
			SELECT First_Assigned_Date__c, CreatedDate, OwnerId
			FROM Case
			WHERE Escalation_Tier__c = 'Level 2'
			LIMIT 1
		];
		caseRec.Escalation_Tier__c = 'Level 1';

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [SELECT DeEscalation_Date__c FROM Case WHERE Id = :caseRec.Id];
		Assert.isNotNull(updatedCase.DeEscalation_Date__c);
	}

	@IsTest
	static void testProcessEscalationChange_WhenCaseIsEscalatedToL2AndDateIsNotBlank_EscalationDateIsPopulated() {
		Case caseRec = [
			SELECT First_Assigned_Date__c, CreatedDate, OwnerId
			FROM Case
			WHERE Escalation_Tier__c = 'Level 1'
			LIMIT 1
		];
		caseRec.Escalation_Tier__c = 'Level 2';
		caseRec.Escalation_L2_Date__c = Date.today();

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [
			SELECT Escalation_L2_Date__c, Escalation_L2_SME_Engaged_Date__c, Escalation_L2_SLO__c
			FROM Case
			WHERE Id = :caseRec.Id
		];
		Assert.isNotNull(updatedCase.Escalation_L2_Date__c);
		Assert.isNull(updatedCase.Escalation_L2_SME_Engaged_Date__c);
		Assert.isNull(updatedCase.Escalation_L2_SLO__c);
	}

	@IsTest
	static void testProcessEscalationChange_WhenCaseIsEscalatedToL3AndDateIsBlank_EscalationDateIsPopulated() {
		Case caseRec = [
			SELECT First_Assigned_Date__c, CreatedDate, OwnerId
			FROM Case
			WHERE Escalation_Tier__c = 'Level 2'
			LIMIT 1
		];
		caseRec.Escalation_Tier__c = 'Level 3';

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [SELECT Escalation_L3_Date__c FROM Case WHERE Id = :caseRec.Id];
		Assert.isNotNull(updatedCase.Escalation_L3_Date__c);
	}

	@IsTest
	static void testProcessEscalationChange_WhenCaseIsEscalatedToL3AndL4DateIsNotBlank_EscalationDateIsPopulated() {
		List<Case> newCaseList = new List<Case>();
		Map<Id, Case> caseMap = new Map<Id, Case>();

		Case caseRec = [
			SELECT
				First_Assigned_Date__c,
				CreatedDate,
				OwnerId,
				Escalation_L4_Date__c,
				Escalation_Team__c,
				First_EscalationDate__c
			FROM Case
			WHERE Escalation_Tier__c = 'Level 2'
			LIMIT 1
		];
		caseRec.Escalation_Tier__c = 'Level 3';
		caseRec.Escalation_L3_Date__c = Date.today();

		Test.startTest();
		update caseRec;
		newCaseList.add(caseRec);
		caseRec.Escalation_Tier__c = 'Level 4';
		caseRec.Escalation_L4_Date__c = Date.today();
		caseMap.put(caseRec.Id, caseRec);
		CaseTriggerUtilityWithoutSharing.processEscalationChange(newCaseList, caseMap);
		Test.stopTest();

		Case updatedCase = [
			SELECT Escalation_L3_Date__c, Escalation_L3_SME_Engaged_Date__c, Escalation_L3_SLO__c
			FROM Case
			WHERE Id = :caseRec.Id
		];
		Assert.isNotNull(updatedCase.Escalation_L3_Date__c);
		Assert.isNull(updatedCase.Escalation_L3_SME_Engaged_Date__c);
		Assert.isNull(updatedCase.Escalation_L3_SLO__c);
	}

	@IsTest
	static void testProcessEscalationChange_WhenCaseIsEscalated_FirstEscalationDateIsPopulatedAndNeverOverwritten() {
		List<Case> newCaseList = [
			SELECT
				First_Assigned_Date__c,
				CreatedDate,
				OwnerId,
				Escalation_L4_Date__c,
				Escalation_Team__c,
				First_EscalationDate__c,
				Escalation_Tier__c,
				Escalation_L2_Date__c
			FROM Case
			WHERE Escalation_Tier__c = 'Level 1'
			LIMIT 1
		];

		Map<Id, Case> oldMap = new Map<Id, Case>(newCaseList.deepClone(true, true, true));

		for (case newCase : newCaseList) {
			newCase.Escalation_Tier__c = 'Level 2';
		}

		Test.startTest();
		CaseTriggerUtilityWithoutSharing.processEscalationChange(newCaseList, oldMap);
		Case updatedCase = [SELECT First_EscalationDate__c FROM Case WHERE Id = :newCaseList[0].Id];
		Datetime firstEscalationDate = updatedCase.First_EscalationDate__c;

		for (case newCase : newCaseList) {
			newCase.Escalation_Tier__c = 'Level 1';
		}
		CaseTriggerUtilityWithoutSharing.processEscalationChange(newCaseList, oldMap);
		updatedCase = [SELECT Escalation_Tier__c FROM Case WHERE Id = :newCaseList[0].Id];
		Assert.areEqual(
			'Level 1',
			updatedCase.Escalation_Tier__c,
			'Escalation Level should be deescalated to level 1'
		);

		for (case newCase : newCaseList) {
			newCase.Escalation_Tier__c = 'Level 2';
		}
		CaseTriggerUtilityWithoutSharing.processEscalationChange(newCaseList, oldMap);

		Test.stopTest();

		updatedCase = [SELECT First_EscalationDate__c FROM Case WHERE Id = :newCaseList[0].Id];
		Assert.areEqual(
			firstEscalationDate,
			updatedCase.First_EscalationDate__c,
			'First Escalation Date should not change regardless of de-escalation and re-escalation.'
		);
	}

	@IsTest
	static void testSetFirstSolvedDate_WhenFirstSolvedIsNotBlank_GetValueFromCreatedDate() {
		Case caseRec = [SELECT First_Solved_Date__c, CreatedDate, OwnerId FROM Case LIMIT 1];
		caseRec.Status = 'Solved';

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [
			SELECT First_Solved_Date__c, CreatedDate
			FROM Case
			WHERE Id = :caseRec.Id
		];
		Assert.isNotNull(updatedCase.First_Solved_Date__c);
	}

	@IsTest
	static void testSetEscalationSMEOwnerChange_WhenEscalationTierIs2_L2SMEDateIsUpdated() {
		Case caseRec = [
			SELECT First_Assigned_Date__c, CreatedDate, OwnerId
			FROM Case
			WHERE Escalation_Tier__c = 'Level 1'
			LIMIT 1
		];
		caseRec.Escalation_Tier__c = 'Level 2';
		caseRec.SME_OwnerId__c = UserInfo.getUserId();

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [
			SELECT Escalation_L2_SME_Engaged_Date__c
			FROM Case
			WHERE Id = :caseRec.Id
		];
		Assert.isNotNull(updatedCase.Escalation_L2_SME_Engaged_Date__c);
	}

	@IsTest
	static void testSetEscalationSMEOwnerChange_WhenEscalationTierIs3_L23MEDateIsUpdated() {
		Case caseRec = [
			SELECT First_Assigned_Date__c, CreatedDate, OwnerId
			FROM Case
			WHERE Escalation_Tier__c = 'Level 2'
			LIMIT 1
		];
		caseRec.Escalation_Tier__c = 'Level 3';
		caseRec.SME_OwnerId__c = UserInfo.getUserId();

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [
			SELECT Escalation_L3_SME_Engaged_Date__c
			FROM Case
			WHERE Id = :caseRec.Id
		];
		Assert.isNotNull(updatedCase.Escalation_L3_SME_Engaged_Date__c);
	}

	@IsTest
	static void testIsSloStatusWip_WhenStatusIsWaitingOrWarning_SetToTrue() {
		Assert.isTrue(CaseTriggerUtilityWithoutSharing.isSloStatusWip('Waiting'));
		Assert.isTrue(CaseTriggerUtilityWithoutSharing.isSloStatusWip('Warning'));
		Assert.isFalse(CaseTriggerUtilityWithoutSharing.isSloStatusWip('Solved'));
	}

	@IsTest
	static void testSetEscalationLevelWatermark_WhenEscalationWatermarkIsBlank_SetWatermarkValueFromEscalationTier() {
		Case caseRec = [
			SELECT Escalation_Tier__c, Escalation_Level_Watermark__c
			FROM Case
			WHERE Escalation_Tier__c = 'Level 1'
			LIMIT 1
		];
		caseRec.Escalation_Level_Watermark__c = null;

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [SELECT Escalation_Level_Watermark__c FROM Case WHERE Id = :caseRec.Id];
		Assert.areEqual('Level 1', updatedCase.Escalation_Level_Watermark__c);
	}

	@IsTest
	static void testSetEscalationLevelWatermark_WhenEscalationWatermarkIsLevel2AndEscalationTierIsLevel3_SetWatermarkValueFromEscalationTier() {
		Case caseRec = [
			SELECT Escalation_Tier__c, Escalation_Level_Watermark__c
			FROM Case
			WHERE Escalation_Tier__c = 'Level 3'
			LIMIT 1
		];
		caseRec.Escalation_Level_Watermark__c = 'Level 2';

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [SELECT Escalation_Level_Watermark__c FROM Case WHERE Id = :caseRec.Id];
		Assert.areEqual('Level 3', updatedCase.Escalation_Level_Watermark__c);
	}

	@IsTest
	static void testSetEscalationLevelWatermark_WhenEscalationWatermarkIsLevel1AndEscalationTierIsLevel2_SetWatermarkValueFromEscalationTier() {
		Case caseRec = [
			SELECT Escalation_Tier__c, Escalation_Level_Watermark__c
			FROM Case
			WHERE Escalation_Tier__c = 'Level 2'
			LIMIT 1
		];
		caseRec.Escalation_Level_Watermark__c = 'Level 1';

		Test.startTest();
		update caseRec;
		Test.stopTest();

		Case updatedCase = [SELECT Escalation_Level_Watermark__c FROM Case WHERE Id = :caseRec.Id];
		Assert.areEqual('Level 2', updatedCase.Escalation_Level_Watermark__c);
	}

	@IsTest
	static void testSetEscalationSLO_WhenCaseIsEscalated_SetEscalationSloToCanceled() {
		Case caseRec = [
			SELECT Escalation_Tier__c, Escalation_Level_Watermark__c
			FROM Case
			WHERE Escalation_Tier__c = 'Level 1'
			LIMIT 1
		];

		Case caseRecL3 = [
			SELECT
				Escalation_Tier__c,
				Support_Model__c,
				Escalation_Team__c,
				Severity_Community__c,
				RecordTypeId,
				CreatedDate,
				Escalation_L2_Date__c,
				Escalation_L2_SLO__c,
				Escalation_L3_Date__c,
				Escalation_L4_Date__c,
				Escalation_L5_Date__c,
				Escalation_L3_SLO__c,
				Escalation_L4_SLO__c,
				Escalation_L5_SLO__c,
				RecordType.Name
			FROM Case
			WHERE Escalation_Tier__c = 'Level 3'
			LIMIT 1
		];

		caseRec.Escalation_Tier__c = 'Level 2';
		caseRec.Escalation_L2_SLO__c = 'Waiting';
		caseRec.Escalation_L3_SLO__c = 'Waiting';
		caseRec.Escalation_L4_SLO__c = 'Waiting';
		caseRec.Escalation_L5_SLO__c = 'Waiting';
		caseRecL3.Escalation_Tier__c = 'Level 4';
		caseRecL3.Escalation_Team__c = 'SME-Foo';
		caseRecL3.Escalation_L4_SLO__c = null;
		caseRecL3.Escalation_L4_SME_Engaged_Date__c = null;
		caseRecL3.Escalation_L2_SLO__c = 'Waiting';
		caseRecL3.Escalation_L3_SLO__c = 'Waiting';
		caseRecL3.Escalation_L5_SLO__c = 'Waiting';

		Test.startTest();
		update caseRec;
		CaseTriggerUtilityWithoutSharing.setEscalationSLO(new List<Case>{ caseRecL3 }, null);
		Test.stopTest();

		Case updatedCase = [
			SELECT
				Escalation_L2_SLO__c,
				Escalation_L3_SLO__c,
				Escalation_L4_SLO__c,
				Escalation_L5_SLO__c
			FROM Case
			WHERE Id = :caseRec.Id
		];
		Assert.areEqual('Canceled', updatedCase.Escalation_L2_SLO__c);
		Assert.areEqual('Canceled', updatedCase.Escalation_L3_SLO__c);
		Assert.areEqual('Canceled', updatedCase.Escalation_L4_SLO__c);
		Assert.areEqual('Canceled', updatedCase.Escalation_L5_SLO__c);
	}

	@IsTest
	static void testSetLastCustomerResponseDate_WhenCaseIsCreated_LastCustomerResponseDateIsUpdated() {
		Case caseRec = [SELECT Last_Customer_Response_Date__c, CreatedById FROM Case LIMIT 1];

		Test.startTest();
		CaseTriggerUtilityWithoutSharing.setLastCustomerResponseDate(new List<Case>{ caseRec });
		Test.stopTest();

		Case updatedCase = [SELECT Last_Customer_Response_Date__c FROM Case WHERE Id = :caseRec.Id];
		Assert.isNotNull(updatedCase.Last_Customer_Response_Date__c);
	}

	@IsTest
	static void testProcessNewCmtyQuestion_WhenCaseIsCreated_CaseIsUpdated() {
		FeedItem feedItem = [
			SELECT Id, NetworkScope, Title, Body, ParentId
			FROM FeedItem
			WHERE Title = 'Test FeedItem Community Question'
			LIMIT 1
		];

		Test.startTest();
		CaseTriggerUtilityWithoutSharing.processNewCmtyQuestion(feedItem);
		Test.stopTest();

		Assert.isNotNull(feedItem.Id);
	}

	@IsTest
	static void testHandleCaseOwnerChange_WhenCaseOwnerIsUpdate_CaseContactRoleCreated() {
		User standardUser = [
			SELECT Id, Email
			FROM User
			WHERE LastName = :TestUserFactory.TANIUM_STANDARD_USER
		];
		Contact standardUserContact = [
			SELECT Id, Email
			FROM Contact
			WHERE Email = :standardUser.Email
		];

		List<Case> cases = [SELECT Id, ContactId, OwnerId, IsClosed FROM Case];
		Map<Id, Case> oldMap = new Map<Id, Case>(cases.deepClone(true, true, true));
		cases[0].OwnerId = standardUser.Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			CaseTriggerUtilityWithoutSharing.handleCaseOwnerChange(cases, oldMap);
			Test.stopTest();
		}

		CaseContactRole caseContactRole = [
			SELECT Id, CasesId, ContactId
			FROM caseContactRole
			WHERE CasesId = :cases[0].Id
		];
		Assert.isNotNull(caseContactRole.Id);
		Assert.areEqual(cases[0].Id, caseContactRole.CasesId);
		Assert.areEqual(standardUserContact.Id, caseContactRole.ContactId);
	}
}