/*
 * Limits the order form templates offered on the "Please select an order
 * form template" screen to the ones the quote actually calls for.
 *
 * Nue publishes every template to every quote. This plugin narrows that
 * list to at most two entries:
 *
 *   - the primary document, named by ELV_Template_Selection__c, which
 *     resolves to Direct, Partner or Marketplace;
 *   - License Schedule, added alongside the primary one whenever
 *     ELV_License_Schedule__c is checked.
 *
 * The user still generates one document at a time; this only removes the
 * options that do not belong to the quote.
 *
 * Template names in Nue match the values above verbatim, so selection is
 * a name match. Anything the quote does not call for is dropped, and a
 * quote that resolves to nothing offers nothing rather than falling back
 * to a default - an empty screen is a visible prompt to fix the quote,
 * where a wrong default would be signed.
 *
 * Registered in Nue system settings as the template selection plugin.
 */
global with sharing class QuoteTermTemplateSelectionPlugin
    implements Ruby.CustomPluginManager.TemplateSelectionPlugin {

    /*
     * The schedule document, offered in addition to the primary one.
     * Shares the constant used by the terms matcher so both features
     * name it identically.
     */
    private static final String LICENSE_SCHEDULE =
        FindMatchingQuoteTermVersions.LICENSE_SCHEDULE;

    /*
     * Returns the templates this quote may be generated from, with the
     * primary document first and License Schedule after it.
     *
     * The screen defaults to whichever option leads, and the primary
     * document is the one the quote is generated from every time, so it
     * leads. Within each group Nue's published order is kept.
     *
     * Never returns null: Nue renders the returned list directly, and a
     * null would surface as an error on the generation screen rather
     * than as an empty picklist.
     */
    global List<Ruby.CustomPluginManager.QuoteFormTemplate> getTemplates(
        String quoteId,
        List<Ruby.CustomPluginManager.QuoteFormTemplate> quoteTemplates
    ) {
        List<Ruby.CustomPluginManager.QuoteFormTemplate> primary =
            new List<Ruby.CustomPluginManager.QuoteFormTemplate>();
        List<Ruby.CustomPluginManager.QuoteFormTemplate> schedule =
            new List<Ruby.CustomPluginManager.QuoteFormTemplate>();

        if (quoteTemplates == null || quoteTemplates.isEmpty()) {
            return primary;
        }

        Set<String> wanted = wantedTemplateNames(quoteId);
        if (wanted.isEmpty()) {
            return primary;
        }

        String scheduleName = LICENSE_SCHEDULE.toLowerCase();

        for (Ruby.CustomPluginManager.QuoteFormTemplate template : quoteTemplates) {
            if (template == null || String.isBlank(template.name)) {
                continue;
            }

            String templateName = template.name.trim().toLowerCase();
            if (!wanted.contains(templateName)) {
                continue;
            }

            if (templateName == scheduleName) {
                schedule.add(template);
            } else {
                primary.add(template);
            }
        }

        primary.addAll(schedule);
        return primary;
    }

    /*
     * The template names this quote calls for, lowercased for matching.
     *
     * Names are compared without case or surrounding whitespace so that
     * how a template is typed into Nue cannot silently remove it from
     * the screen. The four names are distinct words, so nothing can
     * collide.
     */
    private Set<String> wantedTemplateNames(String quoteId) {
        Set<String> wanted = new Set<String>();

        Quote quoteRecord = loadQuote(quoteId);
        if (quoteRecord == null) {
            return wanted;
        }

        /*
         * An unusable Template Selection contributes no primary
         * document. The schedule is independent of it, so it is still
         * offered when the quote calls for one.
         */
        String selection = quoteRecord.ELV_Template_Selection__c;
        if (!FindMatchingQuoteTermVersions.isInvalidSelection(selection)) {
            wanted.add(selection.trim().toLowerCase());
        }

        if (quoteRecord.ELV_License_Schedule__c == true) {
            wanted.add(LICENSE_SCHEDULE.toLowerCase());
        }

        return wanted;
    }

    /*
     * The quote behind the generation screen, or null when it cannot be
     * read.
     *
     * Nue passes the id as a String, so a value that is not an id at all
     * reaches the query as text. That and a deleted or inaccessible
     * quote both mean the same thing here - nothing to offer - so they
     * are handled together rather than thrown, which would replace the
     * template screen with an error.
     */
    private Quote loadQuote(String quoteId) {
        if (String.isBlank(quoteId)) {
            return null;
        }

        Id recordId;
        try {
            recordId = Id.valueOf(quoteId.trim());
        } catch (Exception parseError) {
            return null;
        }

        if (recordId.getSobjectType() != Quote.SObjectType) {
            return null;
        }

        List<Quote> quotes = [
            SELECT Id, ELV_Template_Selection__c, ELV_License_Schedule__c
            FROM Quote
            WHERE Id = :recordId
            LIMIT 1
        ];

        return quotes.isEmpty() ? null : quotes[0];
    }
}