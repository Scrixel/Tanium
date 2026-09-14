/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller for the Deal_Desk_Approver_Opportunities Visualforce component
 * @Description: Displays the open Opportunities of the current fiscal quarter that reference the user
 * through Deal_Desk_Approver__c
 * @Date: 2016-04-07
 * @Author: Mahesh G
 * RequestId  ModifiedDate  Description
 * TAN-483    2018-02-22    Updated StageName
 * SS-13636   2026-09-11    Excluded pre-commit Renewal and Order Drafted stages
 */
public class DealDeskApproverOpportunitiesController {
	public Id userId { get; set; }

	public DealDeskApproverOpportunitiesController() {
	}

	public List<Opportunity> getOpportunities() {
		if (String.isBlank(userId)) {
			return null;
		}
		List<Opportunity> opps = [
			SELECT Name, Commit__c, Upside__c, StageName
			FROM Opportunity
			WHERE
				Deal_Desk_Approver__c = :userId
				AND StageName != :Utility.UNCOMMITTED_RENEWAL
				AND StageName != :Utility.ACCOUNT_ASSESSMENT
				AND StageName != :Utility.CUSTOMER_ENGAGED
				AND StageName != :Utility.PROPOSAL_SENT
				AND StageName != :Utility.COMMIT_STAGE
				AND StageName != :Utility.ORDER_DRAFTED
				AND StageName != :Utility.SIGNED_PAPERWORK_RECEIVED
				AND StageName != :Utility.SIGNED_AND_INVOICED
				AND StageName != :Utility.CLOSED_WON
				AND StageName != :Utility.FAILED
				AND CloseDate = THIS_FISCAL_QUARTER
		];
		return opps;
	}
}