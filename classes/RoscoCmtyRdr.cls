public with sharing class RoscoCmtyRdr {

    @AuraEnabled
    public static String getRdrUrl(String url){
        
        String ret = 'https://support.tanium.com'; //bump
    
        try {

            
            System.debug('incoming url:' + url);

            List<String> lUrl = url.split('/');

            // Base Cmty Url
            String baseUrl = 'https:/';
            for(String s : lUrl){
                
                System.debug('s:' + s + '(size:' + s.length() + ')');
                
                if(s == 's'){
                    baseUrl += '/' + s;
                    break;
                } else if( s == 'https:' || s.length() == 0 || s == null){
                    //skip
                } else {
                    baseUrl += '/' + s;
                }
            }
            System.debug('baseUrl:' + baseUrl);

            String last = lUrl[lUrl.size()-1];
            
            System.debug('incoming url last:' + last);

            if(last.contains('?')){
                List<String> lLast = last.split('[?]');
                if( lLast.size() == 2){
            
                    String sKbUrlorNumber = lLast[1];
                    System.debug('sKbUrlorNumber:' + sKbUrlorNumber);

                    String kbType = RoscoCmtyNoShare.getKBRecordType(sKbUrlorNumber);
                    if( (kbType == 'Support Article') || (kbType == 'Tanium Vulnerability') ){
                        ret = baseUrl + '/support-home?kburl=' + sKbUrlorNumber;
                    } else {
                        ret = baseUrl + '/article/' + sKbUrlorNumber;
                    }
            
            
                }
            }            
                    
        } catch (Exception e) {
            System.debug('getRdrUrl: ' + e.getMessage() + '\n' + e.getStackTraceString() );
        }               

        return ret;            
    }      
    
    @AuraEnabled
    public static String getKBArticleId(String urlName){
        
        String ret = '';
    
        try {

            ret = RoscoCmtyNoShare.getKBArticleId(urlName);
                    
        } catch (Exception e) {
            System.debug('getKBArticleId: ' + e.getMessage() + '\n' + e.getStackTraceString() );
        }               

        return ret;            
    }          
}