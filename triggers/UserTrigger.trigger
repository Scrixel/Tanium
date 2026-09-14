trigger UserTrigger on User(before insert, before update, after update) {
	new UserTriggerHandler().run();
}