/**
 * @Business: ContentDocumentLink Trigger
 * @Date: 2025-10-28
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-6810    2024-01-15	Created the trigger
 * SS-11875   2025-10-28    Updated header documentation
 */
trigger ContentDocumentLinkTrigger on ContentDocumentLink(after insert) {
	new ContentDocumentLinkTriggerHandler().run();
}