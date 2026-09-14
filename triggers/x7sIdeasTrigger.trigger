/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

trigger x7sIdeasTrigger on Idea (before update, after update, after insert) {
	if (Trigger.isBefore) {
		if (Trigger.isUpdate) {
			x7sIdeasTriggerHelper.addStatusCommentOnStatusUpdate(Trigger.new, Trigger.oldMap);
		}
	}
	else {
		if (Trigger.isInsert) {
			x7sIdeasTriggerHelper.createIdeaExtensionRecord(Trigger.new);
		}

		if (Trigger.isUpdate) {
			x7sIdeasTriggerHelper.createExtensionWhenStatusPending(Trigger.new);

			Set<Id> updatedIdeas = new Set<Id>();

			for (Idea item : Trigger.new) {
				if (item.Status != Trigger.oldMap.get(item.Id).Status) {
					updatedIdeas.add(item.Id);
				}
			}

			x7sIdeasNotifications.ideaStatusChange(updatedIdeas);
		}
	}
}