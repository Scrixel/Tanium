public with sharing class KnowledgeNewsCombinedController {
    private static final String PUBLISH_STATUS_ONLINE = 'Online';

    @AuraEnabled
    public static ActionResult fetchKnowledgeNewsArticles(Integer pageNumber, Integer recordsPerPage,
            String dataCategoryGroupUniqueName) {
        ActionResult result = new ActionResult();
        try {
            final Integer TOTAL_KA_RECORDS = getTotalKnowledgeArticles(dataCategoryGroupUniqueName);
            final Integer TOTAL_NEWS_RECORDS = getTotalNewsArticles();
            final Integer RECORD_OFFSET = (pageNumber - 1) * recordsPerPage;
            final Integer TOTAL_PAGES = computeTotalPages(TOTAL_KA_RECORDS + TOTAL_NEWS_RECORDS, recordsPerPage);
            final String[] kaFields = new String[] {
                                         'Title', 'RecordType.Name', 'FirstPublishedDate', 'Summary', 'UrlName',
                                         'Blog_Author__r.Name'
                                     };
            final String[] newsFields = new String[] {
                                        'Name', 'RecordTypeId', 'Publish_DateTime__c', 'Details__c', 'Id',
                                        'Author__r.Name'
                                    };

            // For now, fetch first X Knowledge and News articles published within the last Y days
            //      Once both are fetched, join and use OFFSET against the merged/sorted data
            List<Knowledge__kav> listKa = queryKnowledgeArticles(kaFields, dataCategoryGroupUniqueName, 100, 0, 90);
            List<X7S_News__c> listNews = queryNewsArticles(newsFields, 100, 0, 90);
            // Get Attachments for news articles
            List<Attachment> newsAttachments = queryNewsAttachments(listNews);

            Integer kaIdx = 0;
            Integer newsIdx = 0;
            Integer offsetIdx = RECORD_OFFSET - 1;
            List<Object> mergedResult = new List<Object>();
            while (mergedResult.size() < recordsPerPage) {
                // First we need to progress the pointers to meet the expected offset
                //      Then, we'll begin adding to mergedResult
                if (kaIdx < listKa.size() && newsIdx < listNews.size()) {
                    if (listKa[kaIdx].FirstPublishedDate >= listNews[newsIdx].Publish_DateTime__c) {
                        if (kaIdx + newsIdx < offsetIdx) { ++kaIdx; }
                        else { mergedResult.add(listKa[kaIdx++]); }
                    } else {
                        if (kaIdx + newsIdx < offsetIdx) { ++newsIdx; }
                        else { mergedResult.add(listNews[newsIdx++]); }
                    }
                } else if (kaIdx < listKa.size()) {
                    if (kaIdx + newsIdx < offsetIdx) { ++kaIdx; }
                    else { mergedResult.add(listKa[kaIdx++]); }
                } else if (newsIdx < listNews.size()) {
                    if (kaIdx + newsIdx < offsetIdx) { ++newsIdx; }
                    else { mergedResult.add(listNews[newsIdx++]); }
                } else {
                    break;
                }
            }

            Map<String, Object> mapData = new Map<String, Object> {
                'mergedArticles' => mergedResult,
                'newsAttachments' => newsAttachments,
                'totalPages' => TOTAL_PAGES
            };

            result.setSuccess(mapData);
        } catch (Exception e) {
            result.setFailure(e);
            logException(e);
        }

        return result;
    }

    private static List<Knowledge__kav> queryKnowledgeArticles(String[] fields, String dataCategoryGroupUniqueName,
            Integer recordsPerPage, Integer recordOffset, Integer lookbackDays) {
        List<String> listKAPublishStatus = new List<String> { PUBLISH_STATUS_ONLINE };
        String dataCategoryGroupFilter = buildDataCategoryGroupFilter(dataCategoryGroupUniqueName);

        final String kaQuery = 'SELECT ' + String.join(fields, ', ')
                             + ', (SELECT toLabel(DataCategoryName) FROM DataCategorySelections)'
                             + ' FROM Knowledge__kav'
                             + ' WHERE PublishStatus = :PUBLISH_STATUS_ONLINE'
                             + ' AND FirstPublishedDate >= LAST_N_DAYS:' + lookbackDays + 
                             + (String.isBlank(dataCategoryGroupFilter) ? '' : dataCategoryGroupFilter)
                             + ' ORDER BY FirstPublishedDate DESC'
                             + ' LIMIT ' + recordsPerPage
                             + ' OFFSET ' + recordOffset;
        
        System.debug('\n kaQuery: ' + kaQuery);
        List<Knowledge__kav> listKnowledgeArticle = Database.query(kaQuery);

        return listKnowledgeArticle;
    }

    private static List<X7S_News__c> queryNewsArticles(String[] fields, Integer recordsPerPage, Integer recordOffset, Integer lookbackDays) {
        final String newsQuery = 'SELECT ' + String.join(fields, ', ')
                               + ' FROM X7S_News__c'
                               + ' WHERE Publish_DateTime__c >= LAST_N_DAYS:' + lookbackDays + ' AND'
                               + ' (Archive_DateTime__c > TODAY OR Archive_DateTime__c=NULL)'
                               + ' ORDER BY Publish_DateTime__c DESC'
                               + ' LIMIT ' + recordsPerPage
                               + ' OFFSET ' + recordOffset;
            
        System.debug('\n newsQuery: ' + newsQuery);
        List<X7S_News__c> listNewsArticle = Database.query(newsQuery);

        return listNewsArticle;
    }

    private static List<Attachment> queryNewsAttachments(List<X7S_News__c> newsArticles) {
        final List<String> newsIds = new List<String>();
        for (Integer i = 0; i < newsArticles.size(); ++i) {
            newsIds.add(newsArticles[i].id);
        }

        return [
            SELECT Id,ParentId,Name FROM Attachment WHERE ParentId IN :newsIds
        ];
    }

    private static Integer getTotalKnowledgeArticles(String dataCategoryGroupUniqueName) {
        List<String> listPublishStatus = new List<String> { PUBLISH_STATUS_ONLINE };
        String dataCategoryGroupFilter = buildDataCategoryGroupFilter(dataCategoryGroupUniqueName);

        String kaCountQuery = 'SELECT COUNT() FROM Knowledge__kav'
                              + (listPublishStatus.isEmpty() ? '' : ' WHERE PublishStatus IN :listPublishStatus')
                              + (String.isBlank(dataCategoryGroupFilter) ? '' : dataCategoryGroupFilter);

        System.debug('\n kaCountQuery: ' + kaCountQuery);
        Integer kaCount = Database.countQuery(kaCountQuery);
        return kaCount;
    }

    private static Integer getTotalNewsArticles() {
        Integer newsCount = [
            SELECT COUNT() FROM X7S_News__c
            WHERE Publish_DateTime__c <=: DateTime.now() AND
            (Archive_DateTime__c >: DateTime.now() OR Archive_DateTime__c=NULL)
        ];

        return newsCount;
    }

    private static String buildDataCategoryGroupFilter(String dataCategoryGroupUniqueName) {
        String dataCategorySOQLFilter;
        if(String.isNotBlank(dataCategoryGroupUniqueName)) {
            dataCategoryGroupUniqueName += '__c';
            dataCategorySOQLFilter = ' WITH DATA CATEGORY ' + dataCategoryGroupUniqueName + ' BELOW ALL__c';
        }

        return dataCategorySOQLFilter;
    }

    private static Integer computeTotalPages(Integer totalRecords, Integer recordsPerPage) {
        Integer totalPages = totalRecords / recordsPerPage;
        totalPages += Math.mod(totalRecords, recordsPerPage) > 0 ? 1 : 0;
        return totalPages;
    }

    public static void logException(Exception ex) {
        System.debug('\n Error:' + ex.getMessage()
                     + '\n Stack Trace:' + ex.getStackTraceString());
    }
    
    public class ActionResult {
        @AuraEnabled
        public Boolean isSuccess;
        
        @AuraEnabled
        public String error;
        
        @AuraEnabled
        public Object data;
        
        public void setSuccess(Map<String, Object> mapData) {
            isSuccess = true;
            error = null;
            data = mapData;
        }

        public void setFailure(String errorMessage) {
            isSuccess = false;
            error = errorMessage;
            data = null;
        }

        public void setFailure(Exception ex) {
            isSuccess = false;
            error = ex.getMessage();
            data = new Map<String, String> {
                        'errorDetails' => ex.getStackTraceString()
                    };
        }
    }
}