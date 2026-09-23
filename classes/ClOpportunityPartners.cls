/**
 * @Business: Custom Opportunity Partner Visualforce
 * @Date: 2014-05-25
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description
 * TAN-351   2014-12-16     added partner role
 * TAN-322   2016-10-21     added partner performance field
 * TAN-345   2016-11-29     added controls around partner performance update
 * TAN-623   2016-07-24     Modification related to the PermissionSet "Add_Opportunity_Partner"
 * TAN-900   2020-07-17     Refactored the renderAmount() method and fixed the issues in it.
 */
public class ClOpportunityPartners {
	public List<dtoOppPartner> lstOppPartners { get; set; }
	public String changeIndex { get; set; }
	public Boolean isAccountChange { get; set; }

	public Account acc;
	public String oppId;
	public Decimal accCom;
	private Integer num;
	@TestVisible
	private Boolean hasAddOpportunityPartnerPermission;

	public ClOpportunityPartners(ApexPages.StandardController controller) {
		lstOppPartners = new List<dtoOppPartner>();
		num = 0;
		oppId = ApexPages.currentPage().getParameters().get('oppId');
		String accId = ApexPages.currentPage().getParameters().get('accId');
		Opportunity_Partners__c oppP = (Opportunity_Partners__c) controller.getRecord();
		hasAddOpportunityPartnerPermission = hasUserPermission(
			UserInfo.getUserId(),
			'Add_Opportunity_Partner'
		);

		if (!hasAddOpportunityPartnerPermission) {
			ApexPages.addmessage(
				new ApexPages.message(
					ApexPages.severity.WARNING,
					'You cannot create an Opportunity Partner at this time. Please contact the system administrator for the necessary permissions. Any changes made will not be saved.'
				)
			);
		}

		List<Opportunity_Partners__c> lstoppP = [
			SELECT
				Name,
				Partner_Role__c,
				Expiration_Date__c,
				Collaboration_Agreement__c,
				Partner_Commission__c,
				Opportunity__c,
				Account__c,
				Opportunity__r.Amount,
				Account__r.Commission__c,
				Partner_Contact__c,
				Commission_Amount__c,
				Notes__c,
				Partner_Performance__c
			FROM Opportunity_Partners__c
			WHERE Id = :oppP.Id
			LIMIT 1
		];

		// edit
		if (!lstoppP.isEmpty()) {
			oppP = new Opportunity_Partners__c();
			oppP = lstoppP.get(0);
			oppId = oppP.Opportunity__c;
			accId = oppP.Account__c;
			accCom = oppP.Account__r.Commission__c == null ? 0 : oppP.Account__r.Commission__c;
		} else {
			// new
			oppP = new Opportunity_Partners__c(Opportunity__c = oppId, Partner_Commission__c = 0);
		}

		lstOppPartners.add(new dtoOppPartner(oppP, num + ''));

		if (!lstoppP.isEmpty()) {
			changeIndex = String.valueOf(num);
			renderAmount();
		}
	}

	public void addPartner() {
		lstOppPartners.add(
			new dtoOppPartner(
				new Opportunity_Partners__c(Opportunity__c = oppId, Partner_Commission__c = accCom),
				++num + ''
			)
		);
	}

	public PageReference doSave() {
		List<Opportunity_Partners__c> lstPart = new List<Opportunity_Partners__c>();

		if (!hasAddOpportunityPartnerPermission) {
			ApexPages.addmessage(
				new ApexPages.message(
					ApexPages.severity.ERROR,
					'You are attempting to save/update an opportunity partner and do not have the necessary permissions. Please contact the system administrator'
				)
			);
		} else {
			//do what normally needs to happen
			for (dtoOppPartner d : lstOppPartners) {
				d.oppPartner.Account__r = acc;
				lstPart.add(d.oppPartner);
			}
			Set<String> profile_set = new Set<String>{ 'Tanium Standard User', 'Tanium Inside Sales' };
			List<Profile> p = [SELECT id FROM Profile WHERE name IN :profile_set];
			set<id> profile_id = new Set<id>();
			for (Profile x : p) {
				profile_id.add(x.id);
			}
			boolean hasValidation = false;
			for (Opportunity_Partners__c x : lstPart) {
				if (
					profile_id.contains(userinfo.getProfileId()) &&
					(x.Commission_Amount__c > 0 ||
					x.Partner_Commission__c > 0 ||
					x.Collaboration_Agreement__c == 'Teaming' ||
					x.Collaboration_Agreement__c == 'Registration')
				) {
					ApexPages.addmessage(
						new ApexPages.message(
							ApexPages.severity.Error,
							'You do not have permission to add a partner with commission. You do not have permission to add Deal Reg or Teaming Partners.'
						)
					);
					hasValidation = true;
					return null;
				}
			}
			try {
				if (!hasValidation) {
					upsert lstPart;
				}
			} catch (Exception e) {
				ApexPages.addmessage(
					new ApexPages.message(
						ApexPages.severity.Error,
						'Commission Amount does not match Commission %, please click the calculate button to recalculate'
					)
				);
				return null;
			}
			return new PageReference('/' + oppId);
		}

		return null;
	}

	// calculate total discount
	public void calculateCommission() {
		for (Integer i = 0; i < lstOppPartners.size(); i++) {
			dtoOppPartner cla = lstOppPartners.get(i);
			if (cla.index == changeIndex) {
				for (Opportunity o : [SELECT Amount FROM Opportunity WHERE Id = :oppId]) {
					if (
						o.Amount == null &&
						(cla.oppPartner.Commission_Amount__c == 0 ||
						cla.oppPartner.Commission_Amount__c == null)
					) {
						cla.oppPartner.Partner_Commission__c = 0;
						continue;
					}
					Decimal tmpCommissionAmount = cla.oppPartner.Commission_Amount__c == null
						? 0
						: cla.oppPartner.Commission_Amount__c;
					cla.oppPartner.Partner_Commission__c = tmpCommissionAmount * 100 / o.Amount;
				}
				break;
			}
		}
	}

	public void renderAmount() {
		Set<Id> setAccountId = new Set<Id>();
		Map<Id, Decimal> mapAccountIdToCommission = new Map<Id, Decimal>();
		Opportunity_Partners__c oppPartnerToRender;
		Opportunity opportunity = [SELECT Amount FROM Opportunity WHERE Id = :oppId];

		Integer oppPartnerInfoIndex = String.isNotBlank(changeIndex)
			? Integer.valueOf(changeIndex)
			: null;
		oppPartnerToRender = lstOppPartners[oppPartnerInfoIndex].oppPartner;

		// Compute Partner_Commission__c of "Opportunity Partner"
		if (isAccountChange == true && oppPartnerToRender.Account__c != null) {
			oppPartnerToRender.Partner_Commission__c = fetchAccountComission(
				oppPartnerToRender.Account__c
			);
		}

		Decimal opportunityAmount = opportunity.Amount != null ? opportunity.Amount : 0;
		Decimal partnerCommission = oppPartnerToRender.Partner_Commission__c;
		partnerCommission = partnerCommission != null ? (partnerCommission / 100) : 0;

		// Compute Commission_Amount__c of "Opportunity Partner"
		partnerCommission = (opportunityAmount * partnerCommission);
		partnerCommission = partnerCommission.setscale(0, RoundingMode.HALF_UP);
	}

	private static Decimal fetchAccountComission(Id accountId) {
		Decimal commission = 0;

		List<Account> listAccount = [SELECT Id, Commission__c FROM Account WHERE Id = :accountId];

		if (!listAccount.isEmpty() && listAccount[0].Commission__c != null) {
			commission = listAccount[0].Commission__c;
		}

		return commission;
	}

	private static Boolean hasUserPermission(Id userId, String permissionName) {
		List<PermissionSetAssignment> listPermissionSetAssignment = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE AssigneeId = :userId AND PermissionSet.Name = :permissionName
		];

		return !listPermissionSetAssignment.isEmpty();
	}

	public class dtoOppPartner {
		public Opportunity_Partners__c oppPartner { get; set; }
		public String index { get; set; }

		public dtoOppPartner() {
		}
		public dtoOppPartner(Opportunity_Partners__c oppPartner, String index) {
			this.oppPartner = oppPartner;
			this.index = index;
		}
	}
}