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
 * SS-13771   2026-08-18    Updated class as part of Elevate project
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
					Account.Name,
					Account.Ineligible_for_Migration_Calculation__c,
					Account.Ineligible_for_Migration_Calc_Reason__c,
					EndDate__c
				FROM Opportunity
				WHERE Id = :opportunityId
			];

			if (opportunity.Account.Ineligible_for_Migration_Calculation__c) {
				rt.retData = opportunity.Account.Ineligible_for_Migration_Calc_Reason__c;
				rt.retData =
					'This account cannot be calculated due to: ' +
					opportunity.Account.Ineligible_for_Migration_Calc_Reason__c +
					'. Please reach out to Quoting Operations for manual calculation.';
			} else if (opportunity.EndDate__c == null) {
				rt.retData = 'This opportunity does not have an end date.';
				return rt;
			} else {
				Date startDate = opportunity.EndDate__c.addDays(1);
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
				rt.retData = opportunity.Name + '***' + opportunity.Id + '***' + startDateStr;
			}
		} catch (Exception e) {
			rt.retData = 'This Opportunity is not eligible due to error ' + e.getMessage();
		}
		return rt;
	}

	@AuraEnabled(cacheable=true)
	public static List<Subscription_Migration__c> getSubscription_Migrations(Id opportunityId) {
		return [
			SELECT
				Id,
				Subscription_Net_Price__c,
				Subscription_Product_Name__c,
				Subscription_Quantity__c,
				Subscription_Start_Date__c,
				Annual_Subscription_Net_Total__c
			FROM Subscription_Migration__c
			WHERE Opportunity__c = :opportunityId AND Manual_Entry__c = FALSE
		];
	}

	@AuraEnabled(cacheable=true)
	public static List<Solution_Migration__c> getSolution_Migrations(Id opportunityId) {
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
			WHERE Opportunity__c = :opportunityId AND Manual_Entry__c = FALSE
			ORDER BY Sort_Order__c
		];
	}

	@AuraEnabled(cacheable=true)
	public static List<Subscription_Migration__c> getOtherRenewableProducts(Id opportunityId) {
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
				Opportunity__c = :opportunityId
				AND Manual_Entry__c = FALSE
				AND Non_AEM_Product__c = TRUE
		];
		return otherRenewableProducts;
	}

	@AuraEnabled
	public static EnhancedReturnType getMigrationTotalBaseLine(Id opportunityId) {
		return setMigrationTotalBaseLine(opportunityId);
	}

	public static EnhancedReturnType setMigrationTotalBaseLine(Id opportunityId) {
		EnhancedReturnType rt = new EnhancedReturnType(true, '');
		Opportunity opportunity;
		Decimal migrationTotalBaseline = 0;
		try {
			opportunity = [
				SELECT Id, Migration_Total_Baseline2__c
				FROM Opportunity
				WHERE Id = :opportunityId
			];
		} catch (Exception e) {
			rt.retResult = false;
			rt.retData = 'No Contract Found';
			return rt;
		}

		for (Solution_Migration__c solution_Migration : getSolution_Migrations(opportunityId)) {
			migrationTotalBaseline += solution_Migration.AEM_Solution_Net_Total_Price__c ?? 0;
		}

		if (opportunity.Migration_Total_Baseline2__c != migrationTotalBaseline) {
			opportunity.Migration_Total_Baseline2__c = migrationTotalBaseline;
			try {
				update opportunity;
			} catch (Exception e) {
				rt.retResult = false;
				rt.retData = e.getMessage();
				Logger.error('ProductMigrationController.setMigrationTotalBaseLine ERRORS', e)
					.addTag('apex')
					.addTag('lwc');
				Logger.saveLog();
			}
		}
		rt.retData = String.valueOf(opportunity.Migration_Total_Baseline2__c);
		return rt;
	}

	@AuraEnabled
	public static EnhancedReturnType getPotentialNewModules(Id opportunityId) {
		String renewedContractModules;
		String potentialAEMModules;
		String potentialNewModules;
		EnhancedReturnType rt = new EnhancedReturnType(true);

		ProductMigrationAsync async = new ProductMigrationAsync();
		renewedContractModules = async.getRenewedContractModules(opportunityId);
		potentialAEMModules = async.getPotentialAEMModules(opportunityId);
		potentialNewModules = async.getPotentialNewModules(
			potentialAEMModules,
			renewedContractModules
		);

		rt.retData = potentialNewModules;
		return rt;
	}

	@AuraEnabled
	public static Boolean startCalculation(Id opportunityId) {
		Opportunity opportunity;

		try {
			opportunity = [
				SELECT Id, Account.Segment__c, Account.Sector__c, EndDate__c, MaxQuantity__c
				FROM Opportunity
				WHERE Id = :opportunityId
				LIMIT 1
			];
		} catch (Exception e) {
			opportunity = null;
		}

		return opportunity == null ? false : startCalculation(opportunity);
	}

	public static Boolean startCalculation(Opportunity opportunity) {
		Boolean finishedCalculation = false;
		List<Ruby__Subscription__c> optionSubscriptions = new List<Ruby__Subscription__c>();
		List<Ruby__Subscription__c> moduleSubscriptions = new List<Ruby__Subscription__c>();
		List<String> eligibleProductGroups = new List<String>{
			'Software',
			'Third Party Software',
			'ESR'
		};

		productMigrationData = new ProductMigrationData();

		deletePriorData(opportunity.Id);

		List<Ruby__Subscription__c> subscriptions = [
			SELECT
				Id,
				Ruby__Product__c,
				Ruby__ListPrice__c,
				Ruby__NetSellerPrice__c,
				ELV_ProrateMultiplier__c,
				Ruby__Product__r.Name,
				Ruby__Product__r.Product_Type__c,
				Ruby__BillingAccount__r.Segment__c,
				Ruby__Quantity__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				Ruby__Product__r.Product_Group__c,
				Ruby__RenewalOpportunity__c
			FROM Ruby__Subscription__c
			WHERE
				Ruby__RenewalOpportunity__c = :opportunity.Id
				AND ELV_Bundle__c = FALSE
				AND Ruby__Product__r.Product_Group__c IN :eligibleProductGroups
				AND Ruby__Quantity__c != 0
		];
		for (Ruby__Subscription__c subscription : subscriptions) {
			moduleSubscriptions.add(subscription);
		}

		productMigrationData.addSubscriptionMigrations(subscriptions);
		productMigrationData.insertSubscription_Migrations();
		productMigrationData.syncSubscriptionMigrations(opportunity.Id);

		if (!moduleSubscriptions.isEmpty()) {
			processModules(moduleSubscriptions);
		}

		productMigrationData.insertModule_Migrations();
		productMigrationData.addSubscriptionAggregateMigrations(opportunity.Id);

		if (!productMigrationData.subscriptionAggregateMigrations.isEmpty()) {
			productMigrationData.insertSubscription_Aggregate_Migrations();
			productMigrationData.syncSubscriptionAggregateMigrations(opportunity.Id);
			productMigrationData.modifySubscriptionMigrations();
			productMigrationData.updateSubscription_Migrations();
		}

		productMigrationData.addSolutionMigrations(opportunity);
		productMigrationData.insertSolution_Migrations();
		productMigrationData.syncSolutionMigrations(opportunity.Id);
		productMigrationData.modifySolutionMigrations(opportunity.Id);
		productMigrationData.updateSolution_Migrations();
		finishedCalculation = true;
		return finishedCalculation;
	}

	private static void processModules(List<Ruby__Subscription__c> subscriptions) {
		Set<Id> productIds = new Set<Id>();
		Map<Id, Module__c> productIdModuleMap;

		for (Ruby__Subscription__c subscription : subscriptions) {
			productIds.add(subscription.Ruby__Product__c);
		}

		productIdModuleMap = getProductIdModuleMap(productIds);

		List<Product_Module__c> productModules = [
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

		for (Ruby__Subscription__c subscription : subscriptions) {
			for (Product_Module__c productModule : productModules) {
				if (subscription.Ruby__Product__c == productModule.Product__c) {
					subscriptionId = subscription.Id;
					productId = productModule.Product__r.Id;
					productName = productModule.Product__r.Name;
					moduleName = productModule.Module__r.Name;
					productType = productModule.Product__r.Product_Type__c;
					segment = subscription.Ruby__BillingAccount__r.Segment__c;
					allocationPct = productModule.Attribution_Percentage__c == null
						? 100
						: productModule.Attribution_Percentage__c < 1
								? productModule.Attribution_Percentage__c * 100
								: productModule.Attribution_Percentage__c;

					prorateMultiplier = subscription.ELV_ProrateMultiplier__c;
					subscrListPrice = subscription.Ruby__ListPrice__c;
					subscrNetPrice = subscription.Ruby__NetSellerPrice__c;
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

		List<Product_Module__c> productModules = [
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
		List<Product_Module__c> productModules = [
			SELECT Id, Product__c, Attribution_Percentage__c
			FROM Product_Module__c
			WHERE Product__c IN :productIds
		];

		for (Product_Module__c productModule : productModules) {
			productIdProductModuleMap.put(productModule.Product__c, productModule);
		}
		return productIdProductModuleMap;
	}

	public static void deletePriorData(Id opportunityId) {
		Set<Id> subscription_MigrationIds = new Set<Id>();
		List<Database.DeleteResult> deleteResults;
		List<Solution_Migration__c> solution_Migrations = [
			SELECT Id
			FROM Solution_Migration__c
			WHERE Opportunity__c = :opportunityId AND Manual_Entry__c = FALSE
		];
		List<Subscription_Aggregate_Migration__c> subscription_Aggregate_Migrations = [
			SELECT Id
			FROM Subscription_Aggregate_Migration__c
			WHERE Opportunity__c = :opportunityId AND Manual_Entry__c = FALSE
		];

		Map<Id, Subscription_Migration__c> subscription_MigrationMap = new Map<Id, Subscription_Migration__c>(
			[
				SELECT Id
				FROM Subscription_Migration__c
				WHERE Opportunity__c = :opportunityId AND Manual_Entry__c = FALSE
			]
		);
		subscription_MigrationIds.addAll(subscription_MigrationMap.keySet());

		List<Module_Migration__c> module_Migrations = [
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
					Potential_AEM_Migration_ARR__c,
					Tanium_Software_ARR__c
				FROM Opportunity
				WHERE Id = :oppId
			]
		);
		Id jobId = Test.isRunningTest() ? null : System.enqueueJob(async);
	}
}