/**
 * @Business: Deal Registration Trigger Handling
 * @Date: 2024-09-13
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-8999    2024-09-12    Initial development - Opp Reg to Deal Reg Migration
 * SS-9432    2025-02-22    Add preApprovalChecks and handleMappedOpportunityChange
 * SS-11723   2025-09-23    Populate PFS fields on Deal Registration from related Account
 * SS-11635   2025-09-25    Added call to method assignEndCustomerAccount
 */
public class DealRegistrationTriggerHandler extends TriggerHandler {
	private Map<Id, Account> accountMap = new Map<Id, Account>();
	private Map<Id, User> ownerMap = new Map<Id, User>();
	private List<Deal_Registration__c> deals;
	private Map<Id, Deal_Registration__c> oldMap;

	public DealRegistrationTriggerHandler() {
		super('DealRegistrationTriggerHandler');
		deals = (List<Deal_Registration__c>) Trigger.new;
		oldMap = (Map<Id, Deal_Registration__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		getOwnerAccountMaps();
		DealRegistrationUtility.populateSPIFFEmail(deals);
		DealRegistrationUtility.preApprovalChecks(deals, null);
		DealRegistrationUtility.handleMappedOpportunityChange(deals, null);
		DealRegistrationUtility.processUpdateDealRegOwnerAndEmailFields(
			deals,
			accountMap,
			ownerMap,
			null
		);
		DealRegistrationUtility.updateCurrentApprover(deals, null);
		DealRegistrationUtility.updateFieldsOnDealRegStatusExtensionPending(deals, null);
		DealRegistrationUtility.updateDealRegNewBusDaysExtBusDaysFields(deals, null);
		DealRegistrationUtility.processDealRegEndCustomerAccount(deals, null, accountMap);
		DealRegistrationUtility.assignEndCustomerAccount(deals);
	}

	public override void afterInsert() {
		getOwnerAccountMaps();
		DealRegistrationUtility.processDealRegApprovalAssignment(deals, null, ownerMap);
		DealRegistrationUtility.processDealRegDistributor(deals, null);
	}

	public override void beforeUpdate() {
		getOwnerAccountMaps();
		DealRegistrationUtility.populateDealRegType(deals, oldMap);
		DealRegistrationUtility.preApprovalChecks(deals, oldMap);
		DealRegistrationUtility.handleMappedOpportunityChange(deals, oldMap);
		DealRegistrationUtility.processUpdateDealRegOwnerAndEmailFields(
			deals,
			accountMap,
			ownerMap,
			oldMap
		);
		DealRegistrationUtility.updateCurrentApprover(deals, oldMap);
		DealRegistrationUtility.updateFieldsOnDealRegStatusExtensionPending(deals, oldMap);
		DealRegistrationUtility.updateDealRegNewBusDaysExtBusDaysFields(deals, oldMap);
		DealRegistrationUtility.partnerCreatorDealRegsExist(deals, oldMap);
		DealRegistrationUtility.processDealRegEndCustomerAccount(deals, oldMap, accountMap);
		DealRegistrationUtility.assignEndCustomerAccount(deals);
	}

	public override void afterUpdate() {
		getOwnerAccountMaps();
		DealRegistrationUtility.processDealRegApprovalAssignment(deals, oldMap, ownerMap);
		DealRegistrationUtility.processDealRegDistributor(deals, null);
		DealRegistrationUtility.upsertOpportunityPartner(deals, oldMap);
	}

	public override void beforeDelete() {
		DealRegistrationUtility.checkDeletePermission(oldMap.values());
	}

	private void getOwnerAccountMaps() {
		Set<Id> accountIds = new Set<Id>();
		Set<Id> userIds = new Set<Id>();

		for (Deal_Registration__c deal : deals) {
			if (deal.Account__c != null) {
				accountIds.add(deal.Account__c);
			}
			if (String.valueOf(deal.OwnerId).startsWith('005')) {
				userIds.add(deal.OwnerId);
			}
		}
		accountMap = new Map<Id, Account>(
			[
				SELECT
					Id,
					Name,
					CreatedDate,
					OwnerId,
					Owner.ManagerId,
					Owner.Manager.Email,
					Owner.UserRole.Name,
					Segment__c,
					Primary_PFS_Territory_Name__c,
					Primary_PFS_Territory_Id__c
				FROM Account
				WHERE Id IN :accountIds
			]
		);
		ownerMap = new Map<Id, User>(
			[SELECT Id, Role_Category__c, ManagerId, Manager.Email FROM User WHERE id IN :userIds]
		);
	}
}