trigger AgreementTrigger on Apttus__APTS_Agreement__c(before insert, after update) {
	new AgreementTriggerHandler().run();
}