/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Scheduled email to Deal Desk Approvers about their open Opportunities of the current fiscal quarter
 * @Description: Sends the DealDeskApprover_Opporunities_CurrentFQ template to every User referenced by
 * Opportunity.Deal_Desk_Approver__c that has Opportunities closing this fiscal quarter with Commit or Upside,
 * excluding Signed, Closed, Committed, Failed, pre-commit Renewal and Order Drafted stages
 * @Date: 2016-04-07
 * @Author: Mahesh G
 * RequestId  ModifiedDate  Description
 * TAN-483    2018-02-22    Updated StageName
 * SS-13636   2026-09-11    Excluded pre-commit Renewal and Order Drafted stages
 */
public class ScheduleOppDealDeskApproverNotification implements Schedulable {
	public void execute(SchedulableContext sc) {
		sendDealDeskApproverNotification();
	}

	public void sendDealDeskApproverNotification() {
		try {
			AggregateResult[] aggResults = [
				SELECT Deal_Desk_Approver__c dealDeskApproverId
				FROM Opportunity
				WHERE
					Deal_Desk_Approver__c != NULL
					AND CloseDate = THIS_FISCAL_QUARTER
					AND (NOT StageName LIKE 'Signed%')
					AND (NOT StageName LIKE 'CLOSED%')
					AND (NOT StageName LIKE 'Committed%')
					AND StageName != 'Failed'
					AND StageName != :Utility.ACCOUNT_ASSESSMENT
					AND StageName != :Utility.CUSTOMER_ENGAGED
					AND StageName != :Utility.PROPOSAL_SENT
					AND StageName != :Utility.COMMIT_STAGE
					AND StageName != :Utility.ORDER_DRAFTED
					AND (Commit__c > 0
					OR Upside__c > 0)
				GROUP BY Deal_Desk_Approver__c
			];
			List<Id> listUserIds = new List<Id>();
			for (AggregateResult aggResult : aggResults) {
				listUserIds.add((Id) aggResult.get('dealDeskApproverId'));
			}
			Integer BATCH_SIZE = 100;
			Integer totalBatches = listUserIds.size() / BATCH_SIZE;
			totalBatches += Math.mod(listUserIds.size(), BATCH_SIZE) > 0 ? 1 : 0;

			Id ddaEmailTemplateId = [
				SELECT Id
				FROM EmailTemplate
				WHERE DeveloperName = 'DealDeskApprover_Opporunities_CurrentFQ'
				LIMIT 1
			]
			.Id;
			List<OrgWideEmailAddress> listOrgWideEmails = [
				SELECT Id
				FROM OrgWideEmailAddress
				WHERE DisplayName = 'Tanium - No Reply'
				LIMIT 1
			];
			Id noReplyEmailAddress = listOrgWideEmails.isEmpty() ? null : listOrgWideEmails[0].Id;

			for (Integer batchNumber = 0; batchNumber < totalBatches; batchNumber++) {
				List<Messaging.SingleEmailMessage> listSingleEmailMSG = new List<Messaging.SingleEmailMessage>();
				Integer startIndex = batchNumber * BATCH_SIZE;
				Integer endIndex = startIndex + BATCH_SIZE;
				endIndex = endIndex > listUserIds.size() ? listUserIds.size() : endIndex;

				for (Integer index = startIndex; index < endIndex; index++) {
					Messaging.SingleEmailMessage message = buildSingleEmailMessage(
						ddaEmailTemplateId,
						listUserIds[index],
						listUserIds[index],
						false,
						noReplyEmailAddress
					);
					listSingleEmailMSG.add(message);
				}
				Messaging.SendEmailResult[] listEmailSendResults = Messaging.sendEmail(
					listSingleEmailMSG
				);
				for (Messaging.SendEmailResult emailResult : listEmailSendResults) {
					System.debug(
						'\n Success:' +
							emailResult.success +
							'\n Error:' +
							JSON.serialize(emailResult.getErrors())
					);
				}
			}
		} catch (Exception ex) {
			System.debug(
				'ScheduleOppDealDeskApproverNotification Error:' +
					ex.getMessage() +
					'\nStack Trace:' +
					ex.getStackTraceString()
			);
		}
	}

	public Messaging.SingleEmailMessage buildSingleEmailMessage(
		Id templateId,
		Id targetObjectId,
		Id whatId,
		Boolean hasToSaveActivity,
		Id orgWideEmailAdressId
	) {
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
		message.setTemplateId(templateId);
		message.setTargetObjectId(targetObjectId);
		message.setWhatId(whatId);
		message.SaveAsActivity = hasToSaveActivity;
		message.setOrgWideEmailAddressId(orgWideEmailAdressId);
		message.setBCCAddresses(new List<String>{ 'tanium@cumulusvision.com' });

		return message;
	}
}