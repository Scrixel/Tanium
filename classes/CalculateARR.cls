/**
 * @Business: Do ARR calcuation
 * @Date: 2018-08-18
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description
 * TAN-641    2018-08-18     Initial Development
 * TAN-645    2018-08-29     Annoted recalculateARR method as AuraEnabled.
 */
global class CalculateARR {
	@AuraEnabled
	webService static String recalculateARR(String oppId) {
		List<OpportunityLineItem> oli = [
			SELECT
				id,
				product2Id,
				End_Date__c,
				TRAC_StartDate__c,
				Prod_Max_End_Date__c,
				Prod_Min_Start_Date__c,
				Transaction_Type__c,
				Product_Line__c
			FROM OpportunityLineItem
			WHERE OpportunityId = :oppId AND Transaction_Type__c != NULL AND Product_Line__c != NULL
			ORDER BY product2Id
		];

		oli = doARRCalculations(oli);
		update oli;
		return 'done';
	}

	public static List<OpportunityLineItem> doARRCalculations(List<OpportunityLineItem> oli) {
		map<string, date> startDates_map = new Map<string, date>();
		map<string, date> endDates_map = new Map<string, date>();
		for (OpportunityLineItem x : oli) {
			if (startDates_map.get(x.Product_Line__c + x.Transaction_Type__c) == null) {
				startDates_map.put(x.Product_Line__c + x.Transaction_Type__c, x.TRAC_StartDate__c);
			} else {
				date lastStartDate = startDates_map.get(x.Product_Line__c + x.Transaction_Type__c);
				if (x.TRAC_StartDate__c < lastStartDate)
					startDates_map.put(x.Product_Line__c + x.Transaction_Type__c, x.TRAC_StartDate__c);
			}
			if (endDates_map.get(x.Product_Line__c + x.Transaction_Type__c) == null) {
				endDates_map.put(x.Product_Line__c + x.Transaction_Type__c, x.End_Date__c);
			} else {
				date lastEndDate = endDates_map.get(x.Product_Line__c + x.Transaction_Type__c);
				if (x.End_Date__c > lastEndDate)
					endDates_map.put(x.Product_Line__c + x.Transaction_Type__c, x.End_Date__c);
			}
		}

		for (OpportunityLineItem x : oli) {
			if (startDates_map.get(x.Product_Line__c + x.Transaction_Type__c) != null) {
				x.Prod_Min_Start_Date__c = startDates_map.get(x.Product_Line__c + x.Transaction_Type__c);
			}

			if (endDates_map.get(x.Product_Line__c + x.Transaction_Type__c) != null) {
				x.Prod_Max_End_Date__c = endDates_map.get(x.Product_Line__c + x.Transaction_Type__c);
			}
		}
		return oli;
	}
}