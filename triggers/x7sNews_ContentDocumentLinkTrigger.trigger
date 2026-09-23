/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

trigger x7sNews_ContentDocumentLinkTrigger on ContentDocumentLink (before insert) {
	if (Trigger.isBefore && Trigger.isInsert) {
		x7sNewsDocumentLinkHelper.onBeforeInsert(Trigger.new);
	}
}