/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Trigger Handler on POC Request
 * @Date: 2025-11-13
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2025-11-13      Added method to handle approved POC requests
 */
public class POCRequestTriggerHandler extends TriggerHandler {
	private List<POC_Request__c> pocRequests;
	private Map<Id, POC_Request__c> oldMap;

	public POCRequestTriggerHandler() {
		super('POCRequestTriggerHandler');
		pocRequests = (List<POC_Request__c>) Trigger.new;
		oldMap = (Map<Id, POC_Request__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		POCRequestOpportunityUtility.validateApprovedSupportRequestForExceptionCountries(
			pocRequests,
			null
		);
	}

	public override void beforeUpdate() {
		POCRequestOpportunityUtility.validateApprovedSupportRequestForExceptionCountries(
			pocRequests,
			oldMap
		);
	}

	public override void afterUpdate() {
		POCRequestOpportunityUtility.createNewPOCOppAndLineItems(pocRequests, oldMap);
		POCRequestTriggerUtility.handleApprovedPOCRequests(pocRequests, oldMap);
	}
}