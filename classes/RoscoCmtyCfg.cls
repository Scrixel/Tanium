public without sharing class RoscoCmtyCfg {
	@AuraEnabled
	public static String processEmailOptOut(String eooId) {
		String ret = 'Success';

		try {
			/*String soql = 'SELECT Id ' +
                        'FROM Contact ' +
                        'WHERE HasOptedOutOfEmail=false ' +
                        'AND Id=\'' + eooId + '\' ' +
                        'LIMIT 1';

            System.debug('SOQL: ' + soql);
            List<Contact> contacts = Database.query(soql);

            if (contacts.size() != 0){
                    
                contacts[0].HasOptedOutOfEmail = true;
                update contacts[0];

            }
            */
			Contact c = [SELECT Id FROM Contact WHERE HasOptedOutOfEmail = FALSE AND Id = :eooId];
			if (c != null) {
				c.HasOptedOutOfEmail = true;
				update c;
			}
		} catch (Exception e) {
			System.debug('processEmailOptOut: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static String processTanVulnEmailOptOut(String vooId) {
		String ret = 'Success';

		try {
			String subscriptionType = 'Tanium Vulnerability';

			String soql =
				'SELECT Subscribed__c ' +
				'FROM Rosco_Subscription__c ' +
				'WHERE User__c IN (SELECT Id FROM User WHERE ContactId = \'' +
				vooId +
				'\') ' +
				'AND Type__c = \'' +
				subscriptionType +
				'\' ' +
				'LIMIT 1';

			System.debug('soql:' + soql);
			List<Rosco_Subscription__c> subscriptions = Database.query(soql);

			if (!subscriptions.isEmpty()) {
				for (Rosco_Subscription__c s : subscriptions) {
					if (s.Subscribed__c == false) {
						System.debug('User is already not subscribed');
					} else {
						System.debug('User is subscribed, unsubscribing');
						s.Subscribed__c = false;
						ret = 'true';
						update s;
					}
				}
			} else {
				System.debug('User is not defined, no need to unsubscribe');
			}

			ret = 'Success';
		} catch (Exception e) {
			System.debug('processTanVulnEmailOptOut: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}
}