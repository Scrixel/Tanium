/**
 *  Copyright (c) 2026 Tanium
 *
 * @Business: Controller class that supports Lead Conversion functionality
 * @Date:     2026-02-12
 * @Author:   Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12490   2026-02-12    Created the class
 * SS-12490   2026-02-19    Migrated CustomLeadConvertExtension to LeadConvertController
 */
public with sharing class LeadConvertController {
	private static final String CONVERTED_STATUS_LABEL = 'Converted Status';

	@AuraEnabled
	public static Lead getLead(Id leadId) {
		return [SELECT Id, Name, OwnerId, Email, Status, Company FROM Lead WHERE Id = :leadId];
	}

	@AuraEnabled(cacheable=true)
	public static List<String> getConvertedLeadStatusOptions() {
		List<String> options = new List<String>();
		for (LeadStatus status : [
			SELECT MasterLabel
			FROM LeadStatus
			WHERE IsConverted = TRUE
			ORDER BY SortOrder
		]) {
			options.add(status.MasterLabel);
		}
		return options;
	}

	@AuraEnabled
	public static EnhancedReturnType convertLead(String leadJsonStr, String taskJsonStr) {
		if (String.isBlank(leadJsonStr) || String.isBlank(taskJsonStr)) {
			return new EnhancedReturnType(
				false,
				System.Label.Lead_Convert_Invalid_Request_Error_Message
			);
		}
		LeadInfo leadInfo = (LeadInfo) JSON.deserialize(leadJsonStr, LeadInfo.class);
		TaskInfo taskInfo = (TaskInfo) JSON.deserialize(taskJsonStr, TaskInfo.class);

		EnhancedReturnType validationResult = validateConvertRequest(leadInfo, taskInfo);
		if (!validationResult.retResult) {
			return validationResult;
		}

		Database.LeadConvert leadConvert = new Database.LeadConvert();
		leadConvert.setLeadId(leadInfo.leadId);
		leadConvert.setAccountId(leadInfo.accountId);
		if (leadInfo.contactId != null) {
			leadConvert.setContactId(leadInfo.contactId);
		}
		leadConvert.setConvertedStatus(leadInfo.convertedStatus);
		leadConvert.setDoNotCreateOpportunity(leadInfo.doNotCreateOpportunity);
		if (!leadInfo.doNotCreateOpportunity && String.isNotBlank(leadInfo.opportunityName)) {
			leadConvert.setOpportunityName(leadInfo.opportunityName);
		}
		leadConvert.setOwnerId(leadInfo.ownerId);
		leadConvert.setSendNotificationEmail(leadInfo.sendEmailToOwner == true);

		SavePoint savePoint = Database.setSavePoint();
		Database.LeadConvertResult leadConvertResult = Database.convertLead(leadConvert, false);
		if (leadConvertResult.isSuccess()) {
			insertTaskRecord(
				leadInfo.ownerId,
				taskInfo,
				leadConvertResult.getContactId(),
				leadConvertResult.getOpportunityId()
			);
			return new EnhancedReturnType(true, leadConvertResult.getAccountId());
		} else {
			String errorMsg = leadConvertResult.getErrors().isEmpty()
				? System.Label.Lead_Convert_Lead_Conversion_Failed_Error_Message
				: leadConvertResult.getErrors()[0].getMessage();
			Database.rollback(savePoint);
			return new EnhancedReturnType(false, errorMsg);
		}
	}

	@TestVisible
	private static EnhancedReturnType validateConvertRequest(LeadInfo leadInfo, TaskInfo taskInfo) {
		List<String> labels = getRequiredValidationFieldLabels();
		List<String> values = new List<String>{
			leadInfo.leadId != null ? String.valueOf(leadInfo.leadId) : '',
			leadInfo.accountId != null ? String.valueOf(leadInfo.accountId) : '',
			leadInfo.ownerId != null ? String.valueOf(leadInfo.ownerId) : '',
			leadInfo.convertedStatus,
			taskInfo.taskType,
			taskInfo.taskStatus,
			taskInfo.taskSubject,
			taskInfo.taskPriority
		};
		String requiredFieldsError = buildRequiredFieldsError(labels, values);
		if (requiredFieldsError != null) {
			return new EnhancedReturnType(false, requiredFieldsError);
		}
		List<Lead> leads = [SELECT IsConverted FROM Lead WHERE Id = :leadInfo.leadId LIMIT 1];
		if (!leads.isEmpty() && leads[0].IsConverted) {
			return new EnhancedReturnType(
				false,
				System.Label.Lead_Convert_Lead_Already_Converted_Error_Message
			);
		}
		return new EnhancedReturnType(true);
	}

	@TestVisible
	private static List<String> getRequiredValidationFieldLabels() {
		List<String> labels = new List<String>();
		labels.add(Lead.SObjectType.getDescribe().getLabel());
		labels.add(Account.SObjectType.getDescribe().getLabel());
		labels.add(getFieldLabel(Lead.SObjectType, 'OwnerId'));
		labels.add(CONVERTED_STATUS_LABEL);
		labels.add(getFieldLabel(Task.SObjectType, 'Type'));
		labels.add(getFieldLabel(Task.SObjectType, 'Status'));
		labels.add(getFieldLabel(Task.SObjectType, 'Subject'));
		labels.add(getFieldLabel(Task.SObjectType, 'Priority'));
		return labels;
	}

	@TestVisible
	private static String getFieldLabel(Schema.SObjectType sobjectType, String fieldApiName) {
		return sobjectType
			?.getDescribe()
			?.fields
			?.getMap()
			?.get(fieldApiName)
			?.getDescribe()
			?.getLabel() ?? fieldApiName;
	}

	@TestVisible
	private static String buildRequiredFieldsError(List<String> labels, List<String> values) {
		List<String> missingFields = new List<String>();
		for (Integer i = 0; i < values.size(); i++) {
			if (String.isBlank(values[i])) {
				missingFields.add(labels[i]);
			}
		}
		return missingFields.isEmpty()
			? null
			: System.Label.Lead_Convert_Required_Fields_Error_Message_Prefix +
			  String.join(missingFields, ', ');
	}

	@TestVisible
	private static void insertTaskRecord(Id ownerId, TaskInfo taskInfo, Id contactId, Id oppId) {
		Task task = new Task();
		task.OwnerId = ownerId;
		task.WhoId = contactId;
		task.WhatId = oppId;
		task.Subject = taskInfo.taskSubject;
		task.Type = taskInfo.taskType;
		task.Status = taskInfo.taskStatus;
		task.Description = taskInfo.taskDescription;
		task.Priority = taskInfo.taskPriority;
		task.Team__c = taskInfo.taskTeam;

		if (String.isNotBlank(taskInfo.taskMeetingDateStr)) {
			task.Meeting_Date__c = Date.valueOf(taskInfo.taskMeetingDateStr);
		}
		if (String.isNotBlank(taskInfo.taskActivityDateStr)) {
			task.ActivityDate = Date.valueOf(taskInfo.taskActivityDateStr);
		} else {
			task.ActivityDate = Date.today();
		}

		if (taskInfo.isReminderSet) {
			DateTime reminderDateTime = parseReminderDateTime(
				taskInfo.reminderDateStr,
				taskInfo.reminderTimeStr
			);
			if (reminderDateTime != null) {
				task.ReminderDateTime = reminderDateTime;
			}
		}

		List<Database.SaveResult> saveResults = Database.insert(new List<Task>{ task }, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'LeadConvertController.insertTaskRecord ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	@TestVisible
	private static DateTime parseReminderDateTime(String dateString, String timeString) {
		if (String.isBlank(dateString) || String.isBlank(timeString)) {
			return null;
		}
		String timeNormalized = timeString.trim();
		if (timeNormalized.length() == 5) {
			timeNormalized += ':00';
		}
		String combined = dateString.trim() + ' ' + timeNormalized;
		try {
			return DateTime.valueOf(combined);
		} catch (TypeException e) {
			return null;
		}
	}

	public class LeadInfo {
		public Id leadId;
		public Id accountId;
		public Id ownerId;
		public Boolean sendEmailToOwner;
		public Boolean doNotCreateOpportunity;
		public String opportunityName;
		public String convertedStatus;
		public Id contactId;
	}

	public class TaskInfo {
		public String taskSubject;
		public String taskType;
		public String taskActivityDateStr;
		public String taskMeetingDateStr;
		public String taskStatus;
		public String taskDescription;
		public String taskPriority;
		public String taskTeam;
		public Boolean isReminderSet;
		public String reminderDateStr;
		public String reminderTimeStr;
	}
}