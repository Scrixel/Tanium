trigger ELV_ProductTrigger on Product2 (after update) {
	new ELV_ProductTriggerHandler().run();
}