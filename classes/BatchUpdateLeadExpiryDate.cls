/**
 * @Business: "Opp Reg Status" updating to Expired upon expiration date.
 * @Date: 2021-02-25
 * @Author: Anurupa Busi
 * @Request: INC0119131
 * Modified    ModifiedDate   Description
 * INC0119131   2021-02-25     "Opp Reg Status" updating to Expired upon expiration date.
 * SS-9000      2024-09-23     Opp Reg to Deal Reg Migration
 */
public class BatchUpdateLeadExpiryDate implements Database.Batchable<sObject>, Schedulable {
	public Database.QueryLocator start(Database.BatchableContext bc) {
		Date dt = system.today().addDays(10);
		String query =
			'SELECT Id, ' +
			'or_Opportunity_Registration_Expiry_Date__c, ' +
			'PreExpiry_Email_Sent__c ' +
			'FROM Deal_Registration__c ' +
			'WHERE or_Opp_Reg_Status__c = \'Approved\' ' +
			'AND (or_Opportunity_Registration_Expiry_Date__c = :dt ' +
			'OR or_Opportunity_Registration_Expiry_Date__c = TODAY)';
		return Database.getQueryLocator(query);
	}

	public void execute(Database.BatchableContext bc, List<Deal_Registration__c> deals) {
		for (Deal_Registration__c deal : deals) {
			if (System.today() == deal.or_Opportunity_Registration_Expiry_Date__c) {
				deal.or_Opp_Reg_Status__c = 'Expired';
			} else if (
				System.today().addDays(10) == deal.or_Opportunity_Registration_Expiry_Date__c &&
				deal.PreExpiry_Email_Sent__c != true
			) {
				deal.PreExpiry_Email_Sent__c = true;
			}
		}
		Database.SaveResult[] saveResults = Database.update(deals, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'BatchUpdateLeadExpiryDate.execute ERRORS',
				saveResults
			)
			.addTag('apex')
			.addTag('batch');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
	}

	// Scheduler Execute Method
	public void execute(SchedulableContext ctx) {
		BatchUpdateLeadExpiryDate batch = new BatchUpdateLeadExpiryDate();
		Database.executeBatch(batch);
	}
}