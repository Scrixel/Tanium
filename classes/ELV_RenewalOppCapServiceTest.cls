@IsTest
private class ELV_RenewalOppCapServiceTest {
 @IsTest static void selectsLowestCapAndZero(){
  List<Ruby__Subscription__c> sources=new List<Ruby__Subscription__c>{
   new Ruby__Subscription__c(ELV_Contracted_Renewal_Uplift_Percent__c=5),
   new Ruby__Subscription__c(ELV_Contracted_Renewal_Uplift_Percent__c=4.5),
   new Ruby__Subscription__c(ELV_Contracted_Renewal_Uplift_Percent__c=0),
   new Ruby__Subscription__c()
  };
  System.assertEquals(0,ELV_RenewalOppCapService.lowestPopulatedCap(sources));
 }
 @IsTest static void leavesNoCapBlank(){
  System.assertEquals(null,ELV_RenewalOppCapService.lowestPopulatedCap(new List<Ruby__Subscription__c>{new Ruby__Subscription__c(),new Ruby__Subscription__c()}));
 }
}