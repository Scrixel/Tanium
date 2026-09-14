global class FlowUtility {
	@InvocableMethod(Label='Bypass Triggers' Description='Ability to Bypass Triggers from Flow.')
	public static void bypassTriggers(List<TriggerNames> triggerNames) {
		List<String> triggerHandlers = new List<String>();

		if (triggerNames[0].sBQQTriggerControl) {
			SBQQ.TriggerControl.disable();
		}
		if (triggerNames[0].accountTriggerHandler) {
			triggerHandlers.add('AccountTriggerHandler');
		}
		if (triggerNames[0].contactTriggerHandler) {
			triggerHandlers.add('ContactTriggerHandler');
		}
		if (triggerNames[0].opportunityTriggerHandler) {
			triggerHandlers.add('OpportunityTriggerHandler');
		}
		if (triggerNames[0].quoteCPQTriggerHandler) {
			triggerHandlers.add('QuoteCPQTriggerHandler');
		}
		if (!triggerHandlers.isEmpty()) {
			TriggerHandler.bypass(triggerHandlers);
		}
	}

	global class TriggerNames {
		@InvocableVariable(Label='SBQQTriggerControl' Description='SBQQ TriggerControl')
		public boolean sBQQTriggerControl;

		@InvocableVariable(Label='AccountTriggerHandler' Description='TriggerHandler on Account Object')
		public boolean accountTriggerHandler;

		@InvocableVariable(Label='ContactTriggerHandler' Description='TriggerHandler on Contact Object')
		public boolean contactTriggerHandler;

		@InvocableVariable(
			Label='OpportunityTriggerHandler'
			Description='TriggerHandler on Opportunity Object'
		)
		public boolean opportunityTriggerHandler;

		@InvocableVariable(
			Label='QuoteCPQTriggerHandler'
			Description='TriggerHandler on Quote(SBQQ) Object'
		)
		public boolean quoteCPQTriggerHandler;

		public TriggerNames() {
			sBQQTriggerControl = false;
			accountTriggerHandler = false;
			contactTriggerHandler = false;
			opportunityTriggerHandler = false;
			quoteCPQTriggerHandler = false;
		}
	}
}