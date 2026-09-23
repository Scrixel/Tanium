/**
 * @Business: Part of Trigger Framework for the Opportunity object
 * @Date:
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-8013	  2024-08-01		Add Nebula logger on existing DMLs
 * SS-8984	  2024-08-27		Remove Event Logs
 */
public with sharing class OpportunityRenewalUtility {
	private static final String DELAY_IN_MINUTES = System.Label.Quote_And_Lines_Update_Delay_in_minutes;
	private static final Id PARTNER_RECORD_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Account',
		'Partner'
	);
	private static final String QUOTE_LINE_TRIGGER_HANDLER_NAME = 'QuoteLineTriggerHandler';

	public static void updateQuotesAndLinesStartDates(
		List<Opportunity> updatedOpportunityList,
		Map<Id, Opportunity> oldOpportunityMap
	) {
		Set<Id> closedWonOpportunityIds = new Set<Id>();

		for (Opportunity updatedOpportunity : updatedOpportunityList) {
			if (
				oldOpportunityMap.get(updatedOpportunity.Id).StageName != Utility.CLOSED_WON &&
				updatedOpportunity.StageName == Utility.CLOSED_WON
			) {
				closedWonOpportunityIds.add(updatedOpportunity.Id);
			}
		}

		if (!closedWonOpportunityIds.isEmpty()) {
			Datetime now = Datetime.now();
			String schedule = generateSchedule(now);

			String jobID = System.schedule(
				'updateQuotesAndLinesStartDates ' + Math.random(),
				schedule,
				new ScheduleQuoteAndLinesUpdate(closedWonOpportunityIds)
			);
		}
	}

	public static void runQuoteAndLinesUpdates(Set<Id> opportunityIds) {
		List<SBQQ__Quote__c> quoteUpdateList = new List<SBQQ__Quote__c>();
		List<SBQQ__QuoteLine__c> quoteLineUpdateList = new List<SBQQ__QuoteLine__c>();
		Map<Id, RenewalDataWrapper> quoteIdRenewalDataWrapperMap = generateRenewalDataWrapperMap(
			opportunityIds
		);

		for (RenewalDataWrapper renewalDataWrapper : quoteIdRenewalDataWrapperMap.values()) {
			quoteUpdateList.add(renewalDataWrapper.quote);
			quoteLineUpdateList.addAll(renewalDataWrapper.quoteLines);
		}

		Savepoint savePoint = Database.setSavepoint();
		try {
			update quoteUpdateList;
			SBQQ.TriggerControl.disable();
			update quoteLineUpdateList;
		} catch (Exception e) {
			Database.rollback(savePoint);
			Logger.error('OpportunityRenewalUtility.runQuoteAndLinesUpdates ERRORS', e);
			Logger.saveLog();
		}
	}

	@TestVisible
	private static Map<Id, RenewalDataWrapper> generateRenewalDataWrapperMap(
		Set<Id> opportunityIds
	) {
		Map<Id, RenewalDataWrapper> quoteIdRenewalDataWrapperMap = new Map<Id, RenewalDataWrapper>();

		for (SBQQ__Quote__c primaryQuote : [
			SELECT
				Id,
				SBQQ__StartDate__c,
				SBQQ__Opportunity2__r.CloseDate,
				(
					SELECT Id, SBQQ__StartDate__c
					FROM SBQQ__LineItems__r
					WHERE SBQQ__StartDate__c != NULL
					ORDER BY SBQQ__StartDate__c ASC
				)
			FROM SBQQ__Quote__c
			WHERE
				SBQQ__Opportunity2__c IN :opportunityIds
				AND SBQQ__Primary__c = TRUE
				AND Do_Not_Show_Dates__c = FALSE
		]) {
			quoteIdRenewalDataWrapperMap.put(primaryQuote.Id, new RenewalDataWrapper(primaryQuote));
		}

		return quoteIdRenewalDataWrapperMap;
	}

	public static String generateSchedule(Datetime now) {
		Datetime schedule = now.addMinutes(Integer.valueOf(DELAY_IN_MINUTES));
		String cronExpression =
			schedule.second() +
			' ' +
			schedule.minute() +
			' ' +
			schedule.hour() +
			' ' +
			schedule.day() +
			' ' +
			schedule.month() +
			' ' +
			'?' +
			' ' +
			schedule.year();

		return cronExpression;
	}

	@TestVisible
	private class RenewalDataWrapper {
		@TestVisible
		private SBQQ__Quote__c quote = new SBQQ__Quote__c();
		@TestVisible
		private List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();

		public RenewalDataWrapper(SBQQ__Quote__c primaryQuote) {
			quote = primaryQuote;
			quoteLines = primaryQuote.SBQQ__LineItems__r;

			updateQuoteAndQuoteLineStartDates();
		}

		private void updateQuoteAndQuoteLineStartDates() {
			if (!quoteLines.isEmpty() && quote?.SBQQ__Opportunity2__r?.CloseDate != null) {
				quote.SBQQ__StartDate__c = quote.SBQQ__Opportunity2__r.CloseDate;

				Integer daysDelta;

				daysDelta = quoteLines[0]
					.SBQQ__StartDate__c.daysBetween(quote.SBQQ__Opportunity2__r.CloseDate);

				for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
					quoteLine.SBQQ__StartDate__c = quoteLine.SBQQ__StartDate__c.addDays(daysDelta);
				}
			}
		}
	}
}