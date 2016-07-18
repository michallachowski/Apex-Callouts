/**
 * Class AC_FormHandler
 *
 * Trigger Handler for the Account SObject. This class implements the ITrigger
 * interface to help ensure the trigger code is bulkified and all in one place.
 */
public with sharing class AC_FormHandler implements ITrigger {	
	Map<String, AC_Form_Setting__mdt> settingsMap = new Map<String, AC_Form_Setting__mdt>();
	List<AC_Error_Log__c> errorLogs = new List<AC_Error_Log__c>();
	List<AC_HTTP_Request__c> requestsToInsert = new List<AC_HTTP_Request__c>();
	List<AC_Work_Item__c> workitemsToInsert = new List<AC_Work_Item__c>();
	List<Approval.Processsubmitrequest> requests = new List<Approval.Processsubmitrequest>();

	// Constructor
	public AC_FormHandler() {

	}

	public void bulkBefore() {
	}
	
	public void bulkAfter() {
		List<AC_Form_Setting__mdt> settings = [SELECT MasterLabel, HTTP_Request_Required__c, Work_Item_required__c FROM AC_Form_Setting__mdt];
		for (AC_Form_Setting__mdt setting : settings) {
			settingsMap.put(setting.MasterLabel, setting);
		}
	}
		
	public void beforeInsert(SObject so) {
	}
	
	public void beforeUpdate(SObject oldSo, SObject so) {
	}
	
	public void beforeDelete(SObject so) {	
	}
	
	public void afterInsert(SObject so) {
		Approval.Processsubmitrequest req = new Approval.Processsubmitrequest();
		req.setComments('Please approve the following form');
		req.setObjectId(so.Id);

		requests.add(req);
	}
	
	public void afterUpdate(SObject oldSo, SObject so) {
		AC_Form__c oldForm = (AC_Form__c) oldSo;
		AC_Form__c newForm = (AC_Form__c) so;
		if (oldForm.Status__c != 'Approved' && newForm.Status__c == 'Approved') {
			if (settingsMap.get(newForm.Type__c).HTTP_Request_Required__c == true) {
				requestsToInsert.add(new AC_HTTP_Request__c(AC_Form__c = newForm.Id, Status__c = 'Queued'));
			}
			else if (settingsMap.get(newForm.Type__c).Work_Item_required__c == true) {
				workitemsToInsert.add(new AC_Work_Item__c(AC_Form__c = newForm.Id, Status__c = 'Not started'));
			}
		}
	}
	
	public void afterDelete(SObject so) {
	}
	
	public void andFinally() {
		if (requests.isEmpty() == false) {
			try {
				List<Approval.ProcessResult> results = Approval.process(requests);
			}	
			catch (Exception e) {
				//errorLogs.add(new AC_Error_Log__c(Message__c = e.getMessage() + '\n\n' + e.getStackTraceString(), Record_ID__c = so.Id));
			}
		}

		if (errorLogs.isEmpty() == false) {
			insert errorLogs;
		}
		if (requestsToInsert.isEmpty() == false) {
			insert requestsToInsert;
		}
		if (workitemsToInsert.isEmpty() == false) {
			insert workitemsToInsert;
		}
	}
}