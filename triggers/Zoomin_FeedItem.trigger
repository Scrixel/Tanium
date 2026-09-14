/**
 * @Business: Zoomin's Salesforce Feed Items Connector
 * @Date: 2024-01-24
 * @Request: SS-6903
 * Modified  ModifiedDate   Description
 * SS-6903   2024-01-24     Initial development
 **/
trigger Zoomin_FeedItem on FeedItem(after insert, after delete) {
	new Zoomin_FeedItemTriggerHandler().run();
}