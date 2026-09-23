trigger ELV_QuoteLineTrigger on QuoteLineItem (
	before insert,
	before update,
	before delete,
	after insert,
	after update,
	after delete,
	after undelete
) {
	new ELV_QuoteLineTriggerHandler().run();
}