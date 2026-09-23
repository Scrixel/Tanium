/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class for BillingScheduleConfigurator
 * @Date: 2024-12-12
 * @Author: Savita Mirpuri
 * RequestId  ModifiedDate  Description
 * SS-9339    2024-12-24    Enable Quarterly Installment for Quotes with Partners having IsAllowedQuarterlyBilling__c = true
 * SS-10925   2025-05-20    Resolve SOQL Limit Error
 * SS-11278   2025-07-10    Add getBillingScheduleFields
 * SS-13619   2026-08-14    Migrated to standard Quote/QuoteLineItem references
 */
public class BillingScheduleConfiguratorUtility {
	private static Billing_Schedule_Configurator__mdt toolInfo;
	private static final String BUSINESS_MOTION_MSP = 'MSP';
	public static Map<Id, Profile> profileMap = new Map<Id, Profile>();

	@AuraEnabled(cacheable=true)
	public static Utility getUtilityInfo() {
		Utility info = new Utility();
		info.paymentTypeOptions = BillingScheduleConfiguratorUtility.getPaymentTypeOptions(null);
		info.ProfilesWithRestrictedPaymentTypesAccess = BillingScheduleConfiguratorUtility.getProfilesWithRestrictedPaymentTypesAccess();
		info.closedOpportunityError = System.Label.Billing_Schedule_Configurator_Closed_Opportunity_Error;
		info.restrictedPaymentError = System.Label.Billing_Schedule_Configurator_Restricted_Payment_Type_Error;
		return info;
	}

	@AuraEnabled(cacheable=true)
	public static String getProfileName() {
		if (!BillingScheduleConfiguratorUtility.profileMap.containsKey(UserInfo.getProfileId())) {
			BillingScheduleConfiguratorUtility.profileMap.putAll(
				new Map<Id, Profile>([SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()])
			);
		}
		return BillingScheduleConfiguratorUtility.profileMap.get(UserInfo.getProfileId()).Name;
	}

	@AuraEnabled(cacheable=true)
	public static Billing_Schedule_Configurator__mdt getToolInfo() {
		if (toolInfo == null) {
			toolInfo = Billing_Schedule_Configurator__mdt.getInstance(
				'BillingScheduleConfiguratorToolInfo'
			);
		}
		return toolInfo;
	}

	@AuraEnabled(cacheable=true)
	public static List<String> getRestrictedPaymentTypes() {
		List<String> restrictedPaymentTypes = new List<String>();
		toolInfo = getToolInfo();
		if (!String.isBlank(toolInfo.RestrictedPaymentTypes__c)) {
			for (String eachRestrictedPaymentType : toolInfo.RestrictedPaymentTypes__c.split(';')) {
				restrictedPaymentTypes.add(eachRestrictedPaymentType);
			}
		}
		return restrictedPaymentTypes;
	}

	@AuraEnabled(cacheable=true)
	public static List<String> getBundleOptionTypesNotShownInTool() {
		List<String> bundleOptionTypesNotShownInTool = new List<String>();
		toolInfo = getToolInfo();
		if (!String.isBlank(toolInfo.BundleOptionTypesNotShownInTool__c)) {
			for (
				String eachRestrictedBundleOptionType : toolInfo.BundleOptionTypesNotShownInTool__c.split(
					';'
				)
			) {
				bundleOptionTypesNotShownInTool.add(eachRestrictedBundleOptionType);
			}
		}
		return bundleOptionTypesNotShownInTool;
	}

	@AuraEnabled(cacheable=true)
	public static List<String> getProfilesWithRestrictedPaymentTypesAccess() {
		List<String> profilesWithRestrictedPaymentTypesAccess = new List<String>();
		toolInfo = getToolInfo();
		if (!String.isBlank(toolInfo.ProfilesWithRestrictedPaymentTypesAccess__c)) {
			for (
				String eachProfileName : toolInfo.ProfilesWithRestrictedPaymentTypesAccess__c.split(';')
			) {
				profilesWithRestrictedPaymentTypesAccess.add(eachProfileName);
			}
		}
		return profilesWithRestrictedPaymentTypesAccess;
	}

	@AuraEnabled(cacheable=true)
	public static Boolean isSalesRepEligibleToAccessQuarterlyPayment(QuoteLineItem quoteLine) {
		Boolean quarterlyPaymentEligible = false;
		if (
			quoteLine != null &&
			quoteLine.Quote.ELV_Partner__r.IsQuarterlyBillingAllowed__c &&
			quoteLine.Quote.Opportunity?.Business_Motion__c?.equals(BUSINESS_MOTION_MSP)
		) {
			quarterlyPaymentEligible = true;
		}
		return quarterlyPaymentEligible;
	}

	@AuraEnabled(cacheable=true)
	public static List<String> getPaymentTypeOptions(QuoteLineItem quoteLine) {
		String runningUserProfileName = BillingScheduleConfiguratorUtility.getProfileName();
		List<String> restrictedPaymentTypes = BillingScheduleConfiguratorUtility.getRestrictedPaymentTypes();
		BillingScheduleConfiguratorUtility.Utility info = new BillingScheduleConfiguratorUtility.Utility();
		info.paymentTypeOptions = new List<String>();
		Schema.DescribeFieldResult fieldResult = Billing_Schedule__c.PaymentType__c.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for (Schema.PicklistEntry eachPklst : ple) {
			if (getProfilesWithRestrictedPaymentTypesAccess().contains(runningUserProfileName)) {
				if (eachPklst.isActive()) {
					info.paymentTypeOptions.add(eachPklst.getValue());
				}
			} else {
				if (
					isSalesRepEligibleToAccessQuarterlyPayment(quoteLine) &&
					eachPklst.getValue().contains('Quarterly')
				) {
					info.paymentTypeOptions.add(eachPklst.getValue());
				} else if (
					restrictedPaymentTypes.isEmpty() || !restrictedPaymentTypes.contains(eachPklst.getValue())
				) {
					info.paymentTypeOptions.add(eachPklst.getValue());
				}
			}
		}
		return info.paymentTypeOptions;
	}

	@AuraEnabled(cacheable=true)
	public static String getQuoteTermsForLockedDates() {
		toolInfo = getToolInfo();
		String quoteTermsForLockedDates = toolInfo.QuoteTermsForLockedDates__c != null
			? toolInfo.QuoteTermsForLockedDates__c
			: '';
		return quoteTermsForLockedDates;
	}

	@AuraEnabled(cacheable=true)
	public static String getQuoteTermsForUnlockedDates() {
		toolInfo = getToolInfo();
		String quoteTermsForUnlockedDates = toolInfo.QuoteTermsForUnlockedDates__c != null
			? toolInfo.QuoteTermsForUnlockedDates__c
			: '';
		return quoteTermsForUnlockedDates;
	}

	@AuraEnabled(cacheable=true)
	public static String getQuoteTermsForFirstBilling() {
		toolInfo = getToolInfo();
		String quoteTermsForFirstBilling = toolInfo.QuoteTermsForFirstBilling__c != null
			? toolInfo.QuoteTermsForFirstBilling__c
			: '';
		return quoteTermsForFirstBilling;
	}

	public static String getQuoteTermsForZeroDollars() {
		toolInfo = getToolInfo();
		String quoteTermsForZeroDollars = toolInfo.QuoteTermsForZeroDollars__c != null
			? toolInfo.QuoteTermsForZeroDollars__c
			: '';
		return quoteTermsForZeroDollars;
	}

	public static String getBillingScheduleFields() {
		toolInfo = getToolInfo();
		return toolInfo?.Billing_Schedule_Fields__c ?? '';
	}

	public static List<String> getProfilesWithRestrictedOppStageAccess() {
		toolInfo = getToolInfo();
		return toolInfo.ProfilesWithRestrictedOppStageAccess__c.split(';');
	}

	public static List<String> getRestrictedOppStages() {
		toolInfo = getToolInfo();
		return toolInfo.RestrictedOpportunityStagesForToolAccess__c.toLowerCase().split(';');
	}

	public static String getOpportunityStage(String recordId, String objectAPIName) {
		if (objectAPIName == 'Opportunity') {
			Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :recordId];
			return opp.StageName;
		} else {
			Quote quote = [SELECT Id, Opportunity.StageName FROM Quote WHERE Id = :recordId];
			return quote.Opportunity.StageName;
		}
	}

	public static String formatBillingAmount(Decimal billingAmount) {
		if (billingAmount.format().contains('.')) {
			if (billingAmount.format().substringAfter('.').length() > 1) {
				return billingAmount.format();
			} else {
				return (billingAmount.format() + '0');
			}
		} else {
			return (billingAmount.format() + '.00');
		}
	}

	public static String formatBillingDate(Date billingDate) {
		Integer day = billingDate.day();
		Integer month = billingDate.month();
		Integer yr = billingDate.year();

		DateTime DT = DateTime.newInstance(yr, month, day);

		return DT.format('MMMM') + ' ' + yr;
	}

	public class Utility {
		@AuraEnabled
		public List<String> paymentTypeOptions { get; set; }

		@AuraEnabled
		public List<String> profilesWithRestrictedPaymentTypesAccess { get; set; }

		@AuraEnabled
		public String closedOpportunityError { get; set; }

		@AuraEnabled
		public String restrictedPaymentError { get; set; }
	}
}