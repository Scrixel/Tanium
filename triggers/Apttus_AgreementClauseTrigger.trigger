trigger Apttus_AgreementClauseTrigger on Apttus__Agreement_Clause__c(before insert, before update) {
	new Apttus_AgreementClauseTriggerHandler().run();
}