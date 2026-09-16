/**
 * @Business: RoscoCoverage
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-10660   2025-05-01    Removed method page plus class cleanup
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 */
public with sharing class RoscoCoverage {
	public List<Map<String, String>> people;

	public static List<Map<String, String>> convertPeopleJsonToObject(String peopleJson) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			RoscoCoverage people1 = (RoscoCoverage) JSON.deserialize(peopleJson, RoscoCoverage.class);

			for (Map<String, String> p : people1.people) {
				if (!nullOrEmpty(p)) {
					Map<String, String> person = new Map<String, String>();

					Boolean bFoundMobile = false;
					for (String key : p.keyset()) {
						person.put(key, String.valueOf(p.get(key)));

						if (key == 'mobile') {
							bFoundMobile = true;
						}
					}
					if (bFoundMobile) {
						ret.add(person);
					}
				}
			}
		} catch (DmlException e) {
			System.debug(
				'convertPeopleJsonToObject:' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}

		return ret;
	}

	@AuraEnabled
	public static Map<String, String> easyAction(String scheduleType, String action, String mobile) {
		Map<String, String> ret = new Map<String, String>();

		try {
			String soql =
				'SELECT Id,Assigned_People__c ' +
				'FROM Rosco_Coverage__c ' +
				'WHERE Schedule_Type__c = \'' +
				scheduleType +
				'\'';

			List<Rosco_Coverage__c> lBlocks = Database.query(soql);

			if (lBlocks.size() != 0) {
				List<Rosco_Coverage__c> lBlocksToUpdate = new List<Rosco_Coverage__c>();

				Map<String, String> myPeep = easyActionPeople(mobile);
				if (myPeep.get('mobile').length() > 0) {
					for (Rosco_Coverage__c lBlock : lBlocks) {
						List<Map<String, String>> currentAssignedPeopleList = new List<Map<String, String>>();

						Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(
							lBlock.Assigned_People__c
						);
						List<Object> people = (List<Object>) results.get('people');
						for (Object peep : people) {
							Map<String, String> currentAssignedPeep = new Map<String, String>();

							Map<String, Object> pAttributes = (Map<String, Object>) peep;
							for (String attributeName : pAttributes.keyset()) {
								currentAssignedPeep.put(
									String.valueOf(attributeName),
									String.valueOf(pAttributes.get(attributeName))
								);
							}
							currentAssignedPeopleList.add(currentAssignedPeep);
						}

						Boolean updateBlock = false;
						myPeep.put('group', 'Triage');
						List<Map<String, String>> newAssignedPeopleList = new List<Map<String, String>>();

						if (action == 'replace') {
							for (Map<String, String> currentAssignedPeep : currentAssignedPeopleList) {
								if (currentAssignedPeep.get('group') != 'Triage') {
									newAssignedPeopleList.add(currentAssignedPeep);
								}
							}
							newAssignedPeopleList.add(myPeep);
							updateBlock = true;
						} else if (action == 'add') {
							Boolean bFound = false;

							for (Map<String, String> currentAssignedPeep : currentAssignedPeopleList) {
								if (currentAssignedPeep.get('group') == 'Triage') {
									if (currentAssignedPeep.get('name') == myPeep.get('name')) {
										bFound = true;
									} else {
										newAssignedPeopleList.add(currentAssignedPeep);
									}
								} else {
									newAssignedPeopleList.add(currentAssignedPeep);
								}
							}

							if (!bFound) {
								newAssignedPeopleList.add(myPeep);
								updateBlock = true;
							}
						} else if (action == 'remove') {
							for (Map<String, String> currentAssignedPeep : currentAssignedPeopleList) {
								if (currentAssignedPeep.get('group') == 'Triage') {
									if (currentAssignedPeep.get('name') == myPeep.get('name')) {
										updateBlock = true;
									} else {
										newAssignedPeopleList.add(currentAssignedPeep);
									}
								} else {
									newAssignedPeopleList.add(currentAssignedPeep);
								}
							}
						}

						if (updateBlock) {
							JSONGenerator newAssignedPeople = JSON.createGenerator(true);
							newAssignedPeople.writeStartObject();
							newAssignedPeople.writeObjectField('people', newAssignedPeopleList);
							newAssignedPeople.writeEndObject();
							lBlock.Assigned_People__c = newAssignedPeople.getAsString();
							lBlocksToUpdate.add(lBlock);
						}
					}
					String userName = getUserName();
					if (lBlocksToUpdate.size() != 0) {
						update lBlocksToUpdate;
						sendEasySaveNotificationToSlack(
							userName +
							' invoked ' +
							action +
							' coverage block action resulting in ' +
							lBlocksToUpdate.size() +
							' records updated'
						);
					} else {
						sendEasySaveNotificationToSlack(
							userName +
							' invoked ' +
							action +
							' coverage block action action - no records required update'
						);
					}
				}
			}
		} catch (DmlException e) {
			System.debug('easyAction:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		ret = getBlockInfo(scheduleType);
		return ret;
	}

	public static Map<String, String> easyActionPeople(String mobile) {
		Map<String, String> ret = new Map<String, String>();

		try {
			String userid = String.valueOf(UserInfo.getUserId());
			String soql =
				'SELECT Name,pod__c,mobile__c ' +
				'FROM rosco_people__c  ' +
				'WHERE user__c = \'' +
				userId +
				'\' ' +
				'LIMIT 1';

			List<rosco_people__c> lPeople = Database.query(soql);

			Boolean updateBlock = false;
			if (lPeople.size() != 0) {
				ret.put('name', lPeople[0].Name);

				if (mobile == '') {
					ret.put('mobile', lPeople[0].mobile__c);
				} else if (mobile != lPeople[0].mobile__c) {
					ret.put('mobile', mobile);
					lPeople[0].mobile__c = mobile;
					updateBlock = true;
				} else {
					ret.put('mobile', mobile);
				}
			} else {
				rosco_people__c newPeep = new rosco_people__c();
				newPeep.name = UserInfo.getName();
				newPeep.mobile__c = mobile;
				newPeep.pod__c = 'Support Center';
				newPeep.user__c = UserInfo.getUserId();
				insert newPeep;

				ret.put('name', UserInfo.getName());
				ret.put('mobile', mobile);
			}
			if (updateBlock) {
				update lPeople[0];
			}
		} catch (DmlException e) {
			System.debug('easyActionPeople:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static String deleteBlock(String blockStartString, String scheduleType) {
		String ret = 'Error';
		try {
			String soql =
				'SELECT Id ' +
				'FROM Rosco_Coverage__c ' +
				'WHERE Block_start__c = ' +
				blockStartString +
				' ' +
				'AND Schedule_Type__c = \'' +
				scheduleType +
				'\' ' +
				'LIMIT 1';

			List<Rosco_Coverage__c> lBlocks = Database.query(soql);

			if (lBlocks.size() != 0) {
				delete lBlocks;
			}
		} catch (DmlException e) {
			System.debug('deleteBlock:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	public static String getAccountSlackName(String accountId) {
		String ret = 'undetermined';

		try {
			String soql =
				'SELECT Name ' +
				'FROM Rosco_Account__c ' +
				'WHERE account__c = \'' +
				accountId +
				'\'';

			List<Rosco_Account__c> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				for (Rosco_Account__c a : accounts) {
					ret = '#' + String.valueOf(a.Name);
				}
			}
		} catch (Exception e) {
			System.debug('getAccountSlackName: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	public static String getBlockLength(String blockStartString, String scheduleType) {
		String ret = '0';

		try {
			Datetime blockStartDt = (DateTime) JSON.deserialize(
				'"' +
				blockStartString +
				'"',
				DateTime.class
			);
			Decimal start = blockStartDt.getTime() / 1000 / 60 / 60;

			String soql =
				'SELECT Block_start__c ' +
				'FROM Rosco_Coverage__c ' +
				'WHERE Block_start__c > ' +
				blockStartString +
				'AND Schedule_Type__c = \'' +
				scheduleType +
				'\' ' +
				'LIMIT 1';

			List<Rosco_Coverage__c> blocks = Database.query(soql);

			if (blocks.size() != 0) {
				Decimal stop = blocks[0].Block_start__c.getTime() / 1000 / 60 / 60;
				ret = String.valueOf(stop - start);
			}
		} catch (DmlException e) {
			System.debug('getBlockLength:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getBlocks(
		String blockdate,
		String blocktype,
		String blockpod,
		String scheduleType
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			Datetime minDt = DateTime.Now().AddDays(-1);
			Datetime maxDT = DateTime.Now().AddDays(1000);
			if (blockdate == '90') {
				maxDT = DateTime.Now().AddDays(90);
			} else if (blockdate == 'Q1FY22') {
				minDt = DateTime.newInstance(2022, 2, 1, 0, 0, 0);
				maxDt = DateTime.newInstance(2022, 5, 1, 9, 0, 0);
			} else if (blockdate == 'Q2FY22') {
				minDt = DateTime.newInstance(2022, 5, 1, 1, 0, 0);
				maxDt = DateTime.newInstance(2022, 8, 1, 9, 0, 0);
			} else if (blockdate == 'Q3FY22') {
				minDt = DateTime.newInstance(2022, 8, 1, 0, 0, 0);
				maxDt = DateTime.newInstance(2022, 11, 1, 9, 0, 0);
			} else if (blockdate == 'Q4FY22') {
				minDt = DateTime.newInstance(2022, 10, 31, 0, 0, 0);
				maxDt = DateTime.newInstance(2023, 2, 1, 9, 0, 0);
			} else if (blockdate == 'FY22') {
				minDt = DateTime.newInstance(2022, 2, 1, 0, 0, 0);
				maxDt = DateTime.newInstance(2023, 2, 1, 9, 0, 0);
			}
			String minDtStr = minDt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
			String maxDtStr = maxDt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

			String soql =
				'SELECT Block_start__c,' +
				'Type__c,' +
				'Assigned_Group__c,' +
				'Assigned_People__c,' +
				'Comment__c, ' +
				'Business_Hour__c, ' +
				'Pager__c, ' +
				'Flag__c ' +
				'FROM Rosco_Coverage__c ' +
				'WHERE Block_start__c > ' +
				minDtStr +
				' ' +
				'AND Block_start__c < ' +
				maxDtStr +
				' ' +
				'AND Schedule_Type__c = \'' +
				scheduleType +
				'\' ' +
				'ORDER BY Block_start__c ASC';

			List<Rosco_Coverage__c> blocks = Database.query(soql);
			for (Integer i = 0; i < blocks.size(); i++) {
				Rosco_Coverage__c b = blocks[i];

				Map<String, String> block = new Map<String, String>();
				block.put('type', String.valueOf(b.Type__c));
				block.put('comment', String.valueOf(b.Comment__c));
				block.put('pager', String.valueOf(b.Pager__c));
				block.put('businessHour', String.valueOf(b.Business_Hour__c));

				Datetime jst = b.Block_start__c.addHours(9);
				block.put('startJST', 'JST:' + jst.format('EEE, MMM d - h a'));
				block.put(
					'startCET',
					'CET: ' + b.Block_start__c.format('EEE, MMM d - h a', 'Europe/Paris')
				);
				block.put('start', 'UTC:' + b.Block_start__c.format('EEE, MMM d - h a'));
				block.put(
					'startET',
					'ET: ' + b.Block_start__c.format('EEE, MMM d - h a', 'America/New_York')
				);
				block.put(
					'startCT',
					'CT: ' + b.Block_start__c.format('EEE, MMM d - h a', 'America/Chicago')
				);
				block.put(
					'startPT',
					'PT: ' + b.Block_start__c.format('EEE, MMM d - h a', 'America/Los_Angeles')
				);
				String startString = b.Block_start__c.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
				block.put('startString', startString);

				String flagged = String.valueOf(b.Flag__c);
				if ((flagged == null) || (flagged == '')) {
					flagged = 'false';
				}
				block.put('flag', flagged);

				String assignedGroup = String.valueOf(b.Assigned_Group__c);
				if ((assignedGroup == null) || assignedGroup == '') {
					assignedGroup = 'Unassigned';
				}
				block.put('group', assignedGroup);

				String assignedPeople = String.valueOf(b.Assigned_People__c);
				if ((assignedPeople == null) || assignedPeople == '') {
					List<Map<String, String>> aList = new List<Map<String, String>>();
					JSONGenerator gen = JSON.createGenerator(true);
					gen.writeStartObject();
					gen.writeObjectField('people', aList);
					gen.writeEndObject();
					assignedPeople = gen.getAsString();
				}
				block.put('people', String.valueOf(assignedPeople));

				Integer blockTriageCount = 0;
				if (blocktype.contains('(help needed)')) {
					List<Map<String, String>> people = convertPeopleJsonToObject(assignedPeople);
					for (Map<String, String> person : people) {
						if ('Triage' == person.get('group')) {
							blockTriageCount += 1;
						}
					}
				}

				if (i + 1 != blocks.size()) {
					Decimal start = blocks[i].Block_start__c.getTime() / 1000 / 60 / 60;
					Decimal stop = blocks[i + 1].Block_start__c.getTime() / 1000 / 60 / 60;
					Decimal length = stop - start;
					block.put('length', String.valueOf(length));

					Boolean matchBlockType = true;
					if (blocktype != 'All Types') {
						if ((blockType == 'Flagged') && (flagged != 'true')) {
							matchBlockType = false;
						}
						if ((blocktype == 'Non Standard') && (b.Type__c == 'Standard')) {
							matchBlockType = false;
						}
						if (blocktype == 'Non Standard (help needed)') {
							if (b.Type__c == 'Standard') {
								matchBlockType = false;
							} else if (blockTriageCount >= 2) {
								matchBlockType = false;
							}
						}
						if ((blocktype == 'Standard') && (b.Type__c != 'Standard')) {
							matchBlockType = false;
						}
					}

					if (b.Block_start__c < maxDT) {
						if (
							(matchBlockType == true) &&
							((blockpod == 'All Pods') || (assignedGroup == blockpod))
						) {
							ret.add(block);
						}
					}
				}
			}
		} catch (DmlException e) {
			System.debug('getBlocks:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getBlocksAvailable(String scheduleType) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String soql =
				'SELECT Block_start__c ' +
				'FROM Rosco_Coverage__c ' +
				'WHERE Schedule_Type__c = \'' +
				scheduleType +
				'\'';

			List<Datetime> existingBlocks = new List<Datetime>();
			List<Rosco_Coverage__c> oRs = Database.query(soql);
			for (Rosco_Coverage__c r : oRs) {
				existingBlocks.add(r.Block_start__c);
			}

			DateTime dtnow = DateTime.now();
			DateTime dt = DateTime.newInstance(
				dtnow.yearGMT(),
				dtnow.monthGMT(),
				dtnow.dayGmt(),
				dtnow.hourGMT(),
				0,
				0
			);

			DateTime stopdt = dtnow.addDays(120);
			while (dt < stopdt) {
				if (!existingBlocks.contains(dt)) {
					Map<String, String> block = new Map<String, String>();

					Datetime jst = dt.addHours(9);
					block.put('startJST', 'JST:' + jst.format('EEE, MMM d - h a'));
					block.put('startCET', 'CET: ' + dt.format('EEE, MMM d - h a', 'Europe/Paris'));
					block.put('start', 'UTC:' + dt.format('EEE, MMM d - h a'));
					block.put('startET', 'ET: ' + dt.format('EEE, MMM d - h a', 'America/New_York'));
					block.put('startCT', 'CT: ' + dt.format('EEE, MMM d - h a', 'America/Chicago'));
					block.put('startPT', 'PT: ' + dt.format('EEE, MMM d - h a', 'America/Los_Angeles'));
					String startString = dt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
					block.put('startString', startString);
					block.put('type', 'Ad Hoc');
					block.put('comment', '');
					block.put('group', 'Unassigned');
					block.put('people', '');
					ret.add(block);
				}

				dt = dt.addHours(1);
			}
		} catch (DmlException e) {
			System.debug('getBlocksAvailable:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static Map<String, String> getBlockInfo(String scheduleType) {
		Map<String, String> ret = new Map<String, String>();

		try {
			String soql =
				'SELECT Assigned_People__c,Pager__c,Block_start__c ' +
				'FROM Rosco_Coverage__c ' +
				'WHERE Schedule_Type__c = \'' +
				scheduleType +
				'\' ' +
				'ORDER BY Block_start__c DESC';

			List<Rosco_Coverage__c> oRs = Database.query(soql);

			Datetime rn = system.now();
			Rosco_Coverage__c currentBlock = new Rosco_Coverage__c();
			Rosco_Coverage__c nextBlock = new Rosco_Coverage__c();

			for (Rosco_Coverage__c r : oRs) {
				if (r.Block_start__c < rn) {
					currentBlock = r;
					break;
				} else {
					nextBlock = r;
				}
			}

			ret.put('utcTime', rn.formatGMT('yyyy-MM-dd\' \'HH:mm.ss'));

			if (currentBlock.Pager__c == 'true') {
				if (currentBlock.Assigned_People__c != null) {
					List<Map<String, String>> people = convertPeopleJsonToObject(
						String.valueOf(currentBlock.Assigned_People__c)
					);
					if (people != null) {
						String peopleText = '';
						for (Map<String, String> person : people) {
							if ('Triage' == person.get('group')) {
								if (peopleText == '') {
									peopleText = person.get('name');
								} else {
									peopleText = peopleText + ' and ' + person.get('name');
								}
							}
						}
						if (peopleText == '') {
							ret.put(
								'current',
								'Started at ' +
								String.valueOf(currentBlock.Block_start__c) +
								' and has paging enabled but nobody is defined as on triage.'
							);
						} else {
							ret.put(
								'current',
								'Started at ' +
								String.valueOf(currentBlock.Block_start__c) +
								' and is set to page ' +
								peopleText +
								'.'
							);
						}
					} else {
						ret.put(
							'current',
							'Started at ' +
							String.valueOf(currentBlock.Block_start__c) +
							' and has paging enabled but nobody is identified as on call.'
						);
					}
				} else {
					ret.put(
						'current',
						'Started at ' +
						String.valueOf(currentBlock.Block_start__c) +
						' and has paging enabled but nobody is assigned on call.'
					);
				}
			} else {
				ret.put(
					'current',
					'Started at ' +
					String.valueOf(currentBlock.Block_start__c) +
					' and does not having paging enabled.'
				);
			}

			if (nextBlock.Pager__c == 'true') {
				if (nextBlock.Assigned_People__c != null) {
					List<Map<String, String>> people = convertPeopleJsonToObject(
						String.valueOf(nextBlock.Assigned_People__c)
					);

					if (people != null) {
						String peopleText = '';
						for (Map<String, String> person : people) {
							if ('Triage' == person.get('group')) {
								if (peopleText == '') {
									peopleText = person.get('name');
								} else {
									peopleText = peopleText + ' and ' + person.get('name');
								}
							}
						}
						if (peopleText == '') {
							ret.put(
								'next',
								'Starts at ' +
								String.valueOf(nextBlock.Block_start__c) +
								' and has paging enabled but nobody is defined as on triage.'
							);
						} else {
							ret.put(
								'next',
								'Starts at ' +
								String.valueOf(nextBlock.Block_start__c) +
								' and is set to page ' +
								peopleText +
								'.'
							);
						}
					} else {
						ret.put(
							'next',
							'Starts at ' +
							String.valueOf(nextBlock.Block_start__c) +
							' and has paging enabled but nobody is identified as on call.'
						);
					}
				} else {
					ret.put(
						'next',
						'Starts at ' +
						String.valueOf(nextBlock.Block_start__c) +
						' and has paging enabled but nobody is assigned on call.'
					);
				}
			} else {
				ret.put(
					'next',
					'Starts at ' +
					String.valueOf(nextBlock.Block_start__c) +
					' and does not having paging enabled.'
				);
			}
		} catch (DmlException e) {
			System.debug('getBlockInfo:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getPeople() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String soql =
				'SELECT Name,' +
				'mobile__c,' +
				'pod__c ' +
				'FROM rosco_people__c ' +
				'ORDER BY Name ASC';

			List<rosco_people__c> people = Database.query(soql);
			for (Integer i = 0; i < people.size(); i++) {
				rosco_people__c p = people[i];
				String name = '';
				if (p.Name != null) {
					name = p.Name;
				}
				String mobile = '';
				if (p.mobile__c != null) {
					mobile = p.mobile__c;
				}
				String pod = '';
				if (p.pod__c != null) {
					pod = p.pod__c;
				}
				Map<String, String> peep = new Map<String, String>();
				peep.put('name', name);
				peep.put('pod', pod);
				peep.put('mobile', mobile);
				ret.add(peep);
			}
		} catch (DmlException e) {
			System.debug('getPeople:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	public static Map<String, String> getPeopleOnCall(String scheduleType) {
		Map<String, String> ret = new Map<String, String>();

		try {
			Datetime rn = system.now();
			scheduleType = 'Support Center';
			String soql =
				'SELECT Assigned_People__c,Pager__c,Block_start__c ' +
				'FROM Rosco_Coverage__c ' +
				'WHERE Block_start__c	< ' +
				rn.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') +
				'AND Schedule_Type__c = \'' +
				scheduleType +
				'\' ' +
				'ORDER BY Block_start__c DESC LIMIT 1';

			List<Rosco_Coverage__c> oRs = Database.query(soql);
			List<Map<String, String>> people;
			for (Rosco_Coverage__c r : oRs) {
				if (r.Pager__c == 'true') {
					if (r.Assigned_People__c != null) {
						people = convertPeopleJsonToObject(String.valueOf(r.Assigned_People__c));
						if (people != null) {
							for (Map<String, String> person : people) {
								if (!nullOrEmpty(person.get('mobile'))) {
									if ('Triage' == person.get('group')) {
										ret.put(person.get('name'), person.get('mobile'));
									} else if ('Overwatch' == person.get('group')) {
										ret.put(person.get('name') + ' (Overwatch)', person.get('mobile'));
									}
								}
							}
						}
					}
				}
			}
		} catch (DmlException e) {
			System.debug('getPeopleOnCall:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static List<String> getTeams() {
		List<String> ret = new List<String>();
		ret.add('Triage');
		ret.add('Overwatch');
		ret.add('Not Available');

		try {
			String soql =
				'SELECT Name' +
				' FROM TAM_Team__c' +
				' WHERE SME_Component_Name__c != null' +
				' ORDER BY Name ASC NULLS LAST';

			List<TAM_Team__c> aTeams = Database.query(soql);

			if (aTeams.size() != 0) {
				for (TAM_Team__c aTeam : aTeams) {
					ret.add(aTeam.Name);
				}
			}
		} catch (DmlException e) {
			System.debug('getTeams:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static String getUserName() {
		String ret = '';

		try {
			String userId = UserInfo.getUserId();
			if ((userId != '') && (userId != null)) {
				String soql = 'SELECT Name FROM rosco_people__c WHERE user__c = \'' + userId + '\'';
				List<rosco_people__c> people = Database.query(soql);
				for (rosco_people__c p : people) {
					ret = p.Name;
				}
			}
		} catch (DmlException e) {
			System.debug('getUserName:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static String getUserPhone() {
		String ret = '';

		try {
			String userId = UserInfo.getUserId();
			if ((userId != '') && (userId != null)) {
				String soql =
					'SELECT mobile__c FROM rosco_people__c WHERE user__c = \'' +
					userId +
					'\'';

				List<rosco_people__c> people = Database.query(soql);
				for (rosco_people__c p : people) {
					if (p.mobile__c != null) {
						ret = p.mobile__c;
					}
				}
			}
		} catch (DmlException e) {
			System.debug('getUserPhone:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static String getUserPod() {
		String ret = '';
		try {
			String userId = UserInfo.getUserId();
			String soql = 'SELECT pod__c FROM rosco_people__c WHERE user__c = \'' + userId + '\'';
			List<rosco_people__c> people = Database.query(soql);

			for (rosco_people__c p : people) {
				ret = p.pod__c;
			}
		} catch (DmlException e) {
			System.debug('getUserName:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@InvocableMethod(label='Send Case to Coverage Pager')
	public static void processCase(List<Case> cases) {
		try {
			Case aCase = cases[0];
			String coverageType = 'Field TAM';
			String soql =
				'SELECT Support_Model__c ' +
				'FROM Account ' +
				'WHERE Id = \'' +
				aCase.AccountId +
				'\' ' +
				'LIMIT 1';

			List<Account> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				if (accounts[0].Support_Model__c != null) {
					String supportModel = String.valueOf(accounts[0].Support_Model__c);
					if (supportModel.containsIgnoreCase('Support Center')) {
						coverageType = 'Support Center';
					}
				}
			}

			Boolean somebodypaged = false;
			String accountSlackName = getAccountSlackName(aCase.AccountId);
			String sev = String.valueOf(aCase.Severity_Community__c).left(1);
			String smsOnCallText =
				'Tanium Oncall Support: ' +
				'Severity ' +
				sev +
				' ' +
				aCase.CaseNumber +
				' opened by ' +
				accountSlackName +
				', please respond in #triage_tickets ';
			String smsAccountText =
				'Tanium Account Team FYI: ' +
				'Severity ' +
				sev +
				' ' +
				aCase.CaseNumber +
				' opened by ' +
				accountSlackName;
			String smsOverwatchText =
				'Tanium Overwatch FYI: ' +
				'Severity ' +
				sev +
				' ' +
				aCase.CaseNumber +
				' opened by ' +
				accountSlackName;
			if (coverageType == 'Support Center') {
				smsOnCallText =
					'Tanium Oncall Support: ' +
					'Severity ' +
					sev +
					' ' +
					aCase.CaseNumber +
					' opened, please respond in #support_center-tickets ';
				smsAccountText = '';
				smsOverwatchText =
					'Tanium Overwatch FYI: ' +
					'Severity ' +
					sev +
					' ' +
					aCase.CaseNumber +
					' opened';
			}
			String slackSOAText =
				'Page Activity for Severity ' +
				sev +
				' ' +
				aCase.CaseNumber +
				' opened by ' +
				accountSlackName +
				':```';
			String slackChatText = '';
			if (aCase.Subject.contains('ROSCOTESTCASE')) {
				smsOnCallText += 'ROSCOTESTCASE';
				smsAccountText += 'ROSCOTESTCASE';
				smsOverwatchText += 'ROSCOTESTCASE';
				slackSOAText += 'ROSCOTESTCASE';
				slackChatText += 'ROSCOTESTCASE';
			}

			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			Map<String, String> oncall = getPeopleOnCall(coverageType);
			if (!nullOrEmpty(oncall)) {
				for (String p : oncall.keySet()) {
					if (!nullOrEmpty(p)) {
						if (p.containsIgnoreCase(('Overwatch'))) {
							slackSOAText +=
								'Paged ' +
								p +
								' (overwatch duty) at ' +
								oncall.get(p) +
								' for case ' +
								aCase.caseNumber +
								'\n';
						} else {
							slackSOAText +=
								'Paged ' +
								p +
								' (pager duty) at ' +
								oncall.get(p) +
								' for case ' +
								aCase.caseNumber +
								'\n';
							slackChatText +=
								'Paged @' +
								p +
								' (pager duty) at ' +
								oncall.get(p) +
								' for case ' +
								aCase.caseNumber +
								'\n';
						}
						somebodypaged = true;
					}
				}
			}

			if (somebodypaged) {
				List<String> pageNeeded = new List<String>();

				if (cmfields.contains('rosco_page_always__c')) {
					String numbers = String.valueOf(cm.get('rosco_page_always__c'));

					if (nullOrEmpty(numbers) == false) {
						if (numbers.contains(',')) {
							pageNeeded = numbers.split(',');
						} else {
							pageNeeded.add(numbers);
						}
						for (String n : pageNeeded) {
							slackSOAText += 'Paged Always for ' + aCase.caseNumber + ': ' + n + '\n';
						}
					}
				}

				if (!aCase.Subject.contains('ROSCOTESTCASE')) {
					sendPageNotificationToSlack('soa', slackSOAText + '```', coverageType);
					if (slackChatText != '') {
						sendPageNotificationToSlack(null, slackChatText, coverageType);
					}
				}
			}
		} catch (DmlException e) {
			System.debug('processCase:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	@AuraEnabled
	public static List<Map<String, String>> saveBlock(
		String blockStartString,
		String blockType,
		String blockGroup,
		List<Map<String, String>> blockPeople,
		String blockComment,
		String blockLength,
		String blockPager,
		String blockFlag,
		String refreshBlockDate,
		String refreshBlockType,
		String refreshBlockPod,
		String scheduleType
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			if (blockLength == null) {
				blockLength = getBlockLength(blockStartString, scheduleType);
			}

			String oldAssignedPeople = '{ "people" : [ ] }';
			JSONGenerator gen = JSON.createGenerator(true);
			gen.writeStartObject();
			gen.writeObjectField('people', blockPeople);
			gen.writeEndObject();
			String newAssignedPeople = gen.getAsString();
			String soql =
				'SELECT Id,Assigned_People__c ' +
				'FROM Rosco_Coverage__c ' +
				'WHERE Block_start__c = ' +
				blockStartString +
				' ' +
				'AND Schedule_Type__c = \'' +
				scheduleType +
				'\' ' +
				'LIMIT 1';

			List<Rosco_Coverage__c> lBlocks = Database.query(soql);
			if (lBlocks.size() != 0) {
				oldAssignedPeople = lBlocks[0].Assigned_People__c;
				Rosco_Coverage__c block = lBlocks[0];
				block.Type__c = blockType;
				block.Assigned_Group__c = blockGroup;
				block.Comment__c = blockComment;
				block.Pager__c = blockPager;
				block.Flag__c = blockFlag;
				block.Assigned_People__c = newAssignedPeople;
				block.Schedule_Type__c = scheduleType;
				update block;
			} else {
				Rosco_Coverage__c block = new Rosco_Coverage__c();

				block.Block_start__c = (DateTime) JSON.deserialize(
					'"' +
					blockStartString +
					'"',
					DateTime.class
				);
				block.Type__c = blockType;
				block.Assigned_Group__c = blockGroup;
				block.Comment__c = blockComment;
				block.Pager__c = blockPager;
				block.Flag__c = blockFlag;
				block.Assigned_People__c = newAssignedPeople;
				block.Schedule_Type__c = scheduleType;
				insert block;
			}
			updateRoscoPeople(blockPeople);
			sendSaveNotificationToSlack(
				blockStartString,
				blockType,
				blockGroup,
				newAssignedPeople,
				blockComment,
				blockLength,
				blockPager,
				blockFlag
			);
		} catch (DmlException e) {
			System.debug('saveBlock:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		if (refreshBlockdate != '') {
			ret = getBlocks(refreshBlockdate, refreshBlocktype, refreshBlockpod, scheduleType);
		}
		return ret;
	}

	public static void sendPageNotificationToSlack(
		String channel,
		String chatText,
		String coverageType
	) {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String soaChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String soa = String.valueOf(cm.get('rosco_slack_exceptions__c'));

				if (nullOrEmpty(soa) == false) {
					soaChannel = soa;
				}
			}
			String chatChannel = 'C9MU2B4BA';
			if (coverageType == 'Field TAM') {
				if (cmfields.contains('rosco_slack_chat__c')) {
					String chat = String.valueOf(cm.get('rosco_slack_chat__c'));

					if (nullOrEmpty(chat) == false) {
						chatChannel = chat;
					}
				}
			} else if (coverageType == 'Support Center') {
				chatChannel = 'C01DAP85W3A';

				if (cmfields.contains('rosco_slack_chat_channel_supportcenter__c')) {
					String chat = String.valueOf(cm.get('rosco_slack_chat_channel_supportcenter__c'));

					if (nullOrEmpty(chat) == false) {
						chatChannel = chat;
					}
				}
			}
			if (channel == 'soa') {
				chatChannel = soaChannel;
			}
			String webhookURL = '';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}
			JSONGenerator chatGen = JSON.createGenerator(true);
			chatGen.writeStartObject();
			chatGen.writeStringField('channel', chatChannel);
			chatGen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			chatGen.writeStringField('link_names', 'true');
			chatGen.writeStringField('text', chatText);
			chatGen.writeEndObject();
			String chatBody = chatGen.getAsString();
			if (!chatText.contains('ROSCOTESTCASE')) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', chatBody));
			}
		} catch (Exception e) {
			System.debug(
				'sendPageNotificationToSlack: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	public static void sendSaveNotificationToSlack(
		String blockStartString,
		String blockType,
		String blockGroup,
		String assignedPeople,
		String blockComment,
		String blockLength,
		String blockPager,
		String blockFlag
	) {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String soaChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String soa = String.valueOf(cm.get('rosco_slack_exceptions__c'));
				if (nullOrEmpty(soa) == false) {
					soaChannel = soa;
				}
			}
			String webhookURL = '';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}
			String userName = getUserName();
			String soaText =
				'*' +
				userName +
				' saved coverage block.*\n' +
				'*blockStartString:* ' +
				blockStartString +
				'\n' +
				'*blockType:* ' +
				blockType +
				'\n' +
				'*blockGroup:* ' +
				blockGroup +
				'\n' +
				'*blockComment:* ' +
				blockComment.stripHtmlTags() +
				'\n' +
				'*blockLength:* ' +
				blockLength +
				'\n' +
				'*blockPager:* ' +
				blockPager +
				'\n' +
				'*blockFlag:* ' +
				blockFlag +
				'\n' +
				'*assignedPeople:* ```' +
				assignedPeople +
				'```';
			JSONGenerator soaGen = JSON.createGenerator(true);
			soaGen.writeStartObject();
			soaGen.writeStringField('channel', soaChannel);
			soaGen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			soaGen.writeStringField('text', soaText);
			soaGen.writeEndObject();
			if ((userName != '') && (userName != null)) {
				String soaBody = soaGen.getAsString();
				if (!soaText.contains('ROSCOTESTCASE')) {
					System.enqueueJob(new qCallOut(webhookURL, 'POST', soaBody));
				}
			}
		} catch (Exception e) {
			System.debug(
				'sendSaveNotificationToSlack: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	public static void sendEasySaveNotificationToSlack(String soaText) {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String soaChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String soa = String.valueOf(cm.get('rosco_slack_exceptions__c'));

				if (nullOrEmpty(soa) == false) {
					soaChannel = soa;
				}
			}
			String webhookURL = '';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}
			JSONGenerator soaGen = JSON.createGenerator(true);
			soaGen.writeStartObject();
			soaGen.writeStringField('channel', soaChannel);
			soaGen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			soaGen.writeStringField('text', soaText);
			soaGen.writeEndObject();
			String soaBody = soaGen.getAsString();
			if (!Test.isRunningTest()) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', soaBody));
			}
		} catch (Exception e) {
			System.debug(
				'sendEasySaveNotificationToSlack: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	public static void updateRoscoPeople(List<Map<String, String>> roscoPeople) {
		try {
			for (Map<String, String> p : roscoPeople) {
				String mobile = p.get('mobile');
				String name = p.get('name');
				if (mobile != null) {
					if (mobile != '') {
						String soql =
							'SELECT Id ' +
							'FROM rosco_people__c ' +
							'WHERE Name = \'' +
							name +
							'\' ' +
							'LIMIT 1';

						List<rosco_people__c> lPeople = Database.query(soql);
						if (lPeople.size() != 0) {
							rosco_people__c person = lPeople[0];
							person.mobile__c = mobile;
							update person;
						}
					}
				}
			}
		} catch (DmlException e) {
			System.debug('updateRoscoPeople:' + e.getMessage() + '\n' + e.getStackTraceString());
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