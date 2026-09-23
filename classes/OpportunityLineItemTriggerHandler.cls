/**
 * @Business: Handler Class for OpportunityLineItemTrigger
 * @Date: 2017-12-08
 * @Author: Cumulus Vision
 * @Request: TAN-463
 * Modified  ModifiedDate   Description
 * TAN-463   2017-12-08     Initial Development
 */
public class OpportunityLineItemTriggerHandler extends TriggerHandler {
	public List<OpportunityLineItem> oppLineItems;
	public Map<Id, OpportunityLineItem> oldMap;

	public OpportunityLineItemTriggerHandler() {
		super('OpportunityLineItemTriggerHandler');
		this.oppLineItems = (List<OpportunityLineItem>) Trigger.new;
		this.oldMap = (Map<Id, OpportunityLineItem>) Trigger.oldMap;
	}

	public override void afterInsert() {
		OpportunityLineItemTriggerUtility.setIsSoftwareOpportunity(oppLineItems);
	}

	public override void beforeUpdate() {
		OpportunityQuoteLineLockUtility.checkLockedOpportunityProducts(oppLineItems);
	}

	public override void beforeDelete() {
		OpportunityQuoteLineLockUtility.checkLockedOpportunityProducts(oldMap.values());
	}

	public override void afterDelete() {
		OpportunityLineItemTriggerUtility.uncheckHardwareOpportunity(oldMap.values());
		OpportunityLineItemTriggerUtility.setIsSoftwareOpportunity(oldMap.values());
	}
}