/*
 * Coverage for QuoteTermTemplateSelectionPlugin.
 *
 * Runs with SeeAllData because inserting a Quote in this org invokes
 * Ruby.QuoteTrigger, which fails in test context. The tests take an
 * existing quote, set the two driving fields on it, and let the test
 * rollback undo those writes.
 */
@IsTest(SeeAllData=true)
private class QuoteTermTemplateSelectionPluginTest {

    private static final String LICENSE_SCHEDULE = 'License Schedule';

    /*
     * An existing quote whose Template Selection resolves to a real
     * template, used as the subject of every test.
     */
    private static Quote existingQuote() {
        List<Quote> quotes = [
            SELECT Id, ELV_Template_Selection__c, ELV_License_Schedule__c
            FROM Quote
            WHERE ELV_Template_Selection__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(
            !quotes.isEmpty(),
            'This test requires at least one existing Quote with ' +
            'ELV_Template_Selection__c populated.'
        );
        return quotes[0];
    }

    /*
     * Sets the License Schedule checkbox on the subject quote and
     * returns it re-read, so the formula reflects the change.
     */
    private static Quote withLicenseSchedule(Quote subject, Boolean wanted) {
        update new Quote(Id = subject.Id, ELV_License_Schedule__c = wanted);
        return [
            SELECT Id, ELV_Template_Selection__c, ELV_License_Schedule__c
            FROM Quote
            WHERE Id = :subject.Id
        ];
    }

    private static Ruby.CustomPluginManager.QuoteFormTemplate template(
        String templateName
    ) {
        Ruby.CustomPluginManager.QuoteFormTemplate published =
            new Ruby.CustomPluginManager.QuoteFormTemplate();
        published.name = templateName;
        return published;
    }

    /*
     * The four templates Nue publishes, plus the noise the plugin has to
     * survive: a null entry and one with no name.
     */
    private static List<Ruby.CustomPluginManager.QuoteFormTemplate> allPublished() {
        return new List<Ruby.CustomPluginManager.QuoteFormTemplate>{
            template('Direct'),
            template('Partner'),
            template('Marketplace'),
            template(LICENSE_SCHEDULE),
            template(null),
            null
        };
    }

    private static List<String> namesOf(
        List<Ruby.CustomPluginManager.QuoteFormTemplate> templates
    ) {
        List<String> names = new List<String>();
        for (Ruby.CustomPluginManager.QuoteFormTemplate published : templates) {
            names.add(published.name);
        }
        return names;
    }

    /*
     * Without a schedule, only the primary document is offered.
     */
    @IsTest
    static void offersOnlyTheSelectedTemplate() {
        Quote subject = withLicenseSchedule(existingQuote(), false);

        Test.startTest();
        List<Ruby.CustomPluginManager.QuoteFormTemplate> allowed =
            new QuoteTermTemplateSelectionPlugin().getTemplates(
                String.valueOf(subject.Id),
                allPublished()
            );
        Test.stopTest();

        System.assertEquals(
            1,
            allowed.size(),
            'Only the template named by Template Selection should be offered.'
        );
        System.assertEquals(
            subject.ELV_Template_Selection__c,
            allowed[0].name,
            'The offered template should match Template Selection.'
        );
    }

    /*
     * With the schedule checked, both documents are offered, and the
     * primary one is still the one the selection names.
     */
    @IsTest
    static void offersScheduleAlongsideTheSelectedTemplate() {
        Quote subject = withLicenseSchedule(existingQuote(), true);

        Test.startTest();
        List<Ruby.CustomPluginManager.QuoteFormTemplate> allowed =
            new QuoteTermTemplateSelectionPlugin().getTemplates(
                String.valueOf(subject.Id),
                allPublished()
            );
        Test.stopTest();

        List<String> offered = namesOf(allowed);
        System.assertEquals(
            2,
            offered.size(),
            'A quote calling for a schedule should be offered two ' +
            'templates, not ' + offered
        );
        System.assert(
            offered.contains(subject.ELV_Template_Selection__c),
            'The primary template should still be offered: ' + offered
        );
        System.assert(
            offered.contains(LICENSE_SCHEDULE),
            'License Schedule should be offered: ' + offered
        );
        System.assertEquals(
            subject.ELV_Template_Selection__c,
            offered[0],
            'The primary template should be first: ' + offered
        );
    }

    /*
     * The primary document leads the screen even when Nue publishes
     * License Schedule ahead of it, so the default selection is always
     * the document the quote is generated from.
     */
    @IsTest
    static void putsPrimaryTemplateFirst() {
        Quote subject = withLicenseSchedule(existingQuote(), true);

        List<Ruby.CustomPluginManager.QuoteFormTemplate> published =
            new List<Ruby.CustomPluginManager.QuoteFormTemplate>{
                template(LICENSE_SCHEDULE),
                template(subject.ELV_Template_Selection__c)
            };

        Test.startTest();
        List<Ruby.CustomPluginManager.QuoteFormTemplate> allowed =
            new QuoteTermTemplateSelectionPlugin().getTemplates(
                String.valueOf(subject.Id),
                published
            );
        Test.stopTest();

        System.assertEquals(
            new List<String>{
                subject.ELV_Template_Selection__c,
                LICENSE_SCHEDULE
            },
            namesOf(allowed),
            'The primary template should lead, whatever order Nue ' +
            'published in.'
        );
    }

    /*
     * Case and stray whitespace in a Nue template name must not drop it
     * from the screen.
     */
    @IsTest
    static void matchesRegardlessOfCaseAndWhitespace() {
        Quote subject = withLicenseSchedule(existingQuote(), true);

        List<Ruby.CustomPluginManager.QuoteFormTemplate> published =
            new List<Ruby.CustomPluginManager.QuoteFormTemplate>{
                template('  ' + subject.ELV_Template_Selection__c.toUpperCase() + ' '),
                template('license schedule')
            };

        Test.startTest();
        List<Ruby.CustomPluginManager.QuoteFormTemplate> allowed =
            new QuoteTermTemplateSelectionPlugin().getTemplates(
                String.valueOf(subject.Id),
                published
            );
        Test.stopTest();

        System.assertEquals(
            2,
            allowed.size(),
            'Case and surrounding whitespace should not hide a template.'
        );
    }

    /*
     * A published list holding nothing the quote calls for offers
     * nothing - the plugin never falls back to a default.
     */
    @IsTest
    static void offersNothingWhenNoNameMatches() {
        Quote subject = withLicenseSchedule(existingQuote(), false);

        Test.startTest();
        List<Ruby.CustomPluginManager.QuoteFormTemplate> allowed =
            new QuoteTermTemplateSelectionPlugin().getTemplates(
                String.valueOf(subject.Id),
                new List<Ruby.CustomPluginManager.QuoteFormTemplate>{
                    template('Some Other Template'),
                    template(null),
                    null
                }
            );
        Test.stopTest();

        System.assertNotEquals(null, allowed, 'The plugin should return a list.');
        System.assertEquals(
            0,
            allowed.size(),
            'No template should be offered when none matches the quote.'
        );
    }

    /*
     * Nue passing nothing, or an id that resolves to no quote, must not
     * throw - the generation screen should come up empty instead.
     */
    @IsTest
    static void failsSafelyOnUnusableInput() {
        QuoteTermTemplateSelectionPlugin plugin =
            new QuoteTermTemplateSelectionPlugin();

        Test.startTest();
        List<Ruby.CustomPluginManager.QuoteFormTemplate> noTemplates =
            plugin.getTemplates(
                String.valueOf(existingQuote().Id),
                new List<Ruby.CustomPluginManager.QuoteFormTemplate>()
            );
        List<Ruby.CustomPluginManager.QuoteFormTemplate> nullList =
            plugin.getTemplates(String.valueOf(existingQuote().Id), null);
        List<Ruby.CustomPluginManager.QuoteFormTemplate> blankId =
            plugin.getTemplates('', allPublished());
        List<Ruby.CustomPluginManager.QuoteFormTemplate> notAnId =
            plugin.getTemplates('not-an-id', allPublished());
        List<Ruby.CustomPluginManager.QuoteFormTemplate> wrongObject =
            plugin.getTemplates(
                String.valueOf(UserInfo.getUserId()),
                allPublished()
            );
        Test.stopTest();

        System.assertEquals(0, noTemplates.size(), 'Empty in, empty out.');
        System.assertEquals(0, nullList.size(), 'A null list should not throw.');
        System.assertEquals(0, blankId.size(), 'A blank id should offer nothing.');
        System.assertEquals(0, notAnId.size(), 'A non-id should offer nothing.');
        System.assertEquals(
            0,
            wrongObject.size(),
            'An id from another object should offer nothing.'
        );
    }

    /*
     * The unusable-selection sentence contributes no primary document,
     * while a checked schedule is still offered. The formula cannot
     * currently produce that sentence, so the rule is asserted directly
     * against the shared check the plugin uses.
     */
    @IsTest
    static void unusableSelectionOffersNoPrimaryTemplate() {
        System.assert(
            FindMatchingQuoteTermVersions.isInvalidSelection(
                'Invalid Combination of Customer, Partner, & Marketplace Partner'
            ),
            'The unusable-selection sentence should be recognised.'
        );
        System.assert(
            FindMatchingQuoteTermVersions.isInvalidSelection(null),
            'A blank selection should be treated as unusable.'
        );
        System.assert(
            !FindMatchingQuoteTermVersions.isInvalidSelection('Direct'),
            'A real template name should be usable.'
        );
    }
}