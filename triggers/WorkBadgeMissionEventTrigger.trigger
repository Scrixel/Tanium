/**
 * @Business: Platform event (subscription) trigger on WorkBadgeMissionEvent__e
 * @Date: 2024-12-09
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-8303    2024-12-09    Created the trigger
 */
trigger WorkBadgeMissionEventTrigger on WorkBadgeMissionEvent__e(after insert) {
	WorkBadgeMissionTriggerUtility.processEvent(Trigger.new);
}