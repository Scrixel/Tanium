public without sharing class RoscoLog {
	public static void addEntry(
		String user,
		String type,
		String source,
		Decimal logId,
		String level,
		String general,
		String details,
		String exMsg,
		String exStackTraceString
	) {
		try {
			general = general.abbreviate(32000);
			details = details.abbreviate(100000);

			if (exMsg == null) {
				exMsg = '';
			}
			exMsg = exMsg.abbreviate(32000);

			if (exStackTraceString == null) {
				exStackTraceString = '';
			}
			exStackTraceString = exStackTraceString.abbreviate(100000);

			Rosco_Log__c rl = new Rosco_Log__c(
				User__c = user,
				Type__c = type,
				Source__c = source,
				Log_Id__c = logId,
				Level__c = level,
				General__c = general,
				Details__c = details,
				Exception_Message__c = exMsg,
				Exception_StackTraceString__c = exStackTraceString
			);
			insert rl;
		} catch (Exception e) {
			System.debug('addEntry: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}
}