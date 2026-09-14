/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

trigger x7sIdeasCommentTrigger on IdeaComment (after insert) {
	Set<Id> ideaCommentIds = new Set<Id>();

	for (IdeaComment newComment : Trigger.new) {
		ideaCommentIds.add(newComment.Id);
	}

	x7sIdeasNotifications.ideaNewComment(ideaCommentIds);
}