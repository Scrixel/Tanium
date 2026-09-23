/**
 * @Business: ContentDocumentLink TriggerHandler
 * @Date: 2025-10-28
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-6810    2024-01-15	Created the class
 * SS-11875   2025-10-28    Added call to method notifyCaseOwnerOnFileUpload
 */
public with sharing class ContentDocumentLinkTriggerHandler extends TriggerHandler {
	private List<ContentDocumentLink> contentDocumentLinks;
	private Map<Id, ContentDocumentLink> oldMap;

	public ContentDocumentLinkTriggerHandler() {
		super('ContentDocumentLinkTriggerHandler');
		contentDocumentLinks = (List<ContentDocumentLink>) Trigger.new;
		oldMap = (Map<Id, ContentDocumentLink>) Trigger.oldMap;
	}

	public override void afterInsert() {
		ContentDocumentLinkTriggerUtility.setKlarityDateOnOpportunity(contentDocumentLinks);
		ContentDocumentLinkTriggerUtility.notifyCaseOwnerOnFileUpload(contentDocumentLinks);
	}
}