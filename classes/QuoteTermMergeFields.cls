/*
 * Shared merge field handling for the Quote Term library.
 *
 * Nue's template engine resolves the merge fields written into the
 * template definition. It does not re-scan the value it substitutes,
 * so a merge field sitting inside ELV_Quote_Terms__c is printed as
 * literal text. Term bodies are therefore resolved here, before the
 * text is published to the Quote.
 *
 * Used by ResolveQuoteTermMergeFields (the sync), ValidateQuoteTermVersion
 * (the Activate action) and ValidateAllQuoteTermVersionFormulas (the
 * Validate All action) so that one implementation defines what a token
 * is and how it renders.
 */
public with sharing class QuoteTermMergeFields {

    /*
     * A token is {Field__c} or {!Field__c}, optionally a parent path
     * such as {!Opportunity.Account.Name}.
     */
    private static final Pattern TOKEN_PATTERN =
        Pattern.compile('\\{\\s*!?\\s*([A-Za-z0-9_]+(?:\\.[A-Za-z0-9_]+)*)\\s*\\}');

    /*
     * SOQL supports five levels of parent traversal.
     */
    private static final Integer MAX_RELATIONSHIP_DEPTH = 4;

    /*
     * Term bodies written for Nue's template engine qualify the field
     * with the object, as {!quote.ELV_Fixed_Pricing__c}. The prefix is
     * dropped so both that form and the bare {!ELV_Fixed_Pricing__c}
     * resolve to the same Quote field.
     */
    private static final String QUOTE_PREFIX = 'quote.';

    /*
     * These Quote fields are authored through Salesforce's rich text
     * editor. Their HTML is trusted and is intentionally preserved when
     * substituted into the rich-text Quote Terms document.
     */
    private static final Set<String> TRUSTED_RICH_TEXT_QUOTE_FIELDS =
        new Set<String>{
            'elv_additional_terms__c',
            'elv_additional_terms_2__c',
            'elv_additional_terms_3__c',
            'elv_additional_terms_4__c'
        };

    private static Map<String, Schema.DescribeFieldResult> cachedQuoteFields;

    @TestVisible
    private static String normalizePath(String fieldPath) {
        if (String.isBlank(fieldPath)) {
            return fieldPath;
        }
        String trimmed = fieldPath.trim();
        if (trimmed.length() > QUOTE_PREFIX.length() &&
            trimmed.substring(0, QUOTE_PREFIX.length())
                .equalsIgnoreCase(QUOTE_PREFIX)) {
            return trimmed.substring(QUOTE_PREFIX.length());
        }
        return trimmed;
    }

    /*
     * The outcome of parsing and resolving the tokens in one or more bodies.
     */
    public class TokenScan {

        /* Every token found, in the form written in the body. */
        public Set<String> tokens = new Set<String>();

        /* Tokens that resolve to a queryable Quote field path. */
        public Set<String> resolvedTokens = new Set<String>();

        /* Tokens that look like a field but do not resolve. */
        public List<String> unresolvedTokens = new List<String>();

        public Boolean hasErrors {
            get { return !unresolvedTokens.isEmpty(); }
        }
    }

    /*
     * Finds the tokens in a body and reports which of them resolve
     * against the Quote object.
     *
     * Braces around anything that is not plausibly a field are left
     * alone. Legal language contains braces of its own, and treating
     * every one of them as a broken merge field would block terms that
     * are perfectly correct. A token is treated as a merge field when
     * it names a real Quote field, traverses a relationship, or carries
     * a custom field suffix - which is what makes a misspelled
     * {ELV_Fixd_Pricing__c} an error rather than prose.
     */
    public static TokenScan scan(List<String> bodies) {
        TokenScan scanResult = new TokenScan();
        if (bodies == null) {
            return scanResult;
        }

        for (String body : bodies) {
            if (String.isBlank(body)) {
                continue;
            }
            Matcher tokenMatcher = TOKEN_PATTERN.matcher(body);
            while (tokenMatcher.find()) {
                String fieldPath = normalizePath(tokenMatcher.group(1));
                if (!looksLikeFieldPath(fieldPath)) {
                    continue;
                }
                scanResult.tokens.add(fieldPath);
            }
        }

        for (String fieldPath : scanResult.tokens) {
            if (describeFieldPath(fieldPath) == null) {
                scanResult.unresolvedTokens.add(fieldPath);
            } else {
                scanResult.resolvedTokens.add(fieldPath);
            }
        }
        scanResult.unresolvedTokens.sort();

        return scanResult;
    }

    /*
     * A path is treated as a merge field when it is a Quote field, a
     * relationship path, or carries a custom object suffix.
     */
    private static Boolean looksLikeFieldPath(String fieldPath) {
        if (String.isBlank(fieldPath)) {
            return false;
        }
        if (fieldPath.contains('.')) {
            return true;
        }
        if (fieldPath.endsWithIgnoreCase('__c')) {
            return true;
        }
        return quoteFields().containsKey(fieldPath.toLowerCase());
    }

    /*
     * Queries the Quote for every field the tokens name and renders the
     * bodies. Returns the rendered bodies in the order supplied.
     *
     * Values are HTML escaped because the bodies are HTML and print
     * through a rich text element.
     */
    public static List<String> render(
        Id quoteId,
        List<String> bodies,
        TokenScan scanResult
    ) {
        List<String> rendered = new List<String>();
        if (bodies == null) {
            return rendered;
        }
        if (quoteId == null ||
            scanResult == null ||
            scanResult.resolvedTokens.isEmpty()) {
            rendered.addAll(bodies);
            return rendered;
        }

        Quote quoteRecord = queryQuote(quoteId, scanResult.resolvedTokens);
        if (quoteRecord == null) {
            rendered.addAll(bodies);
            return rendered;
        }

        Map<String, String> valuesByToken = new Map<String, String>();
        for (String fieldPath : scanResult.resolvedTokens) {
            valuesByToken.put(
                fieldPath.toLowerCase(),
                formatValue(fieldPath, quoteRecord)
            );
        }

        for (String body : bodies) {
            rendered.add(substitute(body, valuesByToken));
        }
        return rendered;
    }

    /*
     * Replaces each token with its rendered value. A token that was not
     * resolved is left exactly as written, so the failure is visible
     * rather than silently blanked.
     */
    private static String substitute(
        String body,
        Map<String, String> valuesByToken
    ) {
        if (String.isBlank(body)) {
            return body;
        }
        Matcher tokenMatcher = TOKEN_PATTERN.matcher(body);
        List<String> output = new List<String>();
        Integer cursor = 0;

        while (tokenMatcher.find()) {
            String fieldPath = normalizePath(tokenMatcher.group(1));
            String value = valuesByToken.get(fieldPath.toLowerCase());
            if (value == null) {
                continue;
            }
            output.add(body.substring(cursor, tokenMatcher.start()));
            output.add(value);
            cursor = tokenMatcher.end();
        }
        output.add(body.substring(cursor));

        return String.join(output, '');
    }

    /*
     * The Quote, queried with every token path.
     */
    private static Quote queryQuote(Id quoteId, Set<String> fieldPaths) {
        Map<String, String> uniquePaths = new Map<String, String>();
        uniquePaths.put('id', 'Id');
        uniquePaths.put('currencyisocode', 'CurrencyIsoCode');
        for (String fieldPath : fieldPaths) {
            uniquePaths.put(fieldPath.toLowerCase(), fieldPath);
        }

        List<String> selectedFields = new List<String>(uniquePaths.values());
        selectedFields.sort();

        String quoteQuery =
            'SELECT ' + String.join(selectedFields, ', ') +
            ' FROM Quote WHERE Id = :quoteId LIMIT 1';

        List<Quote> quotes = (List<Quote>) Database.query(quoteQuery);
        return quotes.isEmpty() ? null : quotes[0];
    }

    /*
     * Reads a value along a parent path.
     */
    private static Object valueOf(String fieldPath, SObject record) {
        SObject current = record;
        List<String> segments = fieldPath.split('\\.');

        for (Integer i = 0; i < segments.size() - 1; i++) {
            if (current == null) {
                return null;
            }
            current = current.getSObject(segments[i]);
        }
        if (current == null) {
            return null;
        }
        return current.get(segments[segments.size() - 1]);
    }

    /*
     * Renders one value for print.
     *
     * A null reads as blank. Blanking a value is not treated as an
     * error: many terms legitimately reference fields that are empty on
     * a given deal, and failing the sync for those would stop quotes
     * that are entirely correct.
     */
    @TestVisible
    private static String formatValue(String fieldPath, Quote quoteRecord) {
        Schema.DescribeFieldResult fieldDescribe = describeFieldPath(fieldPath);
        Object rawValue = valueOf(fieldPath, quoteRecord);

        if (rawValue == null || fieldDescribe == null) {
            return '';
        }

        Schema.DisplayType fieldType = fieldDescribe.getType();

        if (fieldType == Schema.DisplayType.CURRENCY) {
            return escape(
                currencySymbol(quoteRecord.CurrencyIsoCode) +
                grouped((Decimal) rawValue, 2)
            );
        }
        if (fieldType == Schema.DisplayType.PERCENT) {
            return escape(trimZeros((Decimal) rawValue) + '%');
        }
        if (fieldType == Schema.DisplayType.DOUBLE ||
            fieldType == Schema.DisplayType.INTEGER ||
            fieldType == Schema.DisplayType.LONG) {
            return escape(trimZeros(Decimal.valueOf(String.valueOf(rawValue))));
        }
        if (fieldType == Schema.DisplayType.DATE) {
            return escape(formatDate((Date) rawValue));
        }
        if (fieldType == Schema.DisplayType.DATETIME) {
            return escape(((Datetime) rawValue).format('MM/dd/yyyy'));
        }
        if (fieldType == Schema.DisplayType.BOOLEAN) {
            return ((Boolean) rawValue) ? 'Yes' : 'No';
        }

        if (TRUSTED_RICH_TEXT_QUOTE_FIELDS.contains(fieldPath.toLowerCase())) {
            return String.valueOf(rawValue);
        }

        return escape(String.valueOf(rawValue));
    }

    private static String formatDate(Date value) {
        return String.valueOf(value.month()).leftPad(2, '0') + '/' +
               String.valueOf(value.day()).leftPad(2, '0') + '/' +
               String.valueOf(value.year());
    }

    /*
     * A decimal with thousands separators and a fixed number of places.
     */
    private static String grouped(Decimal value, Integer places) {
        Decimal rounded = value.setScale(places, System.RoundingMode.HALF_UP);
        Boolean isNegative = rounded < 0;
        String digits = String.valueOf(rounded.abs());

        String wholePart = digits.contains('.')
            ? digits.substringBefore('.')
            : digits;
        String decimalPart = digits.contains('.')
            ? digits.substringAfter('.')
            : '';

        String separated = '';
        Integer counter = 0;
        for (Integer i = wholePart.length() - 1; i >= 0; i--) {
            separated = wholePart.substring(i, i + 1) + separated;
            counter++;
            if (Math.mod(counter, 3) == 0 && i > 0) {
                separated = ',' + separated;
            }
        }

        String formatted = separated;
        if (places > 0) {
            formatted += '.' + decimalPart.rightPad(places, '0');
        }
        return (isNegative ? '-' : '') + formatted;
    }

    /*
     * A number without trailing zeros, so a whole number prints as a
     * whole number.
     */
    private static String trimZeros(Decimal value) {
        Decimal normalized = value.setScale(4, System.RoundingMode.HALF_UP);
        if (normalized == normalized.round(System.RoundingMode.HALF_UP)) {
            return grouped(normalized, 0);
        }
        String text = grouped(normalized, 4);
        while (text.endsWith('0')) {
            text = text.substring(0, text.length() - 1);
        }
        if (text.endsWith('.')) {
            text = text.substring(0, text.length() - 1);
        }
        return text;
    }

    /*
     * The currency the Quote is denominated in. Falls back to the ISO
     * code so the amount is never ambiguous.
     */
    private static String currencySymbol(String isoCode) {
        if (String.isBlank(isoCode)) {
            return '';
        }
        Map<String, String> symbols = new Map<String, String>{
            'USD' => '$',
            'EUR' => '\u20AC',
            'GBP' => '\u00A3',
            'JPY' => '\u00A5',
            'AUD' => 'A$',
            'CAD' => 'C$'
        };
        String symbol = symbols.get(isoCode.toUpperCase());
        return symbol == null ? isoCode + ' ' : symbol;
    }

    /*
     * Term bodies are HTML rendered through a rich text element, so a
     * value carrying an ampersand or an angle bracket has to be escaped
     * or it breaks the document.
     */
    private static String escape(String value) {
        return value == null ? '' : value.escapeHtml4();
    }

    /*
     * The describe for a field path from Quote, or null when the path
     * does not resolve.
     */
    public static Schema.DescribeFieldResult describeFieldPath(String fieldPath) {
        if (String.isBlank(fieldPath)) {
            return null;
        }
        fieldPath = normalizePath(fieldPath);
        List<String> segments = fieldPath.split('\\.');
        if (segments.size() > MAX_RELATIONSHIP_DEPTH + 1) {
            return null;
        }

        if (segments.size() == 1) {
            return quoteFields().get(segments[0].toLowerCase());
        }

        SObjectType currentType = Quote.SObjectType;
        for (Integer i = 0; i < segments.size() - 1; i++) {
            SObjectType nextType = parentTypeFor(currentType, segments[i]);
            if (nextType == null) {
                return null;
            }
            currentType = nextType;
        }

        Schema.SObjectField field =
            currentType.getDescribe().fields.getMap()
                .get(segments[segments.size() - 1]);

        return field == null ? null : field.getDescribe();
    }

    /*
     * The single parent an object's relationship name points to.
     * Polymorphic relationships are not traversable by name.
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

    private static Map<String, Schema.DescribeFieldResult> quoteFields() {
        if (cachedQuoteFields == null) {
            cachedQuoteFields = new Map<String, Schema.DescribeFieldResult>();
            for (Schema.SObjectField field :
                 Quote.SObjectType.getDescribe().fields.getMap().values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                cachedQuoteFields.put(
                    fieldDescribe.getName().toLowerCase(),
                    fieldDescribe
                );
            }
        }
        return cachedQuoteFields;
    }

    /*
     * The usable length of a Quote long text field, less a margin for
     * the truncation marker. Read from the describe so a field resize
     * does not require a code or flow change.
     */
    public static Integer quoteFieldLimit(String fieldName) {
        Schema.DescribeFieldResult fieldDescribe =
            quoteFields().get(fieldName.toLowerCase());
        if (fieldDescribe == null) {
            return 0;
        }
        Integer margin = 68;
        Integer usable = fieldDescribe.getLength() - margin;
        return usable < 0 ? 0 : usable;
    }

    /*
     * A readable report of the tokens that did not resolve.
     */
    public static String unresolvedReport(List<String> unresolvedTokens) {
        if (unresolvedTokens == null || unresolvedTokens.isEmpty()) {
            return '';
        }
        List<String> lines = new List<String>();
        for (String fieldPath : unresolvedTokens) {
            lines.add(
                'Unknown merge field {!' + fieldPath + '} - ' +
                'no such field on the Quote object.'
            );
        }
        return String.join(lines, '\n');
    }
}