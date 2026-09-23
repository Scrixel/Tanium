/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Apex-side quote compliance rules for the three "testing" cards whose
 *            build was captured under ELV-CPQ-006.
 *
 *              TNCI-100  Product deployment method must match the deployment method
 *                        recorded on the Account. Hybrid quotes accept anything, blank
 *                        product methods are ignored, and the rep can confirm intent
 *                        with Quote.ELV_Deployment_Exception_Granted__c.
 *              TNCI-118  Component products must not outlive the Core product they are
 *                        sold against. Non-blocking by design, so Info level.
 *              TNCI-102  An MSP-bucket quote must sit on an MSP business motion and on a
 *                        partner account.
 *
 *            These three are evaluated here rather than in the Nue Line Editor plugin
 *            because each needs data the plugin cannot reach: the Account's deployment
 *            method, and the Opportunity account's Type. The plugin sees only Quote and
 *            Quote Line fields.
 *
 *            Levels are load-bearing, not cosmetic. ELV_QuoteMessageService.getBlockingMessages
 *            collects Error and Warning and ignores Info, so the level chosen here decides
 *            whether Submit for Approval is blocked:
 *              TNCI-100 -> Warning  (blocks submit until the exception is granted)
 *              TNCI-118 -> Info     (never blocks; discourages non-compliance only)
 *              TNCI-102 -> Error    (blocks submit)
 *            Nothing here blocks save; the messages are advisory records only.
 *
 *            Message ownership follows ELV_QuoteMessageService: every message carries the
 *            ELV_APEX_ prefix and deletion is scoped to it, so plugin (ELV_UI_) and Nue
 *            managed messages are never touched.
 *
 *            The rule methods deliberately operate on the in-memory QuoteInfo/LineInfo
 *            structs rather than on SObjects. Several inputs are formula fields, which
 *            cannot be assigned in Apex, so this is what makes the logic unit-testable
 *            without DML.
 */
public with sharing class ELV_QuoteComplianceRules {
	/** Field keys, appended to ELV_QuoteMessageService.FIELD_PREFIX when the message is built. */
	public static final String FIELD_DEPLOYMENT_MISMATCH = 'Deployment_Method_Mismatch';
	public static final String FIELD_COMPONENT_COTERM = 'Component_Coterm';
	public static final String FIELD_MSP_COMPLIANCE = 'MSP_Program_Compliance';

	@TestVisible
	private static final String DEPLOYMENT_ON_PREM = 'OnPrem';
	@TestVisible
	private static final String DEPLOYMENT_HYBRID = 'Hybrid';

	/**
	 * The Quote picklist spells it "OnPrem", the Product and Account picklists spell it
	 * "On-Prem". A raw string comparison would flag every on-premise quote as a mismatch,
	 * so every value is normalised through normalizeDeployment before comparison.
	 */
	private static final String DEPLOYMENT_ON_PREM_HYPHENATED = 'On-Prem';

	/**
	 * Core is identified by SKU prefix; there is no Core flag on the product or the line.
	 * ELV_Product_Family_Core__c is not one despite the name - it is a seats-eligibility
	 * formula over promotion, transaction type and ELV_IncludeInSeatsPurchased__c.
	 *
	 * The optional ELV- prefix matters: Build carries SKUs as TAN-CORE-PLUS-CLOUD while
	 * Partial carries the same product as ELV-TAN-CORE-PLUS-CLOUD, so the prefix is
	 * stripped before matching and the rule behaves identically in both orgs.
	 */
	@TestVisible
	private static final String CORE_SKU_PREFIX = 'TAN-CORE';
	private static final String ELV_SKU_PREFIX = 'ELV-';

	/**
	 * "Account of Type Partner" is not a value the Account Type picklist offers. The
	 * available partner-ish types are MSP partner, Alliance partner, Consulting partner,
	 * Reseller (channel partner, VAR, LAR, etc), Distributor and System Integrator. For an
	 * MSP quote the intended counterparty is the MSP partner, so only that type is
	 * accepted here. Widen this set if the requirement owner rules otherwise.
	 */
	@TestVisible
	private static final Set<String> PARTNER_ACCOUNT_TYPES = new Set<String>{ 'MSP partner' };

	private static final String PROGRAM_BUCKET_MSP = 'MSP';
	private static final String BUSINESS_MOTION_MSP = 'MSP';

	/** How many SKUs a message names before it summarises the remainder. */
	private static final Integer MAX_SKUS_IN_MESSAGE = 3;

	/** One quote line, flattened so the rules can be exercised without DML. */
	public class LineInfo {
		public Id lineId;
		public String sku;
		public String deploymentMethod;
		public Date endDate;

		public LineInfo(Id lineId, String sku, String deploymentMethod, Date endDate) {
			this.lineId = lineId;
			this.sku = sku;
			this.deploymentMethod = deploymentMethod;
			this.endDate = endDate;
		}
	}

	/** One quote and its lines, flattened for the same reason. */
	public class QuoteInfo {
		public Id quoteId;
		public String quoteDeploymentMethod;
		public String accountDeploymentMethod;
		public Boolean deploymentExceptionGranted = false;
		public String programBucket;
		public String opportunityBusinessMotion;
		public String opportunityAccountType;
		public List<LineInfo> lines = new List<LineInfo>();

		public QuoteInfo(Id quoteId) {
			this.quoteId = quoteId;
		}
	}

	/**
	 * Entry point. Re-evaluates the three rules for the supplied Quotes and hands the
	 * outcome to ELV_QuoteMessageService, which replaces only ELV_APEX_ messages.
	 */
	public static void evaluate(Set<Id> quoteIds) {
		ELV_QuoteMessageService.sync(quoteIds, collect(quoteIds));
	}

	/**
	 * Builds the outcome list without persisting it, so the submit controller can preview
	 * what would be raised, and so evaluateApexRules can compose it with other rules.
	 */
	public static List<ELV_QuoteMessageService.RuleMessage> collect(Set<Id> quoteIds) {
		List<ELV_QuoteMessageService.RuleMessage> outcomes = new List<ELV_QuoteMessageService.RuleMessage>();
		if (quoteIds == null || quoteIds.isEmpty()) {
			return outcomes;
		}

		for (QuoteInfo info : load(quoteIds)) {
			outcomes.addAll(runRules(info));
		}

		return outcomes;
	}

	/** Reads everything the three rules need in two queries. */
	@TestVisible
	private static List<QuoteInfo> load(Set<Id> quoteIds) {
		Map<Id, QuoteInfo> infoByQuoteId = new Map<Id, QuoteInfo>();

		for (Quote quote : [
			SELECT
				Id,
				ELV_Deployment_Method__c,
				ELV_Deployment_Exception_Granted__c,
				ELV_Partner_Program_Bucket__c,
				ELV_Business_Motion_Oppty__c,
				Account.Deployment_Method__c,
				Opportunity.Account.Type
			FROM Quote
			WHERE Id IN :quoteIds
		]) {
			QuoteInfo info = new QuoteInfo(quote.Id);
			info.quoteDeploymentMethod = quote.ELV_Deployment_Method__c;
			info.deploymentExceptionGranted = quote.ELV_Deployment_Exception_Granted__c == true;
			info.programBucket = quote.ELV_Partner_Program_Bucket__c;
			info.opportunityBusinessMotion = quote.ELV_Business_Motion_Oppty__c;
			info.accountDeploymentMethod = quote.Account == null
				? null
				: quote.Account.Deployment_Method__c;
			info.opportunityAccountType = quote.Opportunity == null ||
				quote.Opportunity.Account == null
				? null
				: quote.Opportunity.Account.Type;

			infoByQuoteId.put(quote.Id, info);
		}

		if (infoByQuoteId.isEmpty()) {
			return new List<QuoteInfo>();
		}

		for (QuoteLineItem line : [
			SELECT
				Id,
				QuoteId,
				Ruby__ProductSKU__c,
				ELV_Deployment_Method__c,
				Ruby__SubscriptionEndDate__c
			FROM QuoteLineItem
			WHERE QuoteId IN :infoByQuoteId.keySet()
		]) {
			QuoteInfo info = infoByQuoteId.get(line.QuoteId);
			if (info == null) {
				continue;
			}

			info.lines.add(
				new LineInfo(
					line.Id,
					line.Ruby__ProductSKU__c,
					line.ELV_Deployment_Method__c,
					line.Ruby__SubscriptionEndDate__c
				)
			);
		}

		return infoByQuoteId.values();
	}

	/** The rule registry. */
	@TestVisible
	private static List<ELV_QuoteMessageService.RuleMessage> runRules(QuoteInfo info) {
		List<ELV_QuoteMessageService.RuleMessage> results = new List<ELV_QuoteMessageService.RuleMessage>();
		if (info == null) {
			return results;
		}

		ruleDeploymentMethodMatchesAccount(info, results);
		ruleComponentsCotermWithCore(info, results);
		ruleMspProgramCompliance(info, results);

		return results;
	}

	/**
	 * TNCI-100. Warns when a line's product deployment method differs from the deployment
	 * method recorded on the Account.
	 *
	 * Skipped when the quote's deployment method is Hybrid (a Hybrid quote accepts every
	 * product method) and when the Account has no deployment method to compare against.
	 * Lines whose product carries no deployment method are ignored, per the card.
	 *
	 * The warning clears once the rep ticks ELV_Deployment_Exception_Granted__c, which is
	 * the explicit confirmation the acceptance criteria ask for: a plugin message cannot
	 * be acknowledged, but a checkbox on the quote is auditable.
	 */
	@TestVisible
	private static void ruleDeploymentMethodMatchesAccount(
		QuoteInfo info,
		List<ELV_QuoteMessageService.RuleMessage> results
	) {
		if (info.deploymentExceptionGranted) {
			return;
		}

		String accountMethod = normalizeDeployment(info.accountDeploymentMethod);
		if (String.isBlank(accountMethod)) {
			return;
		}

		if (normalizeDeployment(info.quoteDeploymentMethod) == DEPLOYMENT_HYBRID) {
			return;
		}

		List<String> mismatchedSkus = new List<String>();
		for (LineInfo line : info.lines) {
			String lineMethod = normalizeDeployment(line.deploymentMethod);
			if (String.isBlank(lineMethod)) {
				continue;
			}

			if (lineMethod != accountMethod) {
				mismatchedSkus.add(line.sku);
			}
		}

		if (mismatchedSkus.isEmpty()) {
			return;
		}

		results.add(
			new ELV_QuoteMessageService.RuleMessage(
				info.quoteId,
				ELV_QuoteMessageService.LEVEL_WARNING,
				FIELD_DEPLOYMENT_MISMATCH,
				'The Account deployment method is ' +
					info.accountDeploymentMethod +
					', but ' +
					describeSkus(mismatchedSkus) +
					' quoted with a different deployment method. Confirm the correct SKUs were sold, ' +
					'or tick Deployment Exception Granted to confirm this is intended.'
			)
		);
	}

	/**
	 * TNCI-118. Flags component products that outlive the Core product on the same quote.
	 *
	 * Expressed as sibling-versus-sibling rather than child-versus-parent on purpose. The
	 * quote line hierarchy does carry parents, but the parents are bundle headers and Core
	 * SKUs sit as standalone lines - and Nue propagates a bundle's term and end date to its
	 * components, so a parent/child comparison could never fire.
	 *
	 * A component ending before Core is usually deliberate, so only components ending later
	 * are flagged. Lines with no end date - hardware, training, services - are skipped.
	 */
	@TestVisible
	private static void ruleComponentsCotermWithCore(
		QuoteInfo info,
		List<ELV_QuoteMessageService.RuleMessage> results
	) {
		Date coreEndDate = getLatestCoreEndDate(info.lines);
		if (coreEndDate == null) {
			return;
		}

		List<String> lateSkus = new List<String>();
		for (LineInfo line : info.lines) {
			if (line.endDate == null || isCoreSku(line.sku)) {
				continue;
			}

			if (line.endDate > coreEndDate) {
				lateSkus.add(line.sku);
			}
		}

		if (lateSkus.isEmpty()) {
			return;
		}

		results.add(
			new ELV_QuoteMessageService.RuleMessage(
				info.quoteId,
				ELV_QuoteMessageService.LEVEL_INFO,
				FIELD_COMPONENT_COTERM,
				describeSkus(lateSkus) +
					' end after the Core product end date of ' +
					String.valueOf(coreEndDate) +
					'. Component products should co-term with Core.'
			)
		);
	}

	/**
	 * TNCI-102. Errors when an MSP-bucket quote is not on an MSP business motion, or its
	 * opportunity does not sit on a partner account.
	 *
	 * Note on terminology: the card asks for opportunity type "MSSP". No such value exists
	 * on the Business Motion picklist, which offers Direct, Resale, MSP and the inactive
	 * Partner-Led Resale. The solution design's "MSP" is what is implemented.
	 *
	 * The account test reads the Opportunity account's Type directly. Quote.ELV_Account_Type__c
	 * cannot be used: on an MSP quote it deliberately returns the end user's account type,
	 * which is the opposite of what this rule needs.
	 */
	@TestVisible
	private static void ruleMspProgramCompliance(
		QuoteInfo info,
		List<ELV_QuoteMessageService.RuleMessage> results
	) {
		if (info.programBucket != PROGRAM_BUCKET_MSP) {
			return;
		}

		List<String> problems = new List<String>();

		if (info.opportunityBusinessMotion != BUSINESS_MOTION_MSP) {
			problems.add(
				'the Opportunity Business Motion is ' +
					(String.isBlank(info.opportunityBusinessMotion)
						? 'blank'
						: info.opportunityBusinessMotion) +
					' rather than MSP'
			);
		}

		if (!PARTNER_ACCOUNT_TYPES.contains(info.opportunityAccountType)) {
			problems.add(
				'the Opportunity account is ' +
					(String.isBlank(info.opportunityAccountType)
						? 'of no type'
						: 'of type ' + info.opportunityAccountType) +
					' rather than a partner account'
			);
		}

		if (problems.isEmpty()) {
			return;
		}

		results.add(
			new ELV_QuoteMessageService.RuleMessage(
				info.quoteId,
				ELV_QuoteMessageService.LEVEL_ERROR,
				FIELD_MSP_COMPLIANCE,
				'This quote is in the MSP program bucket, but ' +
					String.join(problems, ' and ') +
					'. Correct the Opportunity before submitting for approval.'
			)
		);
	}

	/** The latest end date across the Core lines on the quote, or null when there are none. */
	@TestVisible
	private static Date getLatestCoreEndDate(List<LineInfo> lines) {
		Date latest;

		for (LineInfo line : lines) {
			if (!isCoreSku(line.sku) || line.endDate == null) {
				continue;
			}

			if (latest == null || line.endDate > latest) {
				latest = line.endDate;
			}
		}

		return latest;
	}

	@TestVisible
	private static Boolean isCoreSku(String sku) {
		if (String.isBlank(sku)) {
			return false;
		}

		String normalized = sku.trim().toUpperCase();
		if (normalized.startsWith(ELV_SKU_PREFIX)) {
			normalized = normalized.substring(ELV_SKU_PREFIX.length());
		}

		return normalized.startsWith(CORE_SKU_PREFIX);
	}

	/** Collapses the two spellings of on-premise so comparisons are meaningful. */
	@TestVisible
	private static String normalizeDeployment(String value) {
		if (String.isBlank(value)) {
			return null;
		}

		String trimmed = value.trim();

		return trimmed == DEPLOYMENT_ON_PREM_HYPHENATED ? DEPLOYMENT_ON_PREM : trimmed;
	}

	/** "SKU-A, SKU-B and 4 more lines" - keeps messages readable on large quotes. */
	@TestVisible
	private static String describeSkus(List<String> skus) {
		List<String> named = new List<String>();
		Integer limitReached = Math.min(skus.size(), MAX_SKUS_IN_MESSAGE);

		for (Integer i = 0; i < limitReached; i++) {
			named.add(String.isBlank(skus[i]) ? '(no SKU)' : skus[i]);
		}

		Integer remainder = skus.size() - limitReached;
		String listed = String.join(named, ', ');

		return remainder > 0 ? listed + ' and ' + remainder + ' more' : listed;
	}
}