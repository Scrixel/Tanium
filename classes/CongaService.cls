/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller class for createClickThruAgreement LWC.
 * @Date: 2022-03-28
 * @Author: Tanium Dev Team
 * @Request:
 * RequestId  ModifiedDate  Description
 * SS-8934    2024-12-03    Create user interface in LWC.
 * SS-10174   2025-07-23    Click Through Template name change.
 */

public with sharing class CongaService {
	public static final String AGREEMENT_TYPE_CLICK_THRU = 'Click-Thru Agreement';
	public static final String TEMPLATE_TAAS = System.Label.Click_Thru_Agreement_Templates;
	public static final String TEMPLATE_EULA = System.Label.Click_Thru_Agreement_Other_Template;
	public static final String MLA_RECORDTYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Apttus__APTS_Agreement__c',
		'MLA'
	);

	@AuraEnabled
	public static OpportunityDetails getOppDetails(Id oppId) {
		OpportunityDetails oppDetails = new OpportunityDetails();
		Opportunity opp;
		try {
			opp = [
				SELECT
					Id,
					Name,
					AccountId,
					Account.Name,
					CloseDate,
					Contract_Owner__c,
					Contract_Owner__r.Name,
					Customer_Agreement_Type_Required__c,
					StageName,
					TaaS_Opportunity__c,
					Deployment_Type__c
				FROM Opportunity
				WHERE Id = :oppId
			];
		} catch (Exception error) {
			oppDetails.errorMessage = '' + error.getMessage();
			return oppDetails;
		}

		if (noApttusLicense()) {
			oppDetails.errorMessage =
				'Sorry, you must be a licensed Conga user in order to use this function. Please contact the Contract Owner - ' +
				opp.Contract_Owner__r?.Name +
				' or another member of the Contracts team to assist you in the Agreement creation process.';
			return oppDetails;
		}

		if (opp.StageName != Utility.CLOSED_WON) {
			oppDetails.errorMessage = Label.CongaAgreementClosedWonError;
			return oppDetails;
		}

		if (opp.Customer_Agreement_Type_Required__c != CongaService.AGREEMENT_TYPE_CLICK_THRU) {
			oppDetails.errorMessage = Label.CongaAgreementClickThruError;
			return oppDetails;
		}

		oppDetails.Id = opp.Id;
		oppDetails.name = opp.Name;
		oppDetails.accountId = opp.AccountId;
		oppDetails.accountName = opp.Account.Name;
		oppDetails.closeDate = opp.CloseDate;
		oppDetails.contractOwnerId = opp.Contract_Owner__c;
		oppDetails.deploymentMethod = opp.Deployment_Type__c;
		oppDetails.errorMessage = '';

		return oppDetails;
	}

	@AuraEnabled
	public static SaveResult createAgreement(String oppDetails, String template) {
		try {
			OpportunityDetails opp = (OpportunityDetails) JSON.deserialize(
				oppDetails,
				CongaService.OpportunityDetails.class
			);

			Database.SaveResult sr = CongaService.generateAgreement(opp);
			if (!sr.isSuccess()) {
				return new SaveResult(sr);
			}

			Id agreementId = sr.getId();
			Id templateId = CongaService.getTemplateId(template);
			if (Utility.isFutureMethodAllowed()) {
				CongaService.activateAgreementAPIFuture(agreementId, templateId);
			}

			SaveResult sr2 = CongaService.updateAccountPaymentTerms(opp.accountId);
			if (!sr2.isSuccess) {
				return sr2;
			}

			return new SaveResult();
		} catch (Exception ex) {
			return new SaveResult(ex);
		}
	}

	@TestVisible
	private static Boolean noApttusLicense() {
		List<UserPackageLicense> packagelicense = [
			SELECT Id, PackagelicenseId, PackageLicense.NamespacePrefix
			FROM UserPackageLicense
			WHERE PackageLicense.NamespacePrefix = 'Apttus' AND UserId = :UserInfo.getUserId()
		];
		return packagelicense.isEmpty();
	}

	@TestVisible
	private static Database.SaveResult generateAgreement(OpportunityDetails opp) {
		Id agreementOwner = opp.contractOwnerId == null
			? getDefaultAgreementOwner()
			: opp.contractOwnerId;

		Apttus__APTS_Agreement__c agreement = new Apttus__APTS_Agreement__c(
			Name = opp.accountName + ' Click Thru MLA',
			Agreement_Effective_Date__c = opp.closeDate,
			Agreement_Owner__c = agreementOwner,
			Apttus__Account__c = opp.accountId,
			Apttus_ff_Clause_Certification__c = 'Yes',
			Apttus__Related_Opportunity__c = opp.Id,
			Apttus__Requestor__c = agreementOwner,
			Apttus__Owner_Expiration_Notice__c = '',
			Apttus__Workflow_Trigger_Viewed_Final__c = false,
			Evergreen__c = true,
			Include_License_Schedule__c = 'No',
			MLA_Template_Type__c = 'Click Thru',
			Payment_terms__c = true,
			RecordTypeId = MLA_RECORDTYPE_ID,
			Tanium_Legal_Name__c = 'Tanium Inc.'
		);

		Database.SaveResult insertResult = Database.insert(agreement, false);

		if (insertResult.isSuccess()) {
			agreement.Apttus_Approval__Approval_Status__c = 'Approved';
			Database.SaveResult updateResult = Database.update(agreement, false);

			if (!updateResult.isSuccess()) {
				Logger.logDatabaseErrors(
						LoggingLevel.ERROR,
						'CongaService.generateAgreement, update agreement ERRORS',
						new List<Database.SaveResult>{ updateResult }
					)
					.addTag('apex');
				Logger.saveLog();
			}
			return updateResult;
		} else {
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'CongaService.generateAgreement, insert agreement ERRORS',
					new List<Database.SaveResult>{ insertResult }
				)
				.addTag('apex');
			Logger.saveLog();
		}

		return insertResult;
	}

	@TestVisible
	private static SaveResult updateAccountPaymentTerms(String accId) {
		try {
			Account acc = [SELECT Id, Payment_Terms__c FROM Account WHERE Id = :accId];

			if (acc.Payment_Terms__c == null) {
				acc.Payment_Terms__c = 'Net 30';

				Database.SaveResult updateResult = Database.update(acc, false);

				if (!updateResult.isSuccess()) {
					Logger.logDatabaseErrors(
							LoggingLevel.ERROR,
							'CongaService.updateAccount, update account ERRORS',
							new List<Database.SaveResult>{ updateResult }
						)
						.addTag('apex');
					Logger.saveLog();
					return new SaveResult(updateResult);
				}
			}
			return new SaveResult();
		} catch (Exception ex) {
			return new SaveResult(ex);
		}
	}

	@TestVisible
	private static Id getDefaultAgreementOwner() {
		List<User> agreementOwner = [
			SELECT Id
			FROM User
			WHERE alias = :Label.CongaDefaultAgreementOwnerAlias
			LIMIT 1
		];
		if (!agreementOwner.isEmpty()) {
			return agreementOwner[0].Id;
		}

		return null;
	}

	@TestVisible
	private static Id getTemplateId(String templateName) {
		return [SELECT Id FROM Apttus__APTS_Template__c WHERE Name = :templateName LIMIT 1].Id;
	}

	@TestVisible
	@future(callout=true)
	private static void activateAgreementAPIFuture(Id agreementId, Id templateId) {
		String apiServerURL =
			System.Url.getSalesforceBaseUrl().toExternalForm() +
			'/services/Soap/u/42.0/' +
			UserInfo.getOrganizationId();

		if (!Test.isRunningTest()) {
			String generatedDocId = Apttus.MergeWebService.generateDoc(
				templateId,
				agreementId,
				'Full access',
				'PDF',
				UserInfo.getSessionId(),
				apiServerURL
			);

			Boolean activateResult = Apttus.AgreementWebService.activateAgreement(
				agreementId,
				new List<String>{ generatedDocId },
				new List<String>{}
			);
		}

		CongaService.updateClauseAction(agreementId);
	}

	@TestVisible
	private static void updateClauseAction(Id agreementId) {
		List<Apttus__Agreement_Clause__c> clauses = new List<Apttus__Agreement_Clause__c>();

		for (Apttus__Agreement_Clause__c eachClause : [
			SELECT Id, Apttus__Action__c
			FROM Apttus__Agreement_Clause__c
			WHERE Apttus__Agreement__c = :agreementId
		]) {
			eachClause.Apttus__Action__c = 'Final';
			clauses.add(eachClause);
		}

		update clauses;
	}

	public class OpportunityDetails {
		@AuraEnabled
		public Id Id { get; set; }

		@AuraEnabled
		public String name { get; set; }

		@AuraEnabled
		public Id accountId { get; set; }

		@AuraEnabled
		public String accountName { get; set; }

		@AuraEnabled
		public Date closeDate { get; set; }

		@AuraEnabled
		public Id contractOwnerId { get; set; }

		@AuraEnabled
		public String deploymentMethod { get; set; }

		@AuraEnabled
		public String errorMessage { get; set; }
	}

	public class SaveResult {
		SaveResult() {
			this.isSuccess = true;
			this.errorMessage = '';
		}

		SaveResult(Exception e) {
			this.isSuccess = false;
			this.errorMessage = e.getMessage() + '\n\n ' + e.getStackTraceString();
		}

		SaveResult(Database.SaveResult sr) {
			this.isSuccess = false;
			this.errorMessage = sr.getErrors()[0].getMessage();
		}

		@AuraEnabled
		public Boolean isSuccess { get; set; }

		@AuraEnabled
		public String errorMessage { get; set; }
	}
}