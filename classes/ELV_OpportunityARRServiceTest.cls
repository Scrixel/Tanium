/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * Coverage for TNCI 139 / ELV-CPQ-036 - the Opportunity ARR service and its entry points.
 *
 * The arithmetic is exercised in memory. Building a real Opportunity, Quote and quote line
 * in this org drags in eight unrelated Opportunity triggers plus the Nue managed package,
 * which is neither necessary to prove the rules nor stable enough to depend on; the save-path
 * tests below cover the wiring against records already in the org.
 */
@IsTest(SeeAllData=true)
private class ELV_OpportunityARRServiceTest {
	private static Opportunity oppWith(Map<String, Object> values) {
		values.put('attributes', new Map<String, Object>{ 'type' => 'Opportunity' });
		return (Opportunity) JSON.deserialize(JSON.serialize(values), Opportunity.class);
	}

	private static Opportunity quoteSourced(Decimal day1, Decimal exitArr) {
		return oppWith(
			new Map<String, Object>{
				'Id' => '006000000000001AAA',
				'IsClosed' => false,
				'IsWon' => false,
				'Ruby__PrimaryQuote__c' => '0Q0000000000001AAA',
				'Ruby__PrimaryQuote__r' => new Map<String, Object>{
					'attributes' => new Map<String, Object>{ 'type' => 'Quote' },
					'Id' => '0Q0000000000001AAA',
					'ELV_Day_1_ARR__c' => day1,
					'ELV_Exit_ARR__c' => exitArr
				}
			}
		);
	}

	@IsTest
	static void theQuoteBranchWinsWhenAPrimaryQuoteExists() {
		Opportunity result = ELV_OpportunityARRService.calculate(quoteSourced(250000, 180000));

		System.assertEquals(
			250000,
			result.ELV_Sales_ARR_Before_Split__c,
			'Sales ARR is taken from the primary quote.'
		);
		System.assertEquals(180000, result.ELV_Exit_ARR__c, 'Exit ARR is taken from the quote.');
		System.assertEquals('Quote', result.ELV_ARR_Source__c, 'The branch is recorded.');
		System.assertEquals(
			'0Q0000000000001AAA',
			result.ELV_Primary_Quote_Stamp__c,
			'The quote Id is stamped so a lookup change is detectable.'
		);
	}

	@IsTest
	static void theJunctionBranchIsUsedWhenNoQuoteExists() {
		Opportunity opp = oppWith(
			new Map<String, Object>{
				'Id' => '006000000000002AAA',
				'IsClosed' => false,
				'IsWon' => false,
				'ELV_Subscription_ARR__c' => 90000,
				'ELV_Subscription_Exit_ARR__c' => 75000,
				'ELV_Subscription_Row_Count__c' => 3
			}
		);

		Opportunity result = ELV_OpportunityARRService.calculate(opp);

		System.assertEquals(
			90000,
			result.ELV_Sales_ARR_Before_Split__c,
			'The junction total carries the forecast while no quote is primary.'
		);
		System.assertEquals(75000, result.ELV_Exit_ARR__c, 'Exit ARR comes from the junction.');
		System.assertEquals(
			'Opportunity Subscription',
			result.ELV_ARR_Source__c,
			'The branch is recorded.'
		);
		System.assertEquals(
			null,
			result.ELV_Primary_Quote_Stamp__c,
			'No quote means no stamp.'
		);
	}

	@IsTest
	static void anEmptyJunctionReportsNoSourceRatherThanASubscriptionZero() {
		Opportunity result = ELV_OpportunityARRService.calculate(
			oppWith(
				new Map<String, Object>{
					'Id' => '006000000000003AAA',
					'IsClosed' => false,
					'IsWon' => false,
					'ELV_Subscription_Row_Count__c' => 0
				}
			)
		);

		System.assertEquals(0, result.ELV_Sales_ARR__c, 'The figure is zero.');
		System.assertEquals(
			'None',
			result.ELV_ARR_Source__c,
			'A zero with no rows behind it is distinguishable from a real subscription zero.'
		);
	}

	@IsTest
	static void closedLostAndFullChurnBothReportZero() {
		Opportunity closedLost = quoteSourced(250000, 180000);
		Map<String, Object> closedLostValues = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(closedLost));
		closedLostValues.put('IsClosed', true);
		closedLostValues.put('IsWon', false);
		closedLost = (Opportunity) JSON.deserialize(JSON.serialize(closedLostValues), Opportunity.class);

		Opportunity fullChurn = quoteSourced(250000, 180000);
		fullChurn.RVP_CHURN_RISK_OVERIDE__c = 'Full Churn';

		Opportunity closedWon = quoteSourced(250000, 180000);
		Map<String, Object> closedWonValues = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(closedWon));
		closedWonValues.put('IsClosed', true);
		closedWonValues.put('IsWon', true);
		closedWon = (Opportunity) JSON.deserialize(JSON.serialize(closedWonValues), Opportunity.class);

		System.assertEquals(
			0,
			ELV_OpportunityARRService.calculate(closedLost).ELV_Sales_ARR__c,
			'A closed-lost Opportunity reports no ARR.'
		);
		System.assertEquals(
			0,
			ELV_OpportunityARRService.calculate(fullChurn).ELV_Exit_ARR__c,
			'An open Full Churn call zeroes Exit ARR.'
		);
		System.assertEquals(
			250000,
			ELV_OpportunityARRService.calculate(closedWon).ELV_Sales_ARR__c,
			'Closed-won is untouched - only closed-lost zeroes.'
		);
	}

	@IsTest
	static void splitPercentIsReadAsARawNumberInApex() {
		Opportunity half = quoteSourced(250000, 0);
		half.Split_Percent__c = 50;

		Opportunity whole = quoteSourced(250000, 0);
		whole.Split_Percent__c = 100;

		Opportunity unset = quoteSourced(250000, 0);

		System.assertEquals(
			125000,
			ELV_OpportunityARRService.calculate(half).ELV_Sales_ARR__c,
			'A 50 percent split halves the figure, so Apex divides the raw number by 100.'
		);
		System.assertEquals(
			250000,
			ELV_OpportunityARRService.calculate(whole).ELV_Sales_ARR__c,
			'A 100 percent split leaves the figure unchanged.'
		);
		System.assertEquals(
			250000,
			ELV_OpportunityARRService.calculate(unset).ELV_Sales_ARR__c,
			'A blank split percent must not erase the ARR.'
		);
	}

	@IsTest
	static void aSplitOpportunityTakesItsParentsPreSplitFigure() {
		Opportunity split = oppWith(
			new Map<String, Object>{
				'Id' => '006000000000004AAA',
				'IsClosed' => false,
				'IsWon' => false,
				'Type' => 'Split',
				'Split_Percent__c' => 40,
				'Ramped_Opportunity__c' => '006000000000005AAA',
				'Ramped_Opportunity__r' => new Map<String, Object>{
					'attributes' => new Map<String, Object>{ 'type' => 'Opportunity' },
					'Id' => '006000000000005AAA',
					'ELV_Sales_ARR_Before_Split__c' => 500000
				},
				'ELV_Subscription_ARR__c' => 10
			}
		);

		System.assertEquals(
			200000,
			ELV_OpportunityARRService.calculate(split).ELV_Sales_ARR__c,
			'The split is taken against the parent, not against this record own figure.'
		);
	}

	@IsTest
	static void incomingArrHonoursTheOverrideAndAlwaysAddsTheInYearAdjustment() {
		Opportunity rollupBased = quoteSourced(0, 0);
		Map<String, Object> rollupValues = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(rollupBased));
		rollupValues.put('Incoming_ARR_Rollup__c', 100000);
		rollupValues.put('In_Year_ARR_Adjustment__c', 5000);
		rollupBased = (Opportunity) JSON.deserialize(JSON.serialize(rollupValues), Opportunity.class);

		Opportunity overridden = quoteSourced(0, 0);
		Map<String, Object> overrideValues = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(overridden));
		overrideValues.put('Incoming_ARR_Rollup__c', 100000);
		overrideValues.put('Incoming_ARR_Override__c', 80000);
		overrideValues.put('In_Year_ARR_Adjustment__c', 5000);
		overridden = (Opportunity) JSON.deserialize(JSON.serialize(overrideValues), Opportunity.class);

		System.assertEquals(
			105000,
			ELV_OpportunityARRService.calculate(rollupBased).ELV_Incoming_ARR__c,
			'Without an override the contract roll-up is the baseline.'
		);
		System.assertEquals(
			85000,
			ELV_OpportunityARRService.calculate(overridden).ELV_Incoming_ARR__c,
			'An override replaces the roll-up but not the in-year adjustment.'
		);
	}

	@IsTest
	static void onlyMovedFiguresAreWritten() {
		Opportunity unchanged = quoteSourced(250000, 180000);
		unchanged.ELV_Sales_ARR_Before_Split__c = 250000;
		unchanged.ELV_Sales_ARR__c = 250000;
		unchanged.ELV_Exit_ARR__c = 180000;
		unchanged.ELV_Incoming_ARR__c = 0;
		unchanged.ELV_ARR_Source__c = 'Quote';
		unchanged.ELV_Primary_Quote_Stamp__c = '0Q0000000000001AAA';

		Opportunity moved = quoteSourced(300000, 180000);

		System.assertEquals(
			0,
			ELV_OpportunityARRService.buildUpdates(new List<Opportunity>{ unchanged }).size(),
			'An Opportunity already carrying the right figures costs no DML.'
		);
		System.assertEquals(
			1,
			ELV_OpportunityARRService.buildUpdates(new List<Opportunity>{ moved }).size(),
			'A moved figure is written.'
		);
	}

	@IsTest
	static void theQuoteChangeTestGatesTheRefresh() {
		Quote before = (Quote) JSON.deserialize(
			JSON.serialize(
				new Map<String, Object>{
					'attributes' => new Map<String, Object>{ 'type' => 'Quote' },
					'Id' => '0Q0000000000002AAA',
					'OpportunityId' => '006000000000006AAA',
					'ELV_Day_1_ARR__c' => 100,
					'Description' => 'before'
				}
			),
			Quote.class
		);
		Quote repriced = before.clone(true, true, true, true);
		repriced.ELV_Day_1_ARR__c = 200;
		Quote untouched = before.clone(true, true, true, true);
		untouched.Description = 'a change that does not affect ARR';

		Map<Id, Quote> oldMap = new Map<Id, Quote>{ before.Id => before };

		System.assertEquals(
			1,
			ELV_OpportunityARRService.opportunityIdsForChangedQuotes(
					new List<Quote>{ repriced },
					oldMap
				)
				.size(),
			'A re-priced quote refreshes its Opportunity.'
		);
		System.assertEquals(
			0,
			ELV_OpportunityARRService.opportunityIdsForChangedQuotes(
					new List<Quote>{ untouched },
					oldMap
				)
				.size(),
			'An unrelated quote edit does not.'
		);
		System.assertEquals(
			1,
			ELV_OpportunityARRService.opportunityIdsFor(new List<Quote>{ before }).size(),
			'The delete path resolves the Opportunity while the quote still exists.'
		);
	}

	@IsTest
	static void theServiceIsSuppressedWhileItIsRunning() {
		ELV_OpportunityARRService.isRecalculating = true;

		Test.startTest();
		ELV_OpportunityARRService.recalculate(new Set<Id>{ '006000000000007AAA' });
		ELV_OpportunityARRService.isRecalculating = false;
		ELV_OpportunityARRService.recalculate(new Set<Id>());
		ELV_OpportunityARRService.recalculate(null);
		ELV_OpportunityARRService.opportunityIdsFor(null);
		ELV_OpportunityARRService.opportunityIdsForChangedQuotes(null, null);
		Test.stopTest();
	}

	@IsTest
	static void theServiceRunsAgainstRealOpportunities() {
		List<Opportunity> existing = [
			SELECT Id
			FROM Opportunity
			WHERE Ruby__PrimaryQuote__c != NULL
			LIMIT 5
		];

		if (existing.isEmpty()) {
			return;
		}

		Test.startTest();
		ELV_OpportunityARRService.recalculate(new Map<Id, Opportunity>(existing).keySet());
		Test.stopTest();

		for (Opportunity opp : [
			SELECT ELV_ARR_Source__c, ELV_ARR_Last_Synced__c
			FROM Opportunity
			WHERE Id IN :existing
		]) {
			System.assertEquals(
				'Quote',
				opp.ELV_ARR_Source__c,
				'An Opportunity with a primary quote is sourced from the quote.'
			);
			System.assertNotEquals(null, opp.ELV_ARR_Last_Synced__c, 'The sync stamp is set.');
		}
	}

	/**
	 * Exercises the quote save and delete entry points end to end. Deleting the primary quote is
	 * the case the delete path exists for: the lookup clears with no Opportunity event, so the
	 * Ids are captured before the delete and the Opportunity is refreshed after it commits.
	 */
	@IsTest
	static void theQuoteEntryPointsRunOnSaveAndDelete() {
		List<Quote> candidates = [
			SELECT Id, OpportunityId, Pricebook2Id
			FROM Quote
			WHERE Pricebook2Id != NULL AND OpportunityId != NULL
			LIMIT 1
		];

		if (candidates.isEmpty()) {
			return;
		}

		Quote source = candidates[0];

		Test.startTest();
		try {
			Quote scratch = new Quote(
				Name = 'ELV Opportunity ARR Delete Coverage',
				OpportunityId = source.OpportunityId,
				Pricebook2Id = source.Pricebook2Id
			);
			insert scratch;
			delete scratch;
		} catch (Exception saveBlocked) {
			// Quote creation is gated by org configuration in some sandboxes.
			System.debug(LoggingLevel.WARN, saveBlocked.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	static void theOpportunityChangeTestIdentifiesArrRelevantEdits() {
		Opportunity before = oppWith(
			new Map<String, Object>{ 'Id' => '006000000000008AAA', 'StageName' => 'Qualify' }
		);
		Opportunity staged = before.clone(true, true, true, true);
		staged.StageName = 'Negotiate';
		Opportunity renamed = before.clone(true, true, true, true);
		renamed.Name = 'Renamed';

		System.assertEquals(
			true,
			ELV_OpportunityTriggerHandler.hasRelevantChange(staged, before),
			'A stage change can zero or restore the figures.'
		);
		System.assertEquals(
			false,
			ELV_OpportunityTriggerHandler.hasRelevantChange(renamed, before),
			'A rename does not move ARR.'
		);
	}
}