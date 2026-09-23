public with sharing class FindMatchingQuoteTermVersions {

    /*
     * The schedule document's name in Nue, shared with the template
     * selection plugin so both features name it identically.
     */
    public static final String LICENSE_SCHEDULE = 'License Schedule';

    /*
     * The sentence ELV_Template_Selection__c returns when the customer,
     * partner and marketplace partner flags do not describe a document.
     */
    public static final String INVALID_SELECTION =
        'Invalid Combination of Customer, Partner, & Marketplace Partner';

    /*
     * Maximum number of query/evaluate passes.
     *
     * Each pass may discover one or more parent paths that the formula
     * engine needs but that were not queried. The loop ends as soon as a
     * pass discovers nothing new.
     */
    private static final Integer MAX_EVALUATION_PASSES = 6;

    /*
     * SOQL supports five levels of parent traversal. Paths deeper than
     * this are not expanded.
     */
    private static final Integer MAX_RELATIONSHIP_DEPTH = 4;

    /*
     * Cached describe of the Quote object.
     *
     * Collected once per transaction because the base field list is the
     * same for every incoming request.
     */
    private static List<String> cachedBaseQuoteFieldNames;

    /*
     * Input supplied by Flow.
     */
    public class Request {
        @InvocableVariable(
            label='Quote ID'
            description='The Quote record whose fields will be evaluated.'
            required=true
        )
        public Id quoteId;
    }

    /*
     * Output returned to Flow.
     *
     * Each Flow interview receives one Result containing a collection
     * of matching Quote Term Version records, plus any formulas that
     * could not be compiled or evaluated.
     */
    public class Result {
        @InvocableVariable(
            label='Matching Quote Term Versions'
            description='Active Source Quote Term Versions whose template type matches the Quote and whose Tested Formula evaluates to true.'
        )
        public List<ELV_Quote_Term_Version__c> matchingQuoteTermVersions;

        @InvocableVariable(
            label='Formula Errors'
            description='Quote Term Versions whose Tested Formula could not be compiled or evaluated. These did not produce a match.'
        )
        public List<String> formulaErrors;

        @InvocableVariable(
            label='Template Selection'
            description='The value of ELV_Template_Selection__c on the Quote, reported so the caller can name it when it does not resolve.'
        )
        public String templateSelection;

        @InvocableVariable(
            label='Template Selection Unusable'
            description='True when ELV_Template_Selection__c is blank or reports an invalid combination, so no primary document can be determined.'
        )
        public Boolean templateSelectionInvalid;

        @InvocableVariable(
            label='Has Formula Errors'
            description='True when at least one Tested Formula could not be compiled or evaluated.'
        )
        public Boolean hasFormulaErrors;
    }

    /*
     * Makes this method available as an Apex Action in Flow.
     */
    @InvocableMethod(
        label='Find Matching Quote Term Versions'
        description='Returns active Source Quote Term Versions whose template type matches the Quote and whose Tested Formula evaluates to true.'
        category='Quote Term Management'
    )
    public static List<Result> findMatches(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        /*
         * Preserve the order of the incoming Flow requests.
         */
        List<Id> orderedQuoteIds = new List<Id>();
        Set<Id> quoteIds = new Set<Id>();
        for (Request request : requests) {
            Id quoteId = request == null ? null : request.quoteId;
            orderedQuoteIds.add(quoteId);
            if (quoteId != null) {
                quoteIds.add(quoteId);
            }
        }

        /*
         * Create one empty result for every incoming Flow request.
         */
        for (Integer i = 0; i < requests.size(); i++) {
            results.add(newEmptyResult());
        }

        if (quoteIds.isEmpty()) {
            return results;
        }

        /*
         * First query only the Quote template type so that candidate
         * Quote Term Versions can be narrowed before any formula work.
         */
        Map<Id, Quote> initialQuotesById = new Map<Id, Quote>([
            SELECT Id, ELV_Template_Selection__c,
                   ELV_License_Schedule__c
            FROM Quote
            WHERE Id IN :quoteIds
        ]);

        /*
         * Template Selection is reported back before any matching work, so
         * that a quote which resolves to no document still tells the caller
         * why.
         */
        Map<Id, String> selectionByQuoteId = new Map<Id, String>();
        for (Quote quoteRecord : initialQuotesById.values()) {
            selectionByQuoteId.put(
                quoteRecord.Id,
                quoteRecord.ELV_Template_Selection__c
            );
        }
        applyTemplateSelection(results, orderedQuoteIds, selectionByQuoteId);

        /*
         * The template types each Quote calls for.
         *
         * Term versions are tagged with the document names Template
         * Selection resolves to - Direct, Partner and Marketplace - so the
         * selection is what narrows them. License Schedule is independent
         * of the selection and is added whenever the Quote is marked for
         * one, because a schedule can accompany any primary document.
         */
        Map<Id, Set<String>> wantedTypesByQuoteId =
            new Map<Id, Set<String>>();
        Set<String> templateTypes = new Set<String>();

        for (Quote quoteRecord : initialQuotesById.values()) {
            Set<String> wanted = new Set<String>();

            String selection = quoteRecord.ELV_Template_Selection__c;
            if (!isInvalidSelection(selection)) {
                wanted.add(selection.trim());
            }

            if (quoteRecord.ELV_License_Schedule__c == true) {
                wanted.add(LICENSE_SCHEDULE);
            }

            wantedTypesByQuoteId.put(quoteRecord.Id, wanted);
            templateTypes.addAll(wanted);
        }
        if (templateTypes.isEmpty()) {
            return results;
        }

        /*
         * Template eligibility is held in Template_Types__c, a multi-select
         * picklist, so a Quote matches when one of the types it calls for
         * is among the values selected on the Quote Term Version.
         *
         * INCLUDES does not accept a bind variable, so the value list is
         * built inline. Values come from the Quote's own picklist data and
         * are escaped before use.
         *
         * Tested_Formula__c is a Long Text Area, so it cannot be filtered
         * for blank/nonblank values in SOQL. Blank formulas are excluded
         * later in Apex.
         */
        List<String> quotedTemplateTypes = new List<String>();
        for (String templateType : templateTypes) {
            quotedTemplateTypes.add(
                '\'' + String.escapeSingleQuotes(templateType) + '\''
            );
        }

        String candidateQuery =
            'SELECT Id, Name, Active__c, Version_Type__c,' +
            ' Template_Types__c, Tested_Formula__c,' +
            ' Quote_Term__c, Display_Order__c, Term_Title__c,' +
            ' Term_Version_Title__c, Term_Version_Body__c, CPQ_Version__c,' +
            ' ELV_Source_Quote_Term_Version__c, Template_Section__c' +
            ' FROM ELV_Quote_Term_Version__c' +
            ' WHERE Active__c = TRUE' +
            ' AND Version_Type__c = \'Source\'' +
            ' AND Template_Types__c INCLUDES (' +
            String.join(quotedTemplateTypes, ', ') + ')' +
            ' ORDER BY Display_Order__c ASC NULLS LAST, Name ASC';

        List<ELV_Quote_Term_Version__c> candidateVersions =
            (List<ELV_Quote_Term_Version__c>) Database.query(candidateQuery);
        if (candidateVersions.isEmpty()) {
            return results;
        }

        /*
         * Compile each stored formula.
         *
         * A formula that references a Quote formula field is recomputed
         * from base fields at evaluation time rather than read from the
         * queried value, so the fields reported by getReferencedFields()
         * are not sufficient on their own. Every base Quote field is
         * queried instead, which covers any formula field defined solely
         * against the Quote.
         */
        Map<Id, FormulaEval.FormulaInstance> formulasByVersionId =
            new Map<Id, FormulaEval.FormulaInstance>();
        List<String> compileErrors = new List<String>();

        Set<String> referencedQuoteFields = new Set<String>();
        referencedQuoteFields.addAll(baseQuoteFieldNames());

        for (ELV_Quote_Term_Version__c version : candidateVersions) {
            if (String.isBlank(version.Tested_Formula__c)) {
                continue;
            }
            try {
                FormulaEval.FormulaInstance formulaInstance =
                    Formula.builder()
                        .withType(Quote.SObjectType)
                        .withReturnType(
                            FormulaEval.FormulaReturnType.Boolean
                        )
                        .withFormula(version.Tested_Formula__c)
                        .build();

                formulasByVersionId.put(version.Id, formulaInstance);

                /*
                 * Cross-object paths are still added because the engine
                 * can consume those values directly when they are present.
                 *
                 * A referenced field that is itself a formula defined on a
                 * parent record is recomputed during evaluation, so the
                 * parent's own base fields are added as well.
                 */
                for (String referencedField :
                     formulaInstance.getReferencedFields()) {

                    referencedQuoteFields.add(referencedField);
                    referencedQuoteFields.addAll(
                        parentBaseFieldsFor(referencedField)
                    );
                }
            } catch (Exception formulaBuildException) {
                /*
                 * An invalid stored formula is not evaluated and therefore
                 * cannot produce a matching Quote Term Version.
                 *
                 * Other valid Quote Term Version formulas can still run.
                 */
                String message =
                    'Unable to compile Tested Formula on Quote Term Version ' +
                    version.Name +
                    ' (' + version.Id + '): ' +
                    formulaBuildException.getMessage();
                compileErrors.add(message);
                System.debug(LoggingLevel.ERROR, message);
            }
        }

        if (formulasByVersionId.isEmpty()) {
            applyCompileErrors(results, compileErrors);
            return results;
        }

        /*
         * Organize candidate versions per Quote so that only the versions
         * for the template types that Quote calls for are evaluated.
         *
         * Built by walking the candidates in query order, so each Quote's
         * list stays in Display_Order__c. A version selected for both the
         * primary document and License Schedule is added once, because a
         * Quote is matched against the version, not against each of its
         * template types.
         */
        Map<Id, List<ELV_Quote_Term_Version__c>> versionsByQuoteId =
            new Map<Id, List<ELV_Quote_Term_Version__c>>();

        for (Id quoteId : wantedTypesByQuoteId.keySet()) {
            versionsByQuoteId.put(
                quoteId,
                new List<ELV_Quote_Term_Version__c>()
            );
        }

        for (ELV_Quote_Term_Version__c version : candidateVersions) {
            if (!formulasByVersionId.containsKey(version.Id)) {
                continue;
            }

            Set<String> versionTypes = new Set<String>(
                selectedTemplateTypes(version.Template_Types__c)
            );
            if (versionTypes.isEmpty()) {
                continue;
            }

            for (Id quoteId : wantedTypesByQuoteId.keySet()) {
                for (String wantedType : wantedTypesByQuoteId.get(quoteId)) {
                    if (versionTypes.contains(wantedType)) {
                        versionsByQuoteId.get(quoteId).add(version);
                        break;
                    }
                }
            }
        }

        /*
         * Field names are deduplicated on a lowercase key because
         * getReferencedFields() is not case consistent, and a duplicate
         * field in the SELECT clause would fail the entire query.
         */
        Map<String, String> uniqueQuoteFields = new Map<String, String>();
        uniqueQuoteFields.put('id', 'Id');
        uniqueQuoteFields.put(
            'elv_template_selection__c',
            'ELV_Template_Selection__c'
        );
        uniqueQuoteFields.put(
            'elv_license_schedule__c',
            'ELV_License_Schedule__c'
        );
        addFields(uniqueQuoteFields, referencedQuoteFields);

        /*
         * Query the Quote, evaluate, and repeat while evaluation reports a
         * parent path that was not queried.
         *
         * A formula field on a parent record is recomputed from that
         * record's own fields, which can reach further parents that no
         * describe of the Quote reveals. When the engine names such a path,
         * it is expanded to that object's base fields and the pass is run
         * again. Results are rebuilt each pass so nothing is double counted.
         */
        Set<String> expandedPaths = new Set<String>();

        for (Integer pass = 0; pass < MAX_EVALUATION_PASSES; pass++) {

            List<Result> passResults = new List<Result>();
            for (Integer i = 0; i < requests.size(); i++) {
                passResults.add(newEmptyResult());
            }
            applyCompileErrors(passResults, compileErrors);
            applyTemplateSelection(
                passResults,
                orderedQuoteIds,
                selectionByQuoteId
            );

            Map<Id, Quote> completeQuotesById;
            try {
                completeQuotesById = queryQuotes(uniqueQuoteFields, quoteIds);
            } catch (Exception queryException) {
                /*
                 * A field path that cannot be queried, most often a
                 * cross-object reference beyond the supported relationship
                 * depth, fails the whole query. Report it rather than
                 * returning silent non-matches.
                 */
                String message =
                    'Unable to query Quote fields required by the stored ' +
                    'formulas: ' + queryException.getMessage();
                System.debug(LoggingLevel.ERROR, message);
                for (Result result : passResults) {
                    result.formulaErrors.add(message);
                    result.hasFormulaErrors = true;
                }
                return passResults;
            }

            Set<String> missingPaths = new Set<String>();

            /*
             * Evaluate the appropriate Quote Term Version formulas
             * separately for each incoming Quote.
             */
            for (Integer requestIndex = 0;
                 requestIndex < orderedQuoteIds.size();
                 requestIndex++) {

                Id quoteId = orderedQuoteIds[requestIndex];
                if (quoteId == null ||
                    !completeQuotesById.containsKey(quoteId)) {
                    continue;
                }

                Quote quoteRecord = completeQuotesById.get(quoteId);
                List<ELV_Quote_Term_Version__c> applicableVersions =
                    versionsByQuoteId.get(quoteId);
                if (applicableVersions == null || applicableVersions.isEmpty()) {
                    continue;
                }

                for (ELV_Quote_Term_Version__c version :
                     applicableVersions) {

                    FormulaEval.FormulaInstance formulaInstance =
                        formulasByVersionId.get(version.Id);
                    try {
                        Object evaluationResult =
                            formulaInstance.evaluate(quoteRecord);

                        if (evaluationResult != null &&
                            (Boolean) evaluationResult == true) {
                            passResults[requestIndex]
                                .matchingQuoteTermVersions
                                .add(version);
                        }
                    } catch (Exception formulaEvaluationException) {
                        /*
                         * A path named by the engine but absent from the
                         * query is recoverable: widen the query and run
                         * another pass.
                         */
                        String unqueriedPath = unqueriedFieldPath(
                            formulaEvaluationException.getMessage()
                        );
                        if (unqueriedPath != null &&
                            !expandedPaths.contains(
                                unqueriedPath.toLowerCase()
                            )) {
                            missingPaths.add(unqueriedPath);
                            continue;
                        }

                        /*
                         * Anything else cannot be evaluated against this
                         * Quote and does not produce a match. This is
                         * reported because it is not the same outcome as
                         * evaluating to false.
                         */
                        String message =
                            'Unable to evaluate Tested Formula on Quote ' +
                            'Term Version ' + version.Name +
                            ' (' + version.Id + ')' +
                            ' against Quote ' + quoteId + ': ' +
                            formulaEvaluationException.getMessage();
                        passResults[requestIndex].formulaErrors.add(message);
                        passResults[requestIndex].hasFormulaErrors = true;
                        System.debug(LoggingLevel.ERROR, message);
                    }
                }
            }

            if (missingPaths.isEmpty()) {
                return passResults;
            }

            /*
             * Widen the Quote query with the newly named paths. A path that
             * cannot be widened is marked as expanded so the next pass
             * reports it as a genuine evaluation error instead of looping.
             */
            for (String missingPath : missingPaths) {
                expandedPaths.add(missingPath.toLowerCase());
                addFields(
                    uniqueQuoteFields,
                    expandPath(missingPath)
                );
            }
        }

        /*
         * The passes did not converge. Report it rather than returning
         * partial matches that look authoritative.
         */
        for (Result result : results) {
            result.formulaErrors.addAll(compileErrors);
            result.formulaErrors.add(
                'Unable to resolve every field required by the stored ' +
                'formulas within ' + MAX_EVALUATION_PASSES +
                ' passes. Paths expanded: ' +
                String.join(new List<String>(expandedPaths), ', ')
            );
            result.hasFormulaErrors = true;
        }
        return results;
    }

    /*
     * The values selected in a multi-select picklist.
     *
     * Stored as a semicolon delimited string. A blank value selects nothing
     * and therefore matches no Quote.
     */
    private static List<String> selectedTemplateTypes(String packedValue) {
        List<String> selected = new List<String>();
        if (String.isBlank(packedValue)) {
            return selected;
        }
        for (String value : packedValue.split(';')) {
            String trimmed = value.trim();
            if (String.isNotBlank(trimmed)) {
                selected.add(trimmed);
            }
        }
        return selected;
    }

    /*
     * Whether a Template Selection value can name a primary document.
     *
     * Blank and the invalid-combination sentence both mean the quote does
     * not resolve to one, and are treated alike. Compared without case or
     * surrounding whitespace so that how the value arrives cannot change
     * the answer.
     */
    public static Boolean isInvalidSelection(String selection) {
        if (String.isBlank(selection)) {
            return true;
        }
        return selection.trim().equalsIgnoreCase(INVALID_SELECTION);
    }

    /*
     * Records the Quote's Template Selection on every result in the list.
     *
     * Applied to each freshly built result list, including the per-pass
     * lists, so the value survives every return path - a caller needs the
     * reason a quote resolved to nothing just as much as it needs matches.
     */
    private static void applyTemplateSelection(
        List<Result> targets,
        List<Id> orderedQuoteIds,
        Map<Id, String> selectionByQuoteId
    ) {
        for (Integer i = 0; i < targets.size(); i++) {
            Id quoteId = i < orderedQuoteIds.size()
                ? orderedQuoteIds[i]
                : null;
            String selection = quoteId == null
                ? null
                : selectionByQuoteId.get(quoteId);
            targets[i].templateSelection = selection;
            targets[i].templateSelectionInvalid = isInvalidSelection(selection);
        }
    }

    private static Result newEmptyResult() {
        Result result = new Result();
        result.matchingQuoteTermVersions =
            new List<ELV_Quote_Term_Version__c>();
        result.formulaErrors = new List<String>();
        result.hasFormulaErrors = false;
        result.templateSelection = null;
        result.templateSelectionInvalid = true;
        return result;
    }

    /*
     * Compile failures apply to every Quote in this invocation.
     */
    private static void applyCompileErrors(
        List<Result> results,
        List<String> compileErrors
    ) {
        if (compileErrors == null || compileErrors.isEmpty()) {
            return;
        }
        for (Result result : results) {
            result.formulaErrors.addAll(compileErrors);
            result.hasFormulaErrors = true;
        }
    }

    private static void addFields(
        Map<String, String> uniqueQuoteFields,
        Iterable<String> fieldNames
    ) {
        Iterator<String> iterator = fieldNames.iterator();
        while (iterator.hasNext()) {
            String fieldName = iterator.next();
            if (String.isBlank(fieldName)) {
                continue;
            }
            uniqueQuoteFields.put(fieldName.toLowerCase(), fieldName);
        }
    }

    private static Map<Id, Quote> queryQuotes(
        Map<String, String> uniqueQuoteFields,
        Set<Id> quoteIds
    ) {
        List<String> quoteFieldNames =
            new List<String>(uniqueQuoteFields.values());
        quoteFieldNames.sort();

        String quoteQuery =
            'SELECT ' +
            String.join(quoteFieldNames, ', ') +
            ' FROM Quote' +
            ' WHERE Id IN :quoteIds';

        return new Map<Id, Quote>((List<Quote>) Database.query(quoteQuery));
    }

    /*
     * The path named by a "retrieved via SOQL without querying the requested
     * field" error, or null when the message is something else.
     */
    @TestVisible
    private static String unqueriedFieldPath(String message) {
        if (String.isBlank(message)) {
            return null;
        }
        Matcher matcher = Pattern.compile(
            '(?i)without querying the requested field:?\\s*([A-Za-z0-9_.]+)'
        ).matcher(message);
        if (!matcher.find()) {
            return null;
        }
        String path = matcher.group(1);
        return String.isBlank(path) ? null : path.trim();
    }

    /*
     * Fields to add for a path the formula engine asked for.
     *
     * When the path resolves to a parent relationship, every base field on
     * that parent is added, because a formula recomputed on that record can
     * read any of them. Otherwise the path is queried as given.
     */
    private static List<String> expandPath(String path) {
        String relativePath = stripLeadingObjectName(path);
        SObjectType pathType = relationshipTypeFor(relativePath);
        if (pathType == null) {
            /*
             * A path that does not resolve to a queryable parent is left out
             * of the query. Adding it would fail the whole Quote query, and
             * the next pass reports it as an evaluation error instead.
             */
            return new List<String>();
        }
        return baseFieldNames(pathType, relativePath + '.');
    }

    /*
     * Evaluation errors name a path either relative to the Quote
     * ("Opportunity.Account") or qualified with the object
     * ("Quote.Opportunity"). Only the relative form is queryable.
     */
    private static String stripLeadingObjectName(String path) {
        String prefix = String.valueOf(Quote.SObjectType) + '.';
        if (path != null && path.length() > prefix.length() &&
            path.substringBefore('.').equalsIgnoreCase(
                String.valueOf(Quote.SObjectType)
            )) {
            return path.substringAfter('.');
        }
        return path;
    }

    /*
     * For a field path, the base fields of every parent record along it.
     *
     * A formula field on a parent is recomputed from that parent's own
     * fields during evaluation, so the queried value alone is not enough.
     */
    private static List<String> parentBaseFieldsFor(String fieldPath) {
        List<String> fieldNames = new List<String>();
        if (String.isBlank(fieldPath) || !fieldPath.contains('.')) {
            return fieldNames;
        }

        List<String> segments = fieldPath.split('\\.');
        List<String> walked = new List<String>();

        /*
         * The final segment is the field itself, not a relationship.
         */
        for (Integer i = 0; i < segments.size() - 1; i++) {
            walked.add(segments[i]);
            String parentPath = String.join(walked, '.');
            SObjectType parentType = relationshipTypeFor(parentPath);
            if (parentType == null) {
                break;
            }
            fieldNames.addAll(baseFieldNames(parentType, parentPath + '.'));
        }
        return fieldNames;
    }

    /*
     * The SObjectType a relationship path from Quote points to, or null when
     * the path is not a traversable parent relationship.
     */
    private static SObjectType relationshipTypeFor(String path) {
        if (String.isBlank(path)) {
            return null;
        }
        List<String> segments = path.split('\\.');
        if (segments.size() > MAX_RELATIONSHIP_DEPTH) {
            return null;
        }

        SObjectType currentType = Quote.SObjectType;
        for (String segment : segments) {
            SObjectType nextType = parentTypeFor(currentType, segment);
            if (nextType == null) {
                return null;
            }
            currentType = nextType;
        }
        return currentType;
    }

    /*
     * The single parent type a relationship name on an object points to.
     *
     * Polymorphic relationships are skipped because their fields cannot be
     * queried through the relationship name.
     */
    private static SObjectType parentTypeFor(
        SObjectType objectType,
        String relationshipName
    ) {
        for (Schema.SObjectField field :
             objectType.getDescribe().fields.getMap().values()) {

            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            String name = fieldDescribe.getRelationshipName();
            if (String.isBlank(name) ||
                !name.equalsIgnoreCase(relationshipName)) {
                continue;
            }
            List<SObjectType> referenceTo = fieldDescribe.getReferenceTo();
            if (referenceTo == null || referenceTo.size() != 1) {
                return null;
            }
            return referenceTo[0];
        }
        return null;
    }

    /*
     * Every accessible base field on the Quote.
     *
     * Parent fields are no longer enumerated up front. They are added from
     * the compiled formulas and from any path the formula engine names
     * during evaluation, which keeps the Quote query to the parents the
     * stored formulas actually reach.
     */
    private static List<String> baseQuoteFieldNames() {
        if (cachedBaseQuoteFieldNames == null) {
            cachedBaseQuoteFieldNames = baseFieldNames(Quote.SObjectType, '');
        }
        return cachedBaseQuoteFieldNames;
    }

    /*
     * Accessible fields that store a value, optionally prefixed with a
     * relationship path.
     *
     * Formula fields are omitted because the formula engine recomputes them
     * from these base fields during evaluation and ignores any queried value.
     * Roll-up summary fields are retained because they store a real value.
     */
    private static List<String> baseFieldNames(
        SObjectType objectType,
        String prefix
    ) {
        List<String> fieldNames = new List<String>();
        for (Schema.SObjectField field :
             objectType.getDescribe().fields.getMap().values()) {

            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

            if (!fieldDescribe.isAccessible()) {
                continue;
            }
            if (String.isNotBlank(fieldDescribe.getCalculatedFormula())) {
                continue;
            }
            fieldNames.add(prefix + fieldDescribe.getName());
        }
        return fieldNames;
    }

}