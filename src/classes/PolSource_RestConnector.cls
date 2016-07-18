public with sharing class PolSource_RestConnector {
     public class PolSource_RestConnectorException extends Exception {}
     
     private String generalEndPoint;
     
     public PolSource_RestConnector () {
        setup();
    }
    
    public void setup() {
        AC_Rest_Settings__c restSettings = AC_Rest_Settings__c.getInstance();

        this.generalEndPoint = restSettings.General_Endpoint__c;
        
        
        if( String.isEmpty(this.generalEndPoint ) ){
            throw new PolSource_RestConnectorException ('AC_Rest_Settings__c setup error.');
        }
    }
    
    public String makeCallout(String method, String requestBody, String endPoint) {
        String result       = '[]';

        Http h              = new Http();
        HttpRequest req     = new HttpRequest();

        req.setMethod(method);
        req.setHeader('Accept', 'application/json');
        req.setHeader('content-type', 'application/json');
        req.setEndpoint(this.generalEndPoint + endPoint);
        req.setBody(requestBody);

        HttpResponse res = h.send(req);
        System.debug(res);
        System.debug(res.getStatusCode());
        System.debug(res.getBody());
        if (200 == res.getStatusCode()) {
            result = res.getBody();
        } else {
            throw new PolSource_RestConnectorException(
                String.format(
                    'Callout error',
                    new List<String>{
                        String.valueOf(res.getStatusCode()),
                        res.getStatus(),
                        res.getBody()
                    }
                    )
            );
        }

        return result;
    }
    
}