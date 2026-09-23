/*
 * @Business: Event Trigger on QuoteRequestEvent__e Platform Event
 * @Date: 07/24/2025
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11140   2025-07-24    Created the Event Trigger
 */
trigger QuoteRequestEventTrigger on QuoteRequest_Event__e(after insert) {
	QuoteRequestTriggerUtility.processQuoteRequestEvent(Trigger.new);
}