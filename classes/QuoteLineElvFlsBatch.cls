public class QuoteLineElvFlsBatch implements Queueable {
  private String cursor;
  public QuoteLineElvFlsBatch(String c){cursor=c;}
  public void execute(QueueableContext qc){
    Set<Id> p=new Set<Id>{'0PS60000000I52FGAS','0PScc000000WG4rGAG','0PS7V0000000bGRWAY','0PS320000008caSGAQ','0PS60000000aNIeGAM','0PScc000000UUGnGAO'};
    String q='SELECT DurableId,QualifiedApiName,DataType FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName=\'QuoteLineItem\' AND QualifiedApiName LIKE \'ELV%\''+(cursor==null?'':' AND DurableId > \''+String.escapeSingleQuotes(cursor)+'\'')+' ORDER BY DurableId LIMIT 100';
    List<FieldDefinition> ds=Database.query(q); if(ds.isEmpty()) return;
    Set<String> ns=new Set<String>(); Map<String,Boolean> ed=new Map<String,Boolean>();
    for(FieldDefinition d:ds){String n='QuoteLineItem.'+d.QualifiedApiName;ns.add(n);ed.put(n,!String.valueOf(d.DataType).startsWith('Formula'));}
    Map<String,FieldPermissions> old=new Map<String,FieldPermissions>();
    for(FieldPermissions x:[SELECT Id,ParentId,Field,PermissionsRead,PermissionsEdit FROM FieldPermissions WHERE ParentId IN:p AND SObjectType='QuoteLineItem' AND Field IN:ns])old.put(String.valueOf(x.ParentId)+'|'+x.Field,x);
    List<FieldPermissions> ins=new List<FieldPermissions>(),upd=new List<FieldPermissions>();
    for(Id i:p)for(String n:ns){String k=String.valueOf(i)+'|'+n;Boolean e=ed.get(n);if(old.containsKey(k)){FieldPermissions x=old.get(k);if(!x.PermissionsRead||x.PermissionsEdit!=e){x.PermissionsRead=true;x.PermissionsEdit=e;upd.add(x);}}else ins.add(new FieldPermissions(ParentId=i,SObjectType='QuoteLineItem',Field=n,PermissionsRead=true,PermissionsEdit=e));}
    if(!ins.isEmpty())Database.insert(ins,false); if(!upd.isEmpty())Database.update(upd,false);
    System.enqueueJob(new QuoteLineElvFlsBatch(ds[ds.size()-1].DurableId));
  }
}