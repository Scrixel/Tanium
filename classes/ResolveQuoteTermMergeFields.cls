/*
 * Resolves the merge fields inside a Quote's term instance bodies.
 *
 * Destination-agnostic: every instance attached to the quote is
 * resolved the same way, whether it publishes to the primary term
 * fields or the License Schedule ones. The flow routes them at publish
 * time from each version's own Template Types.
 *
 * Called twice by Quote Terms - v4 Quote Provision Manager. The first
 * call validates only, before any records are deleted, so a body
 * carrying an unknown merge field stops the run while it is still
 * reversible. The second call renders and stores the resolved text on
 * each instance, and the flow publishes from there.
 *
 * Term_Version_Body__c keeps the raw tokens: it is the audit record of
 * the language, and the field an author edits. Rendered_Body__c holds
 * the resolved text for this quote and is rewritten on every sync.
 */
public with sharing class ResolveQuoteTermMergeFields {

    public class Request {

        @InvocableVariable(
            label='Quote ID'
            description='The Quote whose term instances should be resolved.'
            required=true
        )
        public Id quoteId;

        @InvocableVariable(
            label='Validate Only'
            description='True to check the merge fields without writing the resolved text.'
        )
        public Boolean validateOnly;
    }

    public class Result {

        @InvocableVariable(
            label='Resolved Count'
            description='Number of term instances whose body was resolved.'
        )
        public Integer resolvedCount;

        @InvocableVariable(
            label='Merge Field Count'
            description='Number of distinct merge fields found across the term bodies.'
        )
        public Integer mergeFieldCount;

        @InvocableVariable(
            label='Unresolved Merge Fields'
            description='Merge fields that do not name a field on the Quote object.'
        )
        public List<String> unresolvedMergeFields;

        @InvocableVariable(
            label='Merge Field Errors'
            description='One readable line per unresolved merge field.'
        )
        public String errorText;

        @InvocableVariable(
            label='Has Merge Field Errors'
            description='True when at least one merge field could not be resolved.'
        )
        public Boolean hasMergeFieldErrors;

        @InvocableVariable(
            label='Quote Terms Field Limit'
            description='Usable length of ELV_Quote_Terms__c, read from the field describe.'
        )
        public Integer quoteTermsLimit;

        @InvocableVariable(
            label='Quote Header Terms Field Limit'
            description='Usable length of ELV_Quote_Header_Terms__c, read from the field describe.'
        )
        public Integer quoteHeaderTermsLimit;

        @InvocableVariable(
            label='License Schedule Body Terms Field Limit'
            description='Usable length of ELV_License_Schedule_Body_Terms__c, read from the field describe.'
        )
        public Integer licenseScheduleBodyTermsLimit;

        @InvocableVariable(
            label='License Schedule Header Terms Field Limit'
            description='Usable length of ELV_License_Schedule_Header_Terms__c, read from the field describe.'
        )
        public Integer licenseScheduleHeaderTermsLimit;
    }

    @InvocableMethod(
        label='Resolve Quote Term Merge Fields'
        description='Resolves the merge fields in a Quote\'s term instance bodies and stores the result on Rendered Body.'
        category='Quote Term Management'
    )
    public static List<Result> resolve(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null) {
            return results;
        }

        for (Request request : requests) {
            results.add(resolveOne(request));
        }
        return results;
    }

    private static Result resolveOne(Request request) {
        Result result = new Result();
        result.resolvedCount = 0;
        result.mergeFieldCount = 0;
        result.unresolvedMergeFields = new List<String>();
        result.errorText = '';
        result.hasMergeFieldErrors = false;
        result.quoteTermsLimit =
            QuoteTermMergeFields.quoteFieldLimit('ELV_Quote_Terms__c');
        result.quoteHeaderTermsLimit =
            QuoteTermMergeFields.quoteFieldLimit('ELV_Quote_Header_Terms__c');
        result.licenseScheduleBodyTermsLimit =
            QuoteTermMergeFields.quoteFieldLimit(
                'ELV_License_Schedule_Body_Terms__c'
            );
        result.licenseScheduleHeaderTermsLimit =
            QuoteTermMergeFields.quoteFieldLimit(
                'ELV_License_Schedule_Header_Terms__c'
            );

        if (request == null || request.quoteId == null) {
            return result;
        }

        Boolean validateOnly = request.validateOnly == true;
        Id quoteId = request.quoteId;

        /*
         * Only the instances that will be published are considered.
         * Removed Quote Instance records are excluded, matching the
         * flow's own publish query, so a suppressed term carrying a
         * bad merge field does not block the quote.
         */
        List<ELV_Quote_Term_Version__c> instances = [
            SELECT Id, Name, Term_Version_Body__c, Rendered_Body__c
            FROM ELV_Quote_Term_Version__c
            WHERE Instance_Quote__c = :quoteId
            AND Version_Type__c IN ('Quote Instance', 'Custom Quote Instance')
            ORDER BY Display_Order__c ASC NULLS LAST, Name ASC
        ];

        if (instances.isEmpty()) {
            return result;
        }

        List<String> bodies = new List<String>();
        for (ELV_Quote_Term_Version__c instance : instances) {
            bodies.add(instance.Term_Version_Body__c);
        }

        QuoteTermMergeFields.TokenScan scanResult =
            QuoteTermMergeFields.scan(bodies);

        result.mergeFieldCount = scanResult.tokens.size();

        if (scanResult.hasErrors) {
            result.unresolvedMergeFields = scanResult.unresolvedTokens;
            result.hasMergeFieldErrors = true;
            result.errorText = QuoteTermMergeFields.unresolvedReport(
                scanResult.unresolvedTokens
            );
            return result;
        }

        if (validateOnly) {
            return result;
        }

        List<String> renderedBodies =
            QuoteTermMergeFields.render(quoteId, bodies, scanResult);

        List<ELV_Quote_Term_Version__c> toUpdate =
            new List<ELV_Quote_Term_Version__c>();

        for (Integer i = 0; i < instances.size(); i++) {
            String renderedBody = renderedBodies[i];
            /*
             * Written on every run rather than only on creation. A
             * re-sync after the deal changes has to refresh the values
             * on instances that already exist, which reconciliation by
             * source key does not touch.
             */
            if (instances[i].Rendered_Body__c != renderedBody) {
                instances[i].Rendered_Body__c = renderedBody;
                toUpdate.add(instances[i]);
            }
            result.resolvedCount++;
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        return result;
    }
}