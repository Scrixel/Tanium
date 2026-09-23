/**
 * Copyright (c) 2026, Tanium, Inc.
 *
 * @Business: Trigger Handler class on QuoteRequest_Products__c object
 * @Date: 03/30/2026
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12876   2026-03-30    Created the class
 */
public without sharing class QuoteRequestProductTriggerHandler extends TriggerHandler {
	private List<Quote_Request_Products__c> quoteRequestProducts;
	private Map<Id, Quote_Request_Products__c> oldMap;

	public QuoteRequestProductTriggerHandler() {
		super('QuoteRequestProductTriggerHandler');
		this.quoteRequestProducts = (List<Quote_Request_Products__c>) Trigger.new;
		this.oldMap = (Map<Id, Quote_Request_Products__c>) Trigger.oldMap;
	}

	public override void afterInsert() {
		QuoteRequestTriggerUtility.processQuoteRequestProducts(quoteRequestProducts);
	}
}