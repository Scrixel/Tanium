/**
 * @Business: Handler for Feed Item
 * @Date: 2024-01-24
 * @Author: Nel Francis Buen
 * @Request: SS-6903
 * Modified  ModifiedDate   Description
 * SS-6903   2024-01-24     Initial development
 **/
public class Zoomin_FeedItemTriggerHandler extends TriggerHandler {
	public Zoomin_FeedItemTriggerHandler() {
		super('Zoomin_FeedItemTriggerHandler');
	}

	public override void afterInsert() {
		Zoomin_KFX_FeedItem.feedItemCreated(Trigger.new);
	}

	public override void afterDelete() {
		Zoomin_KFX_FeedItem.feedItemDeleted(Trigger.old);
	}
}