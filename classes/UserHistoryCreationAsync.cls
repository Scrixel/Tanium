public class UserHistoryCreationAsync implements Queueable {
	private List<UserHistory__c> userHistory;

	public UserHistoryCreationAsync(List<UserHistory__c> userHistory) {
		this.userHistory = userHistory;
	}

	public void execute(QueueableContext context) {
		if (userHistory.isEmpty()) {
			return;
		}

		insert userHistory;
	}

	@InvocableMethod(Label='Create User History' Description='Create User History Record')
	public static void createUserHistory(List<UserHistory> userHistories) {
		Id jobId = System.enqueueJob(new UserHistoryCreationAsync(userHistories.get(0).userHistory));
	}

	public class UserHistory {
		@InvocableVariable
		public List<UserHistory__c> userHistory;
	}
}