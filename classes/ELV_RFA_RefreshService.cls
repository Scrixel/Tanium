/**
 * Forces a supported Nue quote update/recalculation before final validation.
 * The technical DateTime nonce is changed through updateHeaderFields, not raw
 * Quote DML, because the Nue documentation states that raw DML recalculates nothing.
 */
public with sharing class ELV_RFA_RefreshService {
    public class RefreshResult {
        public Boolean success = false;
        public String error;
    }

    public static RefreshResult refresh(Id quoteId) {
        RefreshResult out = new RefreshResult();
        if (quoteId == null) { out.error = 'A Quote Id is required.'; return out; }
        try {
            Ruby.GlobalAPITypes.UpdateQuoteRequest request = new Ruby.GlobalAPITypes.UpdateQuoteRequest();
            request.quoteId = String.valueOf(quoteId);
            request.isCommit = true;
            request.recalc = 'AUTO';
            Ruby.GlobalAPITypes.UpdateAction action = new Ruby.GlobalAPITypes.UpdateAction();
            action.action = 'updateHeaderFields';
            action.payload = new Map<String, Object>{
                'fieldValues' => new Map<String, Object>{
                    'ELV_RFA_Approval_Refresh_At__c' => Datetime.now()
                }
            };
            request.actions = new List<Ruby.GlobalAPITypes.UpdateAction>{ action };
            Ruby.GlobalAPITypes.UpdateQuoteResponse response = Ruby.GlobalQuoteServiceAPI.updateQuote(request);
            String status = String.valueOf(response.status);
            if (status != 'SUCCEED' && status != 'SUCCESS') {
                out.error = 'Nue Update Quote returned status ' + status + '.';
                return out;
            }
            out.success = true;
        } catch (Exception e) {
            out.error = 'Nue Update Quote refresh failed: ' + e.getMessage();
        }
        return out;
    }
}