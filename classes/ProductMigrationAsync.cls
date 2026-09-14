/**
 * @Business: Class that supports Product Migratrion functionality
 * @Date:     2025-06-23
 * @Author:   Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11112   2025-06-23    Created the class
 * SS-11649   2025-09-24    Updated methods execute, getContract
 */
public with sharing class ProductMigrationAsync implements Queueable {
	private List<Opportunity> renewalOpps;
	private Decimal potentialAEMMigrationARR;
	private Decimal taniumSoftwareARR;
	private String renewedContractModules;
	private String potentialAEMModules;
	private String potentialNewModules;
	private Integer potentialNewModulesCount;

	public ProductMigrationAsync() {
		this(null);
	}

	public ProductMigrationAsync(List<Opportunity> renewalOpps) {
		this.renewalOpps = renewalOpps;
	}

	// override interface execute method
	public void execute(QueueableContext context) {
		Opportunity opp = this.renewalOpps.remove(0);
		Opportunity oppToUpdate = new Opportunity(
			Id = opp.Id,
			Renewed_Contract_Modules__c = opp.Renewed_Contract_Modules__c,
			Potential_AEM_Modules__c = opp.Potential_AEM_Modules__c,
			Potential_New_Modules__c = opp.Potential_New_Modules__c,
			Potential_New_Module_Count__c = opp.Potential_New_Module_Count__c,
			Potential_AEM_Migration_ARR__c = opp.Potential_AEM_Migration_ARR__c
		);
		Contract contract = getContract(opp.Id);
		Boolean contractFieldValueChanged = false;
		Boolean oppFieldValueChanged = false;
		Boolean calculationCompleted = ProductMigrationController.startCalculation(
			contract.ContractNumber
		);

		taniumSoftwareARR = getTaniumSoftwareARR(contract.ContractNumber);
		renewedContractModules = getRenewedContractModules(contract.ContractNumber);
		potentialAEMModules = getPotentialAEMModules(contract.ContractNumber);
		potentialNewModules = getPotentialNewModules(potentialAEMModules, renewedContractModules);
		potentialNewModulesCount = getPotentialNewModulesCount(potentialNewModules);
		potentialAEMMigrationARR = getPotentialAEMMigrationARR(contract.ContractNumber);

		contractFieldValueChanged = (contract.Tanium_Software_ARR__c != taniumSoftwareARR);

		contract.Tanium_Software_ARR__c = contract.Tanium_Software_ARR__c != taniumSoftwareARR
			? taniumSoftwareARR
			: contract.Tanium_Software_ARR__c;

		oppFieldValueChanged = (oppToUpdate.Renewed_Contract_Modules__c != renewedContractModules ||
		oppToUpdate.Potential_AEM_Modules__c != potentialAEMModules ||
		oppToUpdate.Potential_New_Modules__c != potentialNewModules ||
		oppToUpdate.Potential_New_Module_Count__c != potentialNewModulesCount ||
		oppToUpdate.Potential_AEM_Migration_ARR__c != potentialAEMMigrationARR);

		oppToUpdate.Renewed_Contract_Modules__c = oppToUpdate.Renewed_Contract_Modules__c !=
			renewedContractModules
			? renewedContractModules
			: oppToUpdate.Renewed_Contract_Modules__c;
		oppToUpdate.Potential_AEM_Modules__c = oppToUpdate.Potential_AEM_Modules__c !=
			potentialAEMModules
			? potentialAEMModules
			: oppToUpdate.Potential_AEM_Modules__c;
		oppToUpdate.Potential_New_Modules__c = oppToUpdate.Potential_New_Modules__c !=
			potentialNewModules
			? potentialNewModules
			: oppToUpdate.Potential_New_Modules__c;
		oppToUpdate.Potential_New_Module_Count__c = oppToUpdate.Potential_New_Module_Count__c !=
			potentialNewModulesCount
			? potentialNewModulesCount
			: oppToUpdate.Potential_New_Module_Count__c;
		oppToUpdate.Potential_AEM_Migration_ARR__c = oppToUpdate.Potential_AEM_Migration_ARR__c !=
			potentialAEMMigrationARR
			? potentialAEMMigrationARR
			: oppToUpdate.Potential_AEM_Migration_ARR__c;

		if (contractFieldValueChanged) {
			try {
				Database.update(new List<Contract>{ contract }, true);
			} catch (Exception e) {
				logException(e, new List<Contract>{ contract }, contract.Id);
			}
		}

		if (oppFieldValueChanged) {
			try {
				Database.update(new List<Opportunity>{ oppToUpdate }, true);
			} catch (Exception e) {
				logException(e, new List<Opportunity>{ oppToUpdate }, oppToUpdate.Id);
			}
		}

		if (!this.renewalOpps.isEmpty() || Test.isRunningTest()) {
			submitQueuableJob(this.renewalOpps);
		}
	}

	private Contract getContract(Id oppId) {
		Contract contract;
		try {
			contract = [
				SELECT Id, ContractNumber, Tanium_Software_ARR__c
				FROM Contract
				WHERE SBQQ__RenewalOpportunity__c = :oppId
				LIMIT 1
			];
		} catch (Exception e) {
			contract = null;
		}

		return contract;
	}

	private Decimal getPotentialAEMMigrationARR(String contractNumber) {
		Decimal potentialAEMMigrationARR = 0;

		for (Solution_Migration__c solution_Migration : [
			SELECT Id, AEM_Solution_Net_Total_Price__c
			FROM Solution_Migration__c
			WHERE Contract_Number__c = :contractNumber
		]) {
			potentialAEMMigrationARR += solution_Migration.AEM_Solution_Net_Total_Price__c;
		}
		return potentialAEMMigrationARR;
	}

	private Decimal getTaniumSoftwareARR(String contractNumber) {
		Decimal taniumSoftwareARR = 0;
		for (Subscription_Migration__c subscription_Migration : [
			SELECT Id, Annual_Subscription_Net_Total__c
			FROM Subscription_Migration__c
			WHERE Contract_Number__c = :contractNumber
		]) {
			taniumSoftwareARR += subscription_Migration.Annual_Subscription_Net_Total__c;
		}
		return taniumSoftwareARR;
	}

	public String getRenewedContractModules(String contractNumber) {
		List<String> renewedContractModules;
		Set<String> renewedContractModulesSet = new Set<String>();

		for (Module_Migration__c module_Migration : [
			SELECT Id, Module_Name__c
			FROM Module_Migration__c
			WHERE Contract_Number__c = :contractNumber
		]) {
			renewedContractModulesSet.add(module_Migration.Module_Name__c);
		}

		renewedContractModules = new List<String>(renewedContractModulesSet);
		renewedContractModules.sort();
		return String.join(renewedContractModules, ', ');
	}

	public String getPotentialAEMModules(String contractNumber) {
		Set<Id> aemProductIds = new Set<Id>();
		List<String> potentialAEMModules;
		Set<String> potentialAEMModulesSet = new Set<String>();

		for (Solution_Migration__c solution_Migration : [
			SELECT Id, AEM_Solution__c
			FROM Solution_Migration__c
			WHERE Contract_Number__c = :contractNumber
		]) {
			aemProductIds.add(solution_Migration.AEM_Solution__c);
		}

		for (Product_Module__c productModule : [
			SELECT Id, Module__r.Name
			FROM Product_Module__c
			WHERE Product__c IN :aemProductIds
		]) {
			potentialAEMModulesSet.add(productModule.Module__r.Name);
		}

		potentialAEMModules = new List<String>(potentialAEMModulesSet);
		potentialAEMModules.sort();
		return String.join(potentialAEMModules, ', ');
	}

	public String getPotentialNewModules(
		String potentialAEMModulesStr,
		String renewedContractModulesStr
	) {
		Set<String> potentialAEMModules = new Set<String>(potentialAEMModulesStr.split(', '));
		Set<String> renewedContractModules = new Set<String>(renewedContractModulesStr.split(', '));
		Set<String> potentialNewModulesSet;
		List<String> potentialNewModules;

		potentialNewModulesSet = new Set<String>(potentialAEMModules);
		potentialNewModulesSet.removeAll(renewedContractModules);

		potentialNewModules = new List<String>(potentialNewModulesSet);
		potentialNewModules.sort();
		return String.join(potentialNewModules, ', ');
	}

	private Integer getPotentialNewModulesCount(String potentialNewModulesStr) {
		Set<String> potentialNewModules = new Set<String>(potentialNewModulesStr.split(', '));
		return potentialNewModules.size();
	}

	private void submitQueuableJob(List<Opportunity> opps) {
		ProductMigrationAsync async = new ProductMigrationAsync(opps);
		Id jobId = Test.isRunningTest() ? null : System.enqueueJob(async, 2);
	}

	@TestVisible
	private void logException(Exception e, List<SObject> sObjects, Id recordId) {
		Logger.error('ProductMigrationAsync.execute ERRORS', sObjects, e)
			.setRecordId(recordId)
			.addTag('apex');
		Logger.saveLog();
	}
}