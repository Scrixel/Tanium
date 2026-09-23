/*
 * Copyright (c) 2025 Tanium
 *
 * @Business: Without Sharing Trigger Utility for the CaseTrigger class
 * @Date: 2024-09-11
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-7436      2024-08-27       Resolve tech debts
 * SS-8744      2024-09-24       Moved methods from RoscoCaseProcesses class
 * SS-9019      2024-09-18       Move methods to CaseTriggerUtilityWithoutSharing
 * SS-9451      2024-10-19       Remove logic for adding comments on closed cases
 * SS-9259      2024-10-25       Added logic for populating First Escalation Date
 * SS-9703      2024-11-20       Updated method setCaseStatus
 * SS-9726      2024-12-05       Added logic for populating LastPublicComment and LastPrivateComment.
 * SS-9309      2025-01-07       Added logic to update Last Response Date in processFeedComment.
 * SS-10485     2025-06-19       Updated method processFeedComment
 * SS-11173     2025-07-10       Changed field from Severity__c to Severity_Community__c
 * SS-11999     2025-11-03       Added method addFeedItemFilterFields
 * SS-12298     2026-01-13       Updated addFeedItemFilterFields with ConnectApi and bug fixes
 * SS-13423     2026-06-24       Added method handleCaseOwnerChange
 */
public without sharing class CaseTriggerUtilityWithoutSharing {
	@TestVisible
	private static final String IN_PROGRESS_TROUBLESHOOTING = 'In Progress - Troubleshooting';
	@TestVisible
	private static final String ALL_USERS = 'AllUsers';
	@TestVisible
	private static final String INTERNAL_USERS = 'InternalUsers';
	public static final String LEVEL_ONE = 'Level 1';
	public static final String LEVEL_TWO = 'Level 2';
	public static final String LEVEL_THREE = 'Level 3';
	public static final String LEVEL_FOUR = 'Level 4';
	public static final String LEVEL_FIVE = 'Level 5';
	public static final String SOLVED = 'Solved';
	public static final String CANCELED = 'Canceled';
	public static final String PASS = 'Pass';
	public static final String PUBLISHED = 'Published';
	public static final List<String> VALID_FEEDITEM_TYPES = new List<String>{
		'TextPost',
		'ContentPost',
		'LinkPost'
	};
	public static final List<String> VALID_FEEDCOMMENT_TYPES = new List<String>{
		'TextComment',
		'ContentComment'
	};
	public static void setCaseStatus(
		EmailMessage email,
		List<FeedItem> feedItems,
		List<FeedComment> feedComments
	) {
		if (feedItems != null && !feedItems.isEmpty()) {
			List<Case> casesToUpdate = new List<Case>();
			List<FeedComment> newFeedComments = new List<FeedComment>();
			Map<Id, FeedItem> caseIdsFeedItemMap = new Map<Id, FeedItem>();

			for (FeedItem feedItem : feedItems) {
				if (
					feedItem?.ParentId?.getSObjectType() == Case.SObjectType &&
					feedItem.Visibility == ALL_USERS &&
					feedItem.NetworkScope == 'AllNetworks' &&
					feedItem.Status == PUBLISHED &&
					VALID_FEEDITEM_TYPES.contains(feedItem.Type)
				) {
					if (!RoscoCaseProcesses.isAgent(feedItem.CreatedById)) {
						Boolean caseClosure = false;
						if (!nullOrEmpty(feedItem.Body)) {
							if (feedItem.Body.containsIgnoreCase(Constants.CASE_CLOSE_SUMMARY)) {
								caseClosure = true;
							}
						}
						if (!caseClosure) {
							caseIdsFeedItemMap.put(feedItem.ParentId, feedItem);
						}
					}
				}
			}

			for (Case caseRec : [SELECT Status FROM Case WHERE Id IN :caseIdsFeedItemMap.keySet()]) {
				if (nullOrEmpty(caseRec.Status)) {
					caseRec.Status = IN_PROGRESS_TROUBLESHOOTING;
					casesToUpdate.add(caseRec);
				} else if (caseRec.Status != IN_PROGRESS_TROUBLESHOOTING) {
					caseRec.Status = IN_PROGRESS_TROUBLESHOOTING;
					casesToUpdate.add(caseRec);
				}
			}

			Database.SaveResult[] saveResultsUpdate = Database.update(casesToUpdate, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'CaseTriggerUtility.setCaseStatus ERRORS',
					saveResultsUpdate
				)
				.addTag('apex');
			Logger.saveLog();
		} else if (feedComments != null && !feedComments.isEmpty()) {
			Set<Id> parentIds = new Set<Id>();
			List<Case> casesToUpdate = new List<Case>();
			List<FeedComment> newFeedComments = new List<FeedComment>();

			for (FeedComment feedComment : feedComments) {
				if (
					String.valueOf(feedComment.ParentId).left(3) == '500' &&
					feedComment.Status == PUBLISHED &&
					VALID_FEEDCOMMENT_TYPES.contains(feedComment.CommentType) &&
					!RoscoCaseProcesses.isAgent(feedComment.CreatedById)
				) {
					parentIds.add(feedComment.ParentId);
				}
			}

			for (Case caseRec : [SELECT Id, Status FROM Case WHERE Id IN :parentIds]) {
				if (
					nullOrEmpty(caseRec.Status) ||
					caseRec.Status != IN_PROGRESS_TROUBLESHOOTING &&
					!Constants.CASE_CLOSE_STATUSES.contains(caseRec.Status)
				) {
					caseRec.Status = IN_PROGRESS_TROUBLESHOOTING;
					casesToUpdate.add(caseRec);
				}
			}

			Database.SaveResult[] saveResultsUpdate = Database.update(casesToUpdate, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'CaseTriggerUtility.setCaseStatus ERRORS',
					saveResultsUpdate
				)
				.addTag('apex');
			Logger.saveLog();
		}
	}

	public static void processFeedComment(List<FeedComment> feedComments) {
		List<Case> casesToUpdate = new List<Case>();
		List<FeedComment> validFeedComments = new List<FeedComment>();
		Set<Id> agentComments = new Set<Id>();
		Set<Id> agentFeedItemIds = new Set<Id>();
		Set<Id> feedItemIds = new Set<Id>();

		for (FeedComment feedComment : feedComments) {
			if (
				feedComment.FeedItemId != null &&
				String.valueOf(feedComment.ParentId).left(3) == '500' &&
				feedComment.Status == PUBLISHED &&
				VALID_FEEDCOMMENT_TYPES.contains(feedComment.CommentType)
			) {
				feedItemIds.add(feedComment.FeedItemId);
				validFeedComments.add(feedComment);
				if (RoscoCaseProcesses.isAgent(feedComment.CreatedById)) {
					agentComments.add(feedComment.Id);
				}
			}
		}

		Map<Id, FeedItem> feedItemMap = new Map<Id, FeedItem>(
			[SELECT Id, Visibility, CreatedById, Type FROM FeedItem WHERE Id IN :feedItemIds]
		);

		for (FeedItem feedItem : feedItemMap.values()) {
			if (
				RoscoCaseProcesses.isAgent(feedItem.CreatedById) && feedItem.Type != 'EmailMessageEvent'
			) {
				agentFeedItemIds.add(feedItem.Id);
			}
		}

		for (FeedComment feedComment : validFeedComments) {
			FeedItem feedItem = feedItemMap.get(feedComment.FeedItemId);
			Case caseRec = new Case(Id = feedComment.ParentId);

			String latestComment = feedComment.CommentBody;
			String plainTextComment = RoscoCaseProcesses.convertHTMLToPlainText(latestComment);

			if (feedComment.CommentType == 'ContentComment' && String.isBlank(latestComment)) {
				latestComment = getContentTitle(feedComment.RelatedRecordId);
				plainTextComment = latestComment;
			}

			if (feedItem.Visibility == ALL_USERS) {
				caseRec.LatestPublicCommentHTML__c = latestComment;
				caseRec.LatestPublicComment__c = plainTextComment;
			} else if (feedItem.Visibility == INTERNAL_USERS) {
				caseRec.LatestPrivateCommentHTML__c = latestComment;
				caseRec.LatestPrivateComment__c = plainTextComment;
			}

			if (
				agentComments.contains(feedComment.Id) &&
				!agentFeedItemIds.contains(feedComment.FeedItemId)
			) {
				caseRec.Last_Response_Date__c = System.Datetime.now();
			}

			casesToUpdate.add(caseRec);
		}

		Database.SaveResult[] saveResultsUpdate = Database.update(casesToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'CaseTriggerUtilityWithoutSharing.processFeedComment ERRORS',
				saveResultsUpdate
			)
			.addTag('apex');
		Logger.saveLog();
	}

	private static Map<Id, FeedComment> getFeedItemIdLatestFeedCommentMap(Set<Id> feedItemIds) {
		Map<Id, FeedComment> feedItemIdLatestFeedCommentMap = new Map<Id, FeedComment>();
		FeedComment latestFeedComment;
		Id priorFeedItemId = null;

		for (FeedComment feedComment : [
			SELECT Id, CreatedById, FeedItemId
			FROM FeedComment
			WHERE FeedItemId IN :feedItemIds
			ORDER BY CreatedDate DESC
		]) {
			if (priorFeedItemId != feedComment.FeedItemId) {
				feedItemIdLatestFeedCommentMap.put(feedComment.FeedItemId, feedComment);
			}
			priorFeedItemId = feedComment.FeedItemId;
		}
		return feedItemIdLatestFeedCommentMap;
	}

	public static void processFeedItem(List<FeedItem> feedItems) {
		List<Case> casesToUpdate = new List<Case>();
		Map<Id, FeedItem> caseIdsFeedItemMap = new Map<Id, FeedItem>();

		for (FeedItem feedItem : feedItems) {
			if (
				feedItem.Visibility != null &&
				feedItem?.ParentId?.getSObjectType() == Case.SObjectType &&
				feedItem.Status == PUBLISHED &&
				VALID_FEEDITEM_TYPES.contains(feedItem.Type)
			) {
				caseIdsFeedItemMap.put(feedItem.ParentId, feedItem);
			}
		}

		for (Case caseRec : [SELECT Id, Status FROM Case WHERE Id IN :caseIdsFeedItemMap.keySet()]) {
			FeedItem feedItem = caseIdsFeedItemMap.get(caseRec.Id);
			String latestComment = String.isNotBlank(feedItem.Body) ? feedItem.Body : feedItem.Title;
			String plainTextComment = RoscoCaseProcesses.convertHTMLToPlainText(latestComment);

			if (feedItem?.Visibility == ALL_USERS) {
				caseRec.LatestPublicCommentHTML__c = latestComment;
				caseRec.LatestPublicComment__c = plainTextComment;
				casesToUpdate.add(caseRec);
			} else if (feedItem?.Visibility == INTERNAL_USERS) {
				caseRec.LatestPrivateCommentHTML__c = latestComment;
				caseRec.LatestPrivateComment__c = plainTextComment;
				casesToUpdate.add(caseRec);
			}
		}

		Database.SaveResult[] saveResultsUpdate = Database.update(casesToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'CaseTriggerUtilityWithoutSharing.processFeedItem ERRORS',
				saveResultsUpdate
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void addFeedItemFilterFields(List<FeedItem> feedItems) {
		List<String> eligibleTypes = new List<String>{
			'AdvancedTextPost',
			'ContentPost',
			'LinkPost',
			'TextPost'
		};

		Map<Id, FeedItem> parentCaseIdToFeedItem = new Map<Id, FeedItem>();
		List<String> feedItemIds = new List<String>();
		for (FeedItem feedItem : feedItems) {
			if (
				feedItem.ParentId.getSObjectType() == Case.SObjectType &&
				feedItem.Body != null &&
				!feedItem.Body.contains(Constants.CASE_CLOSE_SUMMARY) &&
				eligibleTypes.contains(feedItem.Type)
			) {
				parentCaseIdToFeedItem.put(feedItem.ParentId, feedItem);
				feedItemIds.add(String.valueOf(feedItem.Id));
			}
		}

		Map<Id, Case> feedItemIdToCase = new Map<Id, Case>();
		for (Case caseRec : [
			SELECT Id, CaseNumber, Account.Name
			FROM Case
			WHERE Id IN :parentCaseIdToFeedItem.keySet()
		]) {
			feedItemIdToCase.put(parentCaseIdToFeedItem.get(caseRec.Id)?.Id, caseRec);
		}

		List<ConnectApi.BatchResult> batchResults = ConnectApi.ChatterFeeds.getFeedElementBatch(
			null,
			feedItemIds
		);

		for (ConnectApi.BatchResult batchResult : batchResults) {
			if (batchResult.isSuccess()) {
				Object result = batchResult.getResult();

				if (result instanceof ConnectApi.FeedItem) {
					ConnectApi.FeedItem item = (ConnectApi.FeedItem) result;
					ConnectApi.FeedItemInput input = ConnectApiHelper.createFeedItemInputFromBody(
						item.body
					);

					modifyFeedItemAndCommentBody(
						input,
						null,
						feedItemIdToCase.get(item.Id)?.Account.Name,
						feedItemIdToCase.get(item.Id)?.CaseNumber
					);
					ConnectApi.ChatterFeeds.updateFeedElement(null, item.id, input);
				}
			}
		}
	}

	public static void addFeedCommentFilterFields(List<FeedComment> feedComments) {
		Map<Id, FeedComment> parentCaseIdToFeedComment = new Map<Id, FeedComment>();
		List<String> feedCommentIds = new List<String>();
		for (FeedComment feedComment : feedComments) {
			if (
				feedComment.ParentId != null &&
				feedComment.ParentId.getSObjectType() == Case.SObjectType &&
				feedComment.CommentBody != null
			) {
				parentCaseIdToFeedComment.put(feedComment.ParentId, feedComment);
				feedCommentIds.add(String.valueOf(feedComment.Id));
			}
		}

		Map<Id, Case> feedCommentIdToCase = new Map<Id, Case>();
		for (Case caseRec : [
			SELECT Id, CaseNumber, Account.Name
			FROM Case
			WHERE Id IN :parentCaseIdToFeedComment.keySet()
		]) {
			feedCommentIdToCase.put(parentCaseIdToFeedComment.get(caseRec.Id)?.Id, caseRec);
		}

		List<ConnectApi.BatchResult> batchResults = ConnectApi.ChatterFeeds.getCommentBatch(
			null,
			feedCommentIds
		);

		for (ConnectApi.BatchResult batchResult : batchResults) {
			if (batchResult.isSuccess()) {
				Object result = batchResult.getResult();

				if (result instanceof ConnectApi.Comment) {
					ConnectApi.Comment comment = (ConnectApi.Comment) result;
					ConnectApi.CommentInput input = ConnectApiHelper.createCommentInputFromBody(
						comment.body
					);

					modifyFeedItemAndCommentBody(
						null,
						input,
						feedCommentIdToCase.get(comment.Id)?.Account.Name,
						feedCommentIdToCase.get(comment.Id)?.CaseNumber
					);
					ConnectApi.ChatterFeeds.updateComment(null, comment.id, input);
				}
			}
		}
	}

	private static void modifyFeedItemAndCommentBody(
		ConnectApi.FeedItemInput feedItemInput,
		ConnectApi.CommentInput commentInput,
		String accountName,
		String caseNumber
	) {
		ConnectApi.MarkupBeginSegmentInput markupBeginInputParagraph = new ConnectApi.MarkupBeginSegmentInput();
		markupBeginInputParagraph.markupType = ConnectApi.MarkupType.Paragraph;

		ConnectApi.TextSegmentInput textInputSpace = new ConnectApi.TextSegmentInput();
		textInputSpace.text = '\u00A0';

		ConnectApi.MarkupEndSegmentInput markupEndInputParagraph = new ConnectApi.MarkupEndSegmentInput();
		markupEndInputParagraph.markupType = ConnectApi.MarkupType.Paragraph;

		ConnectApi.MarkupBeginSegmentInput markupBeginInputItalic = new ConnectApi.MarkupBeginSegmentInput();
		markupBeginInputItalic.markupType = ConnectApi.MarkupType.Italic;

		ConnectApi.TextSegmentInput textInputFields = new ConnectApi.TextSegmentInput();
		textInputFields.text = accountName + ',' + caseNumber;

		ConnectApi.MarkupEndSegmentInput markupEndInputItalic = new ConnectApi.MarkupEndSegmentInput();
		markupEndInputItalic.markupType = ConnectApi.MarkupType.Italic;

		if (feedItemInput != null) {
			feedItemInput.body.messageSegments.add(markupBeginInputParagraph);
			feedItemInput.body.messageSegments.add(textInputSpace);
			feedItemInput.body.messageSegments.add(markupEndInputParagraph);
			feedItemInput.body.messageSegments.add(markupBeginInputItalic);
			feedItemInput.body.messageSegments.add(textInputFields);
			feedItemInput.body.messageSegments.add(markupEndInputItalic);
		}
		if (commentInput != null) {
			commentInput.body.messageSegments.add(markupBeginInputParagraph);
			commentInput.body.messageSegments.add(textInputSpace);
			commentInput.body.messageSegments.add(markupEndInputParagraph);
			commentInput.body.messageSegments.add(markupBeginInputItalic);
			commentInput.body.messageSegments.add(textInputFields);
			commentInput.body.messageSegments.add(markupEndInputItalic);
		}
	}

	public static Boolean nullOrEmpty(Object obj) {
		return (obj == null) ||
			((obj instanceof String) && (((String) obj).trim().length() == 0)) ||
			((obj instanceof List<Object>) && (((List<Object>) obj).size() == 0)) ||
			((obj instanceof Set<Object>) && (((Set<Object>) obj).size() == 0));
	}

	public static void setAssignedDate(List<Case> cases, Map<Id, Case> oldMap) {
		for (Case newCase : cases) {
			if (newCase.First_Assigned_Date__c == null) {
				if (!nullOrEmpty(newCase.OwnerId)) {
					if (
						!RoscoCaseProcesses.isCMSettingTrue(
							'rosco_case_ownerid__c',
							String.valueOf(newCase.OwnerId)
						)
					) {
						if (!Utility.isQueue(newCase.OwnerId)) {
							newCase.First_Assigned_Date__c = System.now();
						}
					}
				}
			} else {
				if (!nullOrEmpty(newCase.CreatedDate)) {
					Decimal diff =
						newCase.First_Assigned_Date__c.getTime() - newCase.CreatedDate.getTime();
					if (math.abs(diff) < 5000) {
						newCase.First_Assigned_Date__c = newCase.CreatedDate;
					}
				}
			}
		}
	}

	public static void setDeescalationDate(List<Case> cases, Map<Id, Case> oldMap) {
		for (Case newCase : cases) {
			Case oldCase = oldMap.get(newCase.Id);
			if (
				!nullOrEmpty(oldCase) &&
				!nullOrEmpty(oldCase.Escalation_Tier__c) &&
				oldCase.Escalation_Tier__c != LEVEL_ONE
			) {
				if (
					nullOrEmpty(newCase.Escalation_Tier__c) || newCase.Escalation_Tier__c == LEVEL_ONE
				) {
					newCase.DeEscalation_Date__c = System.now();
				}
			}
		}
	}

	public static void processEscalationChange(List<Case> cases, Map<Id, Case> oldMap) {
		for (Case newCase : cases) {
			if (
				oldMap != null &&
				String.isBlank(String.valueOf(newCase.First_EscalationDate__c)) &&
				newCase.Escalation_Tier__c != oldMap?.get(newCase.Id)?.Escalation_Tier__c
			) {
				newCase.First_EscalationDate__c = System.now();
			}
			if (newCase.Escalation_Tier__c == LEVEL_TWO) {
				if (nullOrEmpty(newCase.Escalation_L2_Date__c)) {
					newCase.Escalation_L2_Date__c = System.now();
				} else {
					if (
						oldMap != null &&
						((oldMap.get(newCase.Id).Escalation_Tier__c != newCase.Escalation_Tier__c) ||
						(oldMap.get(newCase.Id).Escalation_Team__c != newCase.Escalation_Team__c))
					) {
						newCase.Escalation_L2_Date__c = System.now();
						newCase.Escalation_L2_SME_Engaged_Date__c = null;
						newCase.Escalation_L2_SLO__c = null;
					}
				}
			}
			if (newCase.Escalation_Tier__c == LEVEL_THREE) {
				if (nullOrEmpty(newCase.Escalation_L3_Date__c)) {
					newCase.Escalation_L3_Date__c = System.now();
				} else {
					if (
						oldMap != null &&
						((oldMap.get(newCase.Id).Escalation_Tier__c != newCase.Escalation_Tier__c) ||
						(oldMap.get(newCase.Id).Escalation_Team__c != newCase.Escalation_Team__c))
					) {
						newCase.Escalation_L3_Date__c = System.now();
						newCase.Escalation_L3_SME_Engaged_Date__c = null;
						newCase.Escalation_L3_SLO__c = null;
					}
				}
			}
			if (newCase.Escalation_Tier__c == LEVEL_FOUR) {
				if (nullOrEmpty(newCase.Escalation_L4_Date__c)) {
					newCase.Escalation_L4_Date__c = System.now();
				} else {
					if (
						oldMap != null &&
						((oldMap.get(newCase.Id).Escalation_Tier__c != newCase.Escalation_Tier__c) ||
						(oldMap.get(newCase.Id).Escalation_Team__c != newCase.Escalation_Team__c))
					) {
						newCase.Escalation_L4_Date__c = System.now();
						newCase.Escalation_L4_SME_Engaged_Date__c = null;
						newCase.Escalation_L4_SLO__c = null;
					}
				}
			}
		}
	}

	public static void setFirstSMEAssignedDate(List<Case> cases, Map<Id, Case> oldMap) {
		for (Case newCase : cases) {
			if (
				nullOrEmpty(newCase.First_SME_Assigned_Date__c) && !nullOrEmpty(newCase.SME_OwnerId__c)
			) {
				newCase.First_SME_Assigned_Date__c = System.now();
			}
		}
	}

	public static void setFirstSolvedDate(List<Case> cases, Map<Id, Case> oldMap) {
		for (Case newCase : cases) {
			if (nullOrEmpty(newCase.First_Solved_Date__c)) {
				if (
					newCase.Status == SOLVED || Constants.CASE_CLOSE_STATUSES.contains(newCase.Status)
				) {
					newCase.First_Solved_Date__c = System.now();
				}
			} else {
				Decimal diff = newCase.First_Solved_Date__c.getTime() - newCase.CreatedDate.getTime();
				if (math.abs(diff) < 30000) {
					newCase.First_Solved_Date__c = newCase.CreatedDate;
				}
			}
		}
	}

	public static void setEscalationSMEOwnerChange(List<Case> cases, Map<Id, Case> oldMap) {
		for (Case newCase : cases) {
			if (newCase.Escalation_Tier__c != LEVEL_ONE) {
				if (!nullOrEmpty(newCase.SME_OwnerId__c)) {
					if (newCase.Escalation_Tier__c == LEVEL_TWO) {
						if (nullOrEmpty(newCase.Escalation_L2_SME_Engaged_Date__c)) {
							newCase.Escalation_L2_SME_Engaged_Date__c = System.now();
						}
					} else if (newCase.Escalation_Tier__c == LEVEL_THREE) {
						if (nullOrEmpty(newCase.Escalation_L3_SME_Engaged_Date__c)) {
							newCase.Escalation_L3_SME_Engaged_Date__c = System.now();
						}
					} else if (newCase.Escalation_Tier__c == LEVEL_FOUR) {
						if (nullOrEmpty(newCase.Escalation_L4_SME_Engaged_Date__c)) {
							newCase.Escalation_L4_SME_Engaged_Date__c = System.now();
						}
					}
				}
			}
		}
	}

	public static void setEscalationLevelWatermark(List<Case> cases, Map<Id, Case> oldMap) {
		Set<String> fiveFourLevels = new Set<String>{ LEVEL_FIVE, LEVEL_FOUR };
		Set<String> fiveFourThreeLevels = new Set<String>{ LEVEL_FIVE, LEVEL_FOUR, LEVEL_THREE };
		Set<String> fiveFourThreeTwoLevels = new Set<String>{
			LEVEL_FIVE,
			LEVEL_FOUR,
			LEVEL_THREE,
			LEVEL_TWO
		};

		for (Case newCase : cases) {
			if (nullOrEmpty(newCase.Escalation_Tier__c)) {
				newCase.Escalation_Tier__c = LEVEL_ONE;
				if (nullOrEmpty(newCase.Escalation_Level_Watermark__c)) {
					newCase.Escalation_Level_Watermark__c = LEVEL_ONE;
				}
			} else {
				if (nullOrEmpty(newCase.Escalation_Level_Watermark__c)) {
					newCase.Escalation_Level_Watermark__c = newCase.Escalation_Tier__c;
				} else {
					if (
						newCase.Escalation_Level_Watermark__c == LEVEL_FOUR &&
						newCase.Escalation_Tier__c == LEVEL_FIVE
					) {
						newCase.Escalation_Level_Watermark__c = newCase.Escalation_Tier__c;
					} else if (
						newCase.Escalation_Level_Watermark__c == LEVEL_THREE &&
						fiveFourLevels.contains(newCase.Escalation_Tier__c)
					) {
						newCase.Escalation_Level_Watermark__c = newCase.Escalation_Tier__c;
					} else if (
						newCase.Escalation_Level_Watermark__c == LEVEL_TWO &&
						fiveFourThreeLevels.contains(newCase.Escalation_Tier__c)
					) {
						newCase.Escalation_Level_Watermark__c = newCase.Escalation_Tier__c;
					} else if (
						newCase.Escalation_Level_Watermark__c == LEVEL_ONE &&
						fiveFourThreeTwoLevels.contains(newCase.Escalation_Tier__c)
					) {
						newCase.Escalation_Level_Watermark__c = newCase.Escalation_Tier__c;
					}
				}
			}
		}
	}

	public static Boolean isSloStatusWip(String sloStatus) {
		Set<String> wipStatuses = new Set<String>{ 'Waiting', 'Warning' };
		return wipStatuses.contains(sloStatus);
	}

	public static void setEscalationSLO(List<Case> cases, Map<Id, Case> oldMap) {
		for (Case newCase : cases) {
			if (oldMap != null) {
				Case oldCase = oldMap.get(newCase.Id);
				if (
					(oldCase.Escalation_Tier__c != newCase.Escalation_Tier__c) ||
					(oldCase.Escalation_Team__c != newCase.Escalation_Team__c)
				) {
					if (isSloStatusWip(newCase.Escalation_L2_SLO__c)) {
						newCase.Escalation_L2_SLO__c = CANCELED;
					}
					if (isSloStatusWip(newCase.Escalation_L3_SLO__c)) {
						newCase.Escalation_L3_SLO__c = CANCELED;
					}
					if (isSloStatusWip(newCase.Escalation_L4_SLO__c)) {
						newCase.Escalation_L4_SLO__c = CANCELED;
					}
					if (isSloStatusWip(newCase.Escalation_L5_SLO__c)) {
						newCase.Escalation_L5_SLO__c = CANCELED;
					}
					RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
				}
			}

			if (newCase.Escalation_Tier__c == LEVEL_TWO) {
				if (
					isSloStatusWip(newCase.Escalation_L2_SLO__c) ||
					nullOrEmpty(newCase.Escalation_L2_SLO__c)
				) {
					if (!nullOrEmpty(newCase.Escalation_L2_SME_Engaged_Date__c)) {
						newCase.Escalation_L2_SLO__c = PASS;
						RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
					} else {
						Map<String, String> state = RoscoCaseProcesses.getCaseSloStatus(
							null,
							newCase.Support_Model__c,
							newCase.Escalation_Team__c,
							newCase.Escalation_Tier__c,
							Decimal.valueOf(newCase.Severity_Community__c),
							newCase.Escalation_L2_Date__c,
							newCase.RecordTypeId
						);

						newCase.Escalation_L2_SLO__c = state.get('escalationSLOStatus');
						RoscoCaseProcesses.manageEscalationAlertJobs(null, newCase);
						if (isSloStatusWip(newCase.Escalation_L3_SLO__c)) {
							newCase.Escalation_L3_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}
						if (isSloStatusWip(newCase.Escalation_L4_SLO__c)) {
							newCase.Escalation_L4_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}
						if (isSloStatusWip(newCase.Escalation_L5_SLO__c)) {
							newCase.Escalation_L5_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}
					}
				}
			} else if (newCase.Escalation_Tier__c == LEVEL_THREE) {
				if (
					isSloStatusWip(newCase.Escalation_L3_SLO__c) ||
					nullOrEmpty(newCase.Escalation_L3_SLO__c)
				) {
					if (!nullOrEmpty(newCase.Escalation_L3_SME_Engaged_Date__c)) {
						newCase.Escalation_L3_SLO__c = PASS;
					} else {
						Map<String, String> state = RoscoCaseProcesses.getCaseSloStatus(
							null,
							newCase.Support_Model__c,
							newCase.Escalation_Team__c,
							newCase.Escalation_Tier__c,
							Decimal.valueOf(newCase.Severity_Community__c),
							newCase.Escalation_L3_Date__c,
							newCase.RecordTypeId
						);
						newCase.Escalation_L3_SLO__c = state.get('escalationSLOStatus');
						RoscoCaseProcesses.manageEscalationAlertJobs(null, newCase);
						if (isSloStatusWip(newCase.Escalation_L2_SLO__c)) {
							newCase.Escalation_L2_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}
						if (isSloStatusWip(newCase.Escalation_L4_SLO__c)) {
							newCase.Escalation_L4_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}
						if (isSloStatusWip(newCase.Escalation_L5_SLO__c)) {
							newCase.Escalation_L5_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}
					}
				}
			} else if (newCase.Escalation_Tier__c == LEVEL_FOUR) {
				if (
					isSloStatusWip(newCase.Escalation_L4_SLO__c) ||
					nullOrEmpty(newCase.Escalation_L4_SLO__c)
				) {
					if (!nullOrEmpty(newCase.Escalation_L4_SME_Engaged_Date__c)) {
						newCase.Escalation_L4_SLO__c = PASS;
					} else {
						Map<String, String> state = RoscoCaseProcesses.getCaseSloStatus(
							null,
							newCase.Support_Model__c,
							newCase.Escalation_Team__c,
							newCase.Escalation_Tier__c,
							Decimal.valueOf(newCase.Severity_Community__c),
							newCase.Escalation_L4_Date__c,
							newCase.RecordTypeId
						);
						newCase.Escalation_L4_SLO__c = state.get('escalationSLOStatus');
						RoscoCaseProcesses.manageEscalationAlertJobs(null, newCase);
						if (isSloStatusWip(newCase.Escalation_L2_SLO__c)) {
							newCase.Escalation_L2_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}
						if (isSloStatusWip(newCase.Escalation_L3_SLO__c)) {
							newCase.Escalation_L3_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}

						if (isSloStatusWip(newCase.Escalation_L5_SLO__c)) {
							newCase.Escalation_L5_SLO__c = CANCELED;
							RoscoCaseProcesses.manageEscalationAlertJobsDelete(newCase.Id);
						}
					}
				}
			}
		}
	}

	public static void setLastCustomerResponseDate(List<Case> cases) {
		for (Case newCase : cases) {
			if (!RoscoCaseProcesses.isAgent(UserInfo.getUserId())) {
				newCase.Last_Customer_Response_Date__c = System.now();
			}
		}
	}

	public static void processNewCmtyQuestion(FeedItem feedItem) {
		try {
			if (
				feedItem != null &&
				feedItem.NetworkScope != null &&
				feedItem.NetworkScope == Constants.TANIUM_CUSTOMER_COMMUNITY_ID
			) {
				String title = 'Title is blank';
				if (!String.isBlank(feedItem.Title)) {
					title = String.valueOf(feedItem.Title);
					if (title.length() > 200) {
						title = title.substring(0, 200);
					}
				}

				String body = 'Body is blank';
				if (!String.isBlank(feedItem.Body)) {
					body = String.valueOf(feedItem.Body).stripHtmlTags();
					if (body.length() > 2000) {
						body =
							body.substring(0, 2000) +
							'\n<truncated - please view post online (respond button) to see full message>';
					}
				}

				String reponseButtonTxt = 'Respond';
				String slackText = '';
				if (feedItem?.ParentId?.getSObjectType() == Case.SObjectType) {
					slackText += '*New Community question [' + feedItem.Id + ']';
				} else {
					slackText += '*New Group question [' + feedItem.Id + ']';
					reponseButtonTxt = 'Respond to Group';
				}
				slackText += ' posted by ' + UserInfo.getUserName() + '*';
				slackText += ' ```' + title + '```';
				slackText += ' ```' + body + '```';
				slackText +=
					' <https://tanium.lightning.force.com/servlet/networks/switch?networkId=0DB0e000000Caez&startURL=s/question/' +
					feedItem.Id +
					' | ' +
					reponseButtonTxt +
					'>';
				slackText +=
					'    <https://community.tanium.com/s/question/' +
					feedItem.Id +
					'|Alt Open>';

				if (
					feedItem.Type == 'QuestionPost' ||
					String.valueOf(feedItem.ParentId).left(3) != '005'
				) {
					RoscoCmtyProcesses.slackCommunity(slackText, feedItem.ParentId);
				}
			}
		} catch (Exception e) {
			Logger.error('FeedItemTriggerUtility.processNewCmtyQuestion ERRORS :', e);
			Logger.saveLog();
		}
	}

	public static void handleCaseOwnerChange(List<Case> cases, Map<Id, Case> oldMap) {
		Map<Id, Id> caseIdToUserId = new Map<Id, Id>();
		for (Case cs : cases) {
			if (
				cs.OwnerId != null &&
				Utility.isUser(cs.OwnerId) &&
				cs.OwnerId != Constants.SERVICE_CLOUD_TANIUM_USER_ID &&
				cs.IsClosed == false &&
				(oldMap == null || (cs.OwnerId != oldMap.get(cs.Id).OwnerId))
			) {
				caseIdToUserId.put(cs.Id, cs.OwnerId);
			}
		}
		handleCaseOwnerChange(cases, caseIdToUserId);
	}

	private static void handleCaseOwnerChange(List<Case> cases, Map<Id, Id> caseIdToUserId) {
		Map<Id, String> userIdToUserEmail = new Map<Id, String>();
		for (User u : [SELECT Id, Email FROM User WHERE Id IN :caseIdToUserId.values()]) {
			userIdToUserEmail.put(u.Id, u.Email);
		}

		Map<String, Id> contactEmailToContactId = new Map<String, Id>();
		for (Contact con : [
			SELECT Id, Email
			FROM Contact
			WHERE Email IN :userIdToUserEmail.values()
			ORDER BY CreatedDate ASC
		]) {
			contactEmailToContactId.put(con.Email, con.Id);
		}

		Map<Id, Id> existingContactIdToCaseId = new Map<Id, Id>();
		for (CaseContactRole caseContactRole : [
			SELECT Id, CasesId, ContactId
			FROM CaseContactRole
			WHERE
				CasesId IN :caseIdToUserId.keyset()
				AND ContactId IN :contactEmailToContactId.values()
		]) {
			existingContactIdToCaseId.put(caseContactRole.ContactId, caseContactRole.CasesId);
		}

		Id contactId;
		CaseContactRole caseContactRole;
		List<CaseContactRole> caseContactRolesToInsert = new List<CaseContactRole>();
		for (Case cs : cases) {
			contactId = contactEmailToContactId?.get(userIdToUserEmail?.get(cs.OwnerId));
			if (contactId != null && existingContactIdToCaseId.get(contactId) != cs.Id) {
				caseContactRole = new CaseContactRole();
				caseContactRole.CasesId = cs.Id;
				caseContactRole.ContactId = contactId;
				caseContactRolesToInsert.add(caseContactRole);
			}
		}

		List<Database.SaveResult> saveResults = Database.insert(caseContactRolesToInsert, false);
		Logger.logDatabaseErrors(
			LoggingLevel.ERROR,
			'CaseTriggerUtilityWithoutSharing.handleCaseOwnerChange ERRORS',
			saveResults
		);
	}

	private static String getContentTitle(Id relatedRecordId) {
		return [SELECT Id, Title FROM ContentVersion WHERE Id = :relatedRecordId].Title;
	}
}