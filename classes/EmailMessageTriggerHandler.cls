/*
 * @DATE: 2020-05-12
 * @AUTHOR: Shared Services (jason.johnson), Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Trigger Handler for the EmailMessage class.
 * RequestId  ModifiedDate  Comment
 * SCLOUD-    2020-05-12    Initial Development
 * SS-12056   2025-11-18    Removed call to processOutboundSupportCaseEmail in beforeUpdate method
 */
public class EmailMessageTriggerHandler extends TriggerHandler {
	public static final String CASE_OBJECTID_PREFIX = '500';
	public Boolean isCaseRelated = false;

	public EmailMessage email { get; set; }

	public EmailMessageTriggerHandler() {
		super('EmailMessageTriggerHandler');
		this.isCaseRelated = isEmailCaseRelated();
	}

	public boolean isEmailCaseRelated() {
		this.email = ((List<EmailMessage>) Trigger.new)[0];

		if (
			this.email?.ParentId != null &&
			String.valueOf(email.ParentId).left(3) == CASE_OBJECTID_PREFIX
		) {
			return true;
		}

		return false;
	}

	public override void beforeInsert() {
		if (isCaseRelated) {
			RoscoCaseProcesses.processOutboundSupportCaseEmail(email);
		}
	}

	public override void afterInsert() {
		if (isCaseRelated) {
			RoscoCaseProcesses.processFirstResponseDate(email, null);
			RoscoCaseProcesses.processLastResponseDate(email, null);
			RoscoCaseProcesses.processLastCustomerResponseDate(email, null, null);
			RoscoCaseProcesses.processCaseStatus(email, null, null);
		}
	}

	public override void afterUpdate() {
		if (isCaseRelated) {
			RoscoCaseProcesses.processFirstResponseDate(email, null);
			RoscoCaseProcesses.processLastResponseDate(email, null);
			RoscoCaseProcesses.processLastCustomerResponseDate(email, null, null);
			RoscoCaseProcesses.processCaseStatus(email, null, null);
		}
	}
}