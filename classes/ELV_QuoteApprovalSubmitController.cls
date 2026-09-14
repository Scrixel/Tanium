/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Replaces the stock Submit for Approval action on the standard Quote.
 *            Locks the Quote, refreshes Subscription rollups, checks for blocking
 *            Nue messages, and only then submits to Approvals Pro.
 *
 *            Approvals engine: Approvals Pro (namespace appro).
 *
 *            We call appro.InvocableSubmitForApproval.submitForApproval rather than
 *            appro.ApprovalUtilsController.apexApprovalSubmit. Both are global, but
 *            apexApprovalSubmit returns void and takes an untyped Map, so a failed
 *            submission is indistinguishable from a successful one. The Invocable
 *            entry point takes a typed FlowRequest and returns FlowResponse carrying
 *            isSuccess and errorMessage, which an approval gate needs.
 *
 *            The gate FAILS CLOSED: any step that cannot complete blocks submission
 *            rather than letting an unvalidated quote through.
 */
public with sharing class ELV_QuoteApprovalSubmitController {
	/** Shape returned to the LWC. */
	public class SubmitResult {
		@AuraEnabled
		public Boolean submitted;
		@AuraEnabled
		public List<BlockingMessage> blockingMessages;

		public SubmitResult() {
			this.submitted = false;
			this.blockingMessages = new List<BlockingMessage>();
		}

		public void block(String level, String field, String message) {
			this.blockingMessages.add(new BlockingMessage(level, field, message));
		}
	}

	public class BlockingMessage {
		@AuraEnabled
		public String level;
		@AuraEnabled
		public String field;
		@AuraEnabled
		public String message;

		public BlockingMessage(String level, String field, String message) {
			this.level = level;
			this.field = field;
			this.message = message;
		}

		public BlockingMessage(Ruby__Message__c m) {
			this(m.Ruby__Level__c, m.Ruby__Field__c, m.Ruby__Message__c);
		}
	}

	/**
	 * Synchronous submit, in a fixed order:
	 *   1. lock the Quote row
	 *   2. refresh the Subscription rollups the plugin rules depend on
	 *   3. read the blocking messages the UI Plugin authored
	 *   4. submit to Approvals Pro only when clean
	 */
	@AuraEnabled
	public static SubmitResult submitForApproval(Id quoteId) {
		if (quoteId == null) {
			throw new AuraHandledException('A Quote Id is required.');
		}

		SubmitResult result = new SubmitResult();

		// 1. Lock so a concurrent save cannot invalidate what we are about to check.
		List<Quote> locked = [SELECT Id, Status FROM Quote WHERE Id = :quoteId FOR UPDATE];

		if (locked.isEmpty()) {
			throw new AuraHandledException('Quote not found or not accessible.');
		}

		// 2. Refresh rollups. If this cannot run, the rule inputs are stale, so block -
		//    never submit on the basis of values we could not recompute.
		try {
			ELV_QuoteRollupHelper.refreshAndSave(new Set<Id>{ quoteId });
		} catch (Exception e) {
			result.block(
				'Error',
				'ELV_ROLLUP',
				'Subscription rollups could not be refreshed, so validations cannot be trusted: ' +
					e.getMessage()
			);
			return result;
		}

		// 3. Anything left at Error or Warning blocks the submission.
		for (Ruby__Message__c m : ELV_QuoteMessageService.getBlockingMessages(quoteId)) {
			result.blockingMessages.add(new BlockingMessage(m));
		}

		if (!result.blockingMessages.isEmpty()) {
			return result;
		}

		// 4. Clean - hand off to Approvals Pro.
		appro.InvocableSubmitForApproval.FlowRequest req =
			new appro.InvocableSubmitForApproval.FlowRequest();
		req.recordId = String.valueOf(quoteId);

		List<appro.InvocableSubmitForApproval.FlowResponse> responses;

		try {
			responses = appro.InvocableSubmitForApproval.submitForApproval(
				new List<appro.InvocableSubmitForApproval.FlowRequest>{ req }
			);
		} catch (Exception e) {
			// Approvals Pro throws a NullPointerException when no approval process matches
			// the record. That surfaces to a rep as "Attempt to de-reference a null object",
			// which is useless, so translate it into something actionable.
			String detail = (e instanceof NullPointerException)
				? 'No Approvals Pro approval process is configured for this Quote. ' +
					'Ask an administrator to create an active Approval Process, or supply ' +
					'approvalProcessName on the submit request.'
				: e.getMessage();

			result.block('Error', 'ELV_SUBMIT', 'Could not submit to Approvals Pro: ' + detail);
			return result;
		}

		if (responses == null || responses.isEmpty()) {
			result.block('Error', 'ELV_SUBMIT', 'Approvals Pro returned no response to the submission.');
			return result;
		}

		appro.InvocableSubmitForApproval.FlowResponse r = responses[0];

		if (r.isSuccess == true) {
			result.submitted = true;
		} else {
			result.block(
				'Error',
				'ELV_SUBMIT',
				String.isBlank(r.errorMessage)
					? 'Approvals Pro did not submit the quote and gave no reason.'
					: r.errorMessage
			);
		}

		return result;
	}

	/**
	 * Read-only preview so the UI can show what would block submission
	 * without writing anything or submitting.
	 */
	@AuraEnabled(cacheable=true)
	public static List<BlockingMessage> previewBlockingMessages(Id quoteId) {
		List<BlockingMessage> out = new List<BlockingMessage>();

		for (Ruby__Message__c m : ELV_QuoteMessageService.getBlockingMessages(quoteId)) {
			out.add(new BlockingMessage(m));
		}

		return out;
	}
}