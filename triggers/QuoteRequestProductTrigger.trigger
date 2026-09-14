/*
 * Copyright (c) 2026, Tanium, Inc.
 *
 * @Business: Trigger on QuoteRequest_Product___c Object
 * @Date: 03/27/2026
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12876   2026-03-30    Created the Trigger
 */
trigger QuoteRequestProductTrigger on Quote_Request_Products__c(after insert) {
	new QuoteRequestProductTriggerHandler().run();
}