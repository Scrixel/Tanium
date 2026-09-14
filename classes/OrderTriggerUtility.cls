/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: TriggerUtility on Order object
 * @Date: 2023-08-04
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7566    2024-03-01    Updated method publishOrders adding a new platform event field Opportunity_SubType__c
 * SS-7583    2024-03-21    Removing BoomiRestService code references
 * SS-9244    2024-09-22    Removed Nebula logging on successful transactions
 * SS-12400   2026-01-22    Removed CAM_Name__c field from class
 * SS-13646   2026-08-11    Added publishNueOrderEvents to publish ELV_Order_Event__e
 */
public with sharing class OrderTriggerUtility {
	public static void publishOrders(List<Order> orders) {
		List<Order_Event__e> orderEvents = new List<Order_Event__e>();
		Order_Event__e orderEvent;
		Set<Id> accountIds = new Set<Id>();
		Set<Id> oppIds = new Set<Id>();
		Set<Id> quoteIds = new Set<Id>();
		List<Integration_Callout__c> callouts = new List<Integration_Callout__c>();
		List<Order> eOrders = new List<Order>();

		for (Order order : orders) {
			if (
				order.AccountId != null &&
				order.OpportunityId != null &&
				order.SBQQ__Quote__c != null
			) {
				eOrders.add(order);
				accountIds.add(order.AccountId);
				oppIds.add(order.OpportunityId);
				quoteIds.add(order.SBQQ__Quote__c);
			}
		}

		Map<Id, Account> accountsMap = new Map<Id, Account>(
			[SELECT Id, Name, Netsuite_ID__c, Segment__c FROM Account WHERE Id IN :accountIds]
		);
		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(
			[
				SELECT Id, Description, CloseDate, Owner.Name, Type, Subtype__c, PO_Number__c
				FROM Opportunity
				WHERE Id IN :oppIds
			]
		);
		Map<Id, SBQQ__Quote__c> quotesMap = new Map<Id, SBQQ__Quote__c>(
			[
				SELECT
					Id,
					Name,
					Bill_To_Address_2__c,
					SBQQ__BillingCity__c,
					SBQQ__BillingCountry__c,
					SBQQ__BillingName__c,
					SBQQ__BillingPostalCode__c,
					SBQQ__BillingState__c,
					SBQQ__BillingStreet__c,
					SBQQ__PaymentTerms__c,
					PaymentTypeNew__c,
					Bill_To_Attn__c,
					Max_Computed_Term__c,
					Max_End_Date__c,
					Min_Start_Date__c,
					SBQQ__Partner__r.Netsuite_ID__c,
					SBQQ__PricebookId__c,
					SBQQ__ShippingCity__c,
					SBQQ__ShippingCountry__c,
					SBQQ__ShippingName__c,
					SBQQ__ShippingPostalCode__c,
					SBQQ__ShippingState__c,
					SBQQ__ShippingStreet__c,
					Ship_To_Address_2__c,
					Ship_To_Attn__c,
					End_User_Account_Display__c
				FROM SBQQ__Quote__c
				WHERE Id IN :quoteIds
			]
		);

		for (Order eOrder : eOrders) {
			orderEvent = new Order_Event__e();
			orderEvent.Account_Name__c = accountsMap.get(eOrder.AccountId).Name;
			orderEvent.Account_Netsuite_ID__c = accountsMap.get(eOrder.AccountId).Netsuite_ID__c;
			orderEvent.Account_Segment__c = accountsMap.get(eOrder.AccountId).Segment__c;
			orderEvent.Opportunity_CloseDate__c = oppsMap.get(eOrder.OpportunityId).CloseDate;
			orderEvent.Opportunity_ID__c = oppsMap.get(eOrder.OpportunityId).Id;
			orderEvent.Opportunity_Type__c = oppsMap.get(eOrder.OpportunityId).Type;
			orderEvent.Opportunity_Subtype__c = oppsMap.get(eOrder.OpportunityId).Subtype__c;
			orderEvent.Opportunity_Owner_Name__c = oppsMap.get(eOrder.OpportunityId).Owner.Name;
			orderEvent.Opportunity_Description__c = oppsMap.get(eOrder.OpportunityId).Description;
			orderEvent.Opportunity_PO_Number__c = oppsMap.get(eOrder.OpportunityId).PO_Number__c;
			orderEvent.Order_CreatedDate__c = eOrder.CreatedDate;
			orderEvent.Order_Entity_ID__c = eOrder.Entity_ID__c;
			orderEvent.Order_ID__c = eOrder.Id;
			orderEvent.Order_OrderNumber__c = eOrder.OrderNumber;
			orderEvent.Order_Owner_Department_ID__c = eOrder.Owner_Department_ID__c;
			orderEvent.Order_Owner_Location_ID__c = eOrder.Owner_Location_ID__c;
			orderEvent.Order_Owner_NS_ID__c = eOrder.Owner_NS_ID__c;
			orderEvent.Order_Reseller_NS__c = eOrder.Reseller_NS__c;
			orderEvent.Order_Subsidiary__c = eOrder.Subsidiary__c;
			orderEvent.Order_Subsidiary_ID__c = eOrder.Subsidiary_NS__c;
			orderEvent.Order_TotalAmount__c = eOrder.TotalAmount;
			orderEvent.Quote_Bill_To_Address_2__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.Bill_To_Address_2__c;
			orderEvent.Quote_BillingCity__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__BillingCity__c;
			orderEvent.Quote_BillingCountry__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__BillingCountry__c;
			orderEvent.Quote_BillingName__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__BillingName__c;
			orderEvent.Quote_BillingPostalCode__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__BillingPostalCode__c;
			orderEvent.Quote_BillingState__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__BillingState__c;
			orderEvent.Quote_BillingStreet__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__BillingStreet__c;
			orderEvent.Quote_Bill_To_Attn__c = quotesMap.get(eOrder.SBQQ__Quote__c).Bill_To_Attn__c;
			orderEvent.Quote_ID__c = eOrder.SBQQ__Quote__c;
			orderEvent.Quote_Max_Computed_Term__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.Max_Computed_Term__c;
			orderEvent.Quote_Max_End__c = quotesMap.get(eOrder.SBQQ__Quote__c).Max_End_Date__c;
			orderEvent.Quote_Min_Start_Date__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.Min_Start_Date__c;
			orderEvent.Quote_Partner_Netsuite_ID__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__Partner__r.Netsuite_ID__c;
			orderEvent.Quote_Pricebook_ID__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__PricebookId__c;
			orderEvent.Quote_ShippingCity__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__ShippingCity__c;
			orderEvent.Quote_ShippingCountry__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__ShippingCountry__c;
			orderEvent.Quote_ShippingName__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__ShippingName__c;
			orderEvent.Quote_ShippingPostalCode__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__ShippingPostalCode__c;
			orderEvent.Quote_ShippingState__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__ShippingState__c;
			orderEvent.Quote_ShippingStreet__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__ShippingStreet__c;
			orderEvent.Quote_Ship_To_Address_2__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.Ship_To_Address_2__c;
			orderEvent.Quote_Ship_To_Attn__c = quotesMap.get(eOrder.SBQQ__Quote__c).Ship_To_Attn__c;
			orderEvent.Quote_Payment_Terms__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.SBQQ__PaymentTerms__c;
			orderEvent.Quote_Number__c = quotesMap.get(eOrder.SBQQ__Quote__c).Name;
			orderEvent.Quote_End_User_Account__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.End_User_Account_Display__c;
			orderEvent.Quote_Billing_Payment_Type__c = quotesMap.get(eOrder.SBQQ__Quote__c)
				.PaymentTypeNew__c;
			orderEvents.add(orderEvent);
		}

		List<Database.SaveResult> results = EventBus.publish(orderEvents);
		for (Database.SaveResult result : results) {
			if (result.isSuccess()) {
				callouts.add(new Integration_Callout__c(Name = 'Order_Event__e - ' + result.getId()));
			} else {
				for (Database.Error error : result.getErrors()) {
					Logger.error(
							'Order_Event__c - ' +
							result.getId() +
							' - ' +
							error.getMessage() +
							' - FAILURE'
						)
						.addTag('apex')
						.addTag('platform-event');
				}
			}
		}
		insert callouts;
		Logger.saveLog();
	}

	public static void publishNueOrderEvents(List<Order> orders, Map<Id, Order> oldOrderMap) {
		List<ELV_Order_Event__e> orderEvents = new List<ELV_Order_Event__e>();
		ELV_Order_Event__e orderEvent;
		Set<Id> accountIds = new Set<Id>();
		Set<Id> oppIds = new Set<Id>();
		Set<Id> quoteIds = new Set<Id>();
		List<Integration_Callout__c> callouts = new List<Integration_Callout__c>();
		List<Order> ordersToPublish = new List<Order>();
		Order oldOrder;
		Quote quote;
		Boolean isOrderActivated;

		for (Order order : orders) {
			oldOrder = oldOrderMap?.get(order.Id);
			isOrderActivated =
				order.Status == 'Activated' &&
				(oldOrder == null || oldOrder.Status != 'Activated');
			if (
				order.AccountId != null &&
				order.OpportunityId != null &&
				order.QuoteId != null &&
				isOrderActivated
			) {
				ordersToPublish.add(order);
				accountIds.add(order.AccountId);
				oppIds.add(order.OpportunityId);
				quoteIds.add(order.QuoteId);
			}
		}

		Map<Id, Account> accountsMap = new Map<Id, Account>(
			[SELECT Id, Name, Netsuite_ID__c, Segment__c FROM Account WHERE Id IN :accountIds]
		);
		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(
			[
				SELECT Id, Description, CloseDate, Owner.Name, Type, Subtype__c, PO_Number__c
				FROM Opportunity
				WHERE Id IN :oppIds
			]
		);

		Map<Id, Quote> quotesMap = new Map<Id, Quote>(
			[
				SELECT
					Id,
					QuoteNumber,
					BillingCity,
					BillingCountry,
					BillingName,
					BillingPostalCode,
					BillingState,
					BillingStreet,
					ShippingCity,
					ShippingCountry,
					ShippingName,
					ShippingPostalCode,
					ShippingState,
					ShippingStreet,
					Pricebook2Id,
					Ruby__PaymentTerm__c,
					ELV_Bill_To_Address_2__c,
					ELV_Bill_To_Attn__c,
					ELV_Ship_To_Address_2__c,
					ELV_Ship_To_Attn__c,
					ELV_Max_Computed_Term__c,
					// TEMP: ELV_Max_End_Date__c is being recreated manually - restore this line afterwards.
					// ELV_Max_End_Date__c,
					ELV_Min_Start_Date__c,
					ELV_Partner__r.Netsuite_ID__c,
					ELV_PaymentTypeNew__c,
					ELV_End_User_Account_Display__c
				FROM Quote
				WHERE Id IN :quoteIds
			]
		);

		for (Order order : ordersToPublish) {
			quote = quotesMap.get(order.QuoteId);
			orderEvent = new ELV_Order_Event__e();
			orderEvent.Account_Name__c = accountsMap.get(order.AccountId).Name;
			orderEvent.Account_Netsuite_ID__c = accountsMap.get(order.AccountId).Netsuite_ID__c;
			orderEvent.Account_Segment__c = accountsMap.get(order.AccountId).Segment__c;
			orderEvent.Opportunity_CloseDate__c = oppsMap.get(order.OpportunityId).CloseDate;
			orderEvent.Opportunity_ID__c = oppsMap.get(order.OpportunityId).Id;
			orderEvent.Opportunity_Type__c = oppsMap.get(order.OpportunityId).Type;
			orderEvent.Opportunity_Subtype__c = oppsMap.get(order.OpportunityId).Subtype__c;
			orderEvent.Opportunity_Owner_Name__c = oppsMap.get(order.OpportunityId).Owner.Name;
			orderEvent.Opportunity_Description__c = oppsMap.get(order.OpportunityId).Description;
			orderEvent.Opportunity_PO_Number__c = oppsMap.get(order.OpportunityId).PO_Number__c;
			orderEvent.Order_CreatedDate__c = order.CreatedDate;
			orderEvent.Order_Entity_ID__c = order.Entity_ID__c;
			orderEvent.Order_ID__c = order.Id;
			orderEvent.Order_OrderNumber__c = order.OrderNumber;
			orderEvent.Order_Owner_Department_ID__c = order.Owner_Department_ID__c;
			orderEvent.Order_Owner_Location_ID__c = order.Owner_Location_ID__c;
			orderEvent.Order_Owner_NS_ID__c = order.Owner_NS_ID__c;
			orderEvent.Order_Reseller_NS__c = order.Reseller_NS__c;
			orderEvent.Order_Subsidiary__c = order.Subsidiary__c;
			orderEvent.Order_Subsidiary_ID__c = order.Subsidiary_NS__c;
			orderEvent.Order_TotalAmount__c = order.TotalAmount;
			orderEvent.Quote_ID__c = quote.Id;
			orderEvent.Quote_Number__c = quote.QuoteNumber;
			orderEvent.Quote_Bill_To_Address_2__c = quote.ELV_Bill_To_Address_2__c;
			orderEvent.Quote_Bill_To_Attn__c = quote.ELV_Bill_To_Attn__c;
			orderEvent.Quote_BillingCity__c = quote.BillingCity;
			orderEvent.Quote_BillingCountry__c = quote.BillingCountry;
			orderEvent.Quote_BillingName__c = quote.BillingName;
			orderEvent.Quote_BillingPostalCode__c = quote.BillingPostalCode;
			orderEvent.Quote_BillingState__c = quote.BillingState;
			orderEvent.Quote_BillingStreet__c = quote.BillingStreet;
			orderEvent.Quote_ShippingCity__c = quote.ShippingCity;
			orderEvent.Quote_ShippingCountry__c = quote.ShippingCountry;
			orderEvent.Quote_ShippingName__c = quote.ShippingName;
			orderEvent.Quote_ShippingPostalCode__c = quote.ShippingPostalCode;
			orderEvent.Quote_ShippingState__c = quote.ShippingState;
			orderEvent.Quote_ShippingStreet__c = quote.ShippingStreet;
			orderEvent.Quote_Ship_To_Address_2__c = quote.ELV_Ship_To_Address_2__c;
			orderEvent.Quote_Ship_To_Attn__c = quote.ELV_Ship_To_Attn__c;
			orderEvent.Quote_Max_Computed_Term__c = quote.ELV_Max_Computed_Term__c;
			// TEMP: ELV_Max_End_Date__c is being recreated manually - restore this line afterwards.
			// orderEvent.Quote_Max_End__c = quote.ELV_Max_End_Date__c;
			orderEvent.Quote_Min_Start_Date__c = quote.ELV_Min_Start_Date__c;
			orderEvent.Quote_Partner_Netsuite_ID__c = quote.ELV_Partner__r.Netsuite_ID__c;
			orderEvent.Quote_Payment_Terms__c = quote.Ruby__PaymentTerm__c;
			orderEvent.Quote_Billing_Payment_Type__c = quote.ELV_PaymentTypeNew__c;
			orderEvent.Quote_End_User_Account__c = quote.ELV_End_User_Account_Display__c;
			orderEvents.add(orderEvent);
		}

		List<Database.SaveResult> results = EventBus.publish(orderEvents);
		for (Database.SaveResult result : results) {
			if (result.isSuccess()) {
				callouts.add(new Integration_Callout__c(Name = 'ELV_Order_Event__e - ' + result.getId()));
			} else {
				for (Database.Error error : result.getErrors()) {
					Logger.error(
							'ELV_Order_Event__e - ' +
							result.getId() +
							' - ' +
							error.getMessage() +
							' - FAILURE'
						)
						.addTag('apex')
						.addTag('platform-event');
				}
			}
		}
		insert callouts;
		Logger.saveLog();
	}
}