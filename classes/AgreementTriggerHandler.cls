public with sharing class AgreementTriggerHandler extends TriggerHandler {
	@TestVisible
	private static final List<String> PREPOPULATED_RECORDTYPES = new List<String>{
		'Partner_Agreement',
		'Evaluation',
		'License_Schedule',
		'MLA',
		'NDA',
		'Other_Agreement',
		'Partner_Schedule'
	};
	@TestVisible
	private static final STRING AMENDMENT_APPROVAL_STATUS = 'Approval Required';

	@TestVisible
	private static final String NON_STANDARD_USE = 'NSU';

	@TestVisible
	private static final List<String> TEMPLATE_TYPES_FOR_FINAL_ACTION = System.Label.Agreement_MLA_Template_Types.split(
		','
	);

	private Map<Id, Apttus__APTS_Agreement__c> oldAgreementMap;
	private Map<Id, Apttus__APTS_Agreement__c> newAgreementMap;

	public AgreementTriggerHandler() {
		super('AgreementTriggerHandler');
		this.oldAgreementMap = (Map<Id, Apttus__APTS_Agreement__c>) Trigger.oldMap;
		this.newAgreementMap = (Map<Id, Apttus__APTS_Agreement__c>) Trigger.newMap;
	}

	public override void beforeInsert() {
		prePopulateAmendAgreementData((List<Apttus__APTS_Agreement__c>) Trigger.new);
	}

	public override void afterUpdate() {
		// Check Status Category and create Account Agreement Clause for eligible records.
		Map<Id, Apttus__APTS_Agreement__c> agreementInEffectMap = new Map<Id, Apttus__APTS_Agreement__c>();
		Map<Id, Apttus__APTS_Agreement__c> agreementInEffectChangedMap = new Map<Id, Apttus__APTS_Agreement__c>();

		for (Apttus__APTS_Agreement__c agreement : newAgreementMap.values()) {
			String oldStatus = (oldAgreementMap.get(agreement.Id)).Apttus__Status_Category__c;
			String status = agreement.Apttus__Status_Category__c;
			if (
				oldStatus != 'Amended' &&
				oldStatus != 'In Effect' &&
				(status == 'Amended' ||
				status == 'In Effect')
			) {
				agreementInEffectMap.put(agreement.Id, agreement);
			}
			if (
				status != 'Amended' &&
				status != 'In Effect' &&
				(oldStatus == 'Amended' ||
				oldStatus == 'In Effect')
			) {
				agreementInEffectChangedMap.put(agreement.Id, agreement);
			}
		}

		if (!agreementInEffectMap.isEmpty()) {
			createAccountAgreementClause(agreementInEffectMap);
		}
		if (!agreementInEffectChangedMap.isEmpty()) {
			deleteAccountAgreementClause(agreementInEffectChangedMap);
		}
	}

	@TestVisible
	private void prePopulateAmendAgreementData(List<Apttus__APTS_Agreement__c> agreementList) {
		Set<String> recTypeSet = new Set<String>();
		Map<String, Schema.RecordTypeInfo> agreementRecordTypes = Schema.SObjectType.Apttus__APTS_Agreement__c.getRecordTypeInfosByDeveloperName();
		Id otherAgreementRecTypeId = Utility.getRecordTypeIdByAPIName(
			'Apttus__APTS_Agreement__c',
			'Other_Agreement'
		);
		for (String recordTypeName : PREPOPULATED_RECORDTYPES) {
			if (agreementRecordTypes.get(recordTypeName) != null) {
				recTypeSet.add(agreementRecordTypes.get(recordTypeName).getRecordTypeId());
			}
		}

		List<Apttus__APTS_Agreement__c> agreementsToProcess = new List<Apttus__APTS_Agreement__c>();
		Set<String> agreementNumbers = new Set<String>();

		for (Apttus__APTS_Agreement__c agreement : agreementList) {
			if (recTypeSet.contains(agreement.recordTypeId)) {
				System.debug('Agreement number on a new record ' + agreement.Apttus__Agreement_Number__c);
				agreementNumbers.add(agreement.Apttus__Agreement_Number__c);
				agreementsToProcess.add(agreement);
			}
		}

		Map<String, Id> agreementNumberIdMap = new Map<String, Id>();

		for (Apttus__APTS_Agreement__c existingAgreement : [
			SELECT Id, Apttus__Agreement_Number__c
			FROM Apttus__APTS_Agreement__c
			WHERE Apttus__Agreement_Number__c IN :agreementNumbers
			ORDER BY Apttus__FF_Agreement_Number__c DESC
		]) {
			if (agreementNumberIdMap.get(existingAgreement.Apttus__Agreement_Number__c) == null) {
				agreementNumberIdMap.put(
					existingAgreement.Apttus__Agreement_Number__c,
					existingAgreement.Id
				);
			}
		}

		for (Apttus__APTS_Agreement__c agreement : agreementsToProcess) {
			if (agreement.RecordTypeId == otherAgreementRecTypeId) {
				agreement.Apttus__Status__c = 'Request';
				agreement.Apttus__Status_Category__c = 'Request';
				agreement.Apttus_Approval__Approval_Status__c = 'Approval Required';
			}
			if (String.isNotBlank(agreement.name) && agreement.Name.containsIgnoreCase('Amend')) {
				agreement.Name = agreement.Name.replace('Amended', 'Amendment');
				agreement.Apttus__Status__c = 'Request';
				agreement.Apttus__Status_Category__c = 'Request';
				agreement.Apttus__Parent_Agreement__c = agreementNumberIdMap.get(
					agreement.Apttus__Agreement_Number__c
				);
				agreement.Evergreen__c = false;
				agreement.Clause_Certification__c = false;
				agreement.Apttus_Approval__Approval_Status__c = AMENDMENT_APPROVAL_STATUS;
			}
		}
	}

	private void createAccountAgreementClause(Map<Id, Apttus__APTS_Agreement__c> agreementMap) {
		List<APTMS_Account_Agreement_Clauses__c> accountAgreementClauseList = new List<APTMS_Account_Agreement_Clauses__c>();

		List<Apttus__Agreement_Clause__c> agreementClauseList = [
			SELECT
				Id,
				NAME,
				Apttus__Agreement__c,
				Apttus__Agreement__r.Id,
				Apttus__Agreement__r.Apttus__Account__c,
				Apttus__Agreement__r.Apttus__FF_Agreement_Number__c,
				Apttus__Text__c,
				Apttus__Clause__c,
				Apttus__PrevText__c
			FROM Apttus__Agreement_Clause__c
			WHERE
				Apttus__Agreement__c IN :agreementMap.keyset()
				AND Apttus__Category__c = 'Systems Information'
				AND ((Apttus__Action__c = 'Final'
				AND Apttus__Agreement__r.MLA_Template_Type__c IN :TEMPLATE_TYPES_FOR_FINAL_ACTION)
				OR Apttus__Agreement__r.MLA_Template_Type__c = 'Click Thru')
				AND Apttus__Agreement__r.Apttus__Status_Category__c IN ('In Effect', 'Amended')
		];

		for (Apttus__Agreement_Clause__c agreementClause : agreementClauseList) {
			APTMS_Account_Agreement_Clauses__c accAgreement = new APTMS_Account_Agreement_Clauses__c();
			accAgreement.Account__c = agreementClause.Apttus__Agreement__r.Apttus__Account__c;
			accAgreement.Agreement_Number__c = agreementClause.Apttus__Agreement__r.Apttus__FF_Agreement_Number__c;
			accAgreement.Agreement_Names__c = agreementClause.Apttus__Agreement__r.Id;
			accAgreement.Clause_Text__c = agreementClause.Apttus__Text__c;
			accAgreement.Clause__c = agreementClause.Apttus__Clause__c;
			if (agreementClause.Apttus__Clause__c != null) {
				accAgreement.Allowed__c = agreementClause.Apttus__Clause__c.startsWith(NON_STANDARD_USE)
					? 'No'
					: 'Yes';
			}

			accountAgreementClauseList.add(accAgreement);
		}

		Database.insert(accountAgreementClauseList);
	}

	private void deleteAccountAgreementClause(Map<Id, Apttus__APTS_Agreement__c> agreementMap) {
		delete [
			SELECT Id
			FROM APTMS_Account_Agreement_Clauses__c
			WHERE Agreement_Names__c IN :agreementMap.keyset()
		];
	}
}