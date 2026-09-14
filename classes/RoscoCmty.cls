/**
 * @Business: RoscoCmty - supports community app
 * @Date: 1/25/2021
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7985    2024-05-14    Add Sub-Component Field
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 */
public with sharing class RoscoCmty {
	@AuraEnabled
	public static Map<String, String> closeCase(Map<String, String> caseObj) {
		return RoscoCmtyNoShare.closeCase(caseObj);
	}

	@AuraEnabled
	public static Map<String, String> createCase(
		Map<String, String> caseObj,
		Map<String, String> caseFiles
	) {
		return RoscoCmtyNoShare.createCase(caseObj, caseFiles);
	}

	/** createCode
	 */
	/*
     @AuraEnabled     
    public static Map<String,String> createCode(Map<String,String> codeObj, Map<String,String> codeFiles) {

        Map<String,String> ret = new Map<String,String>();

        try {     
            
            String codeTitle = codeObj.get('Title');
            System.debug('codeTitle:' + codeTitle);

            String codeType = codeObj.get('Type');
            System.debug('codeType:' + codeType);

            String codeDescription= codeObj.get('Description');
            System.debug('codeDescription:' + codeDescription);            
            
            String codeLanguage = codeObj.get('Language');
            System.debug('codeLanguage:' + codeLanguage);   
            
            String codePlatform = codeObj.get('Platform');
            System.debug('codePlatform:' + codePlatform);            
 
            String codeSolution = codeObj.get('Solution');
            System.debug('codeSolution:' + codeSolution);       
            
            String codeKeywords = codeObj.get('Keywords');
            System.debug('codeKeywords:' + codeKeywords);     
            
            
            Rosco_CmtyCode__c newCodeObj = new Rosco_CmtyCode__c(
                Description__c = codeDescription,
                Language__c = codeLanguage,
                Platform__c = codePlatform,
                Solution__c = codeSolution,
                Name = codeTitle,
                Type__c = codeType
            );
            insert newCodeObj;           
            ret.put('CodeId',String.valueOf(newCodeObj.Id));


        } catch (Exception e) {
            System.debug('createCode: ' + e.getMessage() + '\n' + e.getStackTraceString() );
        }               

        return ret;

    }
    */

	@AuraEnabled
	public static List<Map<String, String>> exportCases(String contactId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			// Class is running with Sharing so only cases
			// available via sharing rules is what they will see
			// this is the same behavior as Case List Views

			List<Case> cases = [
				SELECT
					CaseNumber,
					Subject,
					Type,
					Severity_Community__c,
					Status,
					CreatedDate,
					ClosedDate,
					Contact.Name
				FROM Case
				WHERE Status != 'Closed' OR (Status = 'Closed' AND ClosedDate = LAST_N_DAYS:365)
				ORDER BY CaseNumber DESC
			];

			for (Case c : cases) {
				Map<String, String> caseMap = new Map<String, String>();
				caseMap.put('CaseNumber', String.valueOf(c.CaseNumber));
				caseMap.put('Subject', String.valueOf(c.Subject));
				caseMap.put('Severity', String.valueOf(c.Severity_Community__c));
				caseMap.put('Status', String.valueOf(c.Status));
				caseMap.put('Opened', String.valueOf(c.CreatedDate));

				caseMap.put('Closed', '');
				if (c.ClosedDate != null) {
					caseMap.put('Closed', String.valueOf(c.ClosedDate));
				}
				caseMap.put('Contact', String.valueOf(c.Contact.Name));

				ret.add(caseMap);
			}
		} catch (Exception e) {
			System.debug('exportCases: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getArticleFromURL
	 */
	public static String getArticleIdFromUrl(String url) {
		String ret = 'Sorry, article was not found!';

		try {
			String kbUrl = 't-b-d';

			if (url.containsIgnoreCase('?kburl=')) {
				List<String> aUrl = url.split('=');
				kbUrl = aUrl[aUrl.size() - 1];
			} else {
				List<String> aUrl = url.split('/');
				kbUrl = aUrl[aUrl.size() - 1];
			}

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
				'AND IsVisibleInCsp = true ' +
				'UPDATE VIEWSTAT';

			System.debug('soql:' + soql);

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					ret = kb.Id;
				}
			}
		} catch (Exception e) {
			System.debug('getArticleFromURL: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getArticleInit
	 */
	@AuraEnabled
	public static Map<String, String> getArticleInit(String articleId) {
		Map<String, String> ret = new Map<String, String>();
		ret.put('Id', '');
		ret.put('Title', 'Sorry, article was not found!');
		ret.put('Summary', 'Sorry, article was not found!!');
		ret.put('Body', 'Sorry, article was not found!!!');
		ret.put('iFrameURL', '');
		ret.put('URL', '');

		try {
			String whereClause = '';
			if (articleId.left(2) == 'ka') {
				whereClause = 'AND Id = \'' + articleId + '\'';
			} else if (articleId.containsIgnoreCase('https://')) {
				whereClause = 'AND Id = \'' + getArticleIdFromUrl(articleId) + '\'';
			} else {
				whereClause = 'AND ArticleNumber = \'' + articleId + '\'';
			}

			String soql =
				'SELECT ArticleNumber' +
				',Title' +
				',Summary ' +
				',Article_Body__c' +
				',FirstPublishedDate' +
				',LastPublishedDate ' +
				',RecordType.Name ' +
				',UrlName ' +
				'FROM Knowledge__kav ' +
				'WHERE PublishStatus = \'Online\' ' +
				whereClause +
				' ' +
				'UPDATE VIEWSTAT';

			System.debug('soql:' + soql);

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					ret.put('Id', kb.Id);
					ret.put('Title', kb.Title);
					ret.put('Summary', kb.Summary);
					ret.put('Body', String.valueOf(kb.Article_Body__c));
					ret.put('iFrameURL', '');
					ret.put('URL', kb.UrlName);
					ret.put('isInternal', isKbInternal(kb.Id));
					//ret.put('FirstPublishedDate',formatGmt(kb.FirstPublishedDate));
					//ret.put('LastPublishedDate', formatGmt(kb.LastPublishedDate));
				}
			} else {
				if (articleId.length() == 18) {
					String soql2 =
						'SELECT body__c' +
						',Title__c ' +
						'FROM Rosco_CmtyContent__c ' +
						'WHERE Status__c  = \'Online\' ' +
						'AND Id = \'' +
						articleId +
						'\'';

					System.debug('soql2:' + soql2);

					List<Rosco_CmtyContent__c> cc = Database.query(soql2);

					if (!cc.isEmpty()) {
						for (Rosco_CmtyContent__c c : cc) {
							String body = String.valueOf(c.body__c);
							final String URL_EXPRESSION = '(roscourl:.*:roscourl)';
							Pattern urlPattern = Pattern.compile(URL_EXPRESSION);

							String url;
							Matcher urlMatcher = urlPattern.matcher(body);
							if (urlMatcher.find()) {
								url = urlMatcher.group(1);
								url = url.replace(':', '');
								url = url.replace('roscourl', '');
								url = url.replace('https', 'https:');
							}

							ret.put('iFrameURL', url);
							ret.put('Title', c.Title__c);
							ret.put('Summary', '');
						}
					}
				}
			}

			if (ret.get('Title') == 'Sorry, article was not found!') {
				ret = RoscoCmtyNoShare.getArticleInitVuln(articleId);
			}
		} catch (Exception e) {
			System.debug('getArticleInit: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getCaseRecordDetail
	 * getCaseRecordDetail description
	 * @return   return description
	 */
	@AuraEnabled
	public static Map<String, String> getCaseRecordDetail(String caseId) {
		Map<String, String> ret = new Map<String, String>();

		try {
			Case c = [
				SELECT
					CaseNumber,
					Contact.Name,
					Status,
					Severity_Community__c,
					Component__c,
					Component_Version__c,
					Subject,
					Description,
					Type
				FROM Case
				WHERE Id = :caseId
			];

			ret.put('number', String.valueOf(c.CaseNumber));
			ret.put('contact', String.valueOf(c.Contact.Name));
			ret.put('type', String.valueOf(c.Type));
			ret.put('component', String.valueOf(c.Component__c));
			ret.put('componentVersion', String.valueOf(c.Component_Version__c));
			ret.put('status', String.valueOf(c.Status));
			ret.put('severity', String.valueOf(c.Severity_Community__c));
			ret.put('subject', String.valueOf(c.Subject));
			ret.put('description', String.valueOf(c.Description).abbreviate(500));
		} catch (Exception e) {
			System.debug('getCaseRecordDetail: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getCmtyCaseInit
	 * getCmtyCaseInit description
	 * @return   return description
	 */
	@AuraEnabled
	public static Map<String, String> getCmtyCaseInit(String caseId) {
		Map<String, String> ret = new Map<String, String>();

		try {
			Case c = [SELECT Status FROM Case WHERE Id = :caseId];

			ret.put('Status', String.valueOf(c.Status));
		} catch (Exception e) {
			System.debug('getCmtyCaseInit: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getCmtyCodeInit
	 * getCmtyPortalInit description
	 * @return   return description
	 */
	/*
    @AuraEnabled     
    public static Map<String,String> getCmtyCodeInit() {

        Map<String,String> ret = new Map<String,String>();

        try {
               
            ret.put('logToConsole','true');            

        } catch (Exception e) {
            System.debug('getCmtyCodeInit: ' + e.getMessage() + '\n' + e.getStackTraceString() );
        }               

        return ret;
    } 
    */

	/** getCmtyPortalInit
	 * getCmtyPortalInit description
	 * @return   return description
	 */
	@AuraEnabled
	public static Map<String, String> getCmtyPortalInit(String url) {
		Map<String, String> ret = new Map<String, String>();

		try {
			ret = getSplashCmtyContent();

			String userId = UserInfo.getUserId();

			String userProfile = RoscoCmtyNoShare.getUserProfileName(userId);

			if (
				userProfile.containsIgnoreCase('case') ||
				userProfile.containsIgnoreCase('super') ||
				userProfile.containsIgnoreCase('FedRAMP TAM') ||
				userProfile.containsIgnoreCase('Admin')
			) {
				ret.put('canCreateCase', 'true');
			} else {
				ret.put('canCreateCase', 'false');
			}

			ret.put('logToConsole', 'true');

			String subscriptionTaniumVuln = RoscoCmtyNoShare.isSubscribed('Tanium Vulnerability', userId);
			ret.put('subscriptionTaniumVuln', subscriptionTaniumVuln);

			if (url.containsIgnoreCase('/article/') || url.containsIgnoreCase('?kburl=')) {
				ret.put('urlArticleId', RoscoCmtyNoShare.getArticleIdFromUrl(url));
			} else {
				ret.put('urlArticleId', '');
			}
		} catch (Exception e) {
			System.debug('getCmtyPortalInit: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getContentByTopic
	 */
	@AuraEnabled
	public static List<Map<String, String>> getContentByTopic(String topic, Boolean splash) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			//ret = getSupportDocsByTopic(topic, splash);
			List<Map<String, String>> kb = getSupportKBByTopic(topic);
			ret.addAll(kb);
		} catch (DmlException e) {
			System.debug('getContentByTopic:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getCustomerIdAccount
	 */
	@AuraEnabled
	public static Map<String, String> getCustomerIdAccount(String customerId) {
		return RoscoCmtyNoShare.getCustomerIdAccount(customerId);
	}

	/** getSplashCmtyContent
	 */
	public static Map<String, String> getSplashCmtyContent() {
		Map<String, String> ret = new Map<String, String>();

		try {
			String userId = UserInfo.getUserId();

			String soql =
				'SELECT Name, body__c ' +
				'FROM Rosco_CmtyContent__c ' +
				'WHERE Status__c = \'Online\' ' +
				'AND Name LIKE \'splash%\'';

			System.debug('soql:' + soql);

			String contactId = '';
			String profileId = '-1';

			List<Rosco_CmtyContent__c> contents = Database.query(soql);
			if (!contents.isEmpty()) {
				for (Rosco_CmtyContent__c content : contents) {
					ret.put(content.Name, content.body__c);
				}
			}
		} catch (Exception e) {
			System.debug('getSplashCmtyContent: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSupportCreateCaseInit
	 */
	@AuraEnabled
	public static Map<String, Object> getSupportCreateCaseInit() {
		Map<String, Object> ret = new Map<String, Object>();

		try {
			ret.put('logToConsole', 'false');

			// Get User Id and Contact (account) Details
			String userId = UserInfo.getUserId();
			String contactId = RoscoCmtyNoShare.getContactId(userId);
			Map<String, String> contactDetails = RoscoCmtyNoShare.getContactDetails(contactId);
			ret.put('contact', contactDetails);

			// Get Account Contact Relation
			List<Map<String, String>> relations = new List<Map<String, String>>();

			Map<String, String> mRelations = RoscoCmtyNoShare.getAccountContactRelation(contactId);

			if (mRelations.size() > 0) {
				String contactAccountName = contactDetails.get('AccountName');
				List<String> lRelations = new List<String>(mRelations.keySet());
				if (!lRelations.contains(contactAccountName)) {
					lRelations.add(contactAccountName);
				}
				lRelations.sort();
				for (String r : lRelations) {
					Map<String, String> relation = new Map<String, String>();

					if (r == contactAccountName) {
						relation.put('label', contactDetails.get('AccountName'));
						relation.put('value', contactDetails.get('AccountId'));
					} else {
						relation.put('label', r);
						relation.put('value', mRelations.get(r));
					}

					relations.add(relation);
				}
			}
			ret.put('relations', relations);

			// Components
			List<String> lComponents = new List<String>();
			Schema.DescribeFieldResult fieldResult = Case.Component__c.getDescribe();
			List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
			for (Schema.PicklistEntry p : ple) {
				String label = String.valueOf(p.getLabel());
				if (label != 'Other: Product not listed') {
					lComponents.add(String.valueOf(p.getLabel()));
				}
			}
			lComponents.sort();
			lComponents.add('Other: Product not listed');
			List<Map<String, String>> components = new List<Map<String, String>>();
			for (String component : lComponents) {
				Map<String, String> c = new Map<String, String>();
				c.put('label', component);
				c.put('value', component);
				components.add(c);
			}
			ret.put('components', components);

			//Sub-Components
			Map<String, List<String>> subComponents = Utility.getDependentPicklistValues(
				'Case',
				'Component__c',
				'Sub_Component__c'
			);
			ret.put('sub_components', subComponents);

			// severities
			List<Map<String, String>> severities = new List<Map<String, String>>();
			severities.add(new Map<String, String>{ 'label' => '3 - Normal', 'value' => '3' });
			severities.add(
				new Map<String, String>{ 'label' => '2 - Substantial (Production)', 'value' => '2' }
			);
			severities.add(
				new Map<String, String>{ 'label' => '1 - Catastrophic (Production) ', 'value' => '1' }
			);
			ret.put('severities', severities);

			// OS
			List<Map<String, String>> os = new List<Map<String, String>>();
			os.add(new Map<String, String>{ 'label' => 'Windows', 'value' => 'Windows' });
			os.add(new Map<String, String>{ 'label' => 'Linux', 'value' => 'Linux' });
			os.add(new Map<String, String>{ 'label' => 'MacOS', 'value' => 'MacOS' });
			os.add(new Map<String, String>{ 'label' => 'Solaris', 'value' => 'Solaris' });
			os.add(new Map<String, String>{ 'label' => 'AIX', 'value' => 'AIX' });
			ret.put('os', os);

			// frequency
			List<Map<String, String>> frequency = new List<Map<String, String>>();
			frequency.add(new Map<String, String>{ 'label' => 'Always', 'value' => 'Always' });
			frequency.add(
				new Map<String, String>{ 'label' => 'Intermittent', 'value' => 'Intermittent' }
			);
			frequency.add(new Map<String, String>{ 'label' => 'Sporadic', 'value' => 'Sporadic' });
			frequency.add(new Map<String, String>{ 'label' => 'On Demand', 'value' => 'On Demand' });
			frequency.add(new Map<String, String>{ 'label' => 'Unknown', 'value' => 'Unknown' });
			ret.put('frequency', frequency);

			// duration
			List<Map<String, String>> duration = new List<Map<String, String>>();
			duration.add(new Map<String, String>{ 'label' => '< 15 minutes', 'value' => '< 15 minutes' });
			duration.add(new Map<String, String>{ 'label' => '< 30 minutes', 'value' => '< 30 minutes' });
			duration.add(new Map<String, String>{ 'label' => '< 45 minutes', 'value' => '< 45 minutes' });
			duration.add(new Map<String, String>{ 'label' => '< 60 minutes', 'value' => '< 60 minutes' });
			duration.add(new Map<String, String>{ 'label' => '> 60 minutes', 'value' => '> 60 minutes' });
			duration.add(new Map<String, String>{ 'label' => 'Sustained', 'value' => 'Sustained' });
			duration.add(
				new Map<String, String>{
					'label' => 'Sustained till workaround',
					'value' => 'Sustained till workaround'
				}
			);
			duration.add(new Map<String, String>{ 'label' => 'Unknown', 'value' => 'Unknown' });
			ret.put('duration', duration);

			// uiOptions
			Map<String, String> uiOptions = new Map<String, String>();

			uiOptions.put('showPartnerAccountName', 'false');
			String showPartnerAccountName = RoscoCmtyNoShare.getRoscoSetting(
				'rosco_cmty_show_partner_account__c'
			);
			if (showPartnerAccountName == 'true') {
				uiOptions.put('showPartnerAccountName', 'true');
			}

			uiOptions.put('experience', getSupportUserExperience());

			ret.put('uiOptions', uiOptions);

			ret.put('xxx', 'xxx');
			// Splash
			Map<String, String> splash = getSplashCmtyContent();
			ret.put('splash', splash);
		} catch (Exception e) {
			System.debug('getSupportCreateCaseInit: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSupportDocsByTopic
	 */
	public static List<Map<String, String>> getSupportDocsByTopic(String topic, Boolean splash) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String soql =
				'SELECT Name ' +
				',Id ' +
				',body__c ' +
				'FROM Rosco_CmtyContent__c ' +
				'WHERE Topics__c LIKE \'%' +
				topic +
				'%\' ' +
				'AND Content_Type__c = \'Core Doc\'';

			if (splash) {
				soql =
					'SELECT Name ' +
					',Id ' +
					',body__c ' +
					'FROM Rosco_CmtyContent__c ' +
					'WHERE Topics__c LIKE \'%' +
					topic +
					'%\' ' +
					'AND Content_Type__c = \'Splash\'';
			}

			System.debug('soql:' + soql);

			List<Rosco_CmtyContent__c> ccList = Database.query(soql);
			if (!ccList.isEmpty()) {
				for (Rosco_CmtyContent__c c : ccList) {
					Map<String, String> doc = new Map<String, String>();
					doc.put('Id', c.Id);
					doc.put('ArticleNumber', c.Id);
					doc.put('Title', String.valueOf(c.Name));
					doc.put('Summary', '');
					doc.put('Type', 'Tanium Core Documentation');

					doc.put('Popularity', '40');
					ret.add(doc);
				}
			}
		} catch (DmlException e) {
			System.debug('getSupportDocsByTopic:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getSupportKBByTopic
	 */
	public static List<Map<String, String>> getSupportKBByTopic(String topic) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			//List<String> entities = new List<String>();
			//entities.add('ka07V000000UCXWQA4');
			//String entities = '\'ka07V000000UCXWQA4\'';

			String soql =
				'SELECT Id ' +
				',Title ' +
				',Summary ' +
				',ArticleNumber ' +
				',RecordTypeId ' +
				',RecordType.name ' +
				',LastPublishedDate ' +
				',FirstPublishedDate ' +
				'FROM Knowledge__kav ' +
				'WHERE PublishStatus = \'Online\'';

			if (!Test.isRunningTest()) {
				soql +=
					' AND Id IN (SELECT EntityId ' +
					'FROM TopicAssignment ' +
					'WHERE EntityType = \'Knowledge\' ' +
					'AND Topic.Name = \'' +
					topic +
					'\')';
			}
			System.debug('soql:' + soql);

			List<Knowledge__kav> kbList = Database.query(soql);
			String articleIds = '';
			if (kbList.size() != 0) {
				for (Knowledge__kav k : kbList) {
					if (articleIds == '') {
						articleIds = '\'' + String.valueOf(k.Id) + '\'';
					} else {
						articleIds += ',\'' + String.valueOf(k.Id) + '\'';
					}
				}

				String soql2 =
					'SELECT ParentId, toLabel(DataCategoryName) ' +
					'FROM Knowledge__DataCategorySelection ' +
					'WHERE ParentId IN (' +
					articleIds +
					')';

				System.debug('SOQL2: ' + soql);
				List<Knowledge__DataCategorySelection> kbCategories = Database.query(soql2);
				Map<String, String> categories = new Map<String, String>();
				for (Knowledge__DataCategorySelection kbCategory : kbCategories) {
					String parentId = String.valueOf(kbCategory.ParentId);
					String categoryName = String.valueOf(kbCategory.DataCategoryName);
					if (categories.containsKey(parentId)) {
						categories.put(parentId, categories.get(parentId) + ',' + categoryName);
					} else {
						categories.put(parentId, categoryName);
					}
				}

				for (Knowledge__kav k : kbList) {
					Map<String, String> kb = new Map<String, String>();
					kb.put('Id', k.Id);
					kb.put('Title', k.Title);
					kb.put('Summary', k.Summary);
					kb.put('ArticleNumber', k.ArticleNumber);
					kb.put('FirstPublishedDate', k.FirstPublishedDate.formatGMT('yyyy-MM-dd'));
					kb.put('LastPublishedDate', k.LastPublishedDate.formatGMT('yyyy-MM-dd'));
					kb.put('Category', categories.get(k.Id));
					kb.put('Type', k.RecordType.Name);

					// to do
					kb.put('Popularity', '50');

					ret.add(kb);
				}
			}
		} catch (DmlException e) {
			System.debug('getSupportKBByTopic:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getSupportUserExperience
	 */
	public static String getSupportUserExperience() {
		String ret = 'Standard';

		try {
			// The method to determine partners (other than Account Type)
			// is still tbd - performing manual check now.
			String cmPartnerExperienceUserIds = RoscoCmtyNoShare.getRoscoSetting(
				'rosco_cmty_partner_experience__c'
			);
			if (cmPartnerExperienceUserIds.containsIgnoreCase(UserInfo.getUserId())) {
				ret = 'Partner';
			} else {
				String contactId = RoscoCmtyNoShare.getContactId(Userinfo.getUserId());
				String supportModel = RoscoCmtyNoShare.getContactSupportModel(contactId);
				if (supportModel.containsIgnoreCase('partner')) {
					ret = 'Partner';
				}
			}
		} catch (DmlException e) {
			System.debug('getSupportUserExperience:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getVulnInit
	 */
	@AuraEnabled
	public static List<Map<String, String>> getVulnInit() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			ret = RoscoCmtyNoShare.getVulnInitVuln();
		} catch (Exception e) {
			System.debug('getVulnInit: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** isKBInternal
	 */
	public static String isKBInternal(String kbId) {
		String ret = 'false';

		try {
			String soql =
				'SELECT DataCategoryGroupName,DataCategoryName ' +
				'FROM Knowledge__DataCategorySelection  ' +
				'WHERE ParentId = \'' +
				kbId +
				'\' ';

			System.debug('soql:' + soql);
			List<Knowledge__DataCategorySelection> selections = Database.query(soql);

			if (!selections.isEmpty()) {
				if (String.valueOf(selections).contains('Internal_Only')) {
					ret = 'true';
				}
			}
		} catch (Exception e) {
			System.debug('isKBInternal: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** processKnowledgeFeedback
	 */
	@AuraEnabled
	public static void processKnowledgeFeedback(String articleNumber, String text) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			// KnowledgeArticleId
			String kaid = [
				SELECT KnowledgeArticleId
				FROM Knowledge__kav
				WHERE ArticleNumber = :articleNumber
				LIMIT 1
			]
			.KnowledgeArticleId;

			FeedItem fi = new FeedItem(
				Body = text,
				IsRichText = false,
				NetworkScope = 'AllNetworks',
				Type = 'TextPost',
				Visibility = 'InternalUsers',
				ParentId = kaid
			);
			insert fi;
		} catch (DmlException e) {
			System.debug('processKnowledgeFeedback:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** processKnowledgeVote
	 */
	@AuraEnabled
	public static void processKnowledgeVote(String articleNumber, String voteType) {
		try {
			// Vote Type
			String vType = 'Down';
			if (voteType == 'Yes') {
				vType = 'Up';
			}

			// KnowledgeArticleId
			String kaid = [
				SELECT KnowledgeArticleId
				FROM Knowledge__kav
				WHERE ArticleNumber = :articleNumber
				LIMIT 1
			]
			.KnowledgeArticleId;

			String soql =
				'SELECT Id,Type FROM Vote ' +
				'WHERE ParentId = \'' +
				kaid +
				'\' ' +
				'AND CreatedById = \'' +
				UserInfo.getUserId() +
				'\'';

			System.debug('SOQL: ' + soql);
			List<Vote> votes = Database.query(soql);

			if (votes.size() != 0) {
				if (votes[0].Type != vType) {
					votes[0].Type = vType;
					update votes[0];
				}
			} else {
				Vote v = new Vote(Type = vType, ParentId = kaid);
				insert v;
			}
		} catch (DmlException e) {
			System.debug('processKnowledgeVote:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** processPortalFeedback
	 */
	@AuraEnabled
	public static String processPortalFeedback(String feedback) {
		String ret = 'Unknown error';

		try {
			// Get org wide sender id
			String owea = '0D260000000XZFgCAO';

			String userEmail = UserInfo.getUserEmail();

			String emailSubject = 'Tanium Support Portal Feedback';
			List<String> to = new List<String>();
			to.add('soa@tanium.com');

			String htmlBody = userEmail + ' feedback:<br>' + feedback;
			String textBody = userEmail + ' feedback::\n' + feedback;

			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setOrgWideEmailAddressId(owea);
			mail.setToAddresses(to);
			mail.setSubject(emailSubject);
			mail.setHtmlBody(htmlBody);
			mail.setPlainTextBody(textBody);
			if (feedback != 'rosco') {
				Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
			}
		} catch (Exception e) {
			System.debug('processPortalFeedback: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** processSubscriptionToggle
	 */
	@AuraEnabled
	public static String processSubscriptionToggle(String subscriptionType) {
		String ret;

		String userId = UserInfo.getUserId();

		ret = RoscoCmtyNoShare.subscriptionToggle(subscriptionType, userId);

		return ret;
	}

	/** searchCode
	 */
	/*     
    @AuraEnabled
    public static List<Map<String,String>> searchCode(String searchText) {
        
        List<Map<String,String>> ret = new  List<Map<String,String>>();

        try {

            List<List<SObject>> results = [FIND :searchText IN ALL FIELDS RETURNING Rosco_CmtyCode__c (Id,Description__c,Language__c,Name,Platform__c,Solution__c,Type__c) ];
            Rosco_CmtyCode__c [] codeList = ((List<Rosco_CmtyCode__c>)results[0]);

            if( codeList.size() != 0 ){
                for(Rosco_CmtyCode__c c: codeList){

                    Map<String,String> codeObj = new Map<String,String>();
                    codeObj.put('Id', c.Id);
                    codeObj.put('Description', c.Description__c);
                    codeObj.put('Language', c.Language__c);
                    codeObj.put('Title', c.Name);
                    codeObj.put('Platform', c.Platform__c);
                    codeObj.put('Solution', c.Solution__c);
                    codeObj.put('Type', c.Type__c);
                    ret.add(codeObj);


                }
            }

        } catch (DmlException e) {
            System.debug('searchCode:' + e.getMessage() + '\n' + e.getStackTraceString() );
        }
        
        return ret;        
        
    }
    */

	/** searchSupport
	 */
	@AuraEnabled
	public static List<Map<String, String>> searchSupport(String searchText) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			//List<Map<String,String>> docs = searchSupportDocs(searchText);
			//ret.addAll(docs);

			String articleIds = '';

			List<Knowledge__kav> kbList = new List<Knowledge__kav>();
			if (Test.isRunningTest()) {
				kbList = [
					SELECT
						Id,
						Title,
						Summary,
						ArticleNumber,
						RecordTypeId,
						RecordType.Name,
						LastPublishedDate,
						FirstPublishedDate
					FROM Knowledge__kav
					LIMIT 5
				];
			} else {
				List<List<SObject>> results = [
					FIND :searchText
					IN ALL FIELDS
					RETURNING
						Knowledge__kav(
							Id,
							Title,
							Summary,
							ArticleNumber,
							RecordTypeId,
							RecordType.Name,
							LastPublishedDate,
							FirstPublishedDate,
							IsVisibleInCsp
							WHERE PublishStatus = 'Online')
				];
				kbList = ((List<Knowledge__kav>) results[0]);
			}
			System.debug('kbList:' + String.valueOf(kbList));

			if (kbList.size() != 0) {
				for (Knowledge__kav k : kbList) {
					if (articleIds == '') {
						articleIds = '\'' + String.valueOf(k.Id) + '\'';
					} else {
						articleIds += ',\'' + String.valueOf(k.Id) + '\'';
					}
				}

				String soql =
					'SELECT ParentId, toLabel(DataCategoryName) ' +
					'FROM Knowledge__DataCategorySelection ' +
					'WHERE ParentId IN (' +
					articleIds +
					')';

				System.debug('SOQL: ' + soql);
				List<Knowledge__DataCategorySelection> kbCategories = Database.query(soql);
				Map<String, String> categories = new Map<String, String>();
				for (Knowledge__DataCategorySelection kbCategory : kbCategories) {
					String parentId = String.valueOf(kbCategory.ParentId);
					String categoryName = String.valueOf(kbCategory.DataCategoryName);
					if (categories.containsKey(parentId)) {
						categories.put(parentId, categories.get(parentId) + ',' + categoryName);
					} else {
						categories.put(parentId, categoryName);
					}
				}

				for (Knowledge__kav k2 : kbList) {
					if (k2.IsVisibleInCsp = true && k2.RecordType.Name != 'Tanium Vulnerability') {
						Map<String, String> kb = new Map<String, String>();
						kb.put('Id', k2.Id);
						kb.put('Title', k2.Title);
						kb.put('Summary', k2.Summary);
						kb.put('ArticleNumber', k2.ArticleNumber);
						kb.put('FirstPublishedDate', k2.FirstPublishedDate.formatGMT('yyyy-MM-dd'));
						kb.put('LastPublishedDate', k2.LastPublishedDate.formatGMT('yyyy-MM-dd'));
						kb.put('Category', categories.get(k2.Id));
						kb.put('Type', k2.RecordType.Name);

						// to do
						kb.put('Popularity', '50');

						ret.add(kb);
					}
				}
			}
		} catch (DmlException e) {
			System.debug('searchSupport:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		//List<Map<String,String>> disc = searchSupportDisc(searchText);
		//ret.addAll(disc);

		List<Map<String, String>> vuln = RoscoCmtyNoShare.searchTaniumVuln(searchText);
		System.debug(vuln);
		ret.addAll(vuln);

		return ret;
	}

	/** searchSupportDisc
	 */
	public static List<Map<String, String>> searchSupportDisc(String searchText) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String articleIds = '';

			List<List<SObject>> results = [
				FIND :searchText
				IN ALL FIELDS
				RETURNING FeedItem(Id, Title, Body, CreatedDate, CreatedById, NetworkScope)
			];
			FeedItem[] fbList = ((List<FeedItem>) results[0]);

			if (fbList.size() != 0) {
				for (FeedItem fb : fbList) {
					String netId = [SELECT Name FROM Network WHERE Name = 'Tanium Customer Community'].Id;
					String url = Network.getLoginUrl(netId).replace('login', '') + 'question/' + fb.Id;

					Map<String, String> disc = new Map<String, String>();

					disc.put('Id', String.valueOf(fb.Id));
					disc.put('Title', String.valueOf(fb.Title));
					disc.put('ArticleNumber', String.valueOf(fb.Id));
					disc.put('Type', 'Community Discussion');
					disc.put('Popularity', '50');

					if (fb.Body == null) {
						disc.put('Summary', '');
					} else {
						String body = String.valueOf(fb.Body);
						body = body.stripHTMLTags();
						body = body.left(255);
						disc.put('Summary', body);
					}
					ret.add(disc);
				}
			}
		} catch (DmlException e) {
			System.debug('searchSupportDisc:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** searchSupportDocs
	 */
	public static List<Map<String, String>> searchSupportDocs(String searchText) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String articleIds = '';

			List<List<SObject>> results = [
				FIND :searchText
				IN ALL FIELDS
				RETURNING Rosco_CmtyContent__c(Name, Id, url__c)
			];
			Rosco_CmtyContent__c[] ccList = ((List<Rosco_CmtyContent__c>) results[0]);

			if (ccList.size() != 0) {
				for (Rosco_CmtyContent__c c : ccList) {
					Map<String, String> doc = new Map<String, String>();

					doc.put('Id', String.valueOf(c.Id));
					doc.put('ArticleNumber', String.valueOf(c.url__c));
					doc.put('Title', String.valueOf(c.Name));
					doc.put('Summary', '');
					doc.put('Type', 'Tanium Core Documentation');

					doc.put('Popularity', '50');
					ret.add(doc);
				}
			}
		} catch (DmlException e) {
			System.debug('searchSupportDocs:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** searchSupportTypeAhead
	 */
	@AuraEnabled
	public static List<Map<String, String>> searchSupportTypeAhead(String searchText) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String whereClause = '';
			if (searchText.contains(' ')) {
				List<String> lSearchText = searchText.split(' ');
				for (String s : lSearchText) {
					if (whereClause == '') {
						whereClause = 'Title LIKE \'%' + s + '%\'';
					} else {
						whereClause += ' OR Title LIKE \'%' + s + '%\'';
					}
				}
			} else {
				whereClause = 'Title LIKE \'%' + searchText + '%\'';
			}

			String soql =
				'SELECT Title,Id ' +
				'FROM Knowledge__kav ' +
				'WHERE PublishStatus = \'Online\' ' +
				'AND (' +
				whereClause +
				') ' +
				'ORDER BY CreatedDate DESC ' +
				'LIMIT 5';
			System.debug('soql:' + soql);

			List<Knowledge__kav> kbs = Database.query(soql);
			System.debug(kbs);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					Map<String, String> article = new Map<String, String>();
					article.put('label', kb.Title);
					article.put('value', kb.Id);
					ret.add(article);
				}
			}
		} catch (DmlException e) {
			System.debug('searchSupportTypeAhead:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}
}