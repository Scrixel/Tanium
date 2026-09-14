public with sharing class RoscoTanVuln {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** addSubscriber - used by lightning component to readahead
	 * @param search - read ahead value
	 * @return List
	 */
	@AuraEnabled
	public static List<Map<String, String>> addSubscriberEmail(String email) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String soql =
				'SELECT Id ' +
				'FROM User ' +
				'WHERE Email = \'' +
				email +
				'\' ' +
				'AND IsActive = true ' +
				'LIMIT 1';

			System.debug('soql:' + soql);
			List<User> users = Database.query(soql);

			if (!users.isEmpty()) {
				subscribeUser('Tanium Vulnerability', users[0].Id);
			}

			ret = getSubscribers();
		} catch (DmlException e) {
			System.debug('addSubscriberEmail:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** exportCmtyMembers
	 */
	@AuraEnabled
	public static String exportCommunityMembers() {
		String ret = 'Username,Email,Profile,Account,LastLoginDate\n';

		try {
			/*
            Map<String,String> profiles = new Map<String,String>();
            String soql = 'SELECT Id, Name FROM Profile';
            System.debug('SOQL: ' + soql);
            List<Profile> profilesRs = Database.query(soql);
            if (profilesRs.size() != 0){
                for(Profile p: profilesRs){
                    profiles.put(p.Id, p.Name);
                }
            }
            */

			String soql =
				'SELECT Username, ' +
				'Email, ' +
				'Profile.Name, ' +
				'Contact.Account.Name, ' +
				'LastLoginDate ' +
				'FROM User ' +
				'WHERE Profile.Name LIKE \'Tanium Community%\' ' +
				'AND isActive = true';

			System.debug('SOQL: ' + soql);

			List<User> usersRs = Database.query(soql);
			if (usersRs.size() != 0) {
				for (User u : usersRs) {
					if (
						!nullOrEmpty(u.UserName) &&
						!nullOrEmpty(u.Email) &&
						!nullOrEmpty(u.Profile.Name) &&
						!nullOrEmpty(u.Contact.Account.Name) &&
						!nullOrEmpty(u.LastLoginDate)
					) {
						ret +=
							u.UserName +
							',' +
							u.Email +
							',' +
							u.Profile.Name +
							',' +
							String.valueOf(u.Contact.Account.Name).replace(',', ' ') +
							',' +
							u.LastLoginDate +
							'\n';
					}
				}
			}
		} catch (DmlException e) {
			System.debug('exportCommunityMembers:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	private static Map<String, String> getEmailDefaultText() {
		Map<String, String> ret = new Map<String, String>();

		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			// Get Cmty URL
			String cmtyURL = 'https://support.tanium.com/s';
			if (!nullOrEmpty(cm.get('Customer_Community_URL__c'))) {
				cmtyURL = String.valueOf(cm.get('Customer_Community_URL__c'));
			}
			System.debug('cmtyURL:' + cmtyURL);

			List<String> months = new List<String>{
				'January',
				'February',
				'March',
				'April',
				'May',
				'June',
				'July',
				'August',
				'September',
				'October',
				'November',
				'December'
			};
			datetime rn = datetime.now();
			String month = months[rn.month() - 1];
			String day = String.valueOf(rn.day());
			String year = String.valueOf(rn.year());

			String emailSubject =
				'Tanium Vulnerability notification for ' +
				String.valueOf(rn.month()) +
				'/' +
				String.valueOf(rn.day()) +
				'/' +
				String.valueOf(rn.year());
			ret.put('emailSubjectHTML', emailSubject);
			ret.put('emailSubjectTXT', emailSubject);

			/*
            String emailTextPreFixHTML = '<p><img src="data:image/png;base64,' + 
                getBannerBase64() + 
                ' alt="Red dot" /></p>' +
                '<p>Dear John Doe,</p>';
            */

			// Header
			String emailHeader =
				'<div style="text-align:center;background-color:black;color:white;font-size:large;font-weight:bold;">' +
				'<p>Tanium Support Notification</p>' +
				'</div>';

			/*
            if ( !nullOrEmpty( cm.get( 'rosco_tanium_vulnerabilty_banner__c' ))){
                emailBanner = '<p><div style="background-color:black"><center><img height="50%" src=\"' +
                String.valueOf( cm.get( 'rosco_tanium_vulnerabilty_banner__c' )) +
                '\"alt=\"Tanium Support Notificaiton\"></center></div></p>'; 
            }
            */
			System.debug('emailHeader:' + emailHeader);
			ret.put('emailHeader', emailHeader);

			ret.put('emailTextPreFixHTML', '<p>Dear John Doe,');
			ret.put('emailTextPreFixTXT', 'Dear John Doe,\n');

			List<Map<String, String>> recentArticles = getRecentTanVulnArticles();

			String emailTextHTML =
				'<p>On ' +
				month +
				' ' +
				day +
				', ' +
				year +
				', the Tanium Product Security team announced the following update(s).  For additional ' +
				' information, questions or comments please visit the Tanium Support Portal at ' +
				cmtyURL +
				'tanium-vulnerabilities<br>';
			/*for(Map<String,String> article: recentArticles){
                emailTextHTML += '<br><a href=\"' + cmtyURL + 'article/' + article.get('UrlName') + '\">' + article.get('Title') + '</a>';
            }*/
			emailTextHTML += '</p>';
			ret.put('emailTextHTML', emailTextHTML);

			String emailTextTXT =
				'On ' +
				month +
				' ' +
				day +
				', ' +
				year +
				', the Tanium Product Security team announced the following update(s).  For additional ' +
				' information, questions or comments please visit the Tanium Support Portal at ' +
				cmtyURL +
				'\n\n';
			/*for(Map<String,String> article: recentArticles){
                emailTextTXT += '\n' + cmtyURL + 'article/' + article.get('UrlName');
            } */
			ret.put('emailTextTXT', emailTextTXT);

			String emailTextPostFixHTML = '<p>Regards,' + '<br>Tanium Support</p>';
			ret.put('emailTextPostFixHTML', emailTextPostFixHTML);
			String emailTextPostFixTXT =
				'\nRegards,\n' +
				'\nTanium<\n' +
				'\n\n ' +
				'\nTo unsubscribe please login to ' +
				cmtyURL;
			ret.put('emailTextPostFixTXT', emailTextPostFixTXT);

			String emailFooter =
				'<div style="height:30px;text-align:center;background-color:black;color:white;">' +
				'<p style="margin-bottom:5px;margin-top:5px">Please <a style="color:white" href=\"' +
				cmtyURL +
				'cfg?voo=003REPLACE\"><u>click here to unsubscribe</u></a> ' +
				'from future Tanium Vulnerability notifications</p>' +
				'</div>';
			ret.put('emailFooter', emailFooter);

			ret.put('userEmail', UserInfo.getUserEmail());
			ret.put('userAuthorized', 'true');
		} catch (DmlException e) {
			System.debug('getEmailDefaultText:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getHelpArticle
	 */
	private static Map<String, String> getHelpArticle() {
		Map<String, String> ret = new Map<String, String>();

		try {
			String kbUrl = 'tan-vuln-help';
			String soql =
				'SELECT Id' +
				',Title' +
				',Summary ' +
				',Article_Body__c' +
				',FirstPublishedDate' +
				',LastPublishedDate ' +
				',RecordType.Name ' +
				',UrlName ' +
				'FROM Knowledge__kav ' +
				'WHERE UrlName = \'' +
				kbUrl +
				'\' ' +
				'AND PublishStatus = \'Online\' ' +
				'UPDATE VIEWSTAT';

			System.debug('soql:' + soql);

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					ret.put('helpTitle', kb.Title);
					ret.put('helpSummary', kb.Summary);
					ret.put('helpBody', kb.Article_Body__c);
				}
			}
		} catch (DmlException e) {
			System.debug('getHelpArticle:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static Map<String, String> getInit() {
		Map<String, String> ret = new Map<String, String>();

		try {
			if (isAuthorizedUser()) {
				ret = getEmailDefaultText();
			} else {
				ret.put('userAuthorized', 'false');
			}

			ret.putAll(getHelpArticle());

			ret.put('networkId', getNetworkId('Tanium Customer Community'));

			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			// Get Cmty URL
			String cmtyURL = 'https://support.tanium.com/s';
			if (!nullOrEmpty(cm.get('Customer_Community_URL__c'))) {
				cmtyURL = String.valueOf(cm.get('Customer_Community_URL__c'));
			}
			System.debug('cmtyURL:' + cmtyURL);
			ret.put('cmtyURL', cmtyURL);

			String sfdchost = 'tanium--build.lightning.force.com';
			if (!nullOrEmpty(cm.get('rosco_sfdc_dom_c__c'))) {
				sfdchost = String.valueOf(cm.get('rosco_sfdc_dom_c__c'));
			}
			System.debug('sfdchost:' + sfdchost);
			ret.put('sfdchost', sfdchost);

			String reportId = '00O5C000000qYd2UAE';
			if (!nullOrEmpty(cm.get('rosco_tan_vuln_report_id__c'))) {
				reportId = String.valueOf(cm.get('rosco_tan_vuln_report_id__c'));
			}
			System.debug('reportId:' + reportId);
			ret.put('reportId', reportId);			

			ret.put('zdcsv', getZendeskCSVLink());
		} catch (DmlException e) {
			System.debug('getInit:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getNetworkId
	 */
	private static String getNetworkId(String netName) {
		String ret = '';

		try {
			String soql =
				'SELECT Id ' +
				'FROM Network ' +
				'WHERE Name = \'' +
				netName +
				'\' ' +
				'LIMIT 1';

			System.debug('soql:' + soql);

			List<Network> networks = Database.query(soql);
			if (!networks.isEmpty()) {
				for (Network n : networks) {
					ret = String.valueOf(n.Id).left(15);
				}
			}
		} catch (DmlException e) {
			System.debug('getNetworkId:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getRecentTanVulnArticles
	 * @param search - read ahead value
	 * @return List
	 */
	@AuraEnabled
	public static List<Map<String, String>> getRecentTanVulnArticles() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String soql =
				'SELECT  ' +
				'Title, ' +
				'UrlName, ' +
				'Summary ' +
				'FROM Knowledge__kav  ' +
				'WHERE RecordType.Name = \'Tanium Vulnerability\' ' +
				'AND PublishStatus = \'Online\' ' +
				'AND IsVisibleInCsp = true ' +
				'ORDER BY FirstPublishedDate DESC ' +
				'LIMIT 10';

			System.debug('SOQL: ' + soql);
			List<Knowledge__kav> articles = Database.query(soql);
			if (articles.size() > 0) {
				for (Knowledge__kav a : articles) {
					Map<String, String> tmpmap = new Map<String, String>();
					tmpmap.put('Title', a.Title);
					tmpmap.put('UrlName', a.UrlName);
					tmpmap.put('Summary', a.Summary);
					ret.add(tmpmap);
				}
			}
		} catch (DmlException e) {
			System.debug('getRecentTanVulnArticles:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSplashPageContent
	 * @param search - read ahead value
	 * @return List
	 */
	@AuraEnabled
	public static String getSplashPageContent() {
		String ret = '';

		try {
			String soql =
				'SELECT  ' +
				'body__c ' +
				'FROM Rosco_CmtyContent__c  ' +
				'WHERE name = \'splashTaniumVuln\' ' +
				'AND Status__c = \'Online\' ' +
				'LIMIT 1';

			System.debug('SOQL: ' + soql);
			List<Rosco_CmtyContent__c> pages = Database.query(soql);
			if (pages.size() > 0) {
				for (Rosco_CmtyContent__c p : pages) {
					ret = p.body__c;
				}
			}
		} catch (DmlException e) {
			System.debug('getSplashPageContent:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSubscriber
	 * @return List
	 */
	@AuraEnabled
	public static Map<String, String> getSubscriber(String email) {
		Map<String, String> ret = new Map<String, String>();

		try {
			//Map<String,String> usersLastOpen = getUsersLastOpen();

			String soql =
				'SELECT  ' +
				'User__r.Contact.Id, ' +
				'User__r.Contact.Name, ' +
				'User__r.Contact.Email, ' +
				'User__r.Contact.Account.Name, ' +
				'User__r.Contact.IsEmailBounced, ' +
				'User__r.Name, ' +
				'User__r.Email, ' +
				'LastModifiedDate ' +
				'FROM Rosco_Subscription__c ' +
				'WHERE Type__c = \'Tanium Vulnerability\' ' +
				'AND Subscribed__c = true ' +
				'AND User__r.Email = \'' + email + '\'';

			System.debug('SOQL: ' + soql);
			List<Rosco_Subscription__c> subscribers = Database.query(soql);
			if (subscribers.size() > 0) {
				for (Rosco_Subscription__c s : subscribers) {

					if (!nullOrEmpty(s.User__r.ContactId)) {

						if (s.User__r.Contact.IsEmailBounced == true) {
							ret.put('Name', s.User__r.Contact.Name + ' (bounced)');
						} else {
							ret.put('Name', s.User__r.Contact.Name);
						}

						ret.put('Id', s.User__r.ContactId);
						ret.put('Email', email);
						ret.put('Account', s.User__r.Contact.Account.Name);
						ret.put('LastModifiedDate', String.valueOf(s.LastModifiedDate));

					} else {
						ret.put('Id', '0');
						ret.put('Name', s.User__r.Name);
						ret.put('Email', email);
						ret.put('Account', '(No Contact Mapping)');
						ret.put('LastModifiedDate', String.valueOf(s.LastModifiedDate));
					}
				}
			}
		} catch (DmlException e) {
			System.debug('getSubscriber:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSubscribers - used by lightning component to readahead
	 * @param search - read ahead value
	 * @return List
	 */
	@AuraEnabled
	public static List<Map<String, String>> getSubscribers() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			//Map<String,String> usersLastOpen = getUsersLastOpen();

			String soql =
				'SELECT  ' +
				'User__r.Contact.Id, ' +
				'User__r.Contact.Name, ' +
				'User__r.Contact.Email, ' +
				'User__r.Contact.Account.Name, ' +
				'User__r.Contact.IsEmailBounced, ' +
				'User__r.Name, ' +
				'User__r.Email, ' +
				'LastModifiedDate ' +
				'FROM Rosco_Subscription__c ' +
				'WHERE Type__c = \'Tanium Vulnerability\' ' +
				'AND Subscribed__c = true';

			System.debug('SOQL: ' + soql);
			List<Rosco_Subscription__c> subscribers = Database.query(soql);
			if (subscribers.size() > 0) {
				for (Rosco_Subscription__c s : subscribers) {
					/*  
                        |s|{"User__c":"0053S000000bOLmQAM","Id":"a0A3S000000RkUAUA0","User__r":{"Id":"0053S000000bOLmQAM","ContactId":"0033S000004HoluQAC","Contact":{"Id":"0033S000004HoluQAC","Name":"Tanium Fed User A","AccountId":"0013S000005EjPpQAK"}}}|0x3a584ab1                    
                    */
					System.debug(s);

					Map<String, String> tmpmap = new Map<String, String>();

					if (!nullOrEmpty(s.User__r.ContactId)) {
						String email = String.valueOf(s.User__r.Contact.Email);
						email = email.toLowerCase();

						/*
                        if(usersLastOpen.containsKey(email)){
                            tmpmap.put('lastOpen', usersLastOpen.get(email));
                        } else {
                            tmpmap.put('lastOpen', 'never or >180 days');
                        }
                        */
						tmpmap.put('Id', s.User__r.ContactId);

						if (s.User__r.Contact.IsEmailBounced == true) {
							tmpmap.put('Name', s.User__r.Contact.Name + ' (bounced)');
						} else {
							tmpmap.put('Name', s.User__r.Contact.Name);
						}

						tmpmap.put('Email', email);
						tmpmap.put('Account', s.User__r.Contact.Account.Name);
						tmpmap.put('LastModifiedDate', String.valueOf(s.LastModifiedDate));

						ret.add(tmpmap);
					} else {
						if (!nullOrEmpty(s.User__r.Email)) {
							String email = String.valueOf(s.User__r.Email);
							email = email.toLowerCase();

							/*
                            if(usersLastOpen.containsKey(email)){
                                tmpmap.put('lastOpen', usersLastOpen.get(email));
                            } else {
                                tmpmap.put('lastOpen', 'never or >180 days');
                            }*/

							tmpmap.put('Id', '0');
							tmpmap.put('Name', s.User__r.Name);
							tmpmap.put('Email', email);
							tmpmap.put('Account', '(No Contact Mapping)');
							tmpmap.put('LastModifiedDate', String.valueOf(s.LastModifiedDate));

							ret.add(tmpmap);
						}
					}
				}
			}
		} catch (DmlException e) {
			System.debug('getSubscribers:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSubscriberLookup2 - used by lightning component to readahead
	 * @param search - read ahead value
	 * @return
	 */
	@AuraEnabled
	public static List<Map<String, String>> getSubscriberLookup2(String searchKeyWord) {
		// Search Keyword
		searchKeyWord = String.valueOf(searchKeyWord).trim();

		String searchKey = '%' + searchKeyWord + '%';

		List<Map<String, String>> returnList = new List<Map<String, String>>();

		String soql;
		soql =
			'SELECT Id, Contact.Id,Contact.Name,Contact.Email,Contact.Account.Name ' +
			'FROM User ' +
			'WHERE (Contact.Name LIKE \'' +
			searchKey +
			'\' ' +
			'OR Contact.Email LIKE \'' +
			searchKey +
			'\') ' +
			'AND isActive=True ' +
			'AND Id NOT IN (SELECT User__c FROM Rosco_Subscription__c WHERE Type__c = \'Tanium Vulnerability\' AND Subscribed__c = true)' +
			'ORDER BY Name DESC LIMIT 10';

		System.debug('soql:' + soql);
		List<User> users = Database.query(soql);
		System.debug('users:' + users);
		if (!users.isEmpty()) {
			for (User u : users) {
				System.debug('u:' + u);

				Map<String, String> people = new Map<String, String>();
				String uid = String.valueOf(u.Id);
				String cid = String.valueOf(u.Contact.Id);
				String name = String.valueOf(u.Contact.Name);
				String email = String.valueOf(u.Contact.Email);
				String account = String.valueOf(u.Contact.Account.Name);

				System.debug('uid:' + uid);
				System.debug('cid:' + cid);
				System.debug('name:' + name);
				System.debug('email:' + email);
				System.debug('account:' + account);

				people.put('userId', uid);
				people.put('Id', cid);
				people.put('Name', name);
				people.put('Email', email);
				people.put('Account', account);

				people.put('iscontact', 'true');

				if (email.contains('@tanium.com')) {
					people.put('istanium', 'true');
				}

				if (email.contains('@')) {
					returnList.add(people);
				}
			}
		}

		// is the searchKeyWord a valid email and already in returnList?
		if (!String.valueOf(returnList).contains(searchKeyWord)) {
			// Prompt to create
			if (searchKeyWord.contains('@')) {
				Map<String, String> people = new Map<String, String>();
				people.put('Id', '-1');
				people.put('Name', 'tbd');
				people.put('Email', searchKeyWord);
				people.put('Account', 'tbd');
				returnList.add(people);
			}
		}

		// Lets sort list by name

		returnList = RoscoUtility.sortListMapName(returnList);
		return returnList;
	}

	/** getUsersLastOpen
	 * @return List
	 */
	@AuraEnabled
	public static Map<String, String> getUsersLastOpen() {
		Map<String, String> ret = new Map<String, String>();

		try {
			String soql =
				'SELECT ToAddress, LastOpenedDate ' +
				'FROM EmailMessage ' +
				'WHERE Subject LIKE \'Tanium Vulnerability notification for%\' ' +
				'AND LastOpenedDate != null ' +
				'AND LastOpenedDate = LAST_N_DAYS:180 ';

			System.debug('soql:' + soql);
			List<EmailMessage> msgs = Database.query(soql);

			if (!msgs.isEmpty()) {
				for (EmailMessage m : msgs) {
					String toAddress = m.ToAddress;
					toAddress.toLowerCase();
					if (!ret.ContainsKey(toAddress)) {
						ret.put(toAddress, String.valueOf(m.LastOpenedDate));
					}
				}
			}
		} catch (DmlException e) {
			System.debug('getUsersLastOpen:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	private static String getZendeskCSVLink() {
		String ret = '';

		try {
			String cvId = '';

			String soql =
				'SELECT Id ' +
				'FROM ContentVersion ' +
				'WHERE Title = \'rosco_zendesk_migration_csv\' ' +
				'AND IsLatest = true';

			System.debug('soql:' + soql);
			List<ContentVersion> cvs = Database.query(soql);

			if (!cvs.isEmpty()) {
				String sUrl = String.valueOf(URL.getSalesforceBaseUrl().toExternalForm());
				List<String> lUrl = sUrl.split('[.]');

				ret =
					lUrl[0] +
					'--c.documentforce.com/sfc' +
					'/servlet.shepherd/version/download/' +
					cvs[0].Id;
			}

			//'https://tanium--build--c.documentforce.com/sfc/servlet.shepherd/version/download/0686t000000L2Vh?asPdf=false&operationContext=CHATTER';
		} catch (DmlException e) {
			System.debug('getZendeskCSVLink:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getZendeskMigrationCsv
	 */
	/*
    @AuraEnabled     
    public static String getZendeskMigrationCsv2() { 
        
        String csv = 'email,lastZendeskLogin,contactId,accountId,accountName,userId,userProfile,subscribed\n';
        ContentVersion cv = [Select VersionData FROM ContentVersion WHERE ContentDocumentId='0693S00000094SbQAI'];
        blob tempBlob = cv.VersionData;
        
        String tempString = tempBlob.toString();
        tempString = tempSTring.replace('"', '');
        RoscoRowIterator titer = new RoscoRowIterator(tempString, '\n');
        
        Map<String,Object> sfContacts = new Map<String,Object>();
        Map<String,String> obj = new Map<String,String>();
        obj.put('Account', 'Account1');
        obj.put('Profile', 'Profile1');
        obj.put('Subscribed', 'Yes');
        sfContacts.put('99@outlook.com', obj);
        
        String trow;
        do {
            if (titer.hasNext())
                trow = titer.next();
            
            String[] arow = trow.split(',');
            String email = arow[0];
            String lastZendeskLogin = arow[1];
            if(sfContacts.containsKey(email)){
                csv += email + ',' + lastZendeskLogin + ',yes,accountId,accountName,userId,userProfile,subscribed\n';
            } else {
                csv += email + ',' + lastZendeskLogin + ',no,accountId,accountName,userId,userProfile,subscribed\n';                
            }
        
        } while (titer.hasNext());

        return csv;
    }
    */
	/** isAuthorizedUser
	 */
	private static Boolean isAuthorizedUser() {
		Boolean ret = false;

		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			// Get Cmty URL
			String authorizedUsers = '';
			if (!nullOrEmpty(cm.get('rosco_tanium_vulnerabilty_tool_auth__c'))) {
				authorizedUsers = String.valueOf(cm.get('rosco_tanium_vulnerabilty_tool_auth__c'));
			}

			System.debug('authorizedUsers:' + authorizedUsers);

			String currentUserEmail = UserInfo.getUserEmail();
			if (authorizedUsers.containsIgnoreCase(currentUserEmail)) {
				ret = true;
			}
		} catch (DmlException e) {
			System.debug('addSubscriberEmail:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}


	/** isNewEmail
	 * @param search - read ahead value
	 * @return List
	 */
	public static Boolean isNewEmail(String email, String subject) {
		Boolean ret = true;

		try {
			String soql =
				'SELECT  ' +
				'Id ' +
				'FROM EmailMessage  ' +
				'WHERE ToAddress = \'' + email + '\' ' +
				'AND Subject = \'' + subject + '\' ' +
				'LIMIT 1';

			System.debug('SOQL: ' + soql);
			List<EmailMessage> emails = Database.query(soql);
			if (emails.size() > 0) {
				ret = false;
			}
		} catch (DmlException e) {
			System.debug('isNewEmail:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** isSubscribed
	 */
	public static String isSubscribed(String subscriptionType, Id userId) {
		String ret = 'false';

		try {
			String soql =
				'SELECT Subscribed__c ' +
				'FROM Rosco_Subscription__c ' +
				'WHERE User__c = \'' +
				userId +
				'\' ' +
				'AND Type__c = \'' +
				subscriptionType +
				'\' ' +
				'AND Subscribed__c = true';

			System.debug('soql:' + soql);
			List<Rosco_Subscription__c> subscriptions = Database.query(soql);

			if (!subscriptions.isEmpty()) {
				ret = 'true';
			}
		} catch (Exception e) {
			System.debug('isSubscribed: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** removeSubscriber - used by lightning component to readahead
	 * @param search - read ahead value
	 * @return List
	 */
	@AuraEnabled
	public static List<Map<String, String>> removeSubscriberEmail(String email) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String soql =
				'SELECT Id ' +
				'FROM User ' +
				'WHERE ContactId IN (SELECT Id ' +
				'FROM Contact ' +
				'WHERE Email = \'' +
				email +
				'\') ' +
				'LIMIT 1';

			System.debug('soql:' + soql);
			List<User> users = Database.query(soql);

			if (!users.isEmpty()) {
				unSubscribeUser('Tanium Vulnerability', users[0].Id);
			}

			ret = getSubscribers();
		} catch (DmlException e) {
			System.debug('addSubscriberEmail:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** saveSplashPageContent
	 * @param search - read ahead value
	 * @return List
	 */
	@AuraEnabled
	public static String saveSplashPageContent(String splashPage) {
		String ret = '';

		try {
			String soql =
				'SELECT  ' +
				'body__c ' +
				'FROM Rosco_CmtyContent__c  ' +
				'WHERE name = \'splashTaniumVuln\' ' +
				'AND Status__c = \'Online\' ' +
				'LIMIT 1';

			System.debug('SOQL: ' + soql);
			List<Rosco_CmtyContent__c> pages = Database.query(soql);
			if (pages.size() > 0) {
				for (Rosco_CmtyContent__c p : pages) {
					p.body__c = splashPage;
					update p;
					ret = 'Success';
				}
			}
		} catch (DmlException e) {
			System.debug('getSplashPageContent:' + e.getMessage() + '\n' + e.getStackTraceString());
			ret = e.getMessage();
		}

		return ret;
	}

	/** sendEmail
	 */
	@AuraEnabled
	public static String sendEmail(String emailSubject, String emailText, String mode) {
		String ret = 'false';

		try {
			// Get Sender
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D23R0000000093SAA';
			if (cmfields.contains('rosco_owea__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea__c'))) {
					owea = String.valueOf(cm.get('rosco_owea__c'));
				}
			}
			System.debug('owea:' + owea);

			Map<String, String> defaultTxt = getEmailDefaultText();

			String emailHeader = defaultTxt.get('emailHeader');

			String emailHTML = emailText;
			String emailTXT = emailText.stripHtmlTags();
			emailTXT += defaultTxt.get('emailTextPostFixTXT');

			String emailTextPostFixHTML = defaultTxt.get('emailTextPostFixHTML');

			String emailFooter = defaultTxt.get('emailFooter');

			if (mode == 'SendToAllSubscribers') {
				List<Map<String, String>> subscribers = getSubscribers();

				List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();

				for (Map<String, String> subscriber : subscribers) {
					if (!subscriber.get('Name').containsIgnoreCase('(bounced)')) {
						String emailTextPreFixHTML = '<p>Dear ' + subscriber.get('Name') + ',</p>';
						String emailTextPreFixTXT = 'Dear ' + subscriber.get('Name') + ',\n\n';

						emailFooter = emailFooter.replace('003REPLACE', subscriber.get('Id'));

						String contactId = subscriber.get('Id');

						List<String> to = new List<String>();
						to.add(subscriber.get('Email'));

						Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

						if (Pattern.matches('^003[a-zA-Z0-9]{15}$', contactId)) {
							//mail.setTargetObjectId(contactId);
						}
						mail.setOrgWideEmailAddressId(owea);
						mail.setToAddresses(to);
						mail.setSubject(emailSubject);
						mail.setHtmlBody(
							emailHeader +
							emailTextPreFixHTML +
							emailHTML +
							emailTextPostFixHTML +
							emailFooter
						);
						mail.setPlainTextBody(emailTextPreFixTXT + emailTXT);
						mail.setUseSignature(false);
						mails.add(mail);
					}
				}

				if (!Test.isRunningTest()) {
					Messaging.sendEmail(mails);
				}
			} else {
				String emailTextPreFixHTML =
					'<p>Dear ' +
					UserInfo.getFirstName() +
					' ' +
					UserInfo.getLastName() +
					',</p>';
				String emailTextPreFixTXT =
					'Dear ' +
					UserInfo.getFirstName() +
					' ' +
					UserInfo.getLastName() +
					',\n\n';

				List<String> to = new List<String>();
				to.add(UserInfo.getUserEmail());

				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setOrgWideEmailAddressId(owea);
				mail.setToAddresses(to);
				mail.setSubject(emailSubject);
				mail.setHtmlBody(
					emailHeader +
					emailTextPreFixHTML +
					emailHTML +
					emailTextPostFixHTML +
					emailFooter
				);
				mail.setPlainTextBody(emailTextPreFixTXT + emailTXT);
				mail.setUseSignature(false);
				if (!Test.isRunningTest()) {
					Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
				}
			}
		} catch (Exception e) {
			System.debug('sendEmail: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** sendEmailSolo
	 */
	@AuraEnabled
	public static String sendEmailSolo(String emailSubject, String emailText, String email) {

		String ret = 'false';

		try {

			Map<String,String> subscriber = getSubscriber(email);

			// Get Sender
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D23R0000000093SAA';
			if (cmfields.contains('rosco_owea__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea__c'))) {
					owea = String.valueOf(cm.get('rosco_owea__c'));
				}
			}
			System.debug('owea:' + owea);

			Map<String, String> defaultTxt = getEmailDefaultText();

			String emailHeader = defaultTxt.get('emailHeader');

			String emailHTML = emailText;
			String emailTXT = emailText.stripHtmlTags();
			emailTXT += defaultTxt.get('emailTextPostFixTXT');

			String emailTextPostFixHTML = defaultTxt.get('emailTextPostFixHTML');

			String emailFooter = defaultTxt.get('emailFooter');

			String emailTextPreFixHTML = '<p>Dear ' + subscriber.get('Name') + ',</p>';
			String emailTextPreFixTXT = 'Dear ' + subscriber.get('Name') + ',\n\n';

			emailFooter = emailFooter.replace('003REPLACE', subscriber.get('Id'));

			String contactId = subscriber.get('Id');

			List<String> to = new List<String>();
			to.add(subscriber.get('Email'));

			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

			if (Pattern.matches('^003[a-zA-Z0-9]{15}$', contactId)) {
				//mail.setTargetObjectId(contactId);
			}
			mail.setOrgWideEmailAddressId(owea);
			mail.setToAddresses(to);
			mail.setSubject(emailSubject);
			mail.setHtmlBody(
				emailHeader +
				emailTextPreFixHTML +
				emailHTML +
				emailTextPostFixHTML +
				emailFooter
			);
			mail.setPlainTextBody(emailTextPreFixTXT + emailTXT);
			mail.setUseSignature(false);
			if (!Test.isRunningTest()) {
				if(isNewEmail(subscriber.get('Email'), emailSubject)){
					List<Messaging.SendEmailResult> results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
					ret = String.valueOf(results);
				} else {
					ret = 'No Email sent (not a new email)';
				}
			}

		} catch (Exception e) {
			System.debug('sendEmailSolo: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}	

	/** subscribeUser
	 */
	public static String subscribeUser(String subscriptionType, Id userId) {
		String ret = 'false';

		try {
			String soql =
				'SELECT Subscribed__c ' +
				'FROM Rosco_Subscription__c ' +
				'WHERE User__c = \'' +
				userId +
				'\' ' +
				'AND Type__c = \'' +
				subscriptionType +
				'\'';

			System.debug('soql:' + soql);
			List<Rosco_Subscription__c> subscriptions = Database.query(soql);

			if (!subscriptions.isEmpty()) {
				for (Rosco_Subscription__c s : subscriptions) {
					if (s.Subscribed__c == true) {
						System.debug('User is already subscribed');
					} else {
						System.debug('User is unsubscribed, subscribing');
						s.Subscribed__c = true;
						ret = 'true';
						update s;
					}
				}
			} else {
				System.debug('User is not defined, subscribing');
				Rosco_Subscription__c s = new Rosco_Subscription__c(
					Subscribed__c = true,
					Type__c = subscriptionType,
					User__c = userId
				);
				insert s;
				ret = 'true';
			}
		} catch (Exception e) {
			System.debug('subscribeUser: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** unSubscribeUser
	 */
	public static String unSubscribeUser(String subscriptionType, Id userId) {
		String ret = 'false';

		try {
			String soql =
				'SELECT Subscribed__c ' +
				'FROM Rosco_Subscription__c ' +
				'WHERE User__c = \'' +
				userId +
				'\' ' +
				'AND Type__c = \'' +
				subscriptionType +
				'\'';

			System.debug('soql:' + soql);
			List<Rosco_Subscription__c> subscriptions = Database.query(soql);

			if (!subscriptions.isEmpty()) {
				for (Rosco_Subscription__c s : subscriptions) {
					if (s.Subscribed__c == false) {
						System.debug('User is already not subscribed');
					} else {
						System.debug('User is subscribed, unsubscribing');
						s.Subscribed__c = false;
						ret = 'true';
						update s;
					}
				}
			} else {
				System.debug('User is not defined, no need to unsubscribe');
			}
		} catch (Exception e) {
			System.debug('unSubscribeUser: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}
}