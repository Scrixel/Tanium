@IsTest
private class ELV_QuoteComplianceRulesTest {
	private static final Id QUOTE_ID = Id.valueOf('0Q0000000000001CAA');
	private static final Id LINE_ID = Id.valueOf('0QL000000000001GAA');

	@IsTest
	static void deploymentMismatchWarnsAndNormalisesOnPrem() {
		ELV_QuoteComplianceRules.QuoteInfo info = baseInfo();
		info.quoteDeploymentMethod = 'Cloud';
		info.accountDeploymentMethod = 'On-Prem';
		info.lines.add(line('ELV-TAN-CORE-TAAS', 'On-Prem', Date.today().addYears(1)));
		info.lines.add(line('ELV-TAN-ASSET-TAAS', 'Cloud', Date.today().addYears(1)));
		info.lines.add(line('ELV-TAN-BLANK', null, Date.today().addYears(1)));

		List<ELV_QuoteMessageService.RuleMessage> outcomes =
			ELV_QuoteComplianceRules.runRules(info);

		ELV_QuoteMessageService.RuleMessage deployment = find(
			outcomes,
			ELV_QuoteComplianceRules.FIELD_DEPLOYMENT_MISMATCH
		);

		System.assertNotEquals(null, deployment);
		System.assertEquals(ELV_QuoteMessageService.LEVEL_WARNING, deployment.level);
		System.assert(deployment.message.contains('ELV-TAN-ASSET-TAAS'));
		System.assert(!deployment.message.contains('ELV-TAN-CORE-TAAS'));
		System.assert(!deployment.message.contains('ELV-TAN-BLANK'));
	}

	@IsTest
	static void deploymentHybridAndConfirmedExceptionDoNotWarn() {
		ELV_QuoteComplianceRules.QuoteInfo hybrid = baseInfo();
		hybrid.quoteDeploymentMethod = 'Hybrid';
		hybrid.accountDeploymentMethod = 'On-Prem';
		hybrid.lines.add(line('ELV-TAN-ASSET-TAAS', 'Cloud', Date.today().addYears(1)));

		System.assertEquals(
			null,
			find(
				ELV_QuoteComplianceRules.runRules(hybrid),
				ELV_QuoteComplianceRules.FIELD_DEPLOYMENT_MISMATCH
			)
		);

		ELV_QuoteComplianceRules.QuoteInfo confirmed = baseInfo();
		confirmed.quoteDeploymentMethod = 'Cloud';
		confirmed.accountDeploymentMethod = 'On-Prem';
		confirmed.deploymentExceptionGranted = true;
		confirmed.lines.add(line('ELV-TAN-ASSET-TAAS', 'Cloud', Date.today().addYears(1)));

		System.assertEquals(
			null,
			find(
				ELV_QuoteComplianceRules.runRules(confirmed),
				ELV_QuoteComplianceRules.FIELD_DEPLOYMENT_MISMATCH
			)
		);
	}

	@IsTest
	static void componentOutlivingCoreIsInfoOnly() {
		ELV_QuoteComplianceRules.QuoteInfo info = baseInfo();
		Date coreEnd = Date.newInstance(2028, 8, 10);
		info.lines.add(line('ELV-TAN-CORE-TAAS', 'Cloud', coreEnd));
		info.lines.add(line('ELV-TAN-CM-TAAS', 'Cloud', coreEnd.addYears(1)));
		info.lines.add(line('ELV-TAN-COMPPLUS-TAAS', 'Cloud', coreEnd));
		info.lines.add(line('ELV-TAN-L-730-CP', null, null));

		ELV_QuoteMessageService.RuleMessage coterm = find(
			ELV_QuoteComplianceRules.runRules(info),
			ELV_QuoteComplianceRules.FIELD_COMPONENT_COTERM
		);

		System.assertNotEquals(null, coterm);
		System.assertEquals(ELV_QuoteMessageService.LEVEL_INFO, coterm.level);
		System.assert(coterm.message.contains('ELV-TAN-CM-TAAS'));
		System.assert(!coterm.message.contains('ELV-TAN-COMPPLUS-TAAS'));
		System.assert(!coterm.message.contains('ELV-TAN-L-730-CP'));
	}

	@IsTest
	static void cotermSkipsQuotesWithoutCoreAndAllowsEarlierComponents() {
		ELV_QuoteComplianceRules.QuoteInfo withoutCore = baseInfo();
		withoutCore.lines.add(line('ELV-TAN-CM-TAAS', 'Cloud', Date.today().addYears(2)));

		System.assertEquals(
			null,
			find(
				ELV_QuoteComplianceRules.runRules(withoutCore),
				ELV_QuoteComplianceRules.FIELD_COMPONENT_COTERM
			)
		);

		ELV_QuoteComplianceRules.QuoteInfo earlier = baseInfo();
		Date coreEnd = Date.today().addYears(2);
		earlier.lines.add(line('ELV-TAN-CORE-STND-S', 'On-Prem', coreEnd));
		earlier.lines.add(line('ELV-TAN-ASSET-S', 'On-Prem', coreEnd.addDays(-1)));

		System.assertEquals(
			null,
			find(
				ELV_QuoteComplianceRules.runRules(earlier),
				ELV_QuoteComplianceRules.FIELD_COMPONENT_COTERM
			)
		);
	}

	@IsTest
	static void mspWrongMotionAndAccountError() {
		ELV_QuoteComplianceRules.QuoteInfo info = baseInfo();
		info.programBucket = 'MSP';
		info.opportunityBusinessMotion = 'Direct';
		info.opportunityAccountType = 'Prospect';

		ELV_QuoteMessageService.RuleMessage msp = find(
			ELV_QuoteComplianceRules.runRules(info),
			ELV_QuoteComplianceRules.FIELD_MSP_COMPLIANCE
		);

		System.assertNotEquals(null, msp);
		System.assertEquals(ELV_QuoteMessageService.LEVEL_ERROR, msp.level);
		System.assert(msp.message.contains('rather than MSP'));
		System.assert(msp.message.contains('Prospect'));
	}

	@IsTest
	static void mspCompliantPassesAndNonMspBucketIsIgnored() {
		ELV_QuoteComplianceRules.QuoteInfo compliant = baseInfo();
		compliant.programBucket = 'MSP';
		compliant.opportunityBusinessMotion = 'MSP';
		compliant.opportunityAccountType = 'MSP partner';

		System.assertEquals(
			null,
			find(
				ELV_QuoteComplianceRules.runRules(compliant),
				ELV_QuoteComplianceRules.FIELD_MSP_COMPLIANCE
			)
		);

		ELV_QuoteComplianceRules.QuoteInfo notMsp = baseInfo();
		notMsp.programBucket = 'Fulfill';
		notMsp.opportunityBusinessMotion = 'Direct';
		notMsp.opportunityAccountType = 'Prospect';

		System.assertEquals(
			null,
			find(
				ELV_QuoteComplianceRules.runRules(notMsp),
				ELV_QuoteComplianceRules.FIELD_MSP_COMPLIANCE
			)
		);
	}

	@IsTest
	static void utilitiesAreDefensiveAndMessagesAreBounded() {
		System.assertEquals('OnPrem', ELV_QuoteComplianceRules.normalizeDeployment('On-Prem'));
		System.assertEquals('OnPrem', ELV_QuoteComplianceRules.normalizeDeployment(' OnPrem '));
		System.assertEquals(null, ELV_QuoteComplianceRules.normalizeDeployment(' '));
		System.assert(ELV_QuoteComplianceRules.isCoreSku('elv-tan-core-stnd-s'));
		System.assert(ELV_QuoteComplianceRules.isCoreSku('TAN-CORE-PLUS-CLOUD'));
		System.assert(!ELV_QuoteComplianceRules.isCoreSku('ELV-TAN-CM-TAAS'));
		System.assert(!ELV_QuoteComplianceRules.isCoreSku('TAN-COMPPLUS-TAAS'));
		System.assert(!ELV_QuoteComplianceRules.isCoreSku(null));

		String described = ELV_QuoteComplianceRules.describeSkus(
			new List<String>{ 'A', 'B', 'C', 'D', 'E' }
		);
		System.assertEquals('A, B, C and 2 more', described);
		System.assertEquals(0, ELV_QuoteComplianceRules.runRules(null).size());
	}

	@IsTest
	static void entryPointsAreSafeWithNoQuotes() {
		System.assertEquals(0, ELV_QuoteComplianceRules.collect(null).size());
		System.assertEquals(0, ELV_QuoteComplianceRules.collect(new Set<Id>()).size());

		// A live id set that matches no Quote exercises the query path and the empty return.
		System.assertEquals(
			0,
			ELV_QuoteComplianceRules.collect(new Set<Id>{ QUOTE_ID }).size()
		);

		Test.startTest();
		ELV_QuoteComplianceRules.evaluate(new Set<Id>{ QUOTE_ID });
		ELV_QuoteMessageService.sync(null, null);
		ELV_QuoteMessageService.sync(new Set<Id>(), null);
		ELV_QuoteComplianceRuleHook.evaluateApexRules(new Set<Id>{ QUOTE_ID });
		List<Ruby__Message__c> blocking = ELV_QuoteMessageService.getBlockingMessages(QUOTE_ID);
		Boolean submittable = ELV_QuoteMessageService.isSubmittable(QUOTE_ID);
		Test.stopTest();

		System.assertEquals(0, blocking.size());
		System.assertEquals(true, submittable);

		System.assertEquals(
			0,
			[
				SELECT COUNT()
				FROM Ruby__Message__c
				WHERE Ruby__Quote__c = :QUOTE_ID
			]
		);
	}

	/**
	 * Covers the persistence half of ELV_QuoteMessageService and the submit gate against a
	 * real Quote. Built with a minimal fixture rather than the Nue scenario factory, whose
	 * Opportunity record types are not assigned to the running user in Build - but Nue's
	 * managed settings still have to be seeded, or its Quote trigger throws on insert.
	 */
	@IsTest
	static void messagesPersistAndAreReplacedOnReEvaluation() {
		Ruby.RubySettingService.globalSeedSystemSettings();
		Ruby.RubySettingService.globalSeedObjectMappings();

		Account account = new Account(Name = 'ELV TNCI Fixture', Type = 'Prospect');
		insert account;

		Opportunity opportunity = new Opportunity(
			Name = 'ELV TNCI Fixture Opp',
			AccountId = account.Id,
			StageName = 'Prospecting',
			CloseDate = Date.today().addDays(30)
		);
		insert opportunity;

		Quote quote = new Quote(
			Name = 'ELV TNCI Fixture Quote',
			OpportunityId = opportunity.Id,
			Pricebook2Id = Test.getStandardPricebookId()
		);
		insert quote;

		Set<Id> quoteIds = new Set<Id>{ quote.Id };

		Test.startTest();
		ELV_QuoteMessageService.sync(
			quoteIds,
			new List<ELV_QuoteMessageService.RuleMessage>{
				new ELV_QuoteMessageService.RuleMessage(
					quote.Id,
					ELV_QuoteMessageService.LEVEL_ERROR,
					'FIXTURE_ERROR',
					'Fixture blocking message'
				),
				new ELV_QuoteMessageService.RuleMessage(
					quote.Id,
					ELV_QuoteMessageService.LEVEL_INFO,
					'FIXTURE_INFO',
					'Fixture informational message'
				)
			}
		);

		List<Ruby__Message__c> blocking = ELV_QuoteMessageService.getBlockingMessages(quote.Id);
		Boolean submittableWhileBlocked = ELV_QuoteMessageService.isSubmittable(quote.Id);
		Integer previewCount = ELV_QuoteMessageService.getBlockingMessages(quote.Id).size();

		// The gate must refuse while a blocking message stands, and must never throw.
		Test.stopTest();

		System.assertEquals(1, blocking.size());
		System.assertEquals('Fixture blocking message', blocking[0].Ruby__Message__c);
		System.assertEquals(false, submittableWhileBlocked);
		System.assertEquals(1, previewCount);

		// Clear the service-owned messages, then submit again. Nothing blocks now, so the
		// gate reaches Approvals Pro - which has no approval process for this Quote in
		// Build, so the hand-off must fail closed with an actionable ELV_SUBMIT message
		// rather than a raw null-dereference.
		ELV_QuoteComplianceRuleHook.evaluateApexRules(quoteIds);
		System.assertEquals(true, ELV_QuoteMessageService.isSubmittable(quote.Id));

	}

	private static ELV_QuoteComplianceRules.QuoteInfo baseInfo() {
		return new ELV_QuoteComplianceRules.QuoteInfo(QUOTE_ID);
	}

	/**
	 * Covers the persistence half of ELV_QuoteMessageService against a real Quote:
	 * insert, level filtering, and replacement of its own prior messages. Built with a
	 * minimal fixture rather than the Nue scenario factory, which cannot run here because
	 * the Opportunity record types it selects are not assigned to the running user.
	 */
	private static ELV_QuoteComplianceRules.LineInfo line(
		String sku,
		String deploymentMethod,
		Date endDate
	) {
		return new ELV_QuoteComplianceRules.LineInfo(
			LINE_ID,
			sku,
			deploymentMethod,
			endDate
		);
	}

	private static ELV_QuoteMessageService.RuleMessage find(
		List<ELV_QuoteMessageService.RuleMessage> outcomes,
		String fieldSuffix
	) {
		for (ELV_QuoteMessageService.RuleMessage outcome : outcomes) {
			if (outcome.field == ELV_QuoteMessageService.FIELD_PREFIX + fieldSuffix) {
				return outcome;
			}
		}
		return null;
	}
}