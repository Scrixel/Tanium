/**
 * @Business: Zoomin's Salesforce Feed Items Connector
 * @Date: 2024-01-24
 * @Request: SS-6903
 * Modified  ModifiedDate   Description
 * SS-6903   2024-01-24     Initial development
 **/
public class Zoomin_KFX_FeedItem {
	public static void feedItemCreated(List<FeedItem> feeditems) {
		List<Zoomin_FeedItem__c> zfeeditems = new List<Zoomin_FeedItem__c>{};
		for (FeedItem fi : feeditems) {
			if (fi.Type == 'QuestionPost')
				zfeeditems.add(new Zoomin_FeedItem__c(Feed_Item__c = fi.Id));
		}
		insert zfeeditems;
	}

	public static void feedItemDeleted(List<FeedItem> feeditems) {
		Set<Id> deletedFIs = new Set<Id>{};
		for (FeedItem fi : feeditems) {
			if (fi.Type == 'QuestionPost')
				deletedFIs.add(fi.Id);
		}
		List<Zoomin_FeedItem__c> zfeeditems = [
			SELECT Id
			FROM Zoomin_FeedItem__c
			WHERE Feed_Item__c IN :deletedFIs
		];
		delete zfeeditems;
	}
}