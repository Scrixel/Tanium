/**
 * @Business: Do ARR calcuation on Quote (SBQQ__Quote__c & SBQQ__QuoteLine__c)
 * @Date: 2018-11-23
 * @Author: Cumulus Vision
 * @Request: TAN-710
 * Modified  ModifiedDate   Description
 * TAN-710   2018-11-23     Initial Development
 */

global class CalculateARRQuote {
	@AuraEnabled
	webService static String recalculateARR(String quoteId) {
		List<SBQQ__QuoteLine__c> quoteLineList = [
			SELECT
				Id,
				SBQQ__Product__c,
				End_Date__c,
				TRAC_StartDate__c,
				Prod_Max_End_Date__c,
				Prod_Min_Start_Date__c,
				Transaction_Type__c,
				Product_Line__c
			FROM SBQQ__QuoteLine__c
			WHERE SBQQ__Quote__c = :quoteId AND Transaction_Type__c != NULL AND Product_Line__c != NULL
			ORDER BY SBQQ__Product__c
		];

		quoteLineList = doARRCalculations(quoteLineList);
		update quoteLineList;

		return 'done';
	}

	public static List<SBQQ__QuoteLine__c> doARRCalculations(List<SBQQ__QuoteLine__c> quoteLineList) {
		Map<String, Date> startDatesMap = new Map<String, Date>();
		Map<String, Date> endDatesMap = new Map<string, Date>();

		for (SBQQ__QuoteLine__c quoteLine : quoteLineList) {
			if (startDatesMap.get(quoteLine.Product_Line__c + quoteLine.Transaction_Type__c) == null) {
				startDatesMap.put(
					quoteLine.Product_Line__c + quoteLine.Transaction_Type__c,
					quoteLine.TRAC_StartDate__c
				);
			} else {
				Date lastStartDate = startDatesMap.get(
					quoteLine.Product_Line__c + quoteLine.Transaction_Type__c
				);
				if (quoteLine.TRAC_StartDate__c < lastStartDate) {
					startDatesMap.put(
						quoteLine.Product_Line__c + quoteLine.Transaction_Type__c,
						quoteLine.TRAC_StartDate__c
					);
				}
			}

			if (endDatesMap.get(quoteLine.Product_Line__c + quoteLine.Transaction_Type__c) == null) {
				endDatesMap.put(
					quoteLine.Product_Line__c + quoteLine.Transaction_Type__c,
					quoteLine.End_Date__c
				);
			} else {
				Date lastEndDate = endDatesMap.get(
					quoteLine.Product_Line__c + quoteLine.Transaction_Type__c
				);
				if (quoteLine.End_Date__c > lastEndDate) {
					endDatesMap.put(
						quoteLine.Product_Line__c + quoteLine.Transaction_Type__c,
						quoteLine.End_Date__c
					);
				}
			}
		}

		for (SBQQ__QuoteLine__c quoteLine : quoteLineList) {
			if (startDatesMap.get(quoteLine.Product_Line__c + quoteLine.Transaction_Type__c) != null) {
				quoteLine.Prod_Min_Start_Date__c = startDatesMap.get(
					quoteLine.Product_Line__c + quoteLine.Transaction_Type__c
				);
			}

			if (endDatesMap.get(quoteLine.Product_Line__c + quoteLine.Transaction_Type__c) != null) {
				quoteLine.Prod_Max_End_Date__c = endDatesMap.get(
					quoteLine.Product_Line__c + quoteLine.Transaction_Type__c
				);
			}
		}

		return quoteLineList;
	}
}