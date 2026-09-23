/**
 * @Business: Standard trigger handler
 * @Date: 2023-12-07
 * @Author: Varun Shah
 */

public class Apttus_AgreementClauseTriggerHandler extends TriggerHandler {
	private List<Apttus__Agreement_Clause__c> agreementClauses;
	private Map<Id, Apttus__Agreement_Clause__c> oldMap;

	public Apttus_AgreementClauseTriggerHandler() {
		super('Apttus_AgreementClauseTriggerHandler');
		this.agreementClauses = (List<Apttus__Agreement_Clause__c>) Trigger.new;
		this.oldMap = (Map<Id, Apttus__Agreement_Clause__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		Apttus_AgreementClauseTriggerUtility.changeStatus(agreementClauses);
	}

	public override void beforeUpdate() {
		Apttus_AgreementClauseTriggerUtility.changeStatus(agreementClauses, oldMap);
	}
}