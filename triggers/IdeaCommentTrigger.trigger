/*
 * @Business: Trigger on IdeaComment Object
 * @Date: 2025-01-04
 * @Author: Tanium Dev Team
 * @Request: SS-9781
 * Modified  ModifiedDate  Description
 * SS-9781   2025-01-04    Created the trigger
 */
trigger IdeaCommentTrigger on IdeaComment(after insert) {
	new IdeaCommentTriggerHandler().run();
}