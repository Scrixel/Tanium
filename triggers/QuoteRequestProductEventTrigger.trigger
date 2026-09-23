/*
 * @Business: Event Trigger on QuoteRequest_Product_Event__e Platform Event
 * @Date: 07/24/2025
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11140   2025-07-24    Created the Event Trigger
 */
trigger QuoteRequestProductEventTrigger on QuoteRequest_Product_Event__e(after insert) {
	QuoteRequestTriggerUtility.processQuoteRequestProductEvent(Trigger.new);
}