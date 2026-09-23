public with sharing class ValidateAllQuoteTermVersionFormulas {

    /*
     * Input supplied by Flow.
     *
     * Flow passes a collection of ELV_Quote_Term_Version__c record IDs.
     */
    public class Request {

        @InvocableVariable(
            label='Quote Term Version IDs'
            description='Quote Term Version records whose Tested Formula values should be validated.'
            required=true
        )
        public List<Id> quoteTermVersionIds;
    }

    /*
     * Output returned to Flow.
     *
     * One Result is returned for each Request supplied by Flow.
     * The output includes:
     * - the number of invalid formulas
     * - collections containing the invalid record details
     * - one formatted text report that can be displayed directly
     *   on a Flow screen
     */
    public class Result {

        @InvocableVariable(
            label='Total Formula Count'
            description='Total number of unique Quote Term Version records processed.'
        )
        public Integer totalFormulaCount;

        @InvocableVariable(
            label='Valid Formula Count'
            description='Number of Quote Term Version records with valid Boolean formulas.'
        )
        public Integer validFormulaCount;

        @InvocableVariable(
            label='Invalid Formula Count'
            description='Number of Quote Term Version records with blank, inaccessible, or invalid formulas.'
        )
        public Integer invalidFormulaCount;

        @InvocableVariable(
            label='All Formulas Valid'
            description='True when every processed Quote Term Version has a valid Boolean formula.'
        )
        public Boolean allFormulasValid;

        @InvocableVariable(
            label='Invalid Quote Term Version IDs'
            description='IDs of Quote Term Version records with blank, inaccessible, or invalid formulas.'
        )
        public List<Id> invalidQuoteTermVersionIds;

        @InvocableVariable(
            label='Invalid Quote Term Version Names'
            description='Names of Quote Term Version records with blank or invalid formulas.'
        )
        public List<String> invalidQuoteTermVersionNames;

        @InvocableVariable(
            label='Invalid Formula Texts'
            description='Formula text from each Quote Term Version that did not pass validation.'
        )
        public List<String> invalidFormulaTexts;

        @InvocableVariable(
            label='Validation Messages'
            description='Validation error message for each Quote Term Version that did not pass validation.'
        )
        public List<String> validationMessages;

        @InvocableVariable(
            label='Invalid Formula Report'
            description='Formatted report containing every Quote Term Version that did not pass validation.'
        )
        public String invalidFormulaReport;

        @InvocableVariable(
            label='Validation Summary'
            description='Summary of the formula validation results.'
        )
        public String validationSummary;
    }

    /*
     * Makes the method available as an Apex Action in Flow.
     */
    @InvocableMethod(
        label='Validate Quote Term Version Formulas'
        description='Validates the Tested Formula on each selected Quote Term Version against the Quote object and returns details for any formulas that do not compile as Boolean formulas.'
        category='Quote Term Management'
    )
    public static List<Result> validateFormulas(
        List<Request> requests
    ) {
        List<Result> flowResults = new List<Result>();

        if (requests == null) {
            return flowResults;
        }

        /*
         * Flow can technically pass more than one Request because
         * invocable methods are bulkified. Return one Result for
         * each Request.
         */
        for (Request request : requests) {

            Result result = initializeResult();

            if (
                request == null ||
                request.quoteTermVersionIds == null ||
                request.quoteTermVersionIds.isEmpty()
            ) {
                result.allFormulasValid = false;
                result.validationSummary =
                    'No Quote Term Version records were submitted for validation.';
                result.invalidFormulaReport =
                    'No Quote Term Version records were submitted for validation.';

                flowResults.add(result);
                continue;
            }

            /*
             * Remove duplicate IDs before querying.
             */
            Set<Id> requestedIds =
                new Set<Id>(request.quoteTermVersionIds);

            requestedIds.remove(null);

            if (requestedIds.isEmpty()) {
                result.allFormulasValid = false;
                result.validationSummary =
                    'No valid Quote Term Version IDs were submitted for validation.';
                result.invalidFormulaReport =
                    'No valid Quote Term Version IDs were submitted for validation.';

                flowResults.add(result);
                continue;
            }

            /*
             * Query the Quote Term Version records and their formulas.
             *
             * Update Tested_Formula__c here if your actual field API
             * name is different.
             */
            Map<Id, ELV_Quote_Term_Version__c> versionsById =
                new Map<Id, ELV_Quote_Term_Version__c>([
                    SELECT
                        Id,
                        Name,
                        Version_Type__c,
                        Tested_Formula__c
                    FROM ELV_Quote_Term_Version__c
                    WHERE Id IN :requestedIds
                ]);

            /*
             * Process records in the same order they were submitted
             * by Flow while preventing duplicate validation results.
             */
            Set<Id> processedIds = new Set<Id>();

            for (Id versionId : request.quoteTermVersionIds) {

                if (
                    versionId == null ||
                    processedIds.contains(versionId)
                ) {
                    continue;
                }

                processedIds.add(versionId);
                result.totalFormulaCount++;

                ELV_Quote_Term_Version__c version =
                    versionsById.get(versionId);

                /*
                 * This can happen if the record was deleted, the ID is
                 * invalid for this object, or sharing prevents access.
                 */
                if (
                    version != null &&
                    version.Version_Type__c != 'Source'
                ) {
                    continue;
                }

                if (version == null) {
                    addInvalidResult(
                        result,
                        versionId,
                        null,
                        null,
                        'The Quote Term Version could not be found or is not accessible.'
                    );

                    continue;
                }

                /*
                 * Treat a blank formula as invalid.
                 *
                 * If blank formulas should be allowed in your data
                 * model, this section can instead increment the valid
                 * count or skip the record.
                 */
                if (String.isBlank(version.Tested_Formula__c)) {
                    addInvalidResult(
                        result,
                        version.Id,
                        version.Name,
                        version.Tested_Formula__c,
                        'The Tested Formula field is blank.'
                    );

                    continue;
                }

                try {
                    /*
                     * Compile the formula against the Quote object and
                     * require it to return a Boolean value.
                     *
                     * The formula does not need to evaluate to TRUE.
                     * It only needs to be syntactically valid and have
                     * a Boolean return type.
                     */
                    FormulaEval.FormulaInstance formulaInstance =
                        Formula.builder()
                            .withType(Quote.SObjectType)
                            .withReturnType(
                                FormulaEval.FormulaReturnType.BOOLEAN
                            )
                            .withFormula(
                                version.Tested_Formula__c
                            )
                            .build();

                    result.validFormulaCount++;

                } catch (Exception e) {
                    String errorDetail = cleanErrorMessage(
                        e.getMessage()
                    );

                    addInvalidResult(
                        result,
                        version.Id,
                        version.Name,
                        version.Tested_Formula__c,
                        'The formula is invalid: ' + errorDetail
                    );
                }
            }

            result.invalidFormulaCount =
                result.invalidQuoteTermVersionIds.size();

            result.allFormulasValid =
                result.totalFormulaCount > 0 &&
                result.invalidFormulaCount == 0;

            if (result.allFormulasValid) {
                result.validationSummary =
                    'All ' +
                    String.valueOf(result.totalFormulaCount) +
                    ' Quote Term Version formulas are valid Boolean formulas.';

                result.invalidFormulaReport =
                    'No invalid formulas were found.';
            } else {
                result.validationSummary =
                    String.valueOf(result.totalFormulaCount) +
                    ' Quote Term Version record(s) processed. ' +
                    String.valueOf(result.validFormulaCount) +
                    ' valid and ' +
                    String.valueOf(result.invalidFormulaCount) +
                    ' invalid.';

                result.invalidFormulaReport =
                    buildInvalidFormulaReport(result);
            }

            flowResults.add(result);
        }

        return flowResults;
    }

    /*
     * Creates a Result with all collections initialized.
     */
    private static Result initializeResult() {
        Result result = new Result();

        result.totalFormulaCount = 0;
        result.validFormulaCount = 0;
        result.invalidFormulaCount = 0;
        result.allFormulasValid = false;

        result.invalidQuoteTermVersionIds = new List<Id>();
        result.invalidQuoteTermVersionNames = new List<String>();
        result.invalidFormulaTexts = new List<String>();
        result.validationMessages = new List<String>();

        result.invalidFormulaReport = '';
        result.validationSummary = '';

        return result;
    }

    /*
     * Adds one failed validation to the Result.
     *
     * The four collections are populated in the same order, so item
     * 1 in each collection refers to the same Quote Term Version.
     */
    private static void addInvalidResult(
        Result result,
        Id versionId,
        String versionName,
        String formulaText,
        String validationMessage
    ) {
        result.invalidQuoteTermVersionIds.add(versionId);
        result.invalidQuoteTermVersionNames.add(versionName);
        result.invalidFormulaTexts.add(formulaText);
        result.validationMessages.add(validationMessage);
    }

    /*
     * Builds a single readable report that can be placed directly in
     * a Flow Display Text component.
     */
    private static String buildInvalidFormulaReport(
        Result result
    ) {
        if (
            result == null ||
            result.invalidQuoteTermVersionIds == null ||
            result.invalidQuoteTermVersionIds.isEmpty()
        ) {
            return 'No invalid formulas were found.';
        }

        List<String> reportSections = new List<String>();

        for (
            Integer index = 0;
            index < result.invalidQuoteTermVersionIds.size();
            index++
        ) {
            Id versionId =
                result.invalidQuoteTermVersionIds[index];

            String versionName =
                result.invalidQuoteTermVersionNames[index];

            String formulaText =
                result.invalidFormulaTexts[index];

            String validationMessage =
                result.validationMessages[index];

            String displayName =
                String.isBlank(versionName)
                    ? String.valueOf(versionId)
                    : versionName;

            String displayFormula =
                String.isBlank(formulaText)
                    ? '[Blank]'
                    : formulaText;

            String recordUrl =
                versionId == null
                    ? ''
                    : URL.getOrgDomainUrl().toExternalForm() +
                      '/' +
                      String.valueOf(versionId);

            String section =
                'Quote Term Version: ' + displayName + '\n' +
                'Record ID: ' + String.valueOf(versionId) + '\n';

            if (!String.isBlank(recordUrl)) {
                section +=
                    'Record URL: ' + recordUrl + '\n';
            }

            section +=
                'Formula: ' + displayFormula + '\n' +
                'Error: ' + validationMessage;

            reportSections.add(section);
        }

        return String.join(
            reportSections,
            '\n\n----------------------------------------\n\n'
        );
    }

    /*
     * Ensures the returned Salesforce error is populated and does not
     * become excessively long for Flow.
     */
    private static String cleanErrorMessage(
        String errorDetail
    ) {
        if (String.isBlank(errorDetail)) {
            errorDetail =
                'Salesforce could not compile the formula.';
        }

        Integer maximumLength = 500;

        if (errorDetail.length() > maximumLength) {
            errorDetail =
                errorDetail.substring(0, maximumLength) +
                '...';
        }

        return errorDetail;
    }
}