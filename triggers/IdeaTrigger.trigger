/*
 * @Business: Trigger on Idea Object
 * @Date: 2025-01-04
 * @Author: Tanium Dev Team
 * @Request: SS-9781
 * Modified  ModifiedDate  Description
 * SS-9781   2025-01-04    Created the trigger
 */
trigger IdeaTrigger on Idea(after insert) {
	new IdeaTriggerHandler().run();
}