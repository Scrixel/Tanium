/**
 * @BUSINESS: Controller of the "NewPartnerLandscapes" Visualforce page
 * @DATE: 2019-09-20
 * @AUTHOR: Cumulus Vision
 *
 * Modified  ModifiedDate   Description
 * TAN-811   2019-09-25     Initial Development
 * TAN-811   2019-10-04     Updated code to sort picklist values.
 * TAN-831    2019-11-14     added help text to scope of service and changed input to text area
 */
public class NewPartnerLandscapesController {
	private Id accountId;
	public Map<String, List<SelectOption>> mapPartnerLandscapeTypeToPartnerOption {
		get;
		private set;
	}
	public Map<String, List<String>> mapPartnerLandscapeTypeToSelPartner { get; set; }
	public Map<String, String> mapPartnerLandscapeTypeToScopeOfWork { get; set; }
	public Map<String, String> mapPartnerLandscapeTypeToHelpText { get; private set; }
	public Map<String, String> mapPartnerLandscapeTypeToServiceHelpText { get; private set; }
	public Partner_Landscape__c otherPartnerLandscape { get; private set; }
	public String errorMessage { get; private set; }

	public Boolean isValidAccount {
		get {
			return String.isNotBlank(accountId);
		}
	}

	public NewPartnerLandscapesController() {
		try {
			String acctId = ApexPages.currentPage().getParameters().get('id');
			List<Account> listAccount = [SELECT Id FROM Account WHERE Id = :acctId];

			if (listAccount.isEmpty()) {
				accountId = null;
				System.debug('\n Account does not exist.');
			} else {
				accountId = acctId;
				doInitialization();
			}
		} catch (Exception ex) {
			errorMessage = ex.getMessage();
			logException(ex);
		}
	}

	private void doInitialization() {
		otherPartnerLandscape = new Partner_Landscape__c(Account__c = accountId);
		populateMetadataInfo();

		mapPartnerLandscapeTypeToSelPartner = new Map<String, List<String>>();
		mapPartnerLandscapeTypeToScopeOfWork = new Map<String, String>();
		for (String partnerType : mapPartnerLandscapeTypeToPartnerOption.keySet()) {
			mapPartnerLandscapeTypeToSelPartner.put(partnerType, new List<String>());
			mapPartnerLandscapeTypeToScopeOfWork.put(partnerType, '');
		}
		mapPartnerLandscapeTypeToSelPartner = populateExistingPartners(
			accountId,
			mapPartnerLandscapeTypeToSelPartner
		);
	}

	private void populateMetadataInfo() {
		mapPartnerLandscapeTypeToPartnerOption = new Map<String, List<SelectOption>>();
		mapPartnerLandscapeTypeToHelpText = new Map<String, String>();
		mapPartnerLandscapeTypeToServiceHelpText = new Map<String, String>();

		for (Partner_Landscape_Type__mdt plType : [
			SELECT
				Id,
				MasterLabel,
				Help_Text__c,
				Scope_of_Service_Help_Text__c,
				(SELECT Id, MasterLabel FROM Partner_Landscape_Partners__r)
			FROM Partner_Landscape_Type__mdt
		]) {
			Set<String> setPartner = new Set<String>();

			for (Partner_Landscape_Partner__mdt plPartner : plType.Partner_Landscape_Partners__r) {
				setPartner.add(plPartner.MasterLabel);
			}

			List<SelectOption> listPartnerOption = new List<SelectOption>();
			for (String partner : setPartner) {
				listPartnerOption.add(new SelectOption(partner, partner));
			}
			listPartnerOption.sort();
			mapPartnerLandscapeTypeToPartnerOption.put(plType.MasterLabel, listPartnerOption);
			mapPartnerLandscapeTypeToHelpText.put(plType.MasterLabel, plType.Help_Text__c);
			mapPartnerLandscapeTypeToServiceHelpText.put(
				plType.MasterLabel,
				plType.Scope_of_Service_Help_Text__c
			);
		}
	}

	public PageReference insertPartnerLandscapes() {
		List<Partner_Landscape__c> listPartnerLandscapes = new List<Partner_Landscape__c>();
		System.debug(
			'\n mapPartnerLandscapeTypeToSelPartner:' +
			JSON.serialize(mapPartnerLandscapeTypeToSelPartner)
		);

		try {
			clearErrorMessage();
			Account account = getAccount(accountId);

			Map<String, List<String>> mapExistingPLTypeToPartners = new Map<String, List<String>>();
			mapExistingPLTypeToPartners = populateExistingPartners(
				accountId,
				mapExistingPLTypeToPartners
			);

			for (String plType : mapPartnerLandscapeTypeToSelPartner.keySet()) {
				for (String plPartner : mapPartnerLandscapeTypeToSelPartner.get(plType)) {
					if (
						mapExistingPLTypeToPartners.containsKey(plType) &&
						mapExistingPLTypeToPartners.get(plType).contains(plPartner)
					) {
						continue;
					}

					Partner_Landscape__c newPartnerLandscape = new Partner_Landscape__c(
						Account__c = accountId,
						Partner_Type__c = plType,
						Partner__c = plPartner,
						Scope_of_Work__c = mapPartnerLandscapeTypeToScopeOfWork.get(plType)
					);
					listPartnerLandscapes.add(newPartnerLandscape);
				}
			}

			if (!listPartnerLandscapes.isEmpty()) {
				insert listPartnerLandscapes;

				PageReference accountPageRef = new ApexPages.StandardController(account).view();
				accountPageRef.setRedirect(true);
				return accountPageRef;
			} else {
				errorMessage = 'Please select at least one Partner.';
			}
		} catch (Exception ex) {
			errorMessage = ex.getMessage();
			logException(ex);
		}
		return null;
	}

	public PageReference insertOtherPartnerLandscape() {
		try {
			clearErrorMessage();
			Account account = getAccount(accountId);

			if (
				String.isBlank(otherPartnerLandscape.Partner_Type__c) ||
				String.isBlank(otherPartnerLandscape.Partner__c)
			) {
				errorMessage = 'Required fields missing';
				return null;
			}

			insert otherPartnerLandscape;

			PageReference accountPageRef = new ApexPages.StandardController(account).view();
			accountPageRef.setRedirect(true);
			return accountPageRef;
		} catch (Exception ex) {
			errorMessage = ex.getMessage();
			logException(ex);
		}
		return null;
	}

	private static Map<String, List<String>> populateExistingPartners(
		Id accountId,
		Map<String, List<String>> mapPartnerLandscapeTypeToPartners
	) {
		mapPartnerLandscapeTypeToPartners = mapPartnerLandscapeTypeToPartners == null
			? new Map<String, List<String>>()
			: mapPartnerLandscapeTypeToPartners;

		for (Partner_Landscape__c pl : [
			SELECT Id, Partner_Type__c, Partner__c
			FROM Partner_Landscape__c
			WHERE Account__c = :accountId AND Partner_Type__c != NULL AND Partner__c != NULL
		]) {
			String plType = pl.Partner_Type__c;
			if (!mapPartnerLandscapeTypeToPartners.containsKey(plType)) {
				mapPartnerLandscapeTypeToPartners.put(plType, new List<String>());
			}
			mapPartnerLandscapeTypeToPartners.get(plType).add(pl.Partner__c);
		}

		return mapPartnerLandscapeTypeToPartners;
	}

	private void clearErrorMessage() {
		errorMessage = null;
	}

	private static Account getAccount(Id acctId) {
		return [SELECT Id FROM Account WHERE Id = :acctId];
	}

	private static void logException(Exception ex) {
		System.debug(
			'\n Exception occurred.' +
			'\n Error:' +
			ex.getMessage() +
			'\n Stack Trace:' +
			ex.getStackTraceString()
		);
	}
}