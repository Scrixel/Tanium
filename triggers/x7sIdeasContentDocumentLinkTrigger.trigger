/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

trigger x7sIdeasContentDocumentLinkTrigger on ContentDocumentLink (before insert) {

	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			x7sIdeasContentDocumentLinkHelper.onBeforeInsert(Trigger.new);
		}
	}
}