/**
 *  Copyright (c) 2025 Tanium
 *
 * @Business: Class that supports Product Migratrion functionality
 * @Date:     2025-03-08
 * @Author:   Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-10411   2025-03-08    Created the class
 * SS-11112   2025-06-23    Added empty constructor and method getPotentialNewModules
 * SS-11649   2025-09-24    Added method updateAemMigrationFields
 * SS-11576   2025-12-08    Updated methods startCalculation and getSolution_Migrations plus added method getOtherRenewableProducts
 */
public without sharing class ProductMigrationController {
	public static ProductMigrationData productMigrationData;

	@AuraEnabled
	public static EnhancedReturnType isValidOpportunity(Id opportunityId) {
		EnhancedReturnType rt = new EnhancedReturnType(false, '');
		Opportunity opportunity;
		try {
			opportunity = [
				SELECT
					Id,
					Name,
					SBQQ__RenewedContract__r.ContractNumber,
					SBQQ__RenewedContract__r.EndDate,
					Account.Name,
					Account.Ineligible_for_Migration_Calculation__c,
					Account.Ineligible_for_Migration_Calc_Reason__c
				FROM Opportunity
				WHERE Id = :opportunityId AND SBQQ__RenewedContract__c != NULL
			];

			if (opportunity.Account.Ineligible_for_Migration_Calculation__c) {
				rt.retData = opportunity.Account.Ineligible_for_Migration_Calc_Reason__c;
				rt.retData =
					'This account cannot be calculated due to: ' +
					opportunity.Account.Ineligible_for_Migration_Calc_Reason__c +
					'. Please reach out to Quoting Operations for manual calculation.';
			} else {
				Date startDate = (opportunity.SBQQ__RenewedContract__r.EndDate.addDays(1));
				Integer day = startDate.day();
				Integer month = startDate.month();
				Integer year = startDate.year();
				String startDateStr =
					(month < 10 ? '0' + month : '' + month) +
					'/' +
					(day < 10 ? '0' + day : '' + day) +
					'/' +
					year;
				rt.retResult = true;
				rt.retData =
					opportunity.Name +
					'***' +
					opportunity.SBQQ__RenewedContract__r.ContractNumber +
					'***' +
					startDateStr;
			}
		} catch (Exception e) {
			rt.retData = 'This Opportunity is not linked to a renewed contract.';
		}
		return rt;
	}

	@AuraEnabled(cacheable=true)
	public static List<Subscription_Migration__c> getSubscription_Migrations(String contractNumber) {
		return [
			SELECT
				Id,
				Subscription_Net_Price__c,
				Subscription_Product_Name__c,
				Subscription_Quantity__c,
				Subscription_Start_Date__c,
				Annual_Subscription_Net_Total__c
			FROM Subscription_Migration__c
			WHERE Contract_Number__c = :contractNumber AND Manual_Entry__c = FALSE
		];
	}

	@AuraEnabled(cacheable=true)
	public static List<Solution_Migration__c> getSolution_Migrations(String contractNumber) {
		return [
			SELECT
				Id,
				AEM_Solution_Product_Name__c,
				AEM_Solution_List_Price__c,
				AEM_Solution_Net_Unit_Price__c,
				Max_Quantity__c,
				Start_Date__c,
				AEM_Solution_Net_Total_Price__c,
				Partner_Migration_Discount_Displ__c,
				Sort_Order__c
			FROM Solution_Migration__c
			WHERE Contract_Number__c = :contractNumber AND Manual_Entry__c = FALSE
			ORDER BY Sort_Order__c
		];
	}

	@AuraEnabled(cacheable=true)
	public static List<Subscription_Migration__c> getOtherRenewableProducts(String contractNumber) {
		List<Subscription_Migration__c> otherRenewableProducts = [
			SELECT
				Id,
				Subscription_Net_Price__c,
				Subscription_Product_Name__c,
				Subscription_Quantity__c,
				Subscription_Start_Date__c,
				Annual_Subscription_Net_Total__c
			FROM Subscription_Migration__c
			WHERE
				Contract_Number__c = :contractNumber
				AND Manual_Entry__c = FALSE
				AND Non_AEM_Product__c = TRUE
		];
		return otherRenewableProducts;
	}

	@AuraEnabled
	public static EnhancedReturnType getMigrationTotalBaseLine(String contractNumber) {
		return setMigrationTotalBaseLine(contractNumber);
	}

	public static EnhancedReturnType setMigrationTotalBaseLine(String contractNumber) {
		EnhancedReturnType rt = new EnhancedReturnType(true, '');
		Contract contract;
		Decimal migrationTotalBaseline = 0;
		try {
			contract = [
				SELECT Id, Migration_Total_Baseline__c
				FROM Contract
				WHERE ContractNumber = :contractNumber
			];
		} catch (Exception e) {
			rt.retResult = false;
			rt.retData = 'No Contract Found';
			return rt;
		}

		for (Solution_Migration__c solution_Migration : getSolution_Migrations(contractNumber)) {
			migrationTotalBaseline += solution_Migration.AEM_Solution_Net_Total_Price__c;
		}

		if (contract.Migration_Total_Baseline__c != migrationTotalBaseline) {
			contract.Migration_Total_Baseline__c = migrationTotalBaseline;
			try {
				update contract;
			} catch (Exception e) {
				rt.retResult = false;
				rt.retData = e.getMessage();
				Logger.error('ProductMigrationController.setMigrationTotalBaseLine ERRORS', e)
					.addTag('apex')
					.addTag('lwc');
				Logger.saveLog();
			}
		}
		rt.retData = String.valueOf(contract.Migration_Total_Baseline__c);
		return rt;
	}

	@AuraEnabled
	public static EnhancedReturnType getPotentialNewModules(String contractNumber) {
		String renewedContractModules;
		String potentialAEMModules;
		String potentialNewModules;
		EnhancedReturnType rt = new EnhancedReturnType(true);
		ProductMigrationAsync async = new ProductMigrationAsync();
		renewedContractModules = async.getRenewedContractModules(contractNumber);
		potentialAEMModules = async.getPotentialAEMModules(contractNumber);
		potentialNewModules = async.getPotentialNewModules(
			potentialAEMModules,
			renewedContractModules
		);
		rt.retData = potentialNewModules;
		return rt;
	}

	@AuraEnabled
	public static Boolean startCalculation(Id opportunityId) {
		String contractNumber;
		try {
			contractNumber = [
				SELECT Id, SBQQ__RenewedContract__r.ContractNumber
				FROM Opportunity
				WHERE Id = :opportunityId
				LIMIT 1
			]
			.SBQQ__RenewedContract__r.ContractNumber;
		} catch (Exception e) {
			contractNumber = null;
		}

		return contractNumber == null ? false : startCalculation(contractNumber);
	}

	public static Boolean startCalculation(String contractNumber) {
		Boolean finishedCalculation = false;
		List<SBQQ__Subscription__c> optionSubscriptions = new List<SBQQ__Subscription__c>();
		List<SBQQ__Subscription__c> moduleSubscriptions = new List<SBQQ__Subscription__c>();
		List<String> eligibleProductGroups = new List<String>{
			'Software',
			'Third Party Software',
			'ESR'
		};

		productMigrationData = new ProductMigrationData();

		Contract contract = [
			SELECT
				Id,
				ContractNumber,
				Account.Segment__c,
				Account.Sector__c,
				StartDate,
				EndDate,
				Max_Quantity__c
			FROM Contract
			WHERE ContractNumber = :contractNumber
			LIMIT 1
		];

		deletePriorData(contract.Id);

		SBQQ__Subscription__c[] subscriptions = [
			SELECT
				Id,
				SBQQ__Product__c,
				SBQQ__ListPrice__c,
				SBQQ__NetPrice__c,
				SBQQ__ProrateMultiplier__c,
				SBQQ__ProductOption__c,
				SBQQ__Product__r.Name,
				SBQQ__Product__r.Product_Type__c,
				SBQQ__Account__r.Segment__c,
				SBQQ__Quantity__c,
				SBQQ__Contract__c,
				SBQQ__SubscriptionStartDate__c,
				SBQQ__SubscriptionEndDate__c,
				SBQQ__Product__r.Product_Group__c
			FROM SBQQ__Subscription__c
			WHERE
				SBQQ__Contract__c = :contract.Id
				AND SBQQ__Bundle__c = FALSE
				AND SBQQ__Product__r.Product_Group__c IN :eligibleProductGroups
				AND SBQQ__Quantity__c != 0
			ORDER BY SBQQ__Number__c
		];
		for (SBQQ__Subscription__c subscription : subscriptions) {
			if (subscription.SBQQ__ProductOption__c != null) {
				optionSubscriptions.add(subscription);
			} else {
				moduleSubscriptions.add(subscription);
			}
		}

		productMigrationData.addSubscriptionMigrations(subscriptions);
		productMigrationData.insertSubscription_Migrations();
		productMigrationData.syncSubscriptionMigrations(contract.Id);

		if (!optionSubscriptions.isEmpty()) {
			processOptions(optionSubscriptions);
		}
		if (!moduleSubscriptions.isEmpty()) {
			processModules(moduleSubscriptions);
		}

		productMigrationData.insertModule_Migrations();
		productMigrationData.addSubscriptionAggregateMigrations(contract.Id);

		if (!productMigrationData.subscriptionAggregateMigrations.isEmpty()) {
			productMigrationData.insertSubscription_Aggregate_Migrations();
			productMigrationData.syncSubscriptionAggregateMigrations(contract.Id);
			productMigrationData.modifySubscriptionMigrations();
			productMigrationData.updateSubscription_Migrations();
		}
		productMigrationData.addSolutionMigrations(contract);
		productMigrationData.insertSolution_Migrations();
		productMigrationData.syncSolutionMigrations(contract.Id);
		productMigrationData.modifySolutionMigrations(contract.Id);
		productMigrationData.updateSolution_Migrations();
		finishedCalculation = true;
		return finishedCalculation;
	}

	private static void processOptions(SBQQ__Subscription__c[] subscriptions) {
		Map<Id, Module__c> productIdModuleMap;
		Map<Id, Product_Module__c> productIdProductModuleMap;
		Set<Id> productOptionIds = new Set<Id>();
		Set<Id> optionProductIds = new Set<Id>();

		for (SBQQ__Subscription__c subscription : subscriptions) {
			productOptionIds.add(subscription.SBQQ__ProductOption__c);
		}

		SBQQ__ProductOption__c[] productOptions = [
			SELECT
				Id,
				Allocation__c,
				SBQQ__UnitPrice__c,
				SBQQ__ConfiguredSKU__c,
				SBQQ__ProductName__c,
				SBQQ__OptionalSKU__c,
				SBQQ__OptionalSKU__r.Name,
				SBQQ__OptionalSKU__r.Product_Type__c
			FROM SBQQ__ProductOption__c
			WHERE Id IN :productOptionIds
			ORDER BY SBQQ__OptionalSKU__c
		];

		for (SBQQ__ProductOption__c productOption : productOptions) {
			optionProductIds.add(productOption.SBQQ__OptionalSKU__c);
		}

		productIdModuleMap = getProductIdModuleMap(optionProductIds);
		productIdProductModuleMap = getProductIdProductModuleMap(optionProductIds);

		Id subscriptionId;
		Id productId;
		String productName;
		String moduleName;
		String productType;
		String segment;
		Decimal allocationPct;
		Decimal allocationListPrice;
		Decimal allocationNetPrice;
		Decimal prorateMultiplier;
		Decimal subscrListPrice;
		Decimal subscrNetPrice;

		for (SBQQ__Subscription__c subscription : subscriptions) {
			for (SBQQ__ProductOption__c productOption : productOptions) {
				if (subscription.SBQQ__ProductOption__c == productOption.Id) {
					subscriptionId = subscription.Id;
					productId = productOption.SBQQ__OptionalSKU__r.Id;
					productName = productOption.SBQQ__OptionalSKU__r.Name;
					moduleName = productIdModuleMap.get(productOption.SBQQ__OptionalSKU__c)?.Name;
					productType = productOption.SBQQ__OptionalSKU__r.Product_Type__c;
					segment = subscription.SBQQ__Account__r.Segment__c;
					allocationPct = productIdProductModuleMap.get(productOption.SBQQ__OptionalSKU__c)
							.Attribution_Percentage__c == null
						? 100
						: productIdProductModuleMap.get(productOption.SBQQ__OptionalSKU__c)
								.Attribution_Percentage__c;
					prorateMultiplier = subscription.SBQQ__ProrateMultiplier__c;
					subscrListPrice = subscription.SBQQ__ListPrice__c;
					subscrNetPrice = subscription.SBQQ__NetPrice__c;
					allocationListPrice = (subscrListPrice / prorateMultiplier) * (allocationPct / 100);
					allocationNetPrice = (subscrNetPrice / prorateMultiplier) * (allocationPct / 100);

					if (productName.contains('Promo') && !productMigrationData.isPromo) {
						productMigrationData.isPromo = true;
					}

					productMigrationData.getSubscriptionMigration(subscriptionId)
						.addModuleMigration(
							productId,
							productName,
							moduleName,
							productType,
							segment,
							allocationPct,
							allocationListPrice,
							allocationNetPrice,
							'Product Option'
						);
				}
			}
		}
	}

	private static void processModules(SBQQ__Subscription__c[] subscriptions) {
		Set<Id> productIds = new Set<Id>();
		Map<Id, Module__c> productIdModuleMap;

		for (SBQQ__Subscription__c subscription : subscriptions) {
			productIds.add(subscription.SBQQ__Product__c);
		}

		productIdModuleMap = getProductIdModuleMap(productIds);

		Product_Module__c[] productModules = [
			SELECT
				Id,
				Attribution_Percentage__c,
				Product_SKU__c,
				Product__c,
				Product__r.Name,
				Product__r.Product_Type__c,
				Module_Product__c,
				Module__c,
				Module__r.Name
			FROM Product_Module__c
			WHERE Product__c IN :productIds
		];

		Id subscriptionId;
		Id productId;
		String productName;
		String moduleName;
		String productType;
		String segment;
		Decimal allocationPct;
		Decimal allocationListPrice;
		Decimal allocationNetPrice;
		Decimal prorateMultiplier;
		Decimal subscrListPrice;
		Decimal subscrNetPrice;

		for (SBQQ__Subscription__c subscription : subscriptions) {
			for (Product_Module__c productModule : productModules) {
				if (subscription.SBQQ__Product__c == productModule.Product__c) {
					subscriptionId = subscription.Id;
					productId = productModule.Product__r.Id;
					productName = productModule.Product__r.Name;
					moduleName = productModule.Module__r.Name;
					productType = productModule.Product__r.Product_Type__c;
					segment = subscription.SBQQ__Account__r.Segment__c;
					allocationPct = productModule.Attribution_Percentage__c == null
						? 100
						: productModule.Attribution_Percentage__c < 1
								? productModule.Attribution_Percentage__c * 100
								: productModule.Attribution_Percentage__c;

					prorateMultiplier = subscription.SBQQ__ProrateMultiplier__c;
					subscrListPrice = subscription.SBQQ__ListPrice__c;
					subscrNetPrice = subscription.SBQQ__NetPrice__c;
					allocationListPrice = (subscrListPrice / prorateMultiplier) * (allocationPct / 100);
					allocationNetPrice = (subscrNetPrice / prorateMultiplier) * (allocationPct / 100);

					if (productName.contains('Promo') && !productMigrationData.isPromo) {
						productMigrationData.isPromo = true;
					}

					productMigrationData.getSubscriptionMigration(subscriptionId)
						.addModuleMigration(
							productId,
							productName,
							moduleName,
							productType,
							segment,
							allocationPct,
							allocationListPrice,
							allocationNetPrice,
							'Module'
						);
				}
			}
		}
	}

	private static Map<Id, Module__c> getProductIdModuleMap(Set<Id> productIds) {
		Set<Id> moduleIds = new Set<Id>();
		Map<Id, Module__c> moduleMap;
		Map<Id, Module__c> productIdModuleMap = new Map<Id, Module__c>();

		Product_Module__c[] productModules = [
			SELECT Id, Module__c, Product__c
			FROM Product_Module__c
			WHERE Product__c IN :productIds
		];

		for (Product_Module__c productModule : productModules) {
			moduleIds.add(productModule.Module__c);
		}

		moduleMap = new Map<Id, Module__c>([SELECT Id, Name FROM Module__c WHERE Id IN :moduleIds]);

		for (Product_Module__c productModule : productModules) {
			productIdModuleMap.put(productModule.Product__c, moduleMap.get(productModule.Module__c));
		}

		return productIdModuleMap;
	}

	private static Map<Id, Product_Module__c> getProductIdProductModuleMap(Set<Id> productIds) {
		Map<Id, Product_Module__c> productIdProductModuleMap = new Map<Id, Product_Module__c>();
		Product_Module__c[] productModules = [
			SELECT Id, Product__c, Attribution_Percentage__c
			FROM Product_Module__c
			WHERE Product__c IN :productIds
		];

		for (Product_Module__c productModule : productModules) {
			productIdProductModuleMap.put(productModule.Product__c, productModule);
		}
		return productIdProductModuleMap;
	}

	public static void deletePriorData(Id contractId) {
		Set<Id> subscription_MigrationIds = new Set<Id>();
		Database.DeleteResult[] deleteResults;
		Solution_Migration__c[] solution_Migrations = [
			SELECT Id
			FROM Solution_Migration__c
			WHERE Contract__c = :contractId AND Manual_Entry__c = FALSE
		];
		Subscription_Aggregate_Migration__c[] subscription_Aggregate_Migrations = [
			SELECT Id
			FROM Subscription_Aggregate_Migration__c
			WHERE Contract__c = :contractId AND Manual_Entry__c = FALSE
		];

		Map<Id, Subscription_Migration__c> subscription_MigrationMap = new Map<Id, Subscription_Migration__c>(
			[
				SELECT Id
				FROM Subscription_Migration__c
				WHERE Contract__c = :contractId AND Manual_Entry__c = FALSE
			]
		);
		subscription_MigrationIds.addAll(subscription_MigrationMap.keySet());

		Module_Migration__c[] module_Migrations = [
			SELECT Id
			FROM Module_Migration__c
			WHERE Subscription_Migration__c IN :subscription_MigrationIds AND Manual_Entry__c = FALSE
		];

		deleteResults = Database.delete(module_Migrations, true);
		deleteResults = Database.delete(subscription_MigrationMap.values(), true);
		deleteResults = Database.delete(subscription_Aggregate_Migrations, true);
		deleteResults = Database.delete(solution_Migrations, true);
	}

	@AuraEnabled
	public static void updateAemMigrationFields(Id oppId) {
		ProductMigrationAsync async = new ProductMigrationAsync(
			[
				SELECT
					Id,
					Renewed_Contract_Modules__c,
					Potential_AEM_Modules__c,
					Potential_New_Modules__c,
					Potential_New_Module_Count__c,
					Potential_AEM_Migration_ARR__c
				FROM Opportunity
				WHERE Id = :oppId
			]
		);
		Id jobId = Test.isRunningTest() ? null : System.enqueueJob(async);
	}
}