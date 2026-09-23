/**
 * @Business: Attachment Trigger Handling
 * @Date: 2016-03-23
 * @Author: Cumulus Vision
 * @Request: TAN-107
 * Modified  ModifiedDate   Description
 * TAN-728   2018-12-13     added Attachment Summary for Budget Records.
 * TAN-1051  2020-12-21     retire win report handling from Attachment.
 */
public class AttachmentTriggerHandler extends TriggerHandler {
	public AttachmentTriggerHandler() {
		super('AttachmentTriggerHandler');
	}

	public override void afterInsert() {
		recalculateBudgetLinks((List<Attachment>) Trigger.New);
	}
	public override void afterDelete() {
		recalculateBudgetLinks((List<Attachment>) Trigger.Old);
	}
	public override void afterUndelete() {
		recalculateBudgetLinks((List<Attachment>) Trigger.New);
	}

	private void recalculateBudgetLinks(List<Attachment> lstAttachment) {
		Set<Id> lstBudgetsIds = new Set<Id>();
		String keyPrefix = Budget__c.SObjectType.getDescribe().getKeyPrefix();
		for (Attachment a : lstAttachment) {
			if (String.valueOf(a.ParentId).startsWith(keyPrefix)) {
				lstBudgetsIds.add(a.ParentId);
			}
		}

		List<Budget__c> budgetsForRecalculating = [
			SELECT
				Id,
				Attachment_Summary__c,
				Attachment_Summary_Rich__c,
				(SELECT Id, Name FROM Attachments)
			FROM Budget__c
			WHERE Id IN :lstBudgetsIds
		];
		Site site = [
			SELECT GuestUserId, Name, Subdomain, UrlPathPrefix
			FROM Site
			WHERE Name = :'Budget_Attachments'
		];
		Organization org = [SELECT InstanceName, IsSandbox, OrganizationType FROM Organization];
		String siteFullUrl = 'https://tanium.secure.force.com/budatt';
		for (Budget__c eachBudget : budgetsForRecalculating) {
			if (eachBudget.Attachments.size() > 0) {
				eachBudget.Attachment_Summary__c = '';
				eachBudget.Attachment_Summary_Rich__c = '';
				for (Attachment att : eachBudget.Attachments) {
					eachBudget.Attachment_Summary__c +=
						'- ' +
						siteFullUrl +
						'/servlet/servlet.FileDownload?file=' +
						att.Id +
						'\n';
					eachBudget.Attachment_Summary_Rich__c +=
						'<a href="' +
						siteFullUrl +
						'/servlet/servlet.FileDownload?file=' +
						att.Id +
						'" target="_blank"> - ' +
						att.Name +
						'</a><br/>';
				}
			} else {
				eachBudget.Attachment_Summary__c = null;
				eachBudget.Attachment_Summary_Rich__c = null;
			}
		}
		update budgetsForRecalculating;
	}
}