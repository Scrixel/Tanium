@isTest
public with sharing class RoscoUserProcessesTest {


    @isTest(SeeAllData=true) static void test_nullOrEmpty() {

        RoscoUserProcesses.nullOrEmpty('foo');
    }


}