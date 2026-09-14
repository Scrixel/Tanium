public with sharing class RoscoSurveyProcesses {
	private static final Id SC_CSAT_REC_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Survey__c',
		'SC_CSAT'
	);
	private static final Id ES_CSAT_REC_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Survey__c',
		'ES_CSAT'
	);
	private static final Id REL_NPS_REC_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Survey__c',
		'Relational_NPS'
	);
	private static final Id IMPL_REC_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Survey__c',
		'Implement'
	);
	private static final Id ONBOARD_REC_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Survey__c',
		'Onboard'
	);
	private static final Id FTAM_REC_TYPE_ID = Utility.getRecordTypeIdByAPIName('Survey__c', 'FTAM');

	private static Map<Id, Contact> contactMap;
	/** processRoscoAccountUpdate
	 */
	public static void processRoscoAccountUpdate(List<Survey__c> surveys) {
		System.debug('processRoscoAccountUpdate()');

		for (Survey__c survey : surveys) {
			if (
				!(survey.Name.containsIgnoreCase('Support Center CSAT') ||
				survey.Name.containsIgnoreCase('Relational NPS'))
			) {
				return;
			}

			String soql =
				'SELECT SurveyCreateDate__c, Relational_1_Recommend__c, Case_1_Recommend__c, Case_2_Overall_Support__c ' +
				'FROM Survey__c ' +
				'WHERE Account__c = \'' +
				survey.Account__c +
				'\' ' +
				'ORDER BY SurveyCreateDate__c DESC NULLS LAST';

			System.debug('SOQL: ' + soql);
			List<Survey__c> surveysInner = Database.query(soql);

			if (surveysInner.size() != 0) {
				soql =
					'SELECT Id ' +
					'FROM Rosco_Account__c ' +
					'WHERE Account__c = \'' +
					survey.Account__c +
					'\' LIMIT 1';
				System.debug('SOQL: ' + soql);
				List<Rosco_Account__c> accounts = Database.query(soql);

				// Relational and Transacational
				Map<String, Integer> allTimeScore = getAllTimeInfo(surveysInner);
				Map<String, Integer> rolling12MonthScore = getRolling12MonthScore(surveysInner);
				Map<String, String> mostRecentScore = getMostRecentScore(surveysInner);

				// Relational
				Map<String, Integer> allTimeRelationalScore = getAllTimeRelationalScore(surveysInner);
				Map<String, Integer> rolling12MonthRelationalScore = getRolling12MonthRelationalScore(
					surveysInner
				);
				Map<String, Integer> rolling12MonthCaseCSAT = getRolling12MonthCaseCSAT(surveysInner);
				Map<String, String> mostRecentRelationalScore = getMostRecentRelationalScore(surveysInner);

				// Transacational
				Map<String, Integer> allTimeCaseScore = getAllTimeCaseInfo(surveysInner);
				Map<String, Integer> rolling12MonthCaseScore = getRolling12MonthCaseScore(surveysInner);
				Map<String, String> mostRecentCaseScore = getMostRecentCaseScore(surveysInner);
				Map<String, Integer> allTimeCaseCSAT = getAllTimeCaseCSAT(surveysInner);
				Map<String, Integer> mostRecentCaseCSAT = getMostRecentCaseCSAT(surveysInner);

				// ESO

				if (accounts.size() != 0) {
					// Relational and Transacational
					accounts[0].Survey_AllTimeScore__c = allTimeScore.get('score');
					accounts[0].Survey_AllTimeCount__c = allTimeScore.get('count');
					accounts[0].Survey_Rolling12MonthScore__c = rolling12MonthScore.get('score');
					accounts[0].Survey_Rolling12MonthCount__c = rolling12MonthScore.get('count');
					accounts[0].Survey_MostRecentScore__c = Integer.valueOf(mostRecentScore.get('score'));
					accounts[0].Survey_MostRecentDate__c = Datetime.valueOfGmt(mostRecentScore.get('date'));

					// Relational
					accounts[0].Survey_AllTimeRelationalScore__c = allTimeRelationalScore.get('score');
					accounts[0].Survey_AllTimeRelationalCount__c = allTimeRelationalScore.get('count');
					accounts[0].Survey_Rolling12MonthRelationalScore__c = rolling12MonthRelationalScore.get(
						'score'
					);
					accounts[0].Survey_Rolling12MonthRelationalCount__c = rolling12MonthRelationalScore.get(
						'count'
					);
					accounts[0].Survey_MostRecentRelationalScore__c = Integer.valueOf(
						mostRecentRelationalScore.get('score')
					);
					accounts[0].Survey_MostRecentRelationalDate__c = Datetime.valueOfGmt(
						mostRecentRelationalScore.get('date')
					);

					// Transacational
					accounts[0].Survey_AllTimeCaseScore__c = allTimeCaseScore.get('score');
					accounts[0].Survey_AllTimeCaseCount__c = allTimeCaseScore.get('count');
					accounts[0].Survey_Rolling12MonthCaseScore__c = rolling12MonthCaseScore.get('score');
					accounts[0].Survey_Rolling12MonthCaseCount__c = rolling12MonthCaseScore.get('count');
					accounts[0].Survey_MostRecentCaseScore__c = Integer.valueOf(
						mostRecentCaseScore.get('score')
					);
					accounts[0].Survey_MostRecentCaseDate__c = Datetime.valueOfGmt(
						mostRecentCaseScore.get('date')
					);

					accounts[0].Survey_AllTimeCaseCSAT__c = allTimeCaseCSAT.get('score');
					accounts[0].Survey_Rolling12MonthCaseCSAT__c = rolling12MonthCaseCSAT.get('score');
					accounts[0].Survey_MostRecentCaseCSAT__c = Integer.valueOf(
						mostRecentCaseCSAT.get('score')
					);

					update accounts[0];
					System.debug('Rosco Account updated: ' + String.valueOf(accounts[0].Id));
				} else {
					Rosco_Account__c account = new Rosco_Account__c();
					account.Account__c = survey.Account__c;

					// Relational and Transacational
					account.Survey_AllTimeScore__c = allTimeScore.get('score');
					account.Survey_AllTimeCount__c = allTimeScore.get('count');
					account.Survey_Rolling12MonthScore__c = rolling12MonthScore.get('score');
					account.Survey_Rolling12MonthCount__c = rolling12MonthScore.get('count');
					account.Survey_MostRecentScore__c = Integer.valueOf(mostRecentScore.get('score'));
					account.Survey_MostRecentDate__c = Datetime.valueOfGmt(mostRecentScore.get('date'));

					// Relational
					account.Survey_AllTimeRelationalScore__c = allTimeRelationalScore.get('score');
					account.Survey_AllTimeRelationalCount__c = allTimeRelationalScore.get('count');
					account.Survey_Rolling12MonthRelationalScore__c = rolling12MonthRelationalScore.get(
						'score'
					);
					account.Survey_Rolling12MonthRelationalCount__c = rolling12MonthRelationalScore.get(
						'count'
					);
					account.Survey_MostRecentRelationalScore__c = Integer.valueOf(
						mostRecentRelationalScore.get('score')
					);
					account.Survey_MostRecentRelationalDate__c = Datetime.valueOfGmt(
						mostRecentRelationalScore.get('date')
					);

					// Transacational
					account.Survey_AllTimeCaseScore__c = allTimeCaseScore.get('score');
					account.Survey_AllTimeCaseCount__c = allTimeCaseScore.get('count');
					account.Survey_Rolling12MonthCaseScore__c = rolling12MonthCaseScore.get('score');
					account.Survey_Rolling12MonthCaseCount__c = rolling12MonthCaseScore.get('count');
					account.Survey_MostRecentCaseScore__c = Integer.valueOf(mostRecentCaseScore.get('score'));
					account.Survey_MostRecentCaseDate__c = Datetime.valueOfGmt(
						mostRecentCaseScore.get('date')
					);

					account.Survey_AllTimeCaseCSAT__c = allTimeCaseCSAT.get('score');
					account.Survey_Rolling12MonthCaseCSAT__c = rolling12MonthCaseCSAT.get('score');
					account.Survey_MostRecentCaseCSAT__c = Integer.valueOf(mostRecentCaseCSAT.get('score'));

					insert account;
					System.debug('Rosco Account Created: ' + String.valueOf(account.Id));
				}
			}
		}
	}

	/** processSurvey
	 */
	public static void processSurvey(List<Survey__c> surveys) {
		System.debug('processSurvey()');
		Set<Id> contactIds = new Set<Id>();

		for (Survey__c survey : surveys) {
			if (survey.Contact__c != null) {
				contactIds.add(survey.Contact__c);
			}
		}

		contactMap = contactIds.isEmpty()
			? new Map<Id, Contact>()
			: new Map<Id, Contact>([SELECT Id, AccountId FROM Contact WHERE Id IN :contactIds]);

		for (Survey__c survey : surveys) {
			System.debug(String.valueOf(JSON.serializePretty(survey, true)));

			processCaseSurveyTranslate(survey);

			if (survey.Name.containsIgnoreCase('Support Center CSAT')) {
				processCaseSurvey(new List<Survey__c>{ survey });
			} else if (survey.Name.containsIgnoreCase('Relational NPS')) {
				processRelationalSurvey(new List<Survey__c>{ survey });
			} else if (survey.Name.containsIgnoreCase('Enterprise Services Engagement Feedback Survey')) {
				processESOSurvey(new List<Survey__c>{ survey });
			} else if (survey.Name.containsIgnoreCase('Implement Survey')) {
				processImplementSurvey(new List<Survey__c>{ survey });
			} else if (survey.Name.containsIgnoreCase('Onboard Survey')) {
				processOnboardSurvey(new List<Survey__c>{ survey });
			} else if (
				survey.Name.containsIgnoreCase('Tanium Enterprise Services Customer Satisfaction Survey')
			) {
				processESCSATSurvey(new List<Survey__c>{ survey });
			} else if (survey.Name.containsIgnoreCase('Tanium Technical Account Management Survey')) {
				processFTAMSurvey(new List<Survey__c>{ survey });
			} else {
				System.debug('Will not process ' + survey.Name);
			}
			System.debug('finished processing');
		}
	}

	/** getAllTimeCaseCSAT
	 */
	public static Map<String, Integer> getAllTimeCaseCSAT(List<Survey__c> surveys) {
		System.debug('getAllTimeCaseCSAT()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', 0);
		ret.put('count', 0);

		Decimal satisfied = 0.0;
		Decimal responses = 0.0;

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Case_2_Overall_Support__c)) {
				if (
					survey.Case_2_Overall_Support__c == 'Extremely satisfied' ||
					survey.Case_2_Overall_Support__c == 'Very satisfied' ||
					survey.Case_2_Overall_Support__c == 'Somewhat satisfied'
				) {
					satisfied += 1;
				}

				responses += 1;
			} else {
				System.debug('Survey is not Case');
			}
		}

		if (responses != 0) {
			Decimal satScore = (satisfied / responses) * 100;
			ret.put('score', Integer.valueOf(satScore.round(System.RoundingMode.UP)));
			ret.put('count', Integer.valueOf(responses));
		}

		return ret;
	}

	/** getAllTimeInfo
	 */
	public static Map<String, Integer> getAllTimeInfo(List<Survey__c> surveys) {
		System.debug('getAllTimeInfo()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', 0);
		ret.put('count', 0);

		Integer responses = 0;
		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			String recommend;
			if (!nullOrEmpty(survey.Case_1_Recommend__c)) {
				recommend = survey.Case_1_Recommend__c;
			} else if (!nullOrEmpty(survey.Relational_1_Recommend__c)) {
				recommend = survey.Relational_1_Recommend__c;
			}

			if (!nullOrEmpty(recommend)) {
				responses += 1;

				String classification = getNPSResponseClassification(String.valueOf(recommend));

				if (classification == 'Promoter') {
					promoters += 1;
				} else if (classification == 'Detractor') {
					detractors += 1;
				}
			} else {
				System.debug('Survey is not Case or Relational');
			}
		}

		if (responses != 0) {
			Integer npsScore = getNPSScore(promoters, detractors, responses);
			ret.put('score', npsScore);
			ret.put('count', responses);
		}

		return ret;
	}

	/** getAllTimeCaseInfo
	 */
	public static Map<String, Integer> getAllTimeCaseInfo(List<Survey__c> surveys) {
		System.debug('getAllTimeCaseInfo()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', 0);
		ret.put('count', 0);

		Integer responses = 0;
		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Case_1_Recommend__c)) {
				responses += 1;

				String classification = getNPSResponseClassification(
					String.valueOf(survey.Case_1_Recommend__c)
				);

				if (classification == 'Promoter') {
					promoters += 1;
				} else if (classification == 'Detractor') {
					detractors += 1;
				}
			} else {
				System.debug('Survey is not Case');
			}
		}

		if (responses != 0) {
			Integer npsScore = getNPSScore(promoters, detractors, responses);
			ret.put('score', npsScore);
			ret.put('count', responses);
		}

		return ret;
	}

	/** getAllTimeRelationalScore
	 */
	public static Map<String, Integer> getAllTimeRelationalScore(List<Survey__c> surveys) {
		System.debug('getAllTimeRelationalScore()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', 0);
		ret.put('count', 0);

		Integer responses = 0;
		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Relational_1_Recommend__c)) {
				responses += 1;

				String classification = getNPSResponseClassification(
					String.valueOf(survey.Relational_1_Recommend__c)
				);

				if (classification == 'Promoter') {
					promoters += 1;
				} else if (classification == 'Detractor') {
					detractors += 1;
				}
			} else {
				System.debug('Survey is not Case');
			}
		}

		if (responses != 0) {
			Integer npsScore = getNPSScore(promoters, detractors, responses);
			ret.put('score', npsScore);
			ret.put('count', responses);
		}

		return ret;
	}

	/** getLabels
	 */
	public static Map<String, String> getLabels(String objApiName) {
		Map<String, String> ret = new Map<String, String>();

		Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
		Schema.SObjectType mySchema = schemaMap.get(objApiName);
		Map<String, Schema.SObjectField> fieldMap = mySchema.getDescribe().fields.getMap();

		// get order api list
		List<String> apiFields = new List<String>();
		for (String fieldName : fieldMap.keySet()) {
			String fieldLabel = fieldMap.get(fieldName).getDescribe().getLabel();
			ret.put(fieldName.toLowerCase(), fieldLabel.toLowerCase()); // this seems to be lower anyway
		}

		return ret;
	}

	/** getMostRecentCaseCSAT
	 */
	public static Map<String, Integer> getMostRecentCaseCSAT(List<Survey__c> surveys) {
		System.debug('getMostRecentCaseCSAT()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', -1);
		ret.put('count', 0);

		Decimal responses = 0.0;
		Decimal satisfied = 0.0;

		Boolean bFound = false;
		Boolean bSatisfied = false;
		for (Survey__c survey : surveys) {
			if (!bFound) {
				if (!nullOrEmpty(survey.Case_2_Overall_Support__c)) {
					if (survey.Case_2_Overall_Support__c == 'Extremely satisfied') {
						ret.put('score', 100);
					} else if (survey.Case_2_Overall_Support__c == 'Very satisfied') {
						ret.put('score', 80);
					} else if (survey.Case_2_Overall_Support__c == 'Somewhat satisfied') {
						ret.put('score', 60);
					} else if (survey.Case_2_Overall_Support__c == 'Not so satisfied') {
						ret.put('score', 40);
					} else if (survey.Case_2_Overall_Support__c == 'Not at all satisfied') {
						ret.put('score', 20);
					}
				}
			}
		}

		return ret;
	}

	/** getMostRecentCaseCSAT
	 */
	public static Map<String, Integer> getMostRecentESCSAT(List<Survey__c> surveys) {
		System.debug('getMostRecentCaseCSAT()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', -1);
		ret.put('count', 0);

		Decimal responses = 0.0;
		Decimal satisfied = 0.0;

		Boolean bFound = false;
		Boolean bSatisfied = false;
		for (Survey__c survey : surveys) {
			if (!bFound) {
				if (!nullOrEmpty(survey.ESCSAT_2_CSAT__c)) {
					if (survey.ESCSAT_2_CSAT__c == 'Extremely satisfied') {
						ret.put('score', 100);
					} else if (survey.ESCSAT_2_CSAT__c == 'Very satisfied') {
						ret.put('score', 80);
					} else if (survey.ESCSAT_2_CSAT__c == 'Somewhat satisfied') {
						ret.put('score', 60);
					} else if (survey.ESCSAT_2_CSAT__c == 'Not so satisfied') {
						ret.put('score', 40);
					} else if (survey.ESCSAT_2_CSAT__c == 'Not at all satisfied') {
						ret.put('score', 20);
					}
				}
			}
		}

		return ret;
	}

	/** getMostRecentCaseCSAT
	 */
	public static Map<String, Integer> getMostRecentFTAMCSAT(List<Survey__c> surveys) {
		System.debug('getMostRecentCaseCSAT()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', -1);
		ret.put('count', 0);

		Decimal responses = 0.0;
		Decimal satisfied = 0.0;

		Boolean bFound = false;
		Boolean bSatisfied = false;
		for (Survey__c survey : surveys) {
			if (!bFound) {
				if (!nullOrEmpty(survey.FTAM_2_CSAT__c)) {
					if (survey.FTAM_2_CSAT__c == 'Extremely satisfied') {
						ret.put('score', 100);
					} else if (survey.FTAM_2_CSAT__c == 'Very satisfied') {
						ret.put('score', 80);
					} else if (survey.FTAM_2_CSAT__c == 'Somewhat satisfied') {
						ret.put('score', 60);
					} else if (survey.FTAM_2_CSAT__c == 'Not so satisfied') {
						ret.put('score', 40);
					} else if (survey.FTAM_2_CSAT__c == 'Not at all satisfied') {
						ret.put('score', 20);
					}
				}
			}
		}

		return ret;
	}

	/** getMostRecentCaseScore
	 */
	public static Map<String, String> getMostRecentCaseScore(List<Survey__c> surveys) {
		System.debug('getMostRecentCaseScore()');

		Map<String, String> ret = new Map<String, String>();
		ret.put('score', '-1');
		ret.put('date', '2000-01-01 00:00:00.000Z');

		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Case_1_Recommend__c)) {
				String classification = getNPSResponseClassification(
					String.valueOf(survey.Case_1_Recommend__c)
				);

				if (classification == 'Promoter') {
					promoters += 1;
				} else if (classification == 'Detractor') {
					detractors += 1;
				}

				Integer score = getNPSScore(promoters, detractors, 1);

				ret.put('score', String.valueOf(score));
				ret.put('date', String.valueOf(survey.SurveyCreateDate__c).replace('T', ' '));
				return ret;
			} else {
				System.debug('Survey is not Case');
			}
		}

		return ret;
	}

	/** getMostRecentRelationalScore
	 */
	public static Map<String, String> getMostRecentRelationalScore(List<Survey__c> surveys) {
		System.debug('getMostRecentRelationalScore()');

		Map<String, String> ret = new Map<String, String>();
		ret.put('score', '-1');
		ret.put('date', '2000-01-01 00:00:00.000Z');

		Integer responses = 0;
		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Relational_1_Recommend__c)) {
				String classification = getNPSResponseClassification(
					String.valueOf(survey.Relational_1_Recommend__c)
				);

				if (classification == 'Promoter') {
					promoters += 1;
				} else if (classification == 'Detractor') {
					detractors += 1;
				}

				Integer score = getNPSScore(promoters, detractors, 1);

				ret.put('score', String.valueOf(score));
				ret.put('date', String.valueOf(survey.SurveyCreateDate__c).replace('T', ' '));
				return ret;
			} else {
				System.debug('Survey is not Case');
			}
		}

		return ret;
	}

	/** getMostRecentScore
	 */
	public static Map<String, String> getMostRecentScore(List<Survey__c> surveys) {
		System.debug('getMostRecentScore()');

		Map<String, String> ret = new Map<String, String>();
		ret.put('score', '-1');
		ret.put('date', '2000-01-01 00:00:00.000Z');

		Integer responses = 0;
		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			String recommend;
			if (!nullOrEmpty(survey.Case_1_Recommend__c)) {
				recommend = survey.Case_1_Recommend__c;
			} else if (!nullOrEmpty(survey.Relational_1_Recommend__c)) {
				recommend = survey.Relational_1_Recommend__c;
			}

			if (!nullOrEmpty(recommend)) {
				String classification = getNPSResponseClassification(String.valueOf(recommend));

				if (classification == 'Promoter') {
					promoters += 1;
				} else if (classification == 'Detractor') {
					detractors += 1;
				}

				Integer score = getNPSScore(promoters, detractors, 1);

				ret.put('score', String.valueOf(score));
				ret.put('date', String.valueOf(survey.SurveyCreateDate__c).replace('T', ' '));
				return ret;
			} else {
				System.debug('Survey is not Case or Relational');
			}
		}

		return ret;
	}

	/** getNPSResponseClassification
	 */
	public static String getNPSResponseClassification(String score) {
		String ret;

		if (score == '10') {
			ret = 'Promoter';
		} else if (score == '9') {
			ret = 'Promoter';
		} else if (score == '8') {
			ret = 'Passive';
		} else if (score == '7') {
			ret = 'Passive';
		} else if (score == '6') {
			ret = 'Detractor';
		} else if (score == '5') {
			ret = 'Detractor';
		} else if (score == '4') {
			ret = 'Detractor';
		} else if (score == '3') {
			ret = 'Detractor';
		} else if (score == '2') {
			ret = 'Detractor';
		} else if (score == '1') {
			ret = 'Detractor';
		} else if (score == '0') {
			ret = 'Detractor';
		}

		return ret;
	}

	/** getNPSScore
	 */
	public static Integer getNPSScore(Integer promoters, Integer detractors, Integer responses) {
		Integer ret = 0;

		Decimal percentagePromoter = 0.0;
		if (promoters != 0) {
			percentagePromoter = Decimal.valueOf(promoters) / Decimal.valueOf(responses);
		}

		Decimal percentageDetractor = 0.0;
		if (detractors != 0) {
			percentageDetractor = Decimal.valueOf(detractors) / Decimal.valueOf(responses);
		}

		Decimal promoterMinusDetractor = percentagePromoter - percentageDetractor;

		Decimal retDec = promoterMinusDetractor * 100.0;
		ret = Integer.valueOf(retDec.round(System.RoundingMode.UP));

		return ret;
	}

	/** getRolling12MonthCaseCSAT
	 */
	public static Map<String, Integer> getRolling12MonthCaseCSAT(List<Survey__c> surveys) {
		System.debug('getRolling12MonthCaseCSAT()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', 0);
		ret.put('count', 0);

		Decimal responses = 0.0;
		Decimal satisfied = 0.0;

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Case_2_Overall_Support__c)) {
				Integer daysOld = getSurveyDaysOld(survey);
				if (daysOld < 365) {
					if (
						survey.Case_2_Overall_Support__c == 'Extremely satisfied' ||
						survey.Case_2_Overall_Support__c == 'Very satisfied' ||
						survey.Case_2_Overall_Support__c == 'Somewhat satisfied'
					) {
						satisfied += 1;
					}

					responses += 1;
				}
			} else {
				System.debug('Survey is not Case');
			}
		}

		if (responses != 0) {
			Decimal satScore = (satisfied / responses) * 100;
			ret.put('score', Integer.valueOf(satScore.round(System.RoundingMode.UP)));
			ret.put('count', Integer.valueOf(responses));
		}

		return ret;
	}

	/** getRolling12MonthCaseScore
	 */
	public static Map<String, Integer> getRolling12MonthCaseScore(List<Survey__c> surveys) {
		System.debug('getRolling12MonthCaseScore()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', 0);
		ret.put('count', 0);

		Integer responses = 0;
		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Case_1_Recommend__c)) {
				Integer daysOld = getSurveyDaysOld(survey);
				if (daysOld < 365) {
					responses += 1;

					String classification = getNPSResponseClassification(
						String.valueOf(survey.Case_1_Recommend__c)
					);

					if (classification == 'Promoter') {
						promoters += 1;
					} else if (classification == 'Detractor') {
						detractors += 1;
					}
				}
			} else {
				System.debug('Survey is not Case');
			}
		}

		if (responses != 0) {
			Integer npsScore = getNPSScore(promoters, detractors, responses);
			ret.put('score', npsScore);
			ret.put('count', responses);
		}

		return ret;
	}

	/** getRolling12MonthRelationalScore
	 */
	public static Map<String, Integer> getRolling12MonthRelationalScore(List<Survey__c> surveys) {
		System.debug('getRolling12MonthRelationalScore()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', 0);
		ret.put('count', 0);

		Integer responses = 0;
		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Relational_1_Recommend__c)) {
				Integer daysOld = getSurveyDaysOld(survey);
				if (daysOld < 365) {
					responses += 1;

					String classification = getNPSResponseClassification(
						String.valueOf(survey.Relational_1_Recommend__c)
					);

					if (classification == 'Promoter') {
						promoters += 1;
					} else if (classification == 'Detractor') {
						detractors += 1;
					}
				}
			} else {
				System.debug('Survey is not Case');
			}
		}

		if (responses != 0) {
			Integer npsScore = getNPSScore(promoters, detractors, responses);
			ret.put('score', npsScore);
			ret.put('count', responses);
		}

		return ret;
	}

	/** getRolling12MonthScore
	 */
	public static Map<String, Integer> getRolling12MonthScore(List<Survey__c> surveys) {
		System.debug('getRolling12MonthCaseScore()');

		Map<String, Integer> ret = new Map<String, Integer>();
		ret.put('score', 0);
		ret.put('count', 0);

		Integer responses = 0;
		Integer promoters = 0;
		Integer detractors = 0;

		for (Survey__c survey : surveys) {
			String recommend;
			if (!nullOrEmpty(survey.Case_1_Recommend__c)) {
				recommend = survey.Case_1_Recommend__c;
			} else if (!nullOrEmpty(survey.Relational_1_Recommend__c)) {
				recommend = survey.Relational_1_Recommend__c;
			}

			if (!nullOrEmpty(recommend)) {
				Integer daysOld = getSurveyDaysOld(survey);
				if (daysOld < 365) {
					responses += 1;

					String classification = getNPSResponseClassification(String.valueOf(recommend));

					if (classification == 'Promoter') {
						promoters += 1;
					} else if (classification == 'Detractor') {
						detractors += 1;
					}
				}
			} else {
				System.debug('Survey is not Case or Relational survey');
			}
		}

		if (responses != 0) {
			Integer npsScore = getNPSScore(promoters, detractors, responses);
			ret.put('score', npsScore);
			ret.put('count', responses);
		}

		return ret;
	}

	/** getSurveyDaysOld
	 */
	public static Integer getSurveyDaysOld(Survey__c survey) {
		System.debug('getSurveyDaysOld()');

		Integer ret = 1000;

		String sDate = String.valueOf(survey.SurveyCreateDate__c);
		System.debug(sDate);

		List<String> lDateT = sDate.split(' ');
		List<String> lDate = lDateT[0].split('-');

		Date dDate = Date.newInstance(
			Integer.valueOf(lDate[0]),
			Integer.valueOf(lDate[1]),
			Integer.valueOf(lDate[2])
		);

		ret = math.abs((system.today()).daysBetween(dDate));

		return ret;
	}

	/** nullOrEmpty
	 */
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** processCaseSurvey
	 */
	private static void processCaseSurvey(List<Survey__c> surveys) {
		System.debug('Processing Case Survey');

		for (Survey__c survey : surveys) {
			System.debug('survey:' + survey);
			removePriorCaseSurvey(survey);

			Map<String, String> nps = getMostRecentCaseScore(surveys);
			Map<String, Integer> sat = getMostRecentCaseCSAT(surveys);

			String soql =
				'SELECT AccountId,ContactId ' +
				'FROM Case ' +
				'WHERE Id = \'' +
				survey.Case__c +
				'\' LIMIT 1';

			System.debug('SOQL: ' + soql);
			List<Case> cases = Database.query(soql);

			System.debug('cases: ' + cases);

			if (cases.size() != 0) {
				survey.Account__c = cases[0].AccountId;
				survey.Contact__c = cases[0].ContactId;
				survey.Case_1_NPS__c = nps.get('score');
				survey.Case_2_Satisfaction__c = String.valueOf(sat.get('score'));
				survey.recordTypeId = SC_CSAT_REC_TYPE_ID;
			}
		}
	}

	/** processCaseSurveyTranslate
	 */
	private static void processCaseSurveyTranslate(Survey__c survey) {
		try {
			System.debug('Processing Case Survey Translate');

			// Get a list of strings that can be translated.
			StaticResource sr = [
				SELECT Id, Body
				FROM StaticResource
				WHERE Name = 'rosco_survey_monkey_translations'
				LIMIT 1
			];
			String body = sr.Body.toString();
			Map<String, Object> srObj = (Map<String, Object>) JSON.deserializeUntyped(body);
			Map<String, Object> map1 = (Map<String, Object>) srObj;
			Map<String, String> translation = new Map<String, String>();
			for (String key : map1.keyset()) {
				translation.put(key, (String) map1.get(key));
			}

			// Loop through fields to see if something can be translated
			Map<String, Object> values = survey.getPopulatedFieldsAsMap();
			for (String fieldName : values.keySet()) {
				System.debug(fieldName + ':' + values.get(fieldName));
				if (translation.containsKey(String.valueOf(values.get(fieldName)))) {
					String oldSurvey = (String) survey.put(
						fieldName,
						translation.get(String.valueOf(values.get(fieldName)))
					);
				}
			}

			/*translation.put('非常に満足','Extremely satisfied');
			translation.put('やや満足','Very satisfied');
			translation.put('普通','Somewhat satisfied');
			translation.put('やや不満','Not so satisfied');
			translation.put('非常に不満','Not at all satisfied');
			translation.put('はい','Yes');
			translation.put('いいえ','No');

			translation.put('強く同意します','Strongly Agree');
			translation.put('同意','Agree');
			translation.put('中性','Neutral');		
			translation.put('同意しない','Disagree');
			translation.put('強く同意しない','Strongly Disagree');
			

			// Case
			if(translation.containsKey(survey.Case_2_Overall_Support__c)){
				survey.Case_2_Overall_Support__c = translation.get(survey.Case_2_Overall_Support__c);
			}
			if(translation.containsKey(survey.Case_3_Speed_of_Resolution__c)){
				survey.Case_3_Speed_of_Resolution__c = translation.get(survey.Case_3_Speed_of_Resolution__c);
			}	
			if(translation.containsKey(survey.Case_4_Technical_Knowledge__c)){
				survey.Case_4_Technical_Knowledge__c = translation.get(survey.Case_4_Technical_Knowledge__c);
			}		
			if(translation.containsKey(survey.Case_5_Issue_Resolved__c)){
				survey.Case_5_Issue_Resolved__c = translation.get(survey.Case_5_Issue_Resolved__c);
			}	
			
			// Enterprise Services
			
			if(translation.containsKey(survey.ESCSAT_2_CSAT__c)){
				survey.ESCSAT_2_CSAT__c = translation.get(survey.ESCSAT_2_CSAT__c);
			}

			if(translation.containsKey(survey.ESCSAT_3_Experience__c)){
				survey.ESCSAT_3_Experience__c = translation.get(survey.ESCSAT_3_Experience__c);
			}
			if(translation.containsKey(survey.ESCSAT_4_Respect__c)){
				survey.ESCSAT_4_Respect__c = translation.get(survey.ESCSAT_4_Respect__c);
			}		
			if(translation.containsKey(survey.ESCSAT_5_Goals__c)){
				survey.ESCSAT_5_Goals__c = translation.get(survey.ESCSAT_5_Goals__c);
			}	
			if(translation.containsKey(survey.ESCSAT_6_Professional__c)){
				survey.ESCSAT_6_Professional__c = translation.get(survey.ESCSAT_6_Professional__c);
			}	
			if(translation.containsKey(survey.ESCSAT_7_Trusted__c)){
				survey.ESCSAT_7_Trusted__c = translation.get(survey.ESCSAT_7_Trusted__c);
			}	
			if(translation.containsKey(survey.ESCSAT_8_Cost__c)){
				survey.ESCSAT_8_Cost__c = translation.get(survey.ESCSAT_8_Cost__c);
			}											
			
			//Field TAM
			if(translation.containsKey(survey.FTAM_2_CSAT__c)){
				survey.FTAM_2_CSAT__c = translation.get(survey.FTAM_2_CSAT__c);
			}	
			
			if(translation.containsKey(survey.FTAM_3_Instrumental__c)){
				survey.FTAM_3_Instrumental__c = translation.get(survey.FTAM_3_Instrumental__c);
			}		
			
			if(translation.containsKey(survey.FTAM_4_Trusted__c)){
				survey.FTAM_4_Trusted__c = translation.get(survey.FTAM_4_Trusted__c);
			}		
			
			if(translation.containsKey(survey.FTAM_5_Deployment__c)){
				survey.FTAM_5_Deployment__c = translation.get(survey.FTAM_5_Deployment__c);
			}	
			
			if(translation.containsKey(survey.FTAM_6_Operationalized__c)){
				survey.FTAM_6_Operationalized__c = translation.get(survey.FTAM_6_Operationalized__c);
			}			

			if(translation.containsKey(survey.FTAM_7_Planning__c)){
				survey.FTAM_7_Planning__c = translation.get(survey.FTAM_7_Planning__c);
			}				

			// Implement
			if(translation.containsKey(survey.Implement_3_Prepare__c)){
				survey.Implement_3_Prepare__c = translation.get(survey.Implement_3_Prepare__c);
			}	
			if(translation.containsKey(survey.Implement_4_Clear__c)){
				survey.Implement_4_Clear__c = translation.get(survey.Implement_4_Clear__c);
			}	
			if(translation.containsKey(survey.Implement_5_Length__c)){
				survey.Implement_5_Length__c = translation.get(survey.Implement_5_Length__c);
			}		
			if(translation.containsKey(survey.Implement_6_Value__c)){
				survey.Implement_6_Value__c = translation.get(survey.Implement_6_Value__c);
			}		
			
			// Onboard
			if(translation.containsKey(survey.Onboard_3_Outcome__c)){
				survey.Onboard_3_Outcome__c = translation.get(survey.Onboard_3_Outcome__c);
			}				
			if(translation.containsKey(survey.Onboard_4_Prepare__c)){
				survey.Onboard_4_Prepare__c = translation.get(survey.Onboard_4_Prepare__c);
			}			

			// Relational
			if(translation.containsKey(survey.Relational_4_Value_Satisfaction__c)){
				survey.Relational_4_Value_Satisfaction__c = translation.get(survey.Relational_4_Value_Satisfaction__c);
			}	
			if(translation.containsKey(survey.Relational_6_Authority__c)){
				survey.Relational_6_Authority__c = translation.get(survey.Relational_6_Authority__c);
			}			
			
			*/
		} catch (Exception e) {
			System.debug(
				'processCaseSurveyTranslate: ' + e.getMessage() + '\n' + e.getStackTraceString()
			);
		}
	}

	/** processESCSATSurvey
	 */
	private static void processESCSATSurvey(List<Survey__c> surveys) {
		System.debug('Processing ES CSAT Survey');

		Map<String, Integer> sat = getMostRecentESCSAT(surveys);

		Survey__c survey = surveys[0];

		if (survey.Contact__c != null) {
			survey.Account__c = contactMap.get(survey.Contact__c)?.AccountId;
			survey.recordTypeId = ES_CSAT_REC_TYPE_ID;
		}

		// update NPS Score
		String classification = getNPSResponseClassification(
			String.valueOf(survey.ESCSAT_1_Recommend__c)
		);
		Integer promoters = 0;
		Integer detractors = 0;
		if (classification == 'Promoter') {
			promoters += 1;
		} else if (classification == 'Detractor') {
			detractors += 1;
		}

		survey.ESCSAT_1_NPS__c = String.valueOf(getNPSScore(promoters, detractors, 1));
		survey.ESCSAT_2_Satisfaction__c = String.valueOf(sat.get('score'));
	}

	/** processESOSurvey
	 */
	private static void processESOSurvey(List<Survey__c> surveys) {
		System.debug('Processing ESO Survey');

		Survey__c survey = surveys[0];

		String soql =
			'SELECT Account__c ' +
			'FROM Account_Support_Request__c ' +
			'WHERE Id = \'' +
			survey.ISR__c +
			'\' LIMIT 1';

		System.debug('SOQL: ' + soql);
		List<Account_Support_Request__c> isrs = Database.query(soql);

		if (isrs.size() != 0) {
			survey.Account__c = isrs[0].Account__c;
			survey.recordTypeId = Utility.getRecordTypeIdByAPIName('Survey__c', 'ES_Feedback');
		}
	}

	/** processFTAMSurvey
	 */
	private static void processFTAMSurvey(List<Survey__c> surveys) {
		System.debug('Processing FTAM Survey');

		Map<String, Integer> sat = getMostRecentFTAMCSAT(surveys);

		Survey__c survey = surveys[0];

		if (survey.Contact__c != null) {
			survey.Account__c = contactMap.get(survey.Contact__c)?.AccountId;
			survey.recordTypeId = FTAM_REC_TYPE_ID;
		}

		// update NPS Score
		String classification = getNPSResponseClassification(
			String.valueOf(survey.FTAM_1_Recommend__c)
		);
		Integer promoters = 0;
		Integer detractors = 0;
		if (classification == 'Promoter') {
			promoters += 1;
		} else if (classification == 'Detractor') {
			detractors += 1;
		}

		survey.FTAM_1_NPS__c = String.valueOf(getNPSScore(promoters, detractors, 1));
		survey.FTAM_2_Satisfaction__c = String.valueOf(sat.get('score'));
	}

	/** processImplementSurvey
	 */
	private static void processImplementSurvey(List<Survey__c> surveys) {
		System.debug('Processing Implement Survey');

		Survey__c survey = surveys[0];

		if (survey.Contact__c != null) {
			survey.Account__c = contactMap.get(survey.Contact__c)?.AccountId;
			survey.recordTypeId = IMPL_REC_TYPE_ID;
		}

		// update NPS Score
		String classification = getNPSResponseClassification(
			String.valueOf(survey.Implement_1_Recommend__c)
		);
		Integer promoters = 0;
		Integer detractors = 0;
		if (classification == 'Promoter') {
			promoters += 1;
		} else if (classification == 'Detractor') {
			detractors += 1;
		}

		survey.Implement_1_NPS__c = String.valueOf(getNPSScore(promoters, detractors, 1));
	}

	/** processOnboardSurvey
	 */
	private static void processOnboardSurvey(List<Survey__c> surveys) {
		System.debug('Processing Onboard Survey');

		Survey__c survey = surveys[0];

		if (survey.Contact__c != null) {
			survey.Account__c = contactMap.get(survey.Contact__c)?.AccountId;
			survey.recordTypeId = ONBOARD_REC_TYPE_ID;
		}

		// update NPS Score
		String classification = getNPSResponseClassification(
			String.valueOf(survey.Onboard_1_Recommend__c)
		);
		Integer promoters = 0;
		Integer detractors = 0;
		if (classification == 'Promoter') {
			promoters += 1;
		} else if (classification == 'Detractor') {
			detractors += 1;
		}

		survey.Onboard_1_NPS__c = String.valueOf(getNPSScore(promoters, detractors, 1));
	}

	/** processRelationalSurvey
	 */
	private static void processRelationalSurvey(List<Survey__c> surveys) {
		Map<String, String> nps = getMostRecentRelationalScore(surveys);

		for (Survey__c survey : surveys) {
			if (survey.Contact__c != null) {
				survey.Account__c = contactMap.get(survey.Contact__c)?.AccountId;
				survey.Relational_1_NPS__c = nps.get('score');
				survey.recordTypeId = REL_NPS_REC_TYPE_ID;
			}
		}
	}
	/** removePriorCaseSurvey
	 */
	public static void removePriorCaseSurvey(Survey__c survey) {
		try {
			/*String soql =
				'SELECT Id ' +
				'FROM Survey__c ' +
				'WHERE Case__c = \'' + survey.Case__c + '\' ' +
				'AND SurveyCreateDate__c > ' + survey.SurveyCreateDate__c;
			System.debug('SOQL: ' + soql);
			
			List<Survey__c> surveys = Database.query(soql);
			*/

			List<Survey__c> surveys = [
				SELECT Id
				FROM Survey__c
				WHERE Case__c = :survey.Case__c AND SurveyCreateDate__c < :survey.SurveyCreateDate__c
			];

			if (surveys.size() != 0) {
				delete surveys;
			} else {
				System.debug('removePriorCaseSurvey no prior surveys');
			}
		} catch (Exception e) {
			System.debug('removePriorCaseSurvey: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** sendAlert
	 */
	public static void sendAlert(List<Survey__c> surveys) {
		System.debug('sendAlert');
		Set<Id> accountIds = new Set<Id>();
		Set<Id> contactIds = new Set<Id>();
		Set<Id> caseIds = new Set<Id>();
		Map<Id, Account> accountMap;
		Map<Id, Contact> contactMap;
		Map<Id, Case> caseMap;

		Map<Id, RecordType> surveyRecordTypeMap = new Map<Id, RecordType>(
			[SELECT Id, DeveloperName FROM RecordType WHERE SobjectType = 'Survey__c']
		);

		for (Survey__c survey : surveys) {
			if (!nullOrEmpty(survey.Account__c)) {
				accountIds.add(survey.Account__c);
			}
			if (!nullOrEmpty(survey.Contact__c)) {
				contactIds.add(survey.Contact__c);
			}
			if (!nullOrEmpty(survey.Case__c)) {
				caseIds.add(survey.Case__c);
			}
		}

		accountMap = accountIds.isEmpty()
			? new Map<Id, Account>()
			: new Map<Id, Account>(
					[SELECT Id, Name, Support_Model__c FROM Account WHERE Id IN :accountIds]
			  );

		contactMap = contactIds.isEmpty()
			? new Map<Id, Contact>()
			: new Map<Id, Contact>([SELECT Id, Name, Email FROM Contact WHERE Id IN :contactIds]);

		caseMap = caseIds.isEmpty()
			? new Map<Id, Case>()
			: new Map<Id, Case>([SELECT CaseNumber, Subject, Owner.Email FROM Case WHERE Id IN :caseIds]);

		try {
			for (Survey__c survey : surveys) {
				if (String.valueOf(survey).contains('RoscoTestCase-skip')) {
					return;
				}

				Map<String, String> settings = new Map<String, String>();

				// use case management settings to determine
				// if survey should be emailed and/or slacked
				Case_Management__c cm = Case_Management__c.getInstance();
				Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

				for (String s : cmfields) {
					System.debug('s:' + s);
				}

				System.debug('survey.recordTypeId:' + survey.recordTypeId);
				String recordTypeName = surveyRecordTypeMap.get(survey.recordTypeId).DeveloperName;
				recordTypeName = recordTypeName.toLowerCase();
				System.debug('recordTypeName:' + recordTypeName);
				// does survey have an email address configured?
				String emailAddressSetting = 'rosco_' + recordTypeName + '_email__c';
				System.debug('emailAddressSetting:' + emailAddressSetting);
				if (cmfields.contains(emailAddressSetting)) {
					if (!nullOrEmpty(cm.get(emailAddressSetting))) {
						settings.put('email', String.valueOf(cm.get(emailAddressSetting)));
						System.debug('email:' + String.valueOf(cm.get(emailAddressSetting)));
					}
				}

				// should we include case owner on email?
				String includeOwnerSurveyEmail = 'rosco_include_owner_survey_email__c';
				System.debug('includeOwnerSurveyEmail:' + includeOwnerSurveyEmail);
				if (cmfields.contains(includeOwnerSurveyEmail)) {
					if (!nullOrEmpty(cm.get(includeOwnerSurveyEmail))) {
						settings.put(
							'includeOwnerSurveyEmail',
							String.valueOf(cm.get(includeOwnerSurveyEmail))
						);
						System.debug(
							'includeOwnerSurveyEmail:' + String.valueOf(cm.get(includeOwnerSurveyEmail))
						);
					}
				}

				// if we're going to email, lets get the owea
				if (!nullOrEmpty(settings.get(emailAddressSetting))) {
					settings.put('owea', '0D260000000XZFgCAO');
					if (cmfields.contains('rosco_owea_noreply__c')) {
						if (!nullOrEmpty(cm.get('rosco_owea_noreply__c'))) {
							settings.put('owea', String.valueOf(cm.get('rosco_owea_noreply__c')));
							System.debug('owea:' + String.valueOf(cm.get('rosco_owea_noreply__c')));
						}
					}
				}

				// does survey have an slack id configured?
				String slackIdSetting = 'rosco_' + recordTypeName + '_slackid__c';
				if (cmfields.contains(slackIdSetting)) {
					if (!nullOrEmpty(cm.get(slackIdSetting))) {
						settings.put('slackId', String.valueOf(cm.get(slackIdSetting)));
						System.debug('slackId:' + String.valueOf(cm.get(slackIdSetting)));
					}
				}

				// if we're doing email or slack lets pull together some info
				if (settings.containsKey('email') || settings.containsKey('slackId')) {
					// url for current salesforce instance
					String url = URL.getOrgDomainUrl().toExternalForm();

					// handy links to Account Case, Contact
					settings.put('surveyId', String.valueOf(survey.Id));
					settings.put('surveyUrl', url + '/' + survey.Id);
					settings.put('surveyName', survey.Name);
					settings.put('surveySubmitted', String.valueOf(survey.SurveyCreateDate__c));

					if (!nullOrEmpty(survey.Account__c)) {
						Account account = accountMap.get(survey.Account__c);
						settings.put('accountId', account.Id);
						settings.put('accountUrl', url + '/' + account.Id);
						settings.put('accountName', account.Name);
						settings.put('accountSupportModel', account.Support_Model__c);
					}

					if (!nullOrEmpty(survey.Contact__c)) {
						Contact contact = contactMap.get(survey.Contact__c);
						settings.put('contactId', contact.Id);
						settings.put('contactUrl', url + '/' + contact.Id);
						settings.put('contactName', contact.Name);
						settings.put('contactEmail', contact.Email);
					}

					if (!nullOrEmpty(survey.Case__c)) {
						Case aCase = caseMap.get(survey.Case__c);
						settings.put('caseId', aCase.Id);
						settings.put('caseUrl', url + '/' + aCase.Id);
						settings.put('caseNumber', aCase.CaseNumber);
						settings.put('caseSubject', aCase.Subject);
						settings.put('caseOwnerEmail', aCase.Owner.Email);
					}

					// lets pull together some of the survey data
					// we want a ordered list of fields for this survey but because
					// we may process different surveys with this function we rely on the
					// the naming convention of Case_1_foo, Case_2_bar and so on for the Case survey
					// and Onboard_1_foo, Onboard_2_bar and so on for the Onboard survey

					// get the labels for the Survey field, we use that in the Slack/Email
					Map<String, String> labels = getLabels('Survey__c');
					// Note: it seems getDescribe().getLabel() was returning lower case
					// so I forced closer case below and forced getLabels to lower case in case
					// something changes.

					Map<String, Object> sJson = (Map<String, Object>) JSON.deserializeUntyped(
						JSON.serialize(survey)
					);

					// get the keys (i.e. Case_1_foo) in the survey being processed and sort
					List<String> keys = new List<String>();
					keys.addAll(sJson.keySet());
					keys.sort();

					// we only want a subset of the survey fields (filtered with regex and contains)
					// put relevant fields into a new fields list
					List<Map<String, String>> fields = new List<Map<String, String>>();
					for (String key : keys) {
						Pattern MyPattern = Pattern.compile('(.*_[0-9](_|a|b|c|d).*)');
						Matcher MyMatcher = MyPattern.matcher(key);
						if (MyMatcher.matches()) {
							if (!key.contains('_Detractor__c') && !key.contains('_Promoter__c')) {
								Map<String, String> field = new Map<String, String>();
								field.put('field_api', key);
								field.put('field_label', labels.get(key.toLowerCase())); // lower because of label
								field.put('field_value', String.valueOf(sJson.get(key)));
								fields.add(field);
							}
						}
					}

					// ok lets send to email and/or slack
					if (settings.containsKey('email')) {
						sendAlertEmail(settings, fields);
					}
					if (settings.containsKey('slackId')) {
						sendAlertSlack(settings, fields);
					}
				}
			}
		} catch (Exception e) {
			System.debug('sendAlert: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** sendAlertEmail
	 */
	public static void sendAlertEmail(
		Map<String, String> settings,
		List<Map<String, String>> fields
	) {
		try {
			// to and bcc addresses
			List<String> to = new List<String>();
			to.add(settings.get('email'));

			if (settings.get('includeOwnerSurveyEmail') == 'true') {
				to.add(settings.get('caseOwnerEmail'));
			}

			List<String> bcc = new List<String>();
			bcc.add('soa@tanium.com');

			// subject
			String subject = 'New Survey response for ' + settings.get('Name');
			if (settings.containsKey('caseNumber')) {
				subject = 'New Survey response for ' + settings.get('caseNumber');
			}

			String htmlBody =
				'<div style="text-align:center;background-color:black;color:white;font-size:large;font-weight:bold;">' +
				'<p>Tanium Survey Received Notification</p></div>';
			htmlBody += '<table size=80%>';

			// first row
			String surveyHyperLink =
				'<a href="' +
				settings.get('surveyUrl') +
				'">' +
				settings.get('surveyName') +
				'</a>';
			htmlBody += '<tr style="background-color:#d2d2d2;font-weight:bold"><td style="font-weight:bold">Survey Name:</td></tr>';
			htmlBody += '<tr><td>' + surveyHyperLink + '</td></tr>';

			// Add case if this is a case survey
			if (settings.containsKey('caseNumber')) {
				String caseHyperLink =
					'<a href="' +
					settings.get('caseUrl') +
					'">' +
					settings.get('caseNumber') +
					' - ' +
					settings.get('caseSubject') +
					'</a>';
				htmlBody += '<tr style="background-color:#d2d2d2;font-weight:bold"><td style="font-weight:bold">Case:</td></tr>';
				htmlBody += '<tr><td>' + caseHyperLink + '</td></tr>';
				htmlBody += '<tr style="background-color:#d2d2d2;font-weight:bold"><td style="font-weight:bold">Case Owner:</td></tr>';
				htmlBody += '<tr><td>' + settings.get('caseOwnerEmail') + '</td></tr>';
			}

			// Add contact
			String contactHyperLink =
				'<a href="' +
				settings.get('contactUrl') +
				'">' +
				settings.get('contactName') +
				' (' +
				settings.get('contactEmail') +
				')</a>';
			htmlBody += '<tr><td style="background-color:#d2d2d2;font-weight:bold">Contact:</td></tr>';
			htmlBody += '<tr><td>' + contactHyperLink + '</td></tr>';

			// Add account
			String accountHyperLink =
				'<a href="' +
				settings.get('accountUrl') +
				'">' +
				settings.get('accountName') +
				' - Support Model:' +
				settings.get('accountSupportModel') +
				'</a>';
			htmlBody += '<tr><td style="background-color:#d2d2d2;font-weight:bold">Account:</td></tr>';
			htmlBody += '<tr><td>' + accountHyperLink + '</td></tr>';

			// Add Submitted
			htmlBody += '<tr><td style="background-color:#d2d2d2;font-weight:bold">Submitted:</td></tr>';
			htmlBody += '<td>' + settings.get('surveySubmitted') + '</td></tr>';

			for (Map<String, String> field : fields) {
				htmlBody +=
					'<tr style="background-color:#d2d2d2;font-weight:bold"><td>' +
					field.get('field_label') +
					':</td></tr>';
				htmlBody += '<tr><td>' + field.get('field_value') + '</td></tr>';
			}

			htmlBody += '</table>';

			// Send Email
			System.debug('owea:' + settings.get('owea'));
			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setOrgWideEmailAddressId(settings.get('owea'));
			mail.setToAddresses(to);
			mail.setBccAddresses(bcc);
			mail.setSubject(subject);
			mail.setHtmlBody(htmlBody);
			mail.setPlainTextBody(htmlBody.stripHtmlTags());
			if (!Test.isRunningTest()) {
				Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
			}
		} catch (Exception e) {
			System.debug('sendAlertEmail: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** sendAlertSlack
	 */
	public static void sendAlertSlack(
		Map<String, String> settings,
		List<Map<String, String>> fields
	) {
		System.debug('sendAlertSlack');

		try {
			String webhookURL = 'https://hooks.slack.com/services/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';

			List<Map<String, Object>> fieldsList = new List<Map<String, Object>>();
			Map<String, Object> fieldsMap = new Map<String, Object>();
			fieldsMap.put('title', '*' + settings.get('surveyName') + '*');
			fieldsMap.put('value', settings.get('surveyUrl'));
			fieldsMap.put('short', false);
			fieldsList.add(fieldsMap);

			String preText = 'New Survey from *' + settings.get('contactEmail') + '*';
			if (settings.containsKey('caseNumber')) {
				preText =
					'New Survey for Case *' +
					settings.get('caseNumber') +
					'* from *' +
					settings.get('contactEmail') +
					'*';

				Map<String, Object> fieldsMap2 = new Map<String, Object>();
				fieldsMap2.put('title', '*' + settings.get('caseSubject') + '*');
				fieldsMap2.put('value', settings.get('caseUrl'));
				fieldsMap2.put('short', false);
				fieldsList.add(fieldsMap2);
			}

			for (Map<String, String> field : fields) {
				Map<String, Object> fieldsMap3 = new Map<String, Object>();
				fieldsMap3.put('title', '*' + field.get('field_label') + '*');
				fieldsMap3.put('value', field.get('field_value'));
				fieldsMap3.put('short', false);
				fieldsList.add(fieldsMap3);
			}

			// mark down
			List<String> mrkdwnList = new List<String>();
			mrkdwnList.add('text');
			mrkdwnList.add('pretext');

			Map<String, Object> attInternalMap = new Map<String, Object>();
			attInternalMap.put('mrkdwn_in', mrkdwnList);
			attInternalMap.put('fallback', preText);
			attInternalMap.put('pretext', preText);
			attInternalMap.put('color', '#D00000');
			attInternalMap.put('fields', fieldsList);

			List<Map<String, Object>> attInternalList = new List<Map<String, Object>>();
			attInternalList.add(attInternalMap);

			// Setup Json for Slack post
			JSONGenerator gen = JSON.createGenerator(true);
			gen.writeStartObject();
			gen.writeStringField('channel', settings.get('slackId'));
			gen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			gen.writeFieldName('attachments');
			gen.writeObject(attInternalList);
			gen.writeEndObject();
			String body = gen.getAsString();

			if (!Test.isRunningTest()) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', body));
			}
		} catch (Exception e) {
			System.debug('sendAlertSlack: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	public class qCallOut implements System.Queueable, Database.AllowsCallouts {
		private final String url;
		private final String method;
		private final String body;

		public qCallOut(String url, String method, String body) {
			this.url = url;
			this.method = method;
			this.body = body;
		}

		public void execute(System.QueueableContext ctx) {
			HttpRequest req = new HttpRequest();
			req.setEndpoint(url);
			req.setMethod(method);
			req.setBody(body);
			Http http = new Http();
			HttpResponse res = http.send(req);
		}
	}
}