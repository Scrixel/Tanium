/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI-187. Appliance Maintenance Bundles.
 *
 *   The Ruby (Nue) managed package's native bundle mechanism -
 *   Ruby__ProductOption__c with Ruby__OptionProductFilter__c driving a
 *   dynamic option - could not be made to work in this org: the JSON schema
 *   documented for another Nue tenant was accepted by the API but rejected
 *   by the Price Builder UI's own parser ("Error parsing
 *   OptionProductFilter__c..."), and no other dynamic option exists in this
 *   org to reverse-engineer a working schema from. Nue's parsing logic lives
 *   in their hosted Price Builder application, outside this org, so it is
 *   also not inspectable via Tooling API.
 *
 *   This service reimplements the required behavior in Apex instead of the
 *   native bundle engine, on the same "auto-add a related line and lock it"
 *   pattern already used in this org for ESO services SKUs. For each of the
 *   4 Appliance tiers, adding the hardware SKU to a quote auto-adds its paired
 *   Maintenance SKU at quantity 1, and that maintenance line is then locked:
 *   its product and quantity cannot be edited, and it is removed automatically
 *   only when its hardware line is removed (never independently).
 *
 *   Wired into the existing ELV_QuoteLineTriggerHandler / ELV_QuoteLineTrigger -
 *   no new trigger was added. See diffs/ in the deployment package for the
 *   exact merge points.
 */
public with sharing class ELV_ApplianceMaintenanceBundleService {
	// Hardware SKU -> paired Maintenance SKU, the 4 Appliance tiers in TNCI-187 scope.
	// Resolved to Product2 Ids at runtime (getHardwareToMaintenanceProductIds) rather than
	// relying on a SKU field on QuoteLineItem, which this org does not stamp today.
	@TestVisible
	private static final Map<String, String> HARDWARE_TO_MAINTENANCE_SKU = new Map<String, String>{
		'TAN-S-330-CP' => 'TAN-S-SUM',
		'TAN-S-335-FB' => 'TAN-S-SUM',
		'TAN-M-430-CP' => 'TAN-M-SUM',
		'TAN-M-435-FB' => 'TAN-M-SUM',
		'TAN-L-730-CP' => 'TAN-L-SUM',
		'TAN-L-735-FB' => 'TAN-L-SUM',
		'TAN-XL-930-CP' => 'TAN-XL-SUM',
		'TAN-XL-935-FB' => 'TAN-XL-SUM'
	};

	private static final String LOCK_EDIT_ERROR =
		'This Maintenance line was added automatically for the Appliance hardware line ' +
		'above it and cannot be edited directly. Change the hardware line\'s quantity instead.';
	private static final String LOCK_DELETE_ERROR =
		'This Maintenance line was added automatically for the Appliance hardware line ' +
		'above it and cannot be removed directly. Remove the hardware line instead - its ' +
		'Maintenance line will be removed with it.';

	/**
	 * After insert. For each newly inserted Appliance hardware line that has no paired
	 * Maintenance line yet on the same quote, inserts one at quantity 1 and stamps the
	 * lock/link fields used by the guards below.
	 */
	public static void autoAddMaintenanceLines(List<QuoteLineItem> newLines) {
		if (newLines == null || newLines.isEmpty()) {
			return;
		}

		Map<Id, Id> hardwareToMaintenanceProductId = getHardwareToMaintenanceProductIds();
		if (hardwareToMaintenanceProductId.isEmpty()) {
			return;
		}

		List<QuoteLineItem> hardwareLines = new List<QuoteLineItem>();
		Set<Id> quoteIds = new Set<Id>();
		for (QuoteLineItem line : newLines) {
			if (
				line.QuoteId != null &&
				line.Product2Id != null &&
				hardwareToMaintenanceProductId.containsKey(line.Product2Id)
			) {
				hardwareLines.add(line);
				quoteIds.add(line.QuoteId);
			}
		}

		if (hardwareLines.isEmpty()) {
			return;
		}

		// Skip a hardware line whose quote already carries the paired maintenance line -
		// e.g. a reconfigure/clone path that copied both, or a partial retry of this insert.
		Set<String> existingHardwareQuoteKeys = getExistingAutoAddedMaintenanceKeys(quoteIds);

		// QuoteLineItem.PricebookEntryId is required - the maintenance line needs the entry
		// for its own product in whatever pricebook the quote is on, not the hardware line's.
		Map<Id, Id> pricebookIdByQuoteId = getPricebookIdsByQuoteId(quoteIds);
		Map<String, PricebookEntry> pricebookEntryByProductAndPricebook = getPricebookEntries(
			new Set<Id>(hardwareToMaintenanceProductId.values()),
			new Set<Id>(pricebookIdByQuoteId.values())
		);

		// The maintenance line must nest under its hardware line the same way this org's
		// other bundles do - Ruby__ParentId__c/Ruby__RootId__c pointing at the hardware line,
		// ELV_Bundled_Product__c true, and Ruby__ProductOption__c set to the existing static
		// Product Option config for that pairing (restored during the native-bundle rollback),
		// so the Quote Line Editor groups and renders it as a bundle child, not a sibling line.
		Map<Id, Id> productOptionIdByHardwareProductId = getProductOptionIdsByHardwareProductId(
			hardwareToMaintenanceProductId
		);

		List<QuoteLineItem> maintenanceLinesToInsert = new List<QuoteLineItem>();
		for (QuoteLineItem hardwareLine : hardwareLines) {
			Id maintenanceProductId = hardwareToMaintenanceProductId.get(hardwareLine.Product2Id);

			String key = hardwareLine.QuoteId + ':' + hardwareLine.Id;
			if (existingHardwareQuoteKeys.contains(key)) {
				continue;
			}

			Id pricebookId = pricebookIdByQuoteId.get(hardwareLine.QuoteId);
			PricebookEntry maintenancePbe = pricebookId == null
				? null
				: pricebookEntryByProductAndPricebook.get(maintenanceProductId + ':' + pricebookId);
			if (maintenancePbe == null) {
				continue;
			}

			Decimal listPrice = maintenancePbe.UnitPrice == null ? 0 : maintenancePbe.UnitPrice;
			Decimal listTotal = listPrice * 1; // Quantity is always 1 on auto-add.

			maintenanceLinesToInsert.add(
				new QuoteLineItem(
					QuoteId = hardwareLine.QuoteId,
					Product2Id = maintenanceProductId,
					PricebookEntryId = maintenancePbe.Id,
					Quantity = 1,
					// This org's Quote Line Editor reads pricing from the Ruby__ fields, not the
					// standard QuoteLineItem price fields - mirrored here from the other bundle
					// lines already in this org, which likewise leave the standard fields at 0.
					UnitPrice = 0,
					Ruby__ListPrice__c = listPrice,
					Ruby__ListTotalPrice__c = listTotal,
					Ruby__Subtotal__c = listTotal,
					Ruby__SalesPrice__c = listPrice,
					Ruby__NetSalesPrice__c = listPrice,
					Ruby__TotalPrice__c = listTotal,
					ELV_Auto_Added_Maintenance__c = true,
					ELV_Auto_Added_From_Line__c = hardwareLine.Id,
					Ruby__ParentId__c = hardwareLine.Id,
					Ruby__RootId__c = hardwareLine.Id,
					ELV_Bundled_Product__c = true,
					Ruby__ProductOption__c = productOptionIdByHardwareProductId.get(hardwareLine.Product2Id)
				)
			);
		}

		if (!maintenanceLinesToInsert.isEmpty()) {
			insert maintenanceLinesToInsert;

			// Let Nue's own pricing engine own the calculation instead of us hand-setting
			// price/total fields - fixes list price / subtotal / totals not reflecting
			// correctly on the auto-added line and its quote.
			for (Id quoteId : new Set<Id>(pricebookIdByQuoteId.keySet())) {
				try {
					new Ruby.GlobalQuoteService().recalculate(quoteId);
				} catch (Exception e) {
					// Recalculation failure should not roll back the line insert itself.
					System.debug(LoggingLevel.WARN, 'ELV_ApplianceMaintenanceBundleService: recalculate failed for ' + quoteId + ': ' + e.getMessage());
				}
			}
		}
	}

	private static Map<Id, Id> getPricebookIdsByQuoteId(Set<Id> quoteIds) {
		Map<Id, Id> pricebookIdByQuoteId = new Map<Id, Id>();
		if (quoteIds == null || quoteIds.isEmpty()) {
			return pricebookIdByQuoteId;
		}

		for (Quote quote : [SELECT Id, Pricebook2Id FROM Quote WHERE Id IN :quoteIds]) {
			if (quote.Pricebook2Id != null) {
				pricebookIdByQuoteId.put(quote.Id, quote.Pricebook2Id);
			}
		}

		return pricebookIdByQuoteId;
	}

	/** "<productId>:<pricebookId>" -> that active PricebookEntry (Id + UnitPrice/list price). */
	private static Map<String, PricebookEntry> getPricebookEntries(Set<Id> productIds, Set<Id> pricebookIds) {
		Map<String, PricebookEntry> pricebookEntryByKey = new Map<String, PricebookEntry>();
		if (productIds.isEmpty() || pricebookIds.isEmpty()) {
			return pricebookEntryByKey;
		}

		for (PricebookEntry entry : [
			SELECT Id, Product2Id, Pricebook2Id, UnitPrice
			FROM PricebookEntry
			WHERE Product2Id IN :productIds
			AND Pricebook2Id IN :pricebookIds
			AND IsActive = TRUE
		]) {
			pricebookEntryByKey.put(entry.Product2Id + ':' + entry.Pricebook2Id, entry);
		}

		return pricebookEntryByKey;
	}

	/**
	 * Hardware Product2 Id -> the existing static Ruby__ProductOption__c Id that pairs it
	 * with its Maintenance product (Ruby__ConfiguredProduct__c = hardware, Ruby__OptionProduct__c
	 * = maintenance). These records already exist in this org - restored to static config
	 * during the native-bundle rollback - so the auto-added line references the same option
	 * config a working native bundle add would have used.
	 */
	private static Map<Id, Id> getProductOptionIdsByHardwareProductId(
		Map<Id, Id> hardwareToMaintenanceProductId
	) {
		Map<Id, Id> productOptionIdByHardwareProductId = new Map<Id, Id>();
		if (hardwareToMaintenanceProductId == null || hardwareToMaintenanceProductId.isEmpty()) {
			return productOptionIdByHardwareProductId;
		}

		for (Ruby__ProductOption__c option : [
			SELECT Id, Ruby__ConfiguredProduct__c, Ruby__OptionProduct__c
			FROM Ruby__ProductOption__c
			WHERE Ruby__ConfiguredProduct__c IN :hardwareToMaintenanceProductId.keySet()
			AND Ruby__OptionProduct__c IN :hardwareToMaintenanceProductId.values()
		]) {
			if (
				hardwareToMaintenanceProductId.get(option.Ruby__ConfiguredProduct__c) ==
				option.Ruby__OptionProduct__c
			) {
				productOptionIdByHardwareProductId.put(option.Ruby__ConfiguredProduct__c, option.Id);
			}
		}

		return productOptionIdByHardwareProductId;
	}

	/**
	 * Before update. An auto-added Maintenance line may not have its product or quantity
	 * changed by hand - only removing/changing the paired hardware line's quantity may
	 * touch it, and that path goes through autoAddMaintenanceLines/cascadeDeleteMaintenanceLines,
	 * not through an edit of the maintenance line itself.
	 */
	public static void blockDirectMaintenanceEdits(
		List<QuoteLineItem> lines,
		Map<Id, QuoteLineItem> oldMap
	) {
		if (lines == null || oldMap == null) {
			return;
		}

		for (QuoteLineItem line : lines) {
			if (line.ELV_Auto_Added_Maintenance__c != true) {
				continue;
			}

			QuoteLineItem oldLine = oldMap.get(line.Id);
			if (oldLine == null) {
				continue;
			}

			if (line.Quantity != oldLine.Quantity || line.Product2Id != oldLine.Product2Id) {
				line.addError(LOCK_EDIT_ERROR);
			}
		}
	}

	/**
	 * Before delete. Direct deletion of an auto-added Maintenance line is blocked; it is
	 * only ever removed as a side effect of removing its hardware line, via
	 * cascadeDeleteMaintenanceLines below.
	 */
	public static void blockDirectMaintenanceDeletes(List<QuoteLineItem> lines) {
		if (lines == null) {
			return;
		}

		for (QuoteLineItem line : lines) {
			if (line.ELV_Auto_Added_Maintenance__c == true && !isCascadeDeleteInProgress()) {
				line.addError(LOCK_DELETE_ERROR);
			}
		}
	}

	/**
	 * After delete. Removing an Appliance hardware line removes its paired Maintenance
	 * line along with it.
	 */
	public static void cascadeDeleteMaintenanceLines(List<QuoteLineItem> deletedLines) {
		if (deletedLines == null || deletedLines.isEmpty()) {
			return;
		}

		Set<Id> deletedHardwareLineIds = new Set<Id>();
		for (QuoteLineItem line : deletedLines) {
			deletedHardwareLineIds.add(line.Id);
		}

		List<QuoteLineItem> maintenanceLinesToDelete = [
			SELECT Id
			FROM QuoteLineItem
			WHERE ELV_Auto_Added_From_Line__c IN :deletedHardwareLineIds
			AND ELV_Auto_Added_Maintenance__c = TRUE
		];

		if (maintenanceLinesToDelete.isEmpty()) {
			return;
		}

		beginCascadeDelete();
		try {
			delete maintenanceLinesToDelete;
		} finally {
			endCascadeDelete();
		}
	}

	// -------------------------------------------------------------------
	// Cascade-delete re-entrancy guard. blockDirectMaintenanceDeletes must
	// reject a user deleting a Maintenance line by hand, but must not reject
	// the delete cascadeDeleteMaintenanceLines performs on its behalf.
	// -------------------------------------------------------------------
	@TestVisible
	private static Boolean cascadeDeleteInProgress = false;

	private static void beginCascadeDelete() {
		cascadeDeleteInProgress = true;
	}

	private static void endCascadeDelete() {
		cascadeDeleteInProgress = false;
	}

	private static Boolean isCascadeDeleteInProgress() {
		return cascadeDeleteInProgress;
	}

	/** Hardware Product2 Id -> paired Maintenance Product2 Id, resolved by ProductCode. */
	private static Map<Id, Id> getHardwareToMaintenanceProductIds() {
		Map<Id, Id> hardwareToMaintenanceProductId = new Map<Id, Id>();

		Set<String> allSkus = new Set<String>(HARDWARE_TO_MAINTENANCE_SKU.keySet());
		allSkus.addAll(HARDWARE_TO_MAINTENANCE_SKU.values());

		Map<String, Id> productIdBySku = new Map<String, Id>();
		for (Product2 product : [
			SELECT Id, ProductCode
			FROM Product2
			WHERE ProductCode IN :allSkus
		]) {
			productIdBySku.put(product.ProductCode, product.Id);
		}

		for (String hardwareSku : HARDWARE_TO_MAINTENANCE_SKU.keySet()) {
			Id hardwareProductId = productIdBySku.get(hardwareSku);
			Id maintenanceProductId = productIdBySku.get(
				HARDWARE_TO_MAINTENANCE_SKU.get(hardwareSku)
			);
			if (hardwareProductId != null && maintenanceProductId != null) {
				hardwareToMaintenanceProductId.put(hardwareProductId, maintenanceProductId);
			}
		}

		return hardwareToMaintenanceProductId;
	}

	/** "<quoteId>:<hardwareLineId>" for every hardware line that already has its pair. */
	private static Set<String> getExistingAutoAddedMaintenanceKeys(Set<Id> quoteIds) {
		Set<String> keys = new Set<String>();
		if (quoteIds == null || quoteIds.isEmpty()) {
			return keys;
		}

		for (QuoteLineItem maintenanceLine : [
			SELECT QuoteId, ELV_Auto_Added_From_Line__c
			FROM QuoteLineItem
			WHERE QuoteId IN :quoteIds
			AND ELV_Auto_Added_Maintenance__c = TRUE
			AND ELV_Auto_Added_From_Line__c != NULL
		]) {
			keys.add(maintenanceLine.QuoteId + ':' + maintenanceLine.ELV_Auto_Added_From_Line__c);
		}

		return keys;
	}
}