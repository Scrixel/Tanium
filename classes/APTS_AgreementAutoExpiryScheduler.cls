global class APTS_AgreementAutoExpiryScheduler implements Schedulable {
	global void execute(SchedulableContext sc) {
		Id batchId = Database.executeBatch(new APTS_AgreementAutoExpiryBatch());
	}
}