/**
 * @Business: Create a new POC Opportunity the related Line Items
 * @Date: 2018-03-14
 * @Author: Cumulus Vision
 * @Request: TAN-487
 * Modified   ModifiedDate   Description
 * TAN-588    2018-05-22     Updated New Opp StageName
 * TAN-596    2018-05-30     Added new Deploy Product
 * TAN-621    2018-07-20     Added new Opportunity Product for Product "TAN-MAP-S"
 * TAN-627    2018-08-01     Added new Opportunity Product and custom appliance quantities for some new products
 * TAN-733    2018-12-13     Added new Opportunity Product TAN-REVEAL-S
 * TAN-798    2019-08-08     Added new Opportunity Product TAN-PERFORMANCE-S
 * TAN-812    2019-09-17     Added additional SKUs.
 * TAN-1016   2020-10-18     Added Chronicle product.
 * TAN-1043   2020-12-07     Remove 'Protect' Product
 * TAN-1044   2020-12-08     Add Enforce product
 * TAN-1190   2021-04-12     Patch sku renamed
 */

public with sharing class POCRequestOpportunityUtility {
	@TestVisible
	private static final Set<String> POC_SKUS = new Set<String>();
	public final static List<String> tanFieldNameList = new List<String>();

	static {
		//Custom metadata API Names have underscores instead of dashes
		for (String pocSKU : POC_SKU__mdt.getAll().keySet()) {
			POC_SKUS.add(pocSKU.replaceAll('_', '-'));
		}
		for (FieldSetMember field : SObjectType.POC_Request__c.FieldSets.POC_TAN_Fields.getFields()) {
			tanFieldNameList.add(field.getFieldPath());
		}
	}

	public static void createNewPOCOppAndLineItems(
		List<POC_Request__c> updatedPOCRequests,
		Map<Id, POC_Request__c> oldPOCRequests
	) {
		Set<Id> pocRequestIds = new Set<Id>();
		for (POC_Request__c pocRequest : updatedPOCRequests) {
			//only create poc opp for requests that do not already have one and have been approved
			if (
				pocRequest.POC_Opportunity__c == null &&
				pocRequest.Approved__c == true &&
				pocRequest.Approved__c != oldPOCRequests.get(pocRequest.Id).Approved__c &&
				pocRequest.POC_Type__c == 'New'
			) {
				Boolean flag = false;
				for (String fieldName : tanFieldNameList) {
					if (Utility.safeDecimal(String.valueOf(pocRequest.get(fieldName))) > 0) {
						flag = true;
					}
				}
				if (flag) {
					pocRequestIds.add(pocRequest.Id);
				}
			}
		}

		//if any poc requests meet the criteria send them to the method for creating a new opp and line items
		if (!pocRequestIds.isEmpty()) {
			createNewPOCOppAndLineItems(pocRequestIds);
		}
	}

	//TAN-487
	private static void createNewPOCOppAndLineItems(Set<Id> pocRequestIds) {
		//Step 1: Add Skus to a list and create a map of the products with the sku code

		Map<String, Id> skuMap = new Map<String, String>();
		List<Product2> products = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :POC_SKUS];

		for (Product2 product : products) {
			skuMap.put(product.ProductCode, product.Id);
		}

		//Step 2: Lookup the POC Request and create a POC Opportunity for that POC Request
		List<POC_Request__c> pocRequests = [
			SELECT Id, Opportunity__r.Name, Opportunity__c, Account__c
			FROM POC_Request__c
			WHERE Id IN :pocRequestIds
		];
		List<Opportunity> pocOpps = new List<Opportunity>();

		for (POC_Request__c pocRequest : pocRequests) {
			String pocName =
				Utility.shortenString(pocRequest.Opportunity__r.Name, 100) +
				' - POC - ' +
				System.today().format();

			Opportunity pocOpp = new Opportunity();
			pocOpp.Name = pocName;
			pocOpp.AccountId = pocRequest.Account__c;
			pocOpp.Type = 'POC';
			pocOpp.StageName = Utility.POC;
			pocOpp.CloseDate = System.today();
			pocOpp.PriceBook2Id = System.Label.POC_PriceBookId;
			pocOpp.Parent_Opportunity__c = pocRequest.Opportunity__c;
			pocOpps.add(pocOpp);
		}

		if (!pocOpps.isEmpty()) {
			insert pocOpps;
		}

		//Step 3: Update the POC Request with the Opportunity that was created
		Map<String, Id> opportunityMap = new Map<String, Id>();
		for (Opportunity o : pocOpps) {
			opportunityMap.put(o.Name, o.Id);
		}

		List<POC_Request__c> uPOCRs = new List<POC_Request__c>();
		Set<Id> pocrIds = new Set<Id>();

		for (POC_Request__c pocRequest : pocRequests) {
			String pocName =
				Utility.shortenString(pocRequest.Opportunity__r.Name, 100) +
				' - POC - ' +
				System.today().format();
			pocRequest.POC_Opportunity__c = opportunityMap.get(pocName);
			uPOCRs.add(pocRequest);
			pocrIds.add(pocRequest.Id);
		}

		if (!uPOCRs.isEmpty()) {
			update uPOCRs;
		}

		//Step 4: Requery the POC Request with the Products needed and new POC Opp. Check which Opp Line items are needed and create them
		List<OpportunityLineItem> oppLines = new List<OpportunityLineItem>();
		for (POC_Request__c pocRequest : [
			SELECT
				Id,
				Opportunity__r.Name,
				Trace__c,
				Patch__c,
				Discover__c,
				IR__c,
				Account__c,
				Start_Date__c,
				Approved__c,
				Protect__c,
				Threat_Response__c,
				IOCD__c,
				Comply__c,
				Asset__c,
				Integrity_Monitor__c,
				Core__c,
				Quantity__c,
				Duration__c,
				Reveal__c,
				Opportunity__c,
				POC_Opportunity__c,
				Deploy__c,
				Map__c,
				Performance__c,
				Provision__c,
				TAN_320_S_Copper_Quantity__c,
				TAN_320_S_Fiber_Quantity__c,
				TAN_420_M_Fiber_Quantity__c,
				TAN_420_M_Copper_Quantity__c,
				TAN_220_DEV_Copper_Quantity__c,
				TAN_220_DEV_Fiber_Quantity__c,
				TAN_720_L_Fiber_Quantity__c,
				TAN_720_L_Copper_Quantity__c,
				TAN_920_XL_Copper_Quantity__c,
				TAN_920_XL_Fiber_Quantity__c,
				TAN_VIRTUAL_Quantity__c,
				TAN_CLOUD_Quantity__c,
				TAN_L_730_CP_Quantity__c,
				TAN_L_735_FB_Quantity__c,
				TAN_M_430_CP_Quantity__c,
				TAN_M_435_FB_Quantity__c,
				TAN_S_330_CP_Quantity__c,
				TAN_S_335_FB_Quantity__c,
				TAN_XL_930_CP_Quantity__c,
				TAN_XL_935_FB_Quantity__c,
				Chronicle__c,
				Enforce__c
			FROM POC_Request__c
			WHERE Id IN :pocRequestIds
		]) {
			Date endDate = pocRequest.Start_Date__c.addDays(Integer.valueOf(pocRequest.Duration__c));

			OpportunityLineItem oli = new OpportunityLineItem(
				OpportunityId = pocRequest.POC_Opportunity__c,
				UnitPrice = 0,
				ServiceDate = pocRequest.Start_Date__c,
				End_Date__c = endDate,
				Quantity = pocRequest.Quantity__c
			);

			if (pocRequest.Trace__c && skuMap.containsKey('TAN-TRACE-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-TRACE-S')));
			}
			if (pocRequest.Patch__c && skuMap.containsKey('TAN-PTCH2-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-PTCH2-S')));
			}
			if (pocRequest.Discover__c && skuMap.containsKey('TAN-DISC-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-DISC-S')));
			}
			if (pocRequest.IR__c && skuMap.containsKey('TAN-IR-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-IR-S')));
			}
			if (pocRequest.IOCD__c && skuMap.containsKey('TAN-IOCD-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-IOCD-S')));
			}
			if (pocRequest.Comply__c && skuMap.containsKey('TAN-COMP-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-COMP-S')));
			}
			if (pocRequest.Asset__c && skuMap.containsKey('TAN-ASSET-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-ASSET-S')));
			}
			if (pocRequest.Integrity_Monitor__c && skuMap.containsKey('TAN-IM-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-IM-S')));
			}
			if (pocRequest.Core__c && skuMap.containsKey('TAN-CORE-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-CORE-S')));
			}
			if (pocRequest.Threat_Response__c && skuMap.containsKey('TAN-TR-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-TR-S')));
			}
			if (pocRequest.Deploy__c && skuMap.containsKey('TAN-DEPLOY-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-DEPLOY-S')));
			}
			if (pocRequest.Map__c && skuMap.containsKey('TAN-MAP-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-MAP-S')));
			}
			if (pocRequest.Reveal__c && skuMap.containsKey('TAN-REVEAL-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-REVEAL-S')));
			}
			if (pocRequest.Performance__c && skuMap.containsKey('TAN-PERFORMANCE-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-PERFORMANCE-S')));
			}
			if (pocRequest.Chronicle__c && skuMap.containsKey('GCP-CHRNCL')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('GCP-CHRNCL')));
			}
			if (pocRequest.Enforce__c && skuMap.containsKey('TAN-ENFORCE-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-ENFORCE-S')));
			}
			if (pocRequest.Provision__c && skuMap.containsKey('TAN-PRV-S')) {
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-PRV-S')));
			}
			if (pocRequest.TAN_320_S_Copper_Quantity__c != null && skuMap.containsKey('TAN-S-320-CP')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_320_S_Copper_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-S-320-CP')));
			}
			if (pocRequest.TAN_320_S_Fiber_Quantity__c != null && skuMap.containsKey('TAN-S-325-FB')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_320_S_Fiber_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-S-325-FB')));
			}
			if (pocRequest.TAN_420_M_Copper_Quantity__c != null && skuMap.containsKey('TAN-M-420-CP')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_420_M_Copper_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-M-420-CP')));
			}
			if (pocRequest.TAN_420_M_Fiber_Quantity__c != null && skuMap.containsKey('TAN-M-425-FB')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_420_M_Fiber_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-M-425-FB')));
			}
			if (
				pocRequest.TAN_220_DEV_Copper_Quantity__c != null && skuMap.containsKey('TAN-DEV-220-CP')
			) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_220_DEV_Copper_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-DEV-220-CP')));
			}
			if (
				pocRequest.TAN_220_DEV_Fiber_Quantity__c != null && skuMap.containsKey('TAN-DEV-225-FB')
			) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_220_DEV_Fiber_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-DEV-225-FB')));
			}
			if (pocRequest.TAN_720_L_Copper_Quantity__c != null && skuMap.containsKey('TAN-L-720-CP')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_720_L_Copper_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-L-720-CP')));
			}
			if (pocRequest.TAN_720_L_Fiber_Quantity__c != null && skuMap.containsKey('TAN-L-725-FB')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_720_L_Fiber_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-L-725-FB')));
			}
			if (pocRequest.TAN_920_XL_Copper_Quantity__c != null && skuMap.containsKey('TAN-XL-920-CP')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_920_XL_Copper_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-XL-920-CP')));
			}
			if (pocRequest.TAN_920_XL_Fiber_Quantity__c != null && skuMap.containsKey('TAN-XL-925-FB')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_920_XL_Fiber_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-XL-925-FB')));
			}
			if (pocRequest.TAN_VIRTUAL_Quantity__c != null && skuMap.containsKey('TAN-VIRTUAL')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_VIRTUAL_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-VIRTUAL')));
			}
			if (pocRequest.TAN_CLOUD_Quantity__c != null && skuMap.containsKey('TAN-CLOUD')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_CLOUD_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-CLOUD')));
			}
			if (pocRequest.TAN_S_330_CP_Quantity__c != null && skuMap.containsKey('TAN-S-330-CP')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_S_330_CP_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-S-330-CP')));
			}
			if (pocRequest.TAN_S_335_FB_Quantity__c != null && skuMap.containsKey('TAN-S-335-FB')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_S_335_FB_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-S-335-FB')));
			}
			if (pocRequest.TAN_M_430_CP_Quantity__c != null && skuMap.containsKey('TAN-M-430-CP')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_M_430_CP_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-M-430-CP')));
			}
			if (pocRequest.TAN_M_435_FB_Quantity__c != null && skuMap.containsKey('TAN-M-435-FB')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_M_435_FB_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-M-435-FB')));
			}
			if (pocRequest.TAN_L_730_CP_Quantity__c != null && skuMap.containsKey('TAN-L-730-CP')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_L_730_CP_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-L-730-CP')));
			}
			if (pocRequest.TAN_L_735_FB_Quantity__c != null && skuMap.containsKey('TAN-L-735-FB')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_L_735_FB_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-L-735-FB')));
			}
			if (pocRequest.TAN_XL_930_CP_Quantity__c != null && skuMap.containsKey('TAN-XL-930-CP')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_XL_930_CP_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-XL-930-CP')));
			}
			if (pocRequest.TAN_XL_935_FB_Quantity__c != null && skuMap.containsKey('TAN-XL-935-FB')) {
				oli.Quantity = Decimal.valueOf(pocRequest.TAN_XL_935_FB_Quantity__c);
				oppLines.add(buildOpportunityProduct(oli, skuMap.get('TAN-XL-935-FB')));
			}
		}

		if (!oppLines.isEmpty()) {
			insert oppLines;
		}
	}

	private static OpportunityLineItem buildOpportunityProduct(
		OpportunityLineItem oliToCloneFrom,
		Id productId
	) {
		OpportunityLineItem newOLI = oliToCloneFrom.clone(false, true);
		newOLI.Product2Id = productId;
		return newOLI;
	}

	//Method to put the validaton on creating/updating poc request record when server country is Afghanistan
	public static void validateApprovedSupportRequestForExceptionCountries(
		List<POC_Request__c> newPOCRequests,
		Map<Id, POC_Request__c> oldPOCRequests
	) {
		Set<Id> accIds = new Set<Id>();
		List<POC_Request__c> restrictedCountryPOC = new List<POC_Request__c>();
		Set<String> setOfAccountIdAndExceptionCountry = new Set<String>();
		Id onPremRecordTypeId = Utility.getRecordTypeIdByAPIName('POC_Request__c', 'Standard');
		Id taasRecordTypeId = Utility.getRecordTypeIdByAPIName('POC_Request__c', 'TaaS');

		//Get set of restricted country records
		Set<String> restrictedCountries = getRestrictedCountries();

		//Check for all the criteria
		for (POC_Request__c eachRequest : newPOCRequests) {
			if (
				eachRequest.Deployment_Country__c != null &&
				restrictedCountries.contains(eachRequest.Deployment_Country__c) &&
				(eachRequest.RecordTypeId == onPremRecordTypeId ||
				eachRequest.RecordTypeId == taasRecordTypeId) &&
				(Trigger.isInsert ||
				(eachRequest.Deployment_Country__c !=
				oldPOCRequests.get(eachRequest.Id).Deployment_Country__c))
			) {
				accIds.add(eachRequest.Account__c);
				restrictedCountryPOC.add(eachRequest);
			}
		}

		//Fetch approved ISR Records
		if (!accIds.isEmpty()) {
			for (Account_Support_Request__c eachISR : [
				SELECT Id, Account__c, Status__c, Exception_Country__c
				FROM Account_Support_Request__c
				WHERE
					Status__c = 'Approved'
					AND Exception_Country__c IN :restrictedCountries
					AND RecordType.DeveloperName = 'Restricted_Country_Exception'
					AND Account__c IN :accIds
			]) {
				String key = eachISR.Account__c + '-' + eachISR.Exception_Country__c;
				setOfAccountIdAndExceptionCountry.add(key);
			}
			for (POC_Request__c eachRequest : restrictedCountryPOC) {
				String key = eachRequest.Account__c + '-' + eachRequest.Deployment_Country__c;
				if (!setOfAccountIdAndExceptionCountry.contains(key)) {
					eachRequest.addError(label.POC_Request_Restricted_Country_Validation_Msg);
				}
			}
		}
	}

	private static Set<String> getRestrictedCountries() {
		Set<String> countryExports = new Set<String>();
		List<Country_For_Export__c> countryExportList = [
			SELECT Id, Name
			FROM Country_For_Export__c
			WHERE License_Approved__c = FALSE
		];
		for (Country_For_Export__c eachCountryExport : countryExportList) {
			countryExports.add(eachCountryExport.name);
		}
		return countryExports;
	}
}