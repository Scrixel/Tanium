/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: ELV-Build-INDEPENDENT-ADD-16 (follow-up fix, 2026-09-19). Defers
 *   ELV_IndependentProductAutoAddService.autoAddEsrLines to a separate, later
 *   transaction via Queueable instead of calling it synchronously from
 *   ELV_QuoteLineTriggerHandler.afterInsert.
 *
 *   Root cause this works around: the Nue Quote Line Editor does not update lines
 *   in place - every save deletes all existing QuoteLineItems on the quote and
 *   re-inserts fresh copies, with the inserts committing before the deletes in the
 *   same transaction. A synchronous call from afterInsert therefore sees the
 *   *previous* save's still-present ESR line (not yet deleted), concludes the quote
 *   already has one, and skips adding a new one - which the same transaction's later
 *   delete pass then removes. Net effect: the quote ends every save with zero ESR
 *   lines, forever one step behind.
 *
 *   Running the check in its own queued transaction, after the triggering transaction
 *   (inserts and deletes both) has committed, removes the race: by the time this
 *   executes, the quote's line set reflects the save's true final state.
 *
 * @Business: follow-up fix, 2026-09-20. Deferring to its own transaction created a new
 *   failure mode instead: this job's own DML (the ESR line insert, and the recalculate()
 *   call it triggers) now runs concurrently with whatever other automation the same save
 *   also queued against the same Quote/QuoteLineItem rows (ELV_CustomCalculationClearQueueable,
 *   ELV_AccountSpendCreditService, Nue's own recalculation, etc.) - all racing for a lock on
 *   the same records. Confirmed in AsyncApexJob history: repeated failures with
 *   "UNABLE_TO_LOCK_ROW, unable to obtain exclusive access to this record", uncaught, so the
 *   job simply dies and the ESR line is never added - with no visible error anywhere a user
 *   would see it. This is the "sometimes doesn't get added" behavior reported 2026-09-20.
 *
 *   Retrying a losing lock a few transactions later - by re-enqueueing itself - gives the
 *   contending automation time to finish and release the row, without looping forever if
 *   something is genuinely stuck.
 */
public with sharing class ELV_EsrAutoAddQueueable implements Queueable {
	private final Set<Id> quoteIds;
	private final Integer attemptNumber;

	@TestVisible
	private static final Integer MAX_LOCK_RETRY_ATTEMPTS = 3;

	public ELV_EsrAutoAddQueueable(Set<Id> quoteIds) {
		this(quoteIds, 1);
	}

	private ELV_EsrAutoAddQueueable(Set<Id> quoteIds, Integer attemptNumber) {
		this.quoteIds = quoteIds;
		this.attemptNumber = attemptNumber;
	}

	/** Enqueues the deferred check, unless the org-wide queueable budget for this transaction is spent. */
	public static void enqueue(Set<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}
		if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
			// Out of queueable budget this transaction (e.g. already deep in a chain
			// started elsewhere) - fall back to the synchronous call so the rule still
			// gets a chance to run, race condition and all, rather than never running.
			ELV_IndependentProductAutoAddService.autoAddEsrLines(quoteIds);
			return;
		}
		System.enqueueJob(new ELV_EsrAutoAddQueueable(quoteIds));
	}

	public void execute(QueueableContext context) {
		try {
			ELV_IndependentProductAutoAddService.autoAddEsrLines(quoteIds);
		} catch (DmlException e) {
			if (isRowLockError(e) && attemptNumber < MAX_LOCK_RETRY_ATTEMPTS && canRetry()) {
				System.debug(
					LoggingLevel.WARN,
					'ELV_EsrAutoAddQueueable: row lock contention on attempt ' + attemptNumber +
						' for quotes ' + quoteIds + ' - re-enqueueing retry ' + (attemptNumber + 1) +
						' of ' + MAX_LOCK_RETRY_ATTEMPTS + '.'
				);
				System.enqueueJob(new ELV_EsrAutoAddQueueable(quoteIds, attemptNumber + 1));
				return;
			}

			// Either not a lock error, or retries are exhausted - surface it loudly. This
			// throw fails the async job (visible in Setup > Apex Jobs / debug logs) instead
			// of the previous behavior, where the line silently never appeared with no
			// trace of why.
			System.debug(
				LoggingLevel.ERROR,
				'ELV_EsrAutoAddQueueable: giving up for quotes ' + quoteIds + ' after ' +
					attemptNumber + ' attempt(s): ' + e.getMessage()
			);
			throw e;
		}
	}

	private static Boolean isRowLockError(DmlException e) {
		return e.getMessage() != null && e.getMessage().contains('UNABLE_TO_LOCK_ROW');
	}

	private static Boolean canRetry() {
		return Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
	}
}