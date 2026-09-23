/**
 *  Copyright (c) 2025 Tanium
 *
 * @Business: Class that supports Product Migratrion functionality
 * @Date:     2025-03-08
 * @Author:   Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-10411   2025-03-08    Created the class
 * SS-10942   2025-05-28    Added method deDuplicateModule_MigrationStdPlus
 * SS-11735   2025-09-17    Updated method deDuplicateModule_MigrationStdPlus
 * SS-12213   2025-12-08    Updated method deDuplicateModule_MigrationStdPlus
 * SS-11576   2025-12-08    Updated class to support non-AEM products
 * SS-13771   2026-08-18    Updated class as part of Elevate project
 */

public class ProductMigrationData {
	public static final Id GLOBAL_PRICEBOOK_ID = Test.isRunningTest()
		? TestFactory.STANDARD_PRICEBOOK_ID
		: [SELECT Id FROM Pricebook2 WHERE Name = 'Global Pricebook' LIMIT 1].Id;
	private static final String CORE_SUBSCRIPTION = 'Core Subscription';
	private static final String CORE_TAAS = 'Core TaaS';
	private static final String EM_SUBSCRIPTION = 'EM Subscription';
	private static final String EM_TAAS = 'EM TaaS';
	private static final String IR_SUBSCRIPTION = 'IR Subscription';
	private static final String IR_TAAS = 'IR TaaS';
	private static final String RC_SUBSCRIPTION = 'RC Subscription';
	private static final String RC_TAAS = 'RC TaaS';
	private static final Set<String> VALID_AEM_PRODUCT_GROUPS = new Set<String>{
		CORE_SUBSCRIPTION,
		CORE_TAAS,
		EM_SUBSCRIPTION,
		EM_TAAS,
		IR_SUBSCRIPTION,
		IR_TAAS,
		RC_SUBSCRIPTION,
		RC_TAAS
	};

	public List<SubscriptionMigration> subscriptionMigrations { get; set; }
	public List<SubscriptionAggregateMigration> subscriptionAggregateMigrations { get; set; }
	public List<SolutionMigration> solutionMigrations { get; set; }
	public List<ModuleMigration> allModuleMigrations { get; set; }
	public Boolean isPromo;

	public ProductMigrationData() {
		subscriptionMigrations = new List<SubscriptionMigration>();
		subscriptionAggregateMigrations = new List<SubscriptionAggregateMigration>();
		solutionMigrations = new List<SolutionMigration>();
		allModuleMigrations = new List<ModuleMigration>();
		isPromo = false;
	}

	public void addSubscriptionMigrations(List<Ruby__Subscription__c> subscriptions) {
		for (Ruby__Subscription__c subscription : subscriptions) {
			this.subscriptionMigrations.add(new SubscriptionMigration(subscription));
		}
	}

	public SubscriptionMigration getSubscriptionMigration(Id subscriptionId) {
		for (SubscriptionMigration subscriptionMigration : this.subscriptionMigrations) {
			if (subscriptionMigration.subscriptionId == subscriptionId) {
				return subscriptionMigration;
			}
		}
		return null;
	}

	public void insertSubscription_Migrations() {
		List<Subscription_Migration__c> subscription_Migrations = new List<Subscription_Migration__c>();
		Subscription_Migration__c subscription_Migration;

		for (SubscriptionMigration subscriptionMigration : this.subscriptionMigrations) {
			subscription_Migration = new Subscription_Migration__c();
			subscription_Migration.Opportunity__c = subscriptionMigration.opportunityId;
			subscription_Migration.ELV_Subscription__c = subscriptionMigration.subscriptionId;
			subscription_Migration.Subscription_Product__c = subscriptionMigration.subscriptionProductId;
			subscription_Migration.Non_AEM_Product__c = subscriptionMigration.nonAemProduct;
			subscription_Migrations.add(subscription_Migration);
		}
		List<Database.SaveResult> saveResults = Database.insert(subscription_Migrations, false);
		logSaveResultErrors('insertSubscription_Migrations', saveResults);
	}

	public void updateSubscription_Migrations() {
		List<Subscription_Migration__c> subscription_Migrations = new List<Subscription_Migration__c>();

		for (SubscriptionMigration subscriptionMigration : this.subscriptionMigrations) {
			if (subscriptionMigration.subscriptionAggregateMigration != null) {
				subscription_Migrations.add(
					new Subscription_Migration__c(
						Id = subscriptionMigration.id,
						Subscription_Aggregate_Migration__c = subscriptionMigration.subscriptionAggregateMigration.id
					)
				);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(subscription_Migrations, false);
		logSaveResultErrors('updateSubscription_Migrations', saveResults);
	}

	public void syncSubscriptionMigrations(Id opportunityId) {
		Map<Id, Id> subscriptionIdSubscriptionMigrationIdMap = new Map<Id, Id>();

		for (Subscription_Migration__c subscription_Migration : [
			SELECT Id, ELV_Subscription__c, Subscription_Product__c
			FROM Subscription_Migration__c
			WHERE Opportunity__c = :opportunityId AND Manual_Entry__c = FALSE
		]) {
			subscriptionIdSubscriptionMigrationIdMap.put(
				subscription_Migration.ELV_Subscription__c,
				subscription_Migration.Id
			);
		}

		for (SubscriptionMigration subscriptionMigration : this.subscriptionMigrations) {
			subscriptionMigration.id = subscriptionIdSubscriptionMigrationIdMap.get(
				subscriptionMigration.subscriptionId
			);
		}
	}

	public void modifySubscriptionMigrations() {
		for (SubscriptionMigration subscriptionMigration : this.subscriptionMigrations) {
			for (
				SubscriptionAggregateMigration subscriptionAggregateMigration : this.subscriptionAggregateMigrations
			) {
				for (
					Id subscription_MigrationId : subscriptionAggregateMigration.subscription_MigrationIds
				)
					if (subscription_MigrationId == subscriptionMigration.id) {
						subscriptionMigration.subscriptionAggregateMigration = subscriptionAggregateMigration;
					}
			}
		}
	}

	public void insertModule_Migrations() {
		List<Module_Migration__c> module_Migrations = new List<Module_Migration__c>();
		Module_Migration__c module_Migration;

		for (SubscriptionMigration subscriptionMigration : this.subscriptionMigrations) {
			this.allModuleMigrations.addAll(subscriptionMigration.getModuleMigrations());
		}

		for (ModuleMigration moduleMigration : this.allModuleMigrations) {
			module_Migration = new Module_Migration__c(
				Subscription_Migration__c = moduleMigration.subscriptionMigrationId,
				Module_Name__c = moduleMigration.moduleName,
				Product__c = moduleMigration.productId,
				Segment__c = moduleMigration.segment,
				AEM_Product_Group__c = moduleMigration.aemProductGroup,
				AEM_Solution__c = moduleMigration.aemProductId,
				Allocation_Percent__c = moduleMigration.allocationPct,
				Allocation_List_Price__c = moduleMigration.allocationListPrice,
				Allocation_Net_Price__c = moduleMigration.allocationNetPrice,
				Source__c = moduleMigration.source
			);
			module_Migrations.add(module_Migration);
		}

		List<Database.SaveResult> saveResults = Database.insert(module_Migrations, false);
		logSaveResultErrors('insertModule_Migrations', saveResults);
	}

	public void addSubscriptionAggregateMigrations(Id opportunityId) {
		List<Subscription_Migration__c> subscription_Migrations;
		Map<Id, Subscription_Migration__c> subscription_MigrationMap = new Map<Id, Subscription_Migration__c>(
			[
				SELECT
					Id,
					Name,
					Opportunity__c,
					Core_Subscription_Allocation_Percent__c,
					Core_Subscription_List_Price__c,
					Core_Subscription_Net_Price__c,
					Core_TaaS_Allocation_Percent__c,
					Core_TaaS_List_Price__c,
					Core_TaaS_Net_Price__c,
					EM_Subscription_Allocation_Percent__c,
					EM_Subscription_List_Price__c,
					EM_Subscription_Net_Price__c,
					EM_TaaS_Allocation_Percent__c,
					EM_TaaS_List_Price__c,
					EM_TaaS_Net_Price__c,
					IR_Subscription_Allocation_Percent__c,
					IR_Subscription_List_Price__c,
					IR_Subscription_Net_Price__c,
					IR_TaaS_Allocation_Percent__c,
					IR_TaaS_List_Price__c,
					IR_TaaS_Net_Price__c,
					RC_Subscription_Allocation_Percent__c,
					RC_Subscription_List_Price__c,
					RC_Subscription_Net_Price__c,
					RC_TaaS_Allocation_Percent__c,
					RC_TaaS_List_Price__c,
					RC_TaaS_Net_Price__c,
					Subscription_Quantity__c,
					Subscription_Product__c
				FROM Subscription_Migration__c
				WHERE
					Opportunity__c = :opportunityId
					AND Manual_Entry__c = FALSE
					AND Non_AEM_Product__c = FALSE
				ORDER BY Subscription_Product__c
			]
		);
		Set<Id> subscription_MigrationIds = new Set<Id>();
		Id priorProductId = null;
		Id priorSubscription_MigrationId;

		for (Subscription_Migration__c subscription_Migration : subscription_MigrationMap.values()) {
			if (subscription_Migration.Subscription_Product__c == priorProductId) {
				subscription_MigrationIds.add(subscription_Migration.Id);
				subscription_MigrationIds.add(priorSubscription_MigrationId);
			}
			priorSubscription_MigrationId = subscription_Migration.Id;
			priorProductId = subscription_Migration.Subscription_Product__c;
		}

		for (Id subscription_MigrationId : subscription_MigrationMap.keySet()) {
			if (!subscription_MigrationIds.contains(subscription_MigrationId)) {
				subscription_MigrationMap.remove(subscription_MigrationId);
			}
		}

		priorProductId = null;
		for (Subscription_Migration__c subscription_Migration : subscription_MigrationMap.values()) {
			if (subscription_Migration.Subscription_Product__c != priorProductId) {
				if (priorProductId != null) {
					addSubscriptionAggregateMigration(subscription_Migrations);
				}
				subscription_Migrations = new List<Subscription_Migration__c>();
				subscription_Migrations.add(subscription_Migration);
			}
			if (subscription_Migration.Subscription_Product__c == priorProductId) {
				subscription_Migrations.add(subscription_Migration);
			}
			priorProductId = subscription_Migration.Subscription_Product__c;
		}
		if (priorProductId != null && !subscription_Migrations.isEmpty()) {
			addSubscriptionAggregateMigration(subscription_Migrations);
		}
	}

	private void addSubscriptionAggregateMigration(
		List<Subscription_Migration__c> subscription_Migrations
	) {
		Decimal netPrice = 0;
		Decimal listPrice = 0;
		Decimal quantity = 0;
		Set<Id> subscription_MigrationIds = new Set<Id>();

		for (Subscription_Migration__c subscription_Migration : subscription_Migrations) {
			quantity += subscription_Migration.Subscription_Quantity__c;
			subscription_MigrationIds.add(subscription_Migration.Id);
		}
		this.subscriptionAggregateMigrations.add(
			new SubscriptionAggregateMigration(
				subscription_Migrations[0].Name.substringAfter('-'),
				subscription_Migrations[0].Opportunity__c,
				subscription_Migrations[0].Subscription_Product__c,
				subscription_Migrations[0].Core_Subscription_Allocation_Percent__c,
				getMaxListPrice(subscription_Migrations, 'Core_Subscription_List_Price__c'),
				getMaxNetPrice(subscription_Migrations, 'Core_Subscription_Net_Price__c'),
				subscription_Migrations[0].Core_TaaS_Allocation_Percent__c,
				getMaxListPrice(subscription_Migrations, 'Core_TaaS_List_Price__c'),
				getMaxNetPrice(subscription_Migrations, 'Core_TaaS_Net_Price__c'),
				subscription_Migrations[0].EM_Subscription_Allocation_Percent__c,
				getMaxListPrice(subscription_Migrations, 'EM_Subscription_List_Price__c'),
				getMaxNetPrice(subscription_Migrations, 'EM_Subscription_Net_Price__c'),
				subscription_Migrations[0].EM_TaaS_Allocation_Percent__c,
				getMaxListPrice(subscription_Migrations, 'EM_TaaS_List_Price__c'),
				getMaxNetPrice(subscription_Migrations, 'EM_TaaS_Net_Price__c'),
				subscription_Migrations[0].IR_Subscription_Allocation_Percent__c,
				getMaxListPrice(subscription_Migrations, 'IR_Subscription_List_Price__c'),
				getMaxNetPrice(subscription_Migrations, 'IR_Subscription_Net_Price__c'),
				subscription_Migrations[0].IR_TaaS_Allocation_Percent__c,
				getMaxListPrice(subscription_Migrations, 'IR_TaaS_List_Price__c'),
				getMaxNetPrice(subscription_Migrations, 'IR_TaaS_Net_Price__c'),
				subscription_Migrations[0].RC_Subscription_Allocation_Percent__c,
				getMaxListPrice(subscription_Migrations, 'RC_Subscription_List_Price__c'),
				getMaxNetPrice(subscription_Migrations, 'RC_Subscription_Net_Price__c'),
				subscription_Migrations[0].RC_TaaS_Allocation_Percent__c,
				getMaxListPrice(subscription_Migrations, 'RC_TaaS_List_Price__c'),
				getMaxNetPrice(subscription_Migrations, 'RC_TaaS_Net_Price__c'),
				quantity,
				subscription_MigrationIds
			)
		);
	}

	public Decimal getMaxNetPrice(
		List<Subscription_Migration__c> subscription_Migrations,
		String field
	) {
		Decimal maxNetPrice = 0;

		for (Subscription_Migration__c subscription_Migration : subscription_Migrations) {
			switch on field {
				when 'Core_Subscription_Net_Price__c' {
					if (subscription_Migration.Core_Subscription_Net_Price__c > maxNetPrice) {
						maxNetPrice = subscription_Migration.Core_Subscription_Net_Price__c;
					}
				}
				when 'Core_TaaS_Net_Price__c' {
					if (subscription_Migration.Core_TaaS_Net_Price__c > maxNetPrice) {
						maxNetPrice = subscription_Migration.Core_TaaS_Net_Price__c;
					}
				}
				when 'EM_Subscription_Net_Price__c' {
					if (subscription_Migration.EM_Subscription_Net_Price__c > maxNetPrice) {
						maxNetPrice = subscription_Migration.EM_Subscription_Net_Price__c;
					}
				}
				when 'EM_TaaS_Net_Price__c' {
					if (subscription_Migration.EM_TaaS_Net_Price__c > maxNetPrice) {
						maxNetPrice = subscription_Migration.EM_TaaS_Net_Price__c;
					}
				}
				when 'IR_Subscription_Net_Price__c' {
					if (subscription_Migration.IR_Subscription_Net_Price__c > maxNetPrice) {
						maxNetPrice = subscription_Migration.IR_Subscription_Net_Price__c;
					}
				}
				when 'IR_TaaS_Net_Price__c' {
					if (subscription_Migration.IR_TaaS_Net_Price__c > maxNetPrice) {
						maxNetPrice = subscription_Migration.IR_TaaS_Net_Price__c;
					}
				}
				when 'RC_Subscription_Net_Price__c' {
					if (subscription_Migration.RC_Subscription_Net_Price__c > maxNetPrice) {
						maxNetPrice = subscription_Migration.RC_Subscription_Net_Price__c;
					}
				}
				when 'RC_TaaS_Net_Price__c' {
					if (subscription_Migration.RC_TaaS_Net_Price__c > maxNetPrice) {
						maxNetPrice = subscription_Migration.RC_TaaS_Net_Price__c;
					}
				}
			}
		}
		return maxNetPrice;
	}

	public Decimal getMaxListPrice(
		List<Subscription_Migration__c> subscription_Migrations,
		String field
	) {
		Decimal maxListPrice = 0;

		for (Subscription_Migration__c subscription_Migration : subscription_Migrations) {
			switch on field {
				when 'Core_Subscription_List_Price__c' {
					if (subscription_Migration.Core_Subscription_List_Price__c > maxListPrice) {
						maxListPrice = subscription_Migration.Core_Subscription_List_Price__c;
					}
				}
				when 'Core_TaaS_List_Price__c' {
					if (subscription_Migration.Core_TaaS_List_Price__c > maxListPrice) {
						maxListPrice = subscription_Migration.Core_TaaS_List_Price__c;
					}
				}
				when 'EM_Subscription_List_Price__c' {
					if (subscription_Migration.EM_Subscription_List_Price__c > maxListPrice) {
						maxListPrice = subscription_Migration.EM_Subscription_List_Price__c;
					}
				}
				when 'EM_TaaS_List_Price__c' {
					if (subscription_Migration.EM_TaaS_List_Price__c > maxListPrice) {
						maxListPrice = subscription_Migration.EM_TaaS_List_Price__c;
					}
				}
				when 'IR_Subscription_List_Price__c' {
					if (subscription_Migration.IR_Subscription_List_Price__c > maxListPrice) {
						maxListPrice = subscription_Migration.IR_Subscription_List_Price__c;
					}
				}
				when 'IR_TaaS_List_Price__c' {
					if (subscription_Migration.IR_TaaS_List_Price__c > maxListPrice) {
						maxListPrice = subscription_Migration.IR_TaaS_List_Price__c;
					}
				}
				when 'RC_Subscription_List_Price__c' {
					if (subscription_Migration.RC_Subscription_List_Price__c > maxListPrice) {
						maxListPrice = subscription_Migration.RC_Subscription_List_Price__c;
					}
				}
				when 'RC_TaaS_List_Price__c' {
					if (subscription_Migration.RC_TaaS_List_Price__c > maxListPrice) {
						maxListPrice = subscription_Migration.RC_TaaS_List_Price__c;
					}
				}
			}
		}
		return maxListPrice;
	}

	public void insertSubscription_Aggregate_Migrations() {
		List<Subscription_Aggregate_Migration__c> subscription_Aggregate_Migrations = new List<Subscription_Aggregate_Migration__c>();
		Subscription_Aggregate_Migration__c subscription_Aggregate_Migration;

		for (
			ProductMigrationData.SubscriptionAggregateMigration subscriptionAggregateMigration : subscriptionAggregateMigrations
		) {
			subscription_Aggregate_Migration = new Subscription_Aggregate_Migration__c();
			subscription_Aggregate_Migration.Name = subscriptionAggregateMigration.name;
			subscription_Aggregate_Migration.Opportunity__c = subscriptionAggregateMigration.opportunityId;
			subscription_Aggregate_Migration.Product__c = subscriptionAggregateMigration.productId;
			subscription_Aggregate_Migration.Core_Subscription_Allocation_Percent__c = subscriptionAggregateMigration.coreSubscriptionAllocationPct;
			subscription_Aggregate_Migration.Core_Subscription_Net_Price__c = subscriptionAggregateMigration.coreSubscriptionNetPrice;
			subscription_Aggregate_Migration.Core_Subscription_List_Price__c = subscriptionAggregateMigration.coreSubscriptionListPrice;
			subscription_Aggregate_Migration.Core_TaaS_Allocation_Percent__c = subscriptionAggregateMigration.coreTaasAllocationPct;
			subscription_Aggregate_Migration.Core_TaaS_Net_Price__c = subscriptionAggregateMigration.coreTaasNetPrice;
			subscription_Aggregate_Migration.Core_TaaS_List_Price__c = subscriptionAggregateMigration.coreTaasListPrice;
			subscription_Aggregate_Migration.EM_Subscription_Allocation_Percent__c = subscriptionAggregateMigration.emSubscriptionAllocationPct;
			subscription_Aggregate_Migration.EM_Subscription_Net_Price__c = subscriptionAggregateMigration.emSubscriptionNetPrice;
			subscription_Aggregate_Migration.EM_Subscription_List_Price__c = subscriptionAggregateMigration.emSubscriptionListPrice;
			subscription_Aggregate_Migration.EM_TaaS_Allocation_Percent__c = subscriptionAggregateMigration.emTaasAllocationPct;
			subscription_Aggregate_Migration.EM_TaaS_Net_Price__c = subscriptionAggregateMigration.emTaasNetPrice;
			subscription_Aggregate_Migration.EM_TaaS_List_Price__c = subscriptionAggregateMigration.emTaasListPrice;
			subscription_Aggregate_Migration.IR_Subscription_Allocation_Percent__c = subscriptionAggregateMigration.irSubscriptionAllocationPct;
			subscription_Aggregate_Migration.IR_Subscription_Net_Price__c = subscriptionAggregateMigration.irSubscriptionNetPrice;
			subscription_Aggregate_Migration.IR_Subscription_List_Price__c = subscriptionAggregateMigration.irSubscriptionListPrice;
			subscription_Aggregate_Migration.IR_TaaS_Allocation_Percent__c = subscriptionAggregateMigration.irTaasAllocationPct;
			subscription_Aggregate_Migration.IR_TaaS_Net_Price__c = subscriptionAggregateMigration.irTaasNetPrice;
			subscription_Aggregate_Migration.IR_TaaS_List_Price__c = subscriptionAggregateMigration.irTaasListPrice;
			subscription_Aggregate_Migration.RC_Subscription_Allocation_Percent__c = subscriptionAggregateMigration.rcSubscriptionAllocationPct;
			subscription_Aggregate_Migration.RC_Subscription_Net_Price__c = subscriptionAggregateMigration.rcSubscriptionNetPrice;
			subscription_Aggregate_Migration.RC_Subscription_List_Price__c = subscriptionAggregateMigration.rcSubscriptionListPrice;
			subscription_Aggregate_Migration.RC_TaaS_Allocation_Percent__c = subscriptionAggregateMigration.rcTaasAllocationPct;
			subscription_Aggregate_Migration.RC_TaaS_Net_Price__c = subscriptionAggregateMigration.rcTaasNetPrice;
			subscription_Aggregate_Migration.RC_TaaS_List_Price__c = subscriptionAggregateMigration.rcTaasListPrice;
			subscription_Aggregate_Migration.Quantity__c = subscriptionAggregateMigration.quantity;
			subscription_Aggregate_Migration.SourceIds__c = String.join(
				subscriptionAggregateMigration.subscription_MigrationIds,
				','
			);
			subscription_Aggregate_Migrations.add(subscription_Aggregate_Migration);
		}
		List<Database.SaveResult> saveResults = Database.insert(
			subscription_Aggregate_Migrations,
			false
		);
		logSaveResultErrors('insertSubscription_Aggregate_Migrations', saveResults);
	}

	public void syncSubscriptionAggregateMigrations(Id opportunityId) {
		Map<String, Subscription_Aggregate_Migration__c> subscription_Aggregate_MigrationNameSubscription_Aggregate_MigrationMap = new Map<String, Subscription_Aggregate_Migration__c>();

		for (Subscription_Aggregate_Migration__c subscription_Aggregate_Migration : [
			SELECT Id, Name
			FROM Subscription_Aggregate_Migration__c
			WHERE Opportunity__c = :opportunityId AND Manual_Entry__c = FALSE
		]) {
			subscription_Aggregate_MigrationNameSubscription_Aggregate_MigrationMap.put(
				subscription_Aggregate_Migration.Name,
				subscription_Aggregate_Migration
			);
		}

		for (
			SubscriptionAggregateMigration subscriptionAggregateMigration : this.subscriptionAggregateMigrations
		) {
			try {
				subscriptionAggregateMigration.id = subscription_Aggregate_MigrationNameSubscription_Aggregate_MigrationMap.get(
						subscriptionAggregateMigration.name
					)
					.Id;
			} catch (Exception e) {
			}
		}
	}

	public void addSolutionMigrations(Opportunity opportunity) {
		for (String aemProductGroup : getAEMProductGroups()) {
			this.solutionMigrations.add(
				new SolutionMigration(opportunity, aemProductGroup, this.isPromo)
			);
		}
	}

	public void insertSolution_Migrations() {
		List<Solution_Migration__c> solution_Migrations = new List<Solution_Migration__c>();
		Solution_Migration__c solution_Migration;

		for (ProductMigrationData.SolutionMigration solutionMigration : this.solutionMigrations) {
			solution_Migration = new Solution_Migration__c();
			solution_Migration.Name = solutionMigration.Name;
			solution_Migration.Opportunity__c = solutionMigration.opportunityId;
			solution_Migration.AEM_Product_Group__c = solutionMigration.aemProductGroup;
			solution_Migration.Migration_Discount__c = solutionMigration.migrationDiscount * 100;
			solution_Migration.Uplift_Percent__c = solutionMigration.upliftPercent * 100;
			solution_Migration.Uplift_Unit_Price__c = solutionMigration.upliftUnitPrice;
			solution_Migration.Start_Date__c = solutionMigration.startDate;
			solution_Migrations.add(solution_Migration);
		}
		List<Database.SaveResult> saveResults = Database.insert(solution_Migrations, false);
		logSaveResultErrors('insertSolution_Migrations', saveResults);
	}

	public void syncSolutionMigrations(Id opportunityId) {
		Map<String, Solution_Migration__c> solution_MigrationNameSolution_MigrationMap = new Map<String, Solution_Migration__c>();

		for (Solution_Migration__c solution_Migration : [
			SELECT
				Id,
				Name,
				Legacy_Discount__c,
				Uplift_Partner_Migration_Percent__c,
				AEM_Solution_Net_Total_Price__c
			FROM Solution_Migration__c
			WHERE Opportunity__c = :opportunityId AND Manual_Entry__c = FALSE
		]) {
			solution_MigrationNameSolution_MigrationMap.put(
				solution_Migration.Name,
				solution_Migration
			);
		}

		for (SolutionMigration solutionMigration : this.solutionMigrations) {
			solutionMigration.id = solution_MigrationNameSolution_MigrationMap.get(
					solutionMigration.name
				)
				.Id;
			solutionMigration.legacyDiscount = solution_MigrationNameSolution_MigrationMap.get(
					solutionMigration.name
				)
				.Legacy_Discount__c;
			solutionMigration.upliftPartnerMigrationPercent = solution_MigrationNameSolution_MigrationMap.get(
					solutionMigration.name
				)
				.Uplift_Partner_Migration_Percent__c;
			solutionMigration.aemSolutionTotal = solution_MigrationNameSolution_MigrationMap.get(
					solutionMigration.name
				)
				.AEM_Solution_Net_Total_Price__c;
		}
	}

	public void modifySolutionMigrations(Id opportunityId) {
		Set<Id> opportunityIds = new Set<Id>();
		Decimal coreSubscriptionAllocationPct = 0;
		Decimal coreSubscriptionNetTotal = 0;
		Decimal coreSubscriptionListTotal = 0;
		Decimal coreSubscriptionMaxQuantity = 0;
		Decimal coreTaasAllocationPct = 0;
		Decimal coreTaasNetTotal = 0;
		Decimal coreTaasListTotal = 0;
		Decimal coreTaasMaxQuantity = 0;
		Decimal emSubscriptionAllocationPct = 0;
		Decimal emSubscriptionNetTotal = 0;
		Decimal emSubscriptionListTotal = 0;
		Decimal emSubscriptionMaxQuantity = 0;
		Decimal emTaasAllocationPct = 0;
		Decimal emTaasNetTotal = 0;
		Decimal emTaasListTotal = 0;
		Decimal emTaasMaxQuantity = 0;
		Decimal irSubscriptionAllocationPct = 0;
		Decimal irSubscriptionNetTotal = 0;
		Decimal irSubscriptionListTotal = 0;
		Decimal irSubscriptionMaxQuantity = 0;
		Decimal irTaasAllocationPct = 0;
		Decimal irTaasNetTotal = 0;
		Decimal irTaasListTotal = 0;
		Decimal irTaasMaxQuantity = 0;
		Decimal rcSubscriptionAllocationPct = 0;
		Decimal rcSubscriptionNetTotal = 0;
		Decimal rcSubscriptionListTotal = 0;
		Decimal rcSubscriptionMaxQuantity = 0;
		Decimal rcTaasAllocationPct = 0;
		Decimal rcTaasNetTotal = 0;
		Decimal rcTaasListTotal = 0;
		Decimal rcTaasMaxQuantity = 0;
		Decimal legacyDiscount = 0;
		Decimal migrationUnitPrice = 0;
		Decimal upliftUnitPrice = 0;
		Map<String, Id> aemProductGroupNameAemSolutionIdMap = new Map<String, Id>();
		Set<Id> subscriptionAggregateMigrationIds = new Set<Id>();

		List<Subscription_Migration__c> subscription_Migrations = [
			SELECT
				Id,
				Core_Subscription_Allocation_Percent__c,
				Core_Subscription_List_Price__c,
				Core_Subscription_Net_Price__c,
				Core_TaaS_Allocation_Percent__c,
				Core_TaaS_List_Price__c,
				Core_TaaS_Net_Price__c,
				EM_Subscription_Allocation_Percent__c,
				EM_Subscription_List_Price__c,
				EM_Subscription_Net_Price__c,
				EM_TaaS_Allocation_Percent__c,
				EM_TaaS_List_Price__c,
				EM_TaaS_Net_Price__c,
				IR_Subscription_Allocation_Percent__c,
				IR_Subscription_List_Price__c,
				IR_Subscription_Net_Price__c,
				IR_TaaS_Allocation_Percent__c,
				IR_TaaS_List_Price__c,
				IR_TaaS_Net_Price__c,
				RC_Subscription_Allocation_Percent__c,
				RC_Subscription_List_Price__c,
				RC_Subscription_Net_Price__c,
				RC_TaaS_Allocation_Percent__c,
				RC_TaaS_List_Price__c,
				RC_TaaS_Net_Price__c,
				Subscription_Quantity__c,
				Subscription_Aggregate_Migration__c
			FROM Subscription_Migration__c
			WHERE
				Opportunity__c = :opportunityId
				AND Manual_Entry__c = FALSE
				AND Non_AEM_Product__c = FALSE
		];

		for (Subscription_Migration__c subscription_Migration : subscription_Migrations) {
			if (subscription_Migration.Subscription_Aggregate_Migration__c != null) {
				subscriptionAggregateMigrationIds.add(
					subscription_Migration.Subscription_Aggregate_Migration__c
				);
				continue;
			}
			coreSubscriptionAllocationPct += subscription_Migration.Core_Subscription_Allocation_Percent__c;
			coreSubscriptionListTotal +=
				subscription_Migration.Core_Subscription_List_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			coreSubscriptionNetTotal +=
				subscription_Migration.Core_Subscription_Net_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			coreTaasAllocationPct += subscription_Migration.Core_TaaS_Allocation_Percent__c;
			coreTaasListTotal +=
				subscription_Migration.Core_TaaS_List_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			coreTaasNetTotal +=
				subscription_Migration.Core_TaaS_Net_Price__c *
				subscription_Migration.Subscription_Quantity__c;

			emSubscriptionAllocationPct += subscription_Migration.EM_Subscription_Allocation_Percent__c;
			emSubscriptionListTotal +=
				subscription_Migration.EM_Subscription_List_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			emSubscriptionNetTotal +=
				subscription_Migration.EM_Subscription_Net_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			emTaasAllocationPct += subscription_Migration.EM_TaaS_Allocation_Percent__c;
			emTaasListTotal +=
				subscription_Migration.EM_TaaS_List_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			emTaasNetTotal +=
				subscription_Migration.EM_TaaS_Net_Price__c *
				subscription_Migration.Subscription_Quantity__c;

			irSubscriptionAllocationPct += subscription_Migration.IR_Subscription_Allocation_Percent__c;
			irSubscriptionListTotal +=
				subscription_Migration.IR_Subscription_List_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			irSubscriptionNetTotal +=
				subscription_Migration.IR_Subscription_Net_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			irTaasAllocationPct += subscription_Migration.IR_TaaS_Allocation_Percent__c;
			irTaasListTotal +=
				subscription_Migration.IR_TaaS_List_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			irTaasNetTotal +=
				subscription_Migration.IR_TaaS_Net_Price__c *
				subscription_Migration.Subscription_Quantity__c;

			rcSubscriptionAllocationPct += subscription_Migration.RC_Subscription_Allocation_Percent__c;
			rcSubscriptionListTotal +=
				subscription_Migration.RC_Subscription_List_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			rcSubscriptionNetTotal +=
				subscription_Migration.RC_Subscription_Net_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			rcTaasAllocationPct += subscription_Migration.RC_TaaS_Allocation_Percent__c;
			rcTaasListTotal +=
				subscription_Migration.RC_TaaS_List_Price__c *
				subscription_Migration.Subscription_Quantity__c;
			rcTaasNetTotal +=
				subscription_Migration.RC_TaaS_Net_Price__c *
				subscription_Migration.Subscription_Quantity__c;

			if (subscription_Migration.Core_Subscription_List_Price__c > 0) {
				if (coreSubscriptionMaxQuantity < subscription_Migration.Subscription_Quantity__c) {
					coreSubscriptionMaxQuantity = subscription_Migration.Subscription_Quantity__c;
				}
			}
			if (subscription_Migration.Core_TaaS_List_Price__c > 0) {
				if (coreTaasMaxQuantity < subscription_Migration.Subscription_Quantity__c) {
					coreTaasMaxQuantity = subscription_Migration.Subscription_Quantity__c;
				}
			}
			if (subscription_Migration.EM_Subscription_List_Price__c > 0) {
				if (emSubscriptionMaxQuantity < subscription_Migration.Subscription_Quantity__c) {
					emSubscriptionMaxQuantity = subscription_Migration.Subscription_Quantity__c;
				}
			}
			if (subscription_Migration.EM_TaaS_List_Price__c > 0) {
				if (emTaasMaxQuantity < subscription_Migration.Subscription_Quantity__c) {
					emTaasMaxQuantity = subscription_Migration.Subscription_Quantity__c;
				}
			}
			if (subscription_Migration.IR_Subscription_List_Price__c > 0) {
				if (irSubscriptionMaxQuantity < subscription_Migration.Subscription_Quantity__c) {
					irSubscriptionMaxQuantity = subscription_Migration.Subscription_Quantity__c;
				}
			}
			if (subscription_Migration.IR_TaaS_List_Price__c > 0) {
				if (irTaasMaxQuantity < subscription_Migration.Subscription_Quantity__c) {
					irTaasMaxQuantity = subscription_Migration.Subscription_Quantity__c;
				}
			}
			if (subscription_Migration.RC_Subscription_List_Price__c > 0) {
				if (rcSubscriptionMaxQuantity < subscription_Migration.Subscription_Quantity__c) {
					rcSubscriptionMaxQuantity = subscription_Migration.Subscription_Quantity__c;
				}
			}
			if (subscription_Migration.RC_TaaS_List_Price__c > 0) {
				if (rcTaasMaxQuantity < subscription_Migration.Subscription_Quantity__c) {
					rcTaasMaxQuantity = subscription_Migration.Subscription_Quantity__c;
				}
			}
		}

		for (Subscription_Aggregate_Migration__c subscription_Aggregate_Migration : [
			SELECT
				Id,
				Core_Subscription_Allocation_Percent__c,
				Core_Subscription_List_Price__c,
				Core_Subscription_Net_Price__c,
				Core_TaaS_Allocation_Percent__c,
				Core_TaaS_List_Price__c,
				Core_TaaS_Net_Price__c,
				EM_Subscription_Allocation_Percent__c,
				EM_Subscription_List_Price__c,
				EM_Subscription_Net_Price__c,
				EM_TaaS_Allocation_Percent__c,
				EM_TaaS_List_Price__c,
				EM_TaaS_Net_Price__c,
				IR_Subscription_Allocation_Percent__c,
				IR_Subscription_List_Price__c,
				IR_Subscription_Net_Price__c,
				IR_TaaS_Allocation_Percent__c,
				IR_TaaS_List_Price__c,
				IR_TaaS_Net_Price__c,
				RC_Subscription_Allocation_Percent__c,
				RC_Subscription_List_Price__c,
				RC_Subscription_Net_Price__c,
				RC_TaaS_Allocation_Percent__c,
				RC_TaaS_List_Price__c,
				RC_TaaS_Net_Price__c,
				Product__c,
				Quantity__c,
				SourceIds__c
			FROM Subscription_Aggregate_Migration__c
			WHERE Id IN :subscriptionAggregateMigrationIds
		]) {
			coreSubscriptionAllocationPct += subscription_Aggregate_Migration.Core_Subscription_Allocation_Percent__c;
			coreSubscriptionListTotal +=
				subscription_Aggregate_Migration.Core_Subscription_List_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			coreSubscriptionNetTotal +=
				subscription_Aggregate_Migration.Core_Subscription_Net_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			coreTaasAllocationPct += subscription_Aggregate_Migration.Core_TaaS_Allocation_Percent__c;
			coreTaasListTotal +=
				subscription_Aggregate_Migration.Core_TaaS_List_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			coreTaasNetTotal +=
				subscription_Aggregate_Migration.Core_TaaS_Net_Price__c *
				subscription_Aggregate_Migration.Quantity__c;

			emSubscriptionAllocationPct += subscription_Aggregate_Migration.EM_Subscription_Allocation_Percent__c;
			emSubscriptionListTotal +=
				subscription_Aggregate_Migration.EM_Subscription_List_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			emSubscriptionNetTotal +=
				subscription_Aggregate_Migration.EM_Subscription_Net_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			emTaasAllocationPct += subscription_Aggregate_Migration.EM_TaaS_Allocation_Percent__c;
			emTaasListTotal +=
				subscription_Aggregate_Migration.EM_TaaS_List_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			emTaasNetTotal +=
				subscription_Aggregate_Migration.EM_TaaS_Net_Price__c *
				subscription_Aggregate_Migration.Quantity__c;

			irSubscriptionAllocationPct += subscription_Aggregate_Migration.IR_Subscription_Allocation_Percent__c;
			irSubscriptionListTotal +=
				subscription_Aggregate_Migration.IR_Subscription_List_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			irSubscriptionNetTotal +=
				subscription_Aggregate_Migration.IR_Subscription_Net_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			irTaasAllocationPct += subscription_Aggregate_Migration.IR_TaaS_Allocation_Percent__c;
			irTaasListTotal +=
				subscription_Aggregate_Migration.IR_TaaS_List_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			irTaasNetTotal +=
				subscription_Aggregate_Migration.IR_TaaS_Net_Price__c *
				subscription_Aggregate_Migration.Quantity__c;

			rcSubscriptionAllocationPct += subscription_Aggregate_Migration.RC_Subscription_Allocation_Percent__c;
			rcSubscriptionListTotal +=
				subscription_Aggregate_Migration.RC_Subscription_List_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			rcSubscriptionNetTotal +=
				subscription_Aggregate_Migration.RC_Subscription_Net_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			rcTaasAllocationPct += subscription_Aggregate_Migration.RC_TaaS_Allocation_Percent__c;
			rcTaasListTotal +=
				subscription_Aggregate_Migration.RC_TaaS_List_Price__c *
				subscription_Aggregate_Migration.Quantity__c;
			rcTaasNetTotal +=
				subscription_Aggregate_Migration.RC_TaaS_Net_Price__c *
				subscription_Aggregate_Migration.Quantity__c;

			if (subscription_Aggregate_Migration.Core_Subscription_List_Price__c > 0) {
				if (coreSubscriptionMaxQuantity < subscription_Aggregate_Migration.Quantity__c) {
					coreSubscriptionMaxQuantity = subscription_Aggregate_Migration.Quantity__c;
				}
			}
			if (subscription_Aggregate_Migration.Core_TaaS_List_Price__c > 0) {
				if (coreTaasMaxQuantity < subscription_Aggregate_Migration.Quantity__c) {
					coreTaasMaxQuantity = subscription_Aggregate_Migration.Quantity__c;
				}
			}
			if (subscription_Aggregate_Migration.EM_Subscription_List_Price__c > 0) {
				if (emSubscriptionMaxQuantity < subscription_Aggregate_Migration.Quantity__c) {
					emSubscriptionMaxQuantity = subscription_Aggregate_Migration.Quantity__c;
				}
			}
			if (subscription_Aggregate_Migration.EM_TaaS_List_Price__c > 0) {
				if (emTaasMaxQuantity < subscription_Aggregate_Migration.Quantity__c) {
					emTaasMaxQuantity = subscription_Aggregate_Migration.Quantity__c;
				}
			}
			if (subscription_Aggregate_Migration.IR_Subscription_List_Price__c > 0) {
				if (irSubscriptionMaxQuantity < subscription_Aggregate_Migration.Quantity__c) {
					irSubscriptionMaxQuantity = subscription_Aggregate_Migration.Quantity__c;
				}
			}
			if (subscription_Aggregate_Migration.IR_TaaS_List_Price__c > 0) {
				if (irTaasMaxQuantity < subscription_Aggregate_Migration.Quantity__c) {
					irTaasMaxQuantity = subscription_Aggregate_Migration.Quantity__c;
				}
			}
			if (subscription_Aggregate_Migration.RC_Subscription_List_Price__c > 0) {
				if (rcSubscriptionMaxQuantity < subscription_Aggregate_Migration.Quantity__c) {
					rcSubscriptionMaxQuantity = subscription_Aggregate_Migration.Quantity__c;
				}
			}
			if (subscription_Aggregate_Migration.RC_TaaS_List_Price__c > 0) {
				if (rcTaasMaxQuantity < subscription_Aggregate_Migration.Quantity__c) {
					rcTaasMaxQuantity = subscription_Aggregate_Migration.Quantity__c;
				}
			}
		}

		List<Module_Migration__c> module_Migrations = [
			SELECT Id, AEM_Product_Group__c, AEM_Solution__c, AEM_Solution__r.Name
			FROM Module_Migration__c
			WHERE OpportunityId__c = :opportunityId AND Manual_Entry__c = FALSE
			ORDER BY AEM_Product_Group__c
		];

		for (
			Module_Migration__c module_Migration : deDuplicateModule_MigrationStdPlus(
				module_Migrations
			)
		) {
			aemProductGroupNameAemSolutionIdMap.put(
				module_Migration.AEM_Product_Group__c,
				module_Migration.AEM_Solution__c
			);
		}

		for (SolutionMigration solutionMigration : this.solutionMigrations) {
			if (solutionMigration.aemProductGroup == CORE_SUBSCRIPTION) {
				solutionMigration.legacyNetTotal = coreSubscriptionNetTotal;
				solutionMigration.legacyListTotal = coreSubscriptionListTotal;
				solutionMigration.maxQuantity = coreSubscriptionMaxQuantity;
			}
			if (solutionMigration.aemProductGroup == CORE_TAAS) {
				solutionMigration.legacyNetTotal = coreTaasNetTotal;
				solutionMigration.legacyListTotal = coreTaasListTotal;
				solutionMigration.maxQuantity = coreTaasMaxQuantity;
			}

			if (solutionMigration.aemProductGroup == EM_SUBSCRIPTION) {
				solutionMigration.legacyNetTotal = emSubscriptionNetTotal;
				solutionMigration.legacyListTotal = emSubscriptionListTotal;
				solutionMigration.maxQuantity = emSubscriptionMaxQuantity;
			}
			if (solutionMigration.aemProductGroup == EM_TAAS) {
				solutionMigration.legacyNetTotal = emTaasNetTotal;
				solutionMigration.legacyListTotal = emTaasListTotal;
				solutionMigration.maxQuantity = emTaasMaxQuantity;
			}
			if (solutionMigration.aemProductGroup == IR_SUBSCRIPTION) {
				solutionMigration.legacyNetTotal = irSubscriptionNetTotal;
				solutionMigration.legacyListTotal = irSubscriptionListTotal;
				solutionMigration.maxQuantity = irSubscriptionMaxQuantity;
			}
			if (solutionMigration.aemProductGroup == IR_TAAS) {
				solutionMigration.legacyNetTotal = irTaasNetTotal;
				solutionMigration.legacyListTotal = irTaasListTotal;
				solutionMigration.maxQuantity = irTaasMaxQuantity;
			}
			if (solutionMigration.aemProductGroup == RC_SUBSCRIPTION) {
				solutionMigration.legacyNetTotal = rcSubscriptionNetTotal;
				solutionMigration.legacyListTotal = rcSubscriptionListTotal;
				solutionMigration.maxQuantity = rcSubscriptionMaxQuantity;
			}
			if (solutionMigration.aemProductGroup == RC_TAAS) {
				solutionMigration.legacyNetTotal = rcTaasNetTotal;
				solutionMigration.legacyListTotal = rcTaasListTotal;
				solutionMigration.maxQuantity = rcTaasMaxQuantity;
			}
			solutionMigration.aemSolutionId = aemProductGroupNameAemSolutionIdMap.get(
				solutionMigration.aemProductGroup
			);
		}

		Map<Id, Decimal> aemSolutionIdsListPriceMap = getAemSolutionIdsListPriceMap(
			aemProductGroupNameAemSolutionIdMap.values()
		);

		for (SolutionMigration solutionMigration : this.solutionMigrations) {
			try {
				legacyDiscount =
					1 - (solutionMigration.legacyNetTotal / solutionMigration.legacyListTotal);
			} catch (Exception e) {
				legacyDiscount = 0;
			}
			solutionMigration.aemSolutionListPrice = aemSolutionIdsListPriceMap.get(
					solutionMigration.aemSolutionId
				) == null
				? 0
				: aemSolutionIdsListPriceMap.get(solutionMigration.aemSolutionId);
			solutionMigration.migrationUnitPrice =
				solutionMigration.aemSolutionListPrice *
				solutionMigration.maxQuantity *
				(1 - legacyDiscount) *
				(1 - solutionMigration.migrationDiscount);
			solutionMigration.upliftUnitPrice =
				solutionMigration.legacyNetTotal *
				(1 + (solutionMigration.upliftPartnerMigrationPercent / 100));
		}
	}

	private static List<Module_Migration__c> deDuplicateModule_MigrationStdPlus(
		List<Module_Migration__c> module_Migrations
	) {
		Map<String, Id> aemSolutionNameModule_MigrationIdMap = new Map<String, Id>();
		Set<Id> deDupedModule_MigrationIds = new Set<Id>();
		Boolean isCoreStdTaas = false;
		Boolean isCorePlusTaas = false;
		String coreStdTaasProductName;
		Boolean isCoreStdSubscription = false;
		Boolean isCorePlusSubscription = false;
		String coreStdSubscriptionProductName;
		Boolean isEmStdTaas = false;
		Boolean isEmPlusTaas = false;
		String emStdTaasProductName;
		Boolean isEmStdSubscription = false;
		Boolean isEmPlusSubscription = false;
		String emStdSubscriptionProductName;
		Boolean isRcStdTaas = false;
		Boolean isRcPlusTaas = false;
		String rcStdTaasProductName;
		Boolean isRcStdSubscription = false;
		Boolean isRcPlusSubscription = false;
		String rcStdSubscriptionProductName;

		for (Module_Migration__c module_Migration : module_Migrations) {
			aemSolutionNameModule_MigrationIdMap.put(
				module_Migration.AEM_Solution__r.Name,
				module_Migration.Id
			);
		}

		for (String aemSolutionName : aemSolutionNameModule_MigrationIdMap.keySet()) {
			if (String.isBlank(aemSolutionName)) {
				continue;
			}
			deDupedModule_MigrationIds.add(aemSolutionNameModule_MigrationIdMap.get(aemSolutionName));

			isCoreStdTaas = (!isCoreStdTaas)
				? aemSolutionName.contains('Core Standard') && aemSolutionName.contains('Tanium Cloud')
				: isCoreStdTaas;
			if (
				aemSolutionName.contains('Core Standard') && aemSolutionName.contains('Tanium Cloud')
			) {
				coreStdTaasProductName = aemSolutionName;
			}
			isCorePlusTaas = (!isCorePlusTaas)
				? aemSolutionName.contains('Core Plus') && aemSolutionName.contains('Tanium Cloud')
				: isCorePlusTaas;
			if (isCoreStdTaas && isCorePlusTaas) {
				deDupedModule_MigrationIds.remove(
					aemSolutionNameModule_MigrationIdMap.get(coreStdTaasProductName)
				);
			}

			isCoreStdSubscription = (!isCoreStdSubscription)
				? aemSolutionName.contains('Core Standard') && aemSolutionName.contains('Subscription')
				: isCoreStdSubscription;
			if (
				aemSolutionName.contains('Core Standard') && aemSolutionName.contains('Subscription')
			) {
				coreStdSubscriptionProductName = aemSolutionName;
			}
			isCorePlusSubscription = (!isCorePlusSubscription)
				? aemSolutionName.contains('Core Plus') && aemSolutionName.contains('Subscription')
				: isCorePlusSubscription;
			if (isCoreStdSubscription && isCorePlusSubscription) {
				deDupedModule_MigrationIds.remove(
					aemSolutionNameModule_MigrationIdMap.get(coreStdSubscriptionProductName)
				);
			}

			isEmStdTaas = (!isEmStdTaas)
				? aemSolutionName.contains('Endpoint Management Standard') &&
				  aemSolutionName.contains('Tanium Cloud')
				: isCoreStdTaas;
			if (
				aemSolutionName.contains('Endpoint Management Standard') &&
				aemSolutionName.contains('Tanium Cloud')
			) {
				emStdTaasProductName = aemSolutionName;
			}
			isEmPlusTaas = (!isEmPlusTaas)
				? aemSolutionName.contains('Endpoint Management Plus') &&
				  aemSolutionName.contains('Tanium Cloud')
				: isEmPlusTaas;
			if (isEmStdTaas && isEmPlusTaas) {
				deDupedModule_MigrationIds.remove(
					aemSolutionNameModule_MigrationIdMap.get(emStdTaasProductName)
				);
			}

			isEmStdSubscription = (!isEmStdSubscription)
				? aemSolutionName.contains('Endpoint Management Standard') &&
				  aemSolutionName.contains('Subscription')
				: isEmStdSubscription;
			if (
				aemSolutionName.contains('Endpoint Management Standard') &&
				aemSolutionName.contains('Subscription')
			) {
				emStdSubscriptionProductName = aemSolutionName;
			}
			isEmPlusSubscription = (!isEmPlusSubscription)
				? aemSolutionName.contains('Endpoint Management Plus') &&
				  aemSolutionName.contains('Subscription')
				: isEmPlusSubscription;
			if (isEmStdSubscription && isEmPlusSubscription) {
				deDupedModule_MigrationIds.remove(
					aemSolutionNameModule_MigrationIdMap.get(emStdSubscriptionProductName)
				);
			}

			isRcStdTaas = (!isRcStdTaas)
				? aemSolutionName.contains('Risk & Compliance Standard') &&
				  aemSolutionName.contains('Tanium Cloud')
				: isRcStdTaas;
			if (
				aemSolutionName.contains('Risk & Compliance Standard') &&
				aemSolutionName.contains('Tanium Cloud')
			) {
				rcStdTaasProductName = aemSolutionName;
			}
			isRcPlusTaas = (!isRcPlusTaas)
				? aemSolutionName.contains('Risk & Compliance Plus') &&
				  aemSolutionName.contains('Tanium Cloud')
				: isRcPlusTaas;
			if (isRcStdTaas && isRcPlusTaas) {
				deDupedModule_MigrationIds.remove(
					aemSolutionNameModule_MigrationIdMap.get(rcStdTaasProductName)
				);
			}

			isRcStdSubscription = (!isRcStdSubscription)
				? aemSolutionName.contains('Risk & Compliance Standard') &&
				  aemSolutionName.contains('Subscription')
				: isRcStdSubscription;
			if (
				aemSolutionName.contains('Risk & Compliance Standard') &&
				aemSolutionName.contains('Subscription')
			) {
				rcStdSubscriptionProductName = aemSolutionName;
			}
			isRcPlusSubscription = (!isRcPlusSubscription)
				? aemSolutionName.contains('Risk & Compliance Plus') &&
				  aemSolutionName.contains('Subscription')
				: isRcPlusSubscription;
			if (isRcStdSubscription && isRcPlusSubscription) {
				deDupedModule_MigrationIds.remove(
					aemSolutionNameModule_MigrationIdMap.get(rcStdSubscriptionProductName)
				);
			}
		}

		List<Module_Migration__c> deDupedModule_Migrations = [
			SELECT Id, AEM_Product_Group__c, AEM_Solution__c, AEM_Solution__r.Name
			FROM Module_Migration__c
			WHERE Id IN :deDupedModule_MigrationIds
		];

		return deDupedModule_Migrations;
	}

	public void updateSolution_Migrations() {
		List<Solution_Migration__c> solution_Migrations = new List<Solution_Migration__c>();
		Solution_Migration__c solution_Migration;

		for (SolutionMigration solutionMigration : this.solutionMigrations) {
			solution_Migration = new Solution_Migration__c(Id = solutionMigration.id);
			solution_Migration.Legacy_List_Total__c = solutionMigration.legacyListTotal;
			solution_Migration.Legacy_Net_Total__c = solutionMigration.legacyNetTotal;
			solution_Migration.Migration_Unit_Price__c = solutionMigration.migrationUnitPrice;
			solution_Migration.Uplift_Unit_Price__c = solutionMigration.upliftUnitPrice;
			solution_Migration.Max_Quantity__c = solutionMigration.maxQuantity;
			solution_Migration.AEM_Solution__c = solutionMigration.aemSolutionId;
			solution_Migration.AEM_Solution_List_Price__c = solutionMigration.aemSolutionListPrice;
			solution_Migrations.add(solution_Migration);
		}
		List<Database.SaveResult> saveResults = Database.update(solution_Migrations, false);
		logSaveResultErrors('updateSolution_Migrations', saveResults);
	}

	public Map<Id, Decimal> getAemSolutionIdsListPriceMap(List<Id> aemProductIdList) {
		Set<Id> aemProductIds = new Set<Id>(aemProductIdList);
		Map<Id, Decimal> aemSolutionIdsListPriceMap = new Map<Id, Decimal>();
		Id globalPriceBookId = GLOBAL_PRICEBOOK_ID;
		for (PricebookEntry pricebookEntry : [
			SELECT Id, Product2Id, UnitPrice
			FROM PricebookEntry
			WHERE
				Product2Id IN :aemProductIds
				AND Pricebook2Id = :globalPriceBookId
				AND CurrencyIsoCode = 'USD'
		]) {
			aemSolutionIdsListPriceMap.put(pricebookEntry.Product2Id, pricebookEntry.UnitPrice);
		}
		return aemSolutionIdsListPriceMap;
	}

	private Set<String> getAEMProductGroups() {
		Set<String> aemProductGroups = new Set<String>();

		for (ProductMigrationData.ModuleMigration moduleMigration : this.allModuleMigrations) {
			if (
				moduleMigration.aemProductGroup != null &&
				VALID_AEM_PRODUCT_GROUPS.contains(moduleMigration.aemProductGroup)
			) {
				aemProductGroups.add(moduleMigration.aemProductGroup);
			}
		}
		return aemProductGroups;
	}

	public class SubscriptionMigration {
		public Id id { get; set; }
		public Id opportunityId { get; set; }
		public Id subscriptionId { get; set; }
		public Id subscriptionProductId { get; set; }
		public Decimal netPrice { get; set; }
		public String productName { get; set; }
		public Decimal quanity { get; set; }
		public Date startDate { get; set; }
		public Date endDate { get; set; }
		public Boolean nonAemProduct { get; set; }
		public List<ModuleMigration> moduleMigrations;
		public SubscriptionAggregateMigration subscriptionAggregateMigration { get; set; }

		public SubscriptionMigration(Ruby__Subscription__c subscription) {
			this.id = null;
			this.opportunityId = subscription.Ruby__RenewalOpportunity__c;
			this.subscriptionId = subscription.Id;
			this.subscriptionProductId = subscription.Ruby__Product__c;
			this.netPrice = subscription.Ruby__NetSellerPrice__c;
			this.productName = subscription.Ruby__Product__r.Name;
			this.quanity = subscription.Ruby__Quantity__c;
			this.startDate = subscription.Ruby__SubscriptionStartDate__c;
			this.endDate = subscription.Ruby__SubscriptionEndDate__c;
			this.nonAemProduct = (subscription.Ruby__Product__r.Product_Group__c != 'Software');
			this.moduleMigrations = new List<ModuleMigration>();
			subscriptionAggregateMigration = null;
		}

		public void addModuleMigration(
			Id productId,
			String productName,
			String moduleName,
			String productType,
			String segment,
			Decimal allocationPct,
			Decimal allocationListPrice,
			Decimal allocationNetPrice,
			String source
		) {
			moduleMigrations.add(
				new ModuleMigration(
					this.id,
					productId,
					productName,
					moduleName,
					productType,
					segment,
					allocationPct,
					allocationListPrice,
					allocationNetPrice,
					source
				)
			);
		}

		public List<ModuleMigration> getModuleMigrations() {
			return moduleMigrations;
		}
	}

	public class SubscriptionAggregateMigration {
		public Id id { get; set; }
		public String name { get; set; }
		public Id opportunityId { get; set; }
		public String aemProductGroup { get; set; }
		public Id productId { get; set; }
		public Decimal coreSubscriptionAllocationPct { get; set; }
		public Decimal coreSubscriptionListPrice { get; set; }
		public Decimal coreSubscriptionNetPrice { get; set; }
		public Decimal coreTaasAllocationPct { get; set; }
		public Decimal coreTaasListPrice { get; set; }
		public Decimal coreTaasNetPrice { get; set; }
		public Decimal emSubscriptionAllocationPct { get; set; }
		public Decimal emSubscriptionListPrice { get; set; }
		public Decimal emSubscriptionNetPrice { get; set; }
		public Decimal emTaasAllocationPct { get; set; }
		public Decimal emTaasListPrice { get; set; }
		public Decimal emTaasNetPrice { get; set; }
		public Decimal irSubscriptionAllocationPct { get; set; }
		public Decimal irSubscriptionListPrice { get; set; }
		public Decimal irSubscriptionNetPrice { get; set; }
		public Decimal irTaasAllocationPct { get; set; }
		public Decimal irTaasListPrice { get; set; }
		public Decimal irTaasNetPrice { get; set; }
		public Decimal rcSubscriptionAllocationPct { get; set; }
		public Decimal rcSubscriptionListPrice { get; set; }
		public Decimal rcSubscriptionNetPrice { get; set; }
		public Decimal rcTaasAllocationPct { get; set; }
		public Decimal rcTaasListPrice { get; set; }
		public Decimal rcTaasNetPrice { get; set; }
		public Decimal quantity { get; set; }
		public Set<Id> subscription_MigrationIds { get; set; }

		public SubscriptionAggregateMigration(
			String name,
			Id opportunityId,
			Id productId,
			Decimal coreSubscriptionAllocationPct,
			Decimal coreSubscriptionListPrice,
			Decimal coreSubscriptionNetPrice,
			Decimal coreTaasAllocationPct,
			Decimal coreTaasListPrice,
			Decimal coreTaasNetPrice,
			Decimal emSubscriptionAllocationPct,
			Decimal emSubscriptionListPrice,
			Decimal emSubscriptionNetPrice,
			Decimal emTaasAllocationPct,
			Decimal emTaasListPrice,
			Decimal emTaasNetPrice,
			Decimal irSubscriptionAllocationPct,
			Decimal irSubscriptionListPrice,
			Decimal irSubscriptionNetPrice,
			Decimal irTaasAllocationPct,
			Decimal irTaasListPrice,
			Decimal irTaasNetPrice,
			Decimal rcSubscriptionAllocationPct,
			Decimal rcSubscriptionListPrice,
			Decimal rcSubscriptionNetPrice,
			Decimal rcTaasAllocationPct,
			Decimal rcTaasListPrice,
			Decimal rcTaasNetPrice,
			Decimal quantity,
			Set<Id> subscription_MigrationIds
		) {
			this.id = null;
			this.name = 'SubscrAggrMigration-' + name;
			this.opportunityId = opportunityId;
			this.productId = productId;
			this.coreSubscriptionAllocationPct = coreSubscriptionAllocationPct;
			this.coreSubscriptionListPrice = coreSubscriptionListPrice;
			this.coreSubscriptionNetPrice = coreSubscriptionNetPrice;
			this.coreTaasAllocationPct = coreTaasAllocationPct;
			this.coreTaasListPrice = coreTaasListPrice;
			this.coreTaasNetPrice = coreTaasNetPrice;
			this.emSubscriptionAllocationPct = emSubscriptionAllocationPct;
			this.emSubscriptionListPrice = emSubscriptionListPrice;
			this.emSubscriptionNetPrice = emSubscriptionNetPrice;
			this.emTaasAllocationPct = emTaasAllocationPct;
			this.emTaasListPrice = emTaasListPrice;
			this.emTaasNetPrice = emTaasNetPrice;
			this.irSubscriptionAllocationPct = irSubscriptionAllocationPct;
			this.irSubscriptionListPrice = irSubscriptionListPrice;
			this.irSubscriptionNetPrice = irSubscriptionNetPrice;
			this.irTaasAllocationPct = irTaasAllocationPct;
			this.irTaasListPrice = irTaasListPrice;
			this.irTaasNetPrice = irTaasNetPrice;
			this.rcSubscriptionAllocationPct = rcSubscriptionAllocationPct;
			this.rcSubscriptionListPrice = rcSubscriptionListPrice;
			this.rcSubscriptionNetPrice = rcSubscriptionNetPrice;
			this.rcTaasAllocationPct = rcTaasAllocationPct;
			this.rcTaasListPrice = rcTaasListPrice;
			this.rcTaasNetPrice = rcTaasNetPrice;
			this.quantity = quantity;
			this.subscription_MigrationIds = subscription_MigrationIds;
		}
	}

	public class ModuleMigration {
		public Id subscriptionMigrationId { get; set; }
		public Id productId { get; set; }
		public String productName { get; set; }
		public String moduleName { get; set; }
		public String productType { get; set; }
		public String segment { get; set; }
		public String aemProductGroup { get; set; }
		public Decimal allocationPct { get; set; }
		public Decimal allocationListPrice { get; set; }
		public Decimal allocationNetPrice { get; set; }
		public String source { get; set; }
		public Id aemProductId { get; set; }

		public ModuleMigration(
			Id subscriptionMigrationId,
			Id productId,
			String productName,
			String moduleName,
			String productType,
			String segment,
			Decimal allocationPct,
			Decimal allocationListPrice,
			Decimal allocationNetPrice,
			String source
		) {
			this.subscriptionMigrationId = subscriptionMigrationId;
			this.productId = productId;
			this.productName = productName;
			this.moduleName = moduleName;
			this.productType = productType;
			this.segment = segment;
			this.aemProductGroup = getAEMProductGroup(moduleName, productType);
			this.allocationPct = allocationPct;
			this.allocationListPrice = allocationListPrice;
			this.allocationNetPrice = allocationNetPrice;
			this.source = source;
			this.aemProductId = getAEMProductId(moduleName, productType, segment);
		}

		public String getAEMProductGroup(String moduleName, String productType) {
			for (AEM_Solution_Map__mdt aemSolution : AEM_Solution_Map__mdt.getAll().values()) {
				if (
					aemSolution.Module__c.toLowerCase() == moduleName.toLowerCase() &&
					aemSolution.Product_Type__c.toLowerCase() == productType.toLowerCase()
				) {
					return aemSolution.AEM_Product_Group__c;
				}
			}
			return null;
		}

		public Id getAEMProductId(String module, String productType, String segment) {
			String productCode = '';
			List<AEM_Solution_Map__mdt> aemSolutions = [
				SELECT Id, AEM_Solution_Product_Code__c, Segment__c
				FROM AEM_Solution_Map__mdt
				WHERE Module__c = :module AND Product_Type__c = :productType
			];

			for (AEM_Solution_Map__mdt aemSolution : aemSolutions) {
				if (aemSolution.Segment__c.contains(segment) || aemSolution.Segment__c == 'All') {
					productCode = aemSolution.AEM_Solution_Product_Code__c;
				}
			}
			try {
				return [
					SELECT Id
					FROM Product2
					WHERE ProductCode = :productCode AND IsActive = TRUE
					LIMIT 1
				]
				.Id;
			} catch (Exception e) {
				return null;
			}
		}
	}

	public class SolutionMigration {
		public String id { get; set; }
		public String name { get; set; }
		public Id opportunityId { get; set; }
		public String aemProductGroup { get; set; }
		public String segment { get; set; }
		public String sector { get; set; }
		public Date startDate { get; set; }
		public Decimal maxQuantity { get; set; }
		public Decimal legacyNetTotal { get; set; }
		public Decimal legacyListTotal { get; set; }
		public Decimal legacyDiscount { get; set; }
		public Decimal upliftPercent { get; set; }
		public Decimal upliftUnitPrice { get; set; }
		public Decimal migrationUnitPrice { get; set; }
		public Decimal migrationDiscount { get; set; }
		public Decimal upliftPartnerMigrationPercent { get; set; }
		public Decimal aemSolutionTotal { get; set; }
		public Id aemSolutionId { get; set; }
		public Decimal aemSolutionListPrice { get; set; }

		public SolutionMigration(Opportunity opportunity, String aemProductGroup, Boolean isPromo) {
			this.name = opportunity.Id + '-' + aemProductGroup;
			this.opportunityId = opportunity.Id;
			this.aemProductGroup = aemProductGroup;
			this.segment = opportunity.Account.Segment__c;
			this.sector = opportunity.Account.Sector__c;
			this.startDate = opportunity.EndDate__c + 1;
			this.maxQuantity = opportunity.MaxQuantity__c;
			this.legacyNetTotal = 0;
			this.legacyListTotal = 0;
			this.legacyDiscount = 0;
			this.migrationDiscount = getMigrationDiscount(this.segment, this.sector, isPromo);
			this.upliftPercent = getUpliftPct(this.segment, this.sector);
			this.migrationUnitPrice = 0;
			this.upliftUnitPrice = 0;
			this.upliftPartnerMigrationPercent = 0;
			this.aemSolutionTotal = 0;
			this.aemSolutionId = null;
			this.aemSolutionListPrice = null;
		}

		private Decimal getMigrationDiscount(String segment, String sector, Boolean isPromo) {
			for (
				Migration_Discount__mdt migrationDiscount : Migration_Discount__mdt.getAll().values()
			) {
				if (
					migrationDiscount.Account_Segment__c == segment &&
					(migrationDiscount.Account_Sector__c == sector ||
					migrationDiscount.Account_Sector__c == 'All')
				) {
					return isPromo
						? migrationDiscount.Promo_Discount__c / 100
						: migrationDiscount.Discount__c / 100;
				}
			}
			return 0;
		}

		private Decimal getUpliftPct(String segment, String sector) {
			for (
				Migration_Discount__mdt migrationDiscount : Migration_Discount__mdt.getAll().values()
			) {
				if (
					migrationDiscount.Account_Segment__c == segment &&
					(migrationDiscount.Account_Sector__c == sector ||
					migrationDiscount.Account_Sector__c == 'All')
				) {
					return migrationDiscount.Uplift_Percent__c / 100;
				}
			}
			return 0;
		}
	}

	private void logSaveResultErrors(String method, List<Database.SaveResult> saveResults) {
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'ProductMigrationData.' + method + ' ERRORS',
				saveResults
			)
			.addTag('apex')
			.addTag('lwc');
		Logger.saveLog();
	}
}