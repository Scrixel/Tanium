/**
 * @Business: Class that contains invocable method to enhance Apttus__Agreement_Clause__c search functionality
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate   Description
 * SS-12145   2025-11-25     Initial Development
 */
public without sharing class Apttus_AgreementClauseInvocable {
	@InvocableMethod(label='Agreement Clause Search non-standard Terms')
	public static List<String> searchNonStandardTerms(List<String> searchCriteria) {
		if (searchCriteria == null || searchCriteria.isEmpty() || searchCriteria[0] == '') {
			return new List<String>{ 'Input list is empty or null.' };
		}
		List<String> searchStrings = getUniqueSortedSearchStrings(searchCriteria[0]);
		List<Apttus__Agreement_Clause__c> agreementClauses;
		List<Apttus__Agreement_Clause__c> agreementClausesToUpdate = new List<Apttus__Agreement_Clause__c>();
		String errorMessage = '';
		Integer numRecordsUpdated = 0;
		String matchesString = '';
		Boolean matchFound = false;
		String regexPattern = '';
		String agreementClauseText = '';

		Pattern p;
		Matcher m;

		for (Apttus__Agreement_Clause__c agreementClause : [
			SELECT Id, Name, Apttus__Text__c
			FROM Apttus__Agreement_Clause__c
			LIMIT 50000
		]) {
			matchFound = false;
			matchesString = '';
			if (String.isBlank(agreementClause.Apttus__Text__c)) {
				continue;
			}
			for (String searchString : searchStrings) {
				regexPattern = '(?i).*' + searchString.toLowerCase().replaceAll('\\s+', '') + '.*';
				agreementClauseText = agreementClause.Apttus__Text__c.replaceAll('\\s+', '');

				if (Pattern.matches(regexPattern, agreementClauseText)) {
					matchFound = true;
					matchesString += searchString + ',';
				}
			}
			if (matchFound) {
				matchesString = matchesString.removeEnd(',');
				agreementClausesToUpdate.add(
					new Apttus__Agreement_Clause__c(
						Id = agreementClause.Id,
						Search_Term_s_that_appear_in_Text__c = matchesString
					)
				);
			}
		}

		List<Database.SaveResult> results = Database.update(agreementClausesToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'Apttus_AgreementClauseInvocable.searchNonStandardTerms ERRORS',
				results
			)
			.addTag('apex')
			.addTag('invocable');
		Logger.saveLog();

		for (Database.SaveResult result : results) {
			if (!result.isSuccess()) {
				errorMessage += result.getErrors()[0].getMessage() + '\n';
			} else {
				numRecordsUpdated++;
			}
		}

		return String.isBlank(errorMessage)
			? new List<String>{
					'Successfully updated ' +
					numRecordsUpdated +
					' agreement clause records.'
			  }
			: new List<String>{ errorMessage };
	}

	@TestVisible
	private static List<String> getUniqueSortedSearchStrings(String searchCriteria) {
		List<String> searchStrings = new List<String>();
		for (String searchString : searchCriteria.split(',')) {
			if (!searchStrings.contains(searchString.trim())) {
				searchStrings.add(searchString.trim());
			}
		}
		searchStrings.sort();
		return searchStrings;
	}
}