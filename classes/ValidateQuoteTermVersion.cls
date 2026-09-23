/*
 * The validation behind the Activate action.
 *
 * Activating a source version is the single point at which language
 * enters the library, so both checks happen here: the Tested Formula
 * has to compile as a Boolean against Quote, and every merge field in
 * the body has to name a real Quote field. Either failure leaves the
 * record inactive and unsaved.
 */
public with sharing class ValidateQuoteTermVersion {

    public class Request {

        @InvocableVariable(
            label='Formula Text'
            description='Optional Boolean formula to validate against the Quote object. When blank, only body merge fields are validated.'
        )
        public String formulaText;

        @InvocableVariable(
            label='Term Version Body'
            description='The term body whose merge fields should be validated.'
        )
        public String termVersionBody;
    }

    public class Result {

        @InvocableVariable(
            label='Is Valid'
            description='True when the formula compiles and every merge field resolves.'
        )
        public Boolean isValid;

        @InvocableVariable(
            label='Is Formula Valid'
            description='True when the formula compiles as a Boolean against Quote.'
        )
        public Boolean isFormulaValid;

        @InvocableVariable(
            label='Formula Message'
            description='The formula validation result or compilation error.'
        )
        public String formulaMessage;

        @InvocableVariable(
            label='Are Merge Fields Valid'
            description='True when every merge field in the body names a Quote field.'
        )
        public Boolean areMergeFieldsValid;

        @InvocableVariable(
            label='Merge Field Message'
            description='The merge field validation result or the unknown fields found.'
        )
        public String mergeFieldMessage;

        @InvocableVariable(
            label='Merge Fields Found'
            description='The merge fields present in the body, comma separated.'
        )
        public String mergeFieldList;

        @InvocableVariable(
            label='Merge Field Count'
            description='Number of distinct merge fields found in the body.'
        )
        public Integer mergeFieldCount;
    }

    @InvocableMethod(
        label='Validate Quote Term Version'
        description='Validates the Tested Formula and the body merge fields on a Quote Term Version.'
        category='Quote Term Management'
    )
    public static List<Result> validate(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null) {
            return results;
        }

        for (Request request : requests) {
            results.add(validateOne(request));
        }
        return results;
    }

    private static Result validateOne(Request request) {
        Result result = new Result();
        result.isFormulaValid = false;
        result.areMergeFieldsValid = false;
        result.mergeFieldCount = 0;
        result.mergeFieldList = '';

        /*
         * The formula check is a genuine compile against Quote, not a
         * pattern match, so a formula only passes if Salesforce itself
         * accepts it.
         */
        if (String.isBlank(request == null ? null : request.formulaText)) {
            result.isFormulaValid = true;
            result.formulaMessage = 'No formula was supplied; formula validation was skipped.';
        } else try {
            Formula.builder()
                .withType(Quote.SObjectType)
                .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
                .withFormula(request.formulaText)
                .build();

            result.isFormulaValid = true;
            result.formulaMessage =
                'The formula is valid and returns a Boolean value.';

        } catch (Exception e) {
            String errorDetail = e.getMessage();
            if (String.isBlank(errorDetail)) {
                errorDetail = 'Salesforce could not compile the formula.';
            }
            if (errorDetail.length() > 500) {
                errorDetail = errorDetail.substring(0, 500) + '...';
            }
            result.isFormulaValid = false;
            result.formulaMessage = 'The formula is invalid: ' + errorDetail;
        }

        QuoteTermMergeFields.TokenScan scanResult =
            QuoteTermMergeFields.scan(
                new List<String>{ request.termVersionBody }
            );

        result.mergeFieldCount = scanResult.tokens.size();

        List<String> found = new List<String>(scanResult.tokens);
        found.sort();
        result.mergeFieldList = String.join(found, ', ');

        if (scanResult.hasErrors) {
            result.areMergeFieldsValid = false;
            result.mergeFieldMessage = QuoteTermMergeFields.unresolvedReport(
                scanResult.unresolvedTokens
            );
        } else if (scanResult.tokens.isEmpty()) {
            result.areMergeFieldsValid = true;
            result.mergeFieldMessage =
                'The body contains no merge fields.';
        } else {
            result.areMergeFieldsValid = true;
            result.mergeFieldMessage =
                String.valueOf(result.mergeFieldCount) +
                ' merge field(s) validated: ' + result.mergeFieldList;
        }

        result.isValid = result.isFormulaValid && result.areMergeFieldsValid;
        return result;
    }
}