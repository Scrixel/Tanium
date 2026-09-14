/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Lead Trigger Handler
 * @Date: 2015-04
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * TAN-854    2020-03-25     code clean up. added logic for opportunity registration approval.
 * TAN-949    2020-10-14     1. Set Opp Reg Approval Assignment to result assignment from metadata 2. Set Distributor Company name equal to Partner Name
 * TAN-1046   2020-12-15     migrated some OppReg process to trigger from process builder.
 * TAN-1047   2020-12-17     oppReg - set close date to today + 270 days on new opp created.
 * TAN-1048   2020-12-29     oppReg - logic consolidation round 2 -- Default SPIFF Email, only create opp if no extensions, minor query logic update (no impact)
 * TAN-1068   2021-01-08     oppReg - prevent deletion of opp reg lead.
 * TAN-1095   2021-02-22     oppReg - set RVP/AVP based on Owner. rework/consolidate some addt'l owner related logic
 * TAN-1114   2021-03-03     oppReg - set Opp_Reg_ID__c on opportunity during approval transition. Set default stage as well.
 * TAN-1198   2021-05-07     Removed usage of Opportunty_Partner__c object's Expiration_Date__c field.
 * TAN-1185   2021-05-26     Added after insert event to update Opp_Reg_Approval_Assignment__c field.
 * SS-1028	  2023-01-12     Restrict Lead Deletion
 * SS-7569    2024-04-02     Removed redudant method call in afterInsert, added call to methods partnerCreatorOppRegsExist, upsertOpportunityPartner
 * SS-7569    2024-04-03     Various layout changes and other changes to align with current coding guidelines
 * SS-12400   2026-01-22     Removed OpportunityRegistrationUtility class and related methods
 * SS-12661   2026-02-25     Delete deprecated opp reg related code for Lead object
 * SS-12496   2026-03-06     Class cleanup to follow coding guidelines, moved methods still being used to LeadTriggerUtility class, deleted methods no longer being used
 * SS-13499   2026-07-08     Removed beforeInsert SPIFF email override
 */
public with sharing class LeadTriggerHandler extends TriggerHandler {
	private List<Lead> leads;
	private Map<Id, Lead> oldMap;

	public LeadTriggerHandler() {
		super('LeadTriggerHandler');
		leads = (List<Lead>) Trigger.new;
		oldMap = (Map<Id, Lead>) Trigger.oldMap;
	}

	public override void afterUpdate() {
		LeadTriggerUtility.assignOppManager(leads);
		LeadTriggerUtility.updateOwnerBasedOnTerritory(leads, oldMap);
	}

	public override void beforeDelete() {
		LeadTriggerUtility.checkDeletePermission(oldMap.values());
	}
}