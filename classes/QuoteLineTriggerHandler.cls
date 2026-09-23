/**
 * @Business: Handler for QuoteLineTrigger
 * @Date: 2018-03-23
 * @Author: Cumulus Vision, Tanium Dev Team
 * @Request: TAN-494
 * Modified  ModifiedDate  Description
 * TAN-494	 2018-03-23    Innitial Development
 * TAN-598   2018-06-05    Added new rollup field - Deploy
 * TAN-605   2018-06-18    Added new rollup field - Operations Suite
 * TAN-520   2018-04-02    New Billing Schedule Process
 * TAN-606   2018-06-27    Check for null values
 * TAN-707   2018-11-20    Adjust billing amount such that there sum would be exact to total
 * TAN-743   2019-01-17    Adjust billing dates calculation for Leap year in when Reverse_Billing__c eq true
 * TAN-753   2019-02-07    added additional logic for Reverse Billing and added some debug statements to various IF statements.
 * TAN-845   2020-02-28    logic updates to Billing Amounts 2 and 3. Added 1 day to each for Reverse Billing equal to true.
 * SS-7632   2024-03-26    Remove checkRenewedSubscriptionQuoteLines from beforeDelete method.
 * SS-7665	 2024-04-23    isMSP to use quote.Business_Motion_Oppty__c='MSP'
 * SS-7766   2024-05-15    Added Nebula Logger func., plus class cleanup
 * SS-9803   2024-12-09    Added calls to method QuoteTrackerTriggerHandler.publishQuoteTrackerEvent
 * SS-8074   2025-07-18    Remove references in handler for a deprecated field
 * SS-12886  2026-04-21    Removed call to method QuoteTrackerTriggerHandler.publishQuoteTrackerEvent
 */

public class QuoteLineTriggerHandler extends TriggerHandler {
	public List<SBQQ__QuoteLine__c> quoteLines;
	public Map<Id, SBQQ__QuoteLine__c> oldMap;
	public static final String PROSPECT_ACCOUNT = 'Prospect';
	public static final String SOFTWARE_PRODUCT_GROUP = 'Software';

	public QuoteLineTriggerHandler() {
		super('QuoteLineTriggerHandler');
		this.quoteLines = (List<SBQQ__QuoteLine__c>) Trigger.new;
		this.oldMap = (Map<Id, SBQQ__QuoteLine__c>) Trigger.oldMap;
	}

	public override void afterInsert() {
		populateRollupSummaryfields(quoteLines);
	}

	public override void beforeUpdate() {
		OpportunityQuoteLineLockUtility.checkLockedQuoteLines(quoteLines);
		quoteLineCheckIfMultipleSoftwareBundle(quoteLines);
	}

	public override void afterUpdate() {
		Set<Id> quoteIds = new Set<Id>();
		OpportunityQuoteLineLockUtility.setIsPrimaryUpdated(quoteLines);

		for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
			SBQQ__QuoteLine__c oldQuoteLine = oldMap.get(quoteLine.Id);

			if (
				quoteLine.Product_Line__c != oldQuoteLine.Product_Line__c ||
				quoteLine.Promotion__c != oldQuoteLine.Promotion__c ||
				quoteLine.LicenseMetric__c != oldQuoteLine.LicenseMetric__c ||
				quoteLine.Media_Type__c != oldQuoteLine.Media_Type__c
			) {
				quoteIds.add(quoteLine.SBQQ__Quote__c);
			}
		}
		populateRollupOnQuote(quoteIds);
	}

	public override void beforeDelete() {
		OpportunityQuoteLineLockUtility.checkLockedQuoteLines(oldMap.values());
	}

	public override void afterDelete() {
		populateRollupSummaryFields(oldMap.values());
	}

	public override void afterUndelete() {
		populateRollupSummaryFields(quoteLines);
	}

	private void populateRollupSummaryFields(List<SBQQ__QuoteLine__c> quoteLineList) {
		Set<Id> setQuoteId = new Set<Id>();
		for (SBQQ__QuoteLine__c quoteLine : quoteLineList) {
			setQuoteId.add(quoteLine.SBQQ__Quote__c);
		}
		populateRollupOnQuote(setQuoteId);
	}

	public static void populateRollupOnQuote(Set<Id> quoteIds) {
		List<String> fields = new List<String>{
			'Product_Line__c',
			'Promotion__c',
			'LicenseMetric__c',
			'Media_Type__c'
		};
		String queryTemplate = 'SELECT Id, SBQQ__Quote__c, {0} FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :quoteIds';
		String query = String.format(queryTemplate, new List<String>{ String.join(fields, ', ') });
		List<SBQQ__QuoteLine__c> listQuoteLineItems = database.query(query);
		Map<Id, List<SBQQ__QuoteLine__c>> mapQuoteIdToQuoteLines = createIdToListMap(
			listQuoteLineItems,
			'SBQQ__Quote__c'
		);
		List<SBQQ__Quote__c> listQuoteToupdate = new List<SBQQ__Quote__c>();
		List<QuoteCountAggInfo> listQuoteRollupInfo = getRollupInfo();
		List<SBQQ__QuoteLine__c> listQuoteLine;

		for (Id quoteId : mapQuoteIdToQuoteLines.keySet()) {
			SBQQ__Quote__c quoteToUpdate = new SBQQ__Quote__c(Id = quoteId);
			listQuoteLine = mapQuoteIdToQuoteLines.get(quoteId);
			if (listQuoteLine.isEmpty()) {
				continue;
			}
			Set<Id> setRecordId;
			for (QuoteCountAggInfo rollupField : listQuoteRollupInfo) {
				QuoteLinePicklistFilter filter = rollupField.childObjectFilter;
				setRecordId = new Set<Id>();

				for (String fieldValue : filter.picklistOptions) {
					if (filter.filterOperation == PicklistFieldOperation.CONTAINS) {
						setRecordId.addAll(
							getRecordIdsWithCriteria(listQuoteLine, filter.picklistField, fieldValue)
						);
					}
				}
				quoteToUpdate.put(rollupField.quoteFieldToAggregate, setRecordId.size());
			}
			listQuoteToupdate.add(quoteToUpdate);
		}
		try {
			update listQuoteToupdate;
		} catch (Exception e) {
			Logger.error('QuoteLineTriggerHandler.populateRollupOnQuote ERRORS', e);
			Logger.saveLog();
		}
	}

	private static Set<Id> getRecordIdsWithCriteria(
		List<SBQQ__QuoteLine__c> listQuoteLine,
		String fieldname,
		String valueToCompare
	) {
		Set<Id> quoteLineIds = new Set<Id>();

		for (SBQQ__QuoteLine__c quoteLine : listQuoteLine) {
			String fieldValue = String.valueOf(quoteLine.get(fieldname));

			if (fieldValue != null && fieldValue.equalsIgnoreCase(valueToCompare)) {
				quoteLineIds.add((Id) quoteLine.get('Id'));
			}
		}
		return quoteLineIds;
	}

	private static Map<Id, List<Sobject>> createIdToListMap(
		List<Sobject> listOfRec,
		String Fieldname
	) {
		Map<Id, List<Sobject>> MapOfRecords = new Map<Id, List<Sobject>>();
		for (Sobject SobjectRecord : listOfRec) {
			if (!MapOfRecords.containsKey((Id) SobjectRecord.get(Fieldname))) {
				MapOfRecords.put((Id) SobjectRecord.get(Fieldname), new List<Sobject>());
			}
			MapOfRecords.get((Id) SobjectRecord.get(Fieldname)).add(SobjectRecord);
		}
		return MapOfRecords;
	}

	private static List<QuoteCountAggInfo> getRollupInfo() {
		List<QuoteCountAggInfo> rollupCriteriaList = new List<QuoteCountAggInfo>();
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'Appliance_SKUs__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Appliance' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'Bursting_Count__c',
				'Promotion__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Burst' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'HardwareSupport__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Appliance' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'IRProductDescription__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'IR' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'IR_Use_Only__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Core-LTD' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'Managed_OS__c',
				'LicenseMetric__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Managed OS' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'MediaTypeOnTemplate__c',
				'Media_Type__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Copper', 'Fiber' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'OnsiteTAMCount__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Onsite Support', 'MODLELA' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'PromotionExist__c',
				'Promotion__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Burst', 'Trial', 'FOC' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'Selling_Core_Subparts__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Foundation', 'Authoring', 'Connect', 'Trends' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumAssetDefinitions__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Asset' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumComplyDefinitions__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Comply' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumCoreDefinition__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Core-LTD', 'Core-UPG', 'Platform' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumDiscoverDefinition__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Discover' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumIMDefinitions__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'FIM' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumIOCDetectDef__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'IOC Detect' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumPatchDefinitions__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Patch' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumProtectDefinitions__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Protect' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumSecuritySuiteDef__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Security Suite' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumThreatResponseDef__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Tanium Threat Response' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'TaniumTraceDefinitions__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Trace' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'Tanium_Deploy_Definition__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Deploy' }
			)
		);
		rollupCriteriaList.add(
			buildQuoteCountAggInfo(
				'Operation_Suites_SKU__c',
				'Product_Line__c',
				PicklistFieldOperation.CONTAINS,
				new List<String>{ 'Operations Suite' }
			)
		);
		return rollupCriteriaList;
	}

	public static void quoteLineCheckIfMultipleSoftwareBundle(List<SBQQ__QuoteLine__c> quotelines) {
		Set<Id> softwareProductId = new Set<Id>();
		Set<Id> quoteIds = new Set<Id>();
		Set<Id> tmpQuoteIds = new Set<Id>();
		Set<Id> dexBundleProductIds = getDexBundleProductIds();
		SBQQ__Quote__c quote;

		for (SBQQ__QuoteLine__c quoteline : quotelines) {
			tmpQuoteIds.add(quoteline.SBQQ__Quote__c);
		}

		Map<Id, SBQQ__Quote__c> quotesMap = getQuoteDetails(tmpQuoteIds);

		for (SBQQ__QuoteLine__c quoteline : quotelines) {
			quote = quotesMap.get(quoteline.SBQQ__Quote__c);
			if (
				isProspectAccount(quote) &&
				(quoteline.Product_Group__c == SOFTWARE_PRODUCT_GROUP && quoteline.SBQQ__Bundle__c)
			) {
				if (quoteIds.contains(quoteline.SBQQ__Quote__c)) {
					if (
						softwareProductId.contains(quoteline.SBQQ__Product__c) ||
						dexBundleProductIds.contains(quoteline.SBQQ__Product__c)
					) {
						continue;
					} else {
						quoteline.addError(System.Label.Multiple_Software_Bundle_Error);
					}
				} else {
					if (!dexBundleProductIds.contains(quoteline.SBQQ__Product__c)) {
						quoteIds.add(quoteline.SBQQ__Quote__c);
					}
					softwareProductId.add(quoteline.SBQQ__Product__c);
				}
			}
		}
	}

	private static Map<Id, SBQQ__Quote__c> getQuoteDetails(Set<Id> quoteIds) {
		Map<Id, SBQQ__Quote__c> quoteDetails = new Map<Id, SBQQ__Quote__c>(
			[
				SELECT
					Id,
					Name,
					Business_Motion_Oppty__c,
					SBQQ__Account__c,
					Account_Type__c,
					SBQQ__PricebookId__c,
					SBQQ__Pricebook__c
				FROM SBQQ__Quote__c
				WHERE Id IN :quoteIds
			]
		);
		return quoteDetails;
	}

	public static Boolean isProspectAccount(SBQQ__Quote__c quote) {
		return quote.Account_Type__c == PROSPECT_ACCOUNT;
	}

	private static QuoteCountAggInfo buildQuoteCountAggInfo(
		String parentField,
		String childField,
		PicklistFieldOperation operation,
		List<String> values
	) {
		QuoteCountAggInfo rollup = new QuoteCountAggInfo();
		rollup.quoteFieldToAggregate = parentField;
		rollup.childObjectFilter = new QuoteLinePicklistFilter(childField, operation, values);
		return rollup;
	}

	@TestVisible
	private static Set<Id> getDexBundleProductIds() {
		Map<Id, Product2> productsMap = new Map<Id, Product2>(
			[SELECT Id FROM Product2 WHERE Digital_Employee_Experience_Bundle__c = TRUE]
		);
		return productsMap.keySet();
	}

	public enum PicklistFieldOperation {
		CONTAINS
	}

	class QuoteCountAggInfo {
		String quoteFieldToAggregate;
		QuoteLinePicklistFilter childObjectFilter;
	}

	class QuoteLinePicklistFilter {
		String picklistField;
		PicklistFieldOperation filterOperation;
		String[] picklistOptions;

		public QuoteLinePicklistFilter(
			String childPicklistField,
			PicklistFieldOperation operation,
			String[] textValues
		) {
			picklistField = childPicklistField;
			filterOperation = operation;
			picklistOptions = textValues;
		}
	}
}