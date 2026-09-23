@IsTest
public with sharing class RoscoLogTest {
	@isTest(SeeAllData=false)
	static void Test() {
		RoscoLog.addEntry(
			UserInfo.GetUserId(),
			'type',
			'source',
			1,
			'level',
			'general',
			'details',
			'exMsg',
			'exStackTraceString'
		);
	}
}