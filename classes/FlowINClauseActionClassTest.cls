@IsTest
public with sharing class FlowINClauseActionClassTest {
	@TestSetup
	static void createData() {
		insert new List<Account>{
			new Account(Name = 'A', Rating = 'A'),
			new Account(Name = 'B', Rating = 'B'),
			new Account(Name = 'C', Rating = 'C'),
			new Account(Name = 'D', Rating = 'D'),
			new Account(Name = 'E', Rating = 'E')
		};
	}

	testMethod static void testCloneRecordMethod() {
		FlowINClauseActionClass.FlowInputParameters[] inputList = new List<FlowINClauseActionClass.FlowInputParameters>{};
		FlowINClauseActionClass.FlowOutputParameters[] outputList = new List<FlowINClauseActionClass.FlowOutputParameters>{};

		/* Testing Exception */
		FlowINClauseActionClass.FlowInputParameters invalidInput = new FlowINClauseActionClass.FlowInputParameters();
		invalidInput.objectApiName = 'Acc';
		invalidInput.fieldsToQuery = 'Id,Name,Rating';
		invalidInput.filterField = 'Rating';
		invalidInput.filteringValuesCollection = new List<String>{ 'A', 'B' };
		inputList.add(invalidInput);

		try {
			outputList = FlowINClauseActionClass.filterRecords(inputList);
		} catch (Exception e) {
			System.debug(e.getMessage());
			System.assert(e.getMessage().contains('sObject type \'Acc\' is not supported'));
		}

		inputList.clear();

		/* Preparing Flow Action input list */
		FlowINClauseActionClass.FlowInputParameters input1 = new FlowINClauseActionClass.FlowInputParameters();
		input1.objectApiName = 'Account';
		input1.fieldsToQuery = 'Id,Name,Rating';
		input1.filterField = 'Rating';
		input1.filteringValuesCollection = new List<String>{ 'A', 'B' };

		FlowINClauseActionClass.FlowInputParameters input2 = new FlowINClauseActionClass.FlowInputParameters();
		input2.objectApiName = 'Account';
		input2.fieldsToQuery = 'Id,Name,Rating';
		input2.filterField = 'Rating';
		input2.filteringValuesCollection = new List<String>{ 'C' };

		FlowINClauseActionClass.FlowInputParameters input3 = new FlowINClauseActionClass.FlowInputParameters();
		input3.objectApiName = 'Account';
		input3.fieldsToQuery = 'Id,Name,Rating';
		input3.filterField = 'Rating';
		input3.filteringValuesCollection = new List<String>{ 'D', 'E' };

		inputList.add(input1);
		inputList.add(input2);
		inputList.add(input3);

		Test.startTest();
		outputList = FlowINClauseActionClass.filterRecords(inputList);
		Test.stopTest();

		System.assert(outputList[0].records.size() == 2);
		System.assert(outputList[1].records.size() == 1);
		System.assert(outputList[2].records.size() == 2);
	}
}