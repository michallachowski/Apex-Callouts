public with sharing class AC_HTTPRequestUtils {

    @future (callout = true)
    public static void processHTTPRequestInFuture(Id requestId) {
        AC_HTTP_Request__c obj = [
            SELECT Id, Name, Status__c, URL__c, JSON_Request__c, JSON_Response__c
            FROM AC_HTTP_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        if (null == obj) {
            return;
        }

        PolSource_RestConnector conn = new PolSource_RestConnector();
        String response = conn.makeCallout('POST', obj.JSON_Request__c, obj.URL__c);

        obj.Status__c = 'Completed';
        obj.JSON_Response__c = JSON.serializePretty(
            JSON.deserializeUntyped(response)
        );

        update obj;
    }

}