/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Contact Trigger Handler
 * @Date: 2015-01-12
 * @Author: Cumulus Vision, Tanium Dev Team
 * @Request:
 * Modified  ModifiedDate   Description
 * TAN-444   2017-10-17     Exclude Customer Community External Members Account from domain updates
 * TAN-483   2018-02-22     Updated StageName
 * TAN-903   2020-07-22     Updated Account's Domain__c field only if its current value in blank.
 * TAN-922   2020-08-26     Added logic to trigger IDP auto provisioning from Contact.
 * TAN-926   2020-08-28     Added logic to insert a Opportunity record when specific criteria met.
 * TAN-930   2020-09-12     Added logic to support new HFPOC requirements.
 * TAN-978   2020-10-05     Add Opportunity Contact role when setting admin contact for HFPOC opportunity.
 * TAN-982   2020-10-07     Make Opportunity Contact Role Primary for HFPOC
 * TAN-983   2020-10-08     Set Primary Contact on Opportunity for HFPOC Opp.
 * TAN-1070  2021-01-12     Added Email notification for Failed opportunities to be inserted in After Update.
 * SS-13500  2026-07-27     Remove deprecated fields for project kondo group 2 contact
 */
public class ContactTriggerHandler extends TriggerHandler {
	@TestVisible
	private static ContactTriggerService service = ContactTriggerService.instance;

	@TestVisible
	private List<Contact> newContactList;
	private Map<Id, Contact> newContactMap;
	private Map<Id, Contact> oldContactMap;

	public ContactTriggerHandler() {
		super('ContactTriggerHandler');
		this.newContactList = (List<Contact>) Trigger.new;
		this.newContactMap = (Map<Id, Contact>) Trigger.newMap;
		this.oldContactMap = (Map<Id, Contact>) Trigger.oldMap;
	}

	public override void afterInsert() {
		service.captureDomainContactToAccount(this.newContactList);
	}

	public override void beforeDelete() {
		service.checkDeletePermission(oldContactMap);
	}
}