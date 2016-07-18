/**
 * Class AC_HTTPRequestHandler
 *
 * Trigger Handler for the Account SObject. This class implements the ITrigger
 * interface to help ensure the trigger code is bulkified and all in one place.
 */
public with sharing class AC_HTTPRequestHandler implements ITrigger {
	Map<String, AC_Form_Setting__mdt> settingsMap = new Map<String, AC_Form_Setting__mdt>();

	Map<Id, User> ownersMap = null;
	Map<Id, AC_Form__c> formsMap = null;

	Map<String, String> jsonMap = new Map<String, String>();

	List<AC_Work_Item__c> workitemsToInsert = new List<AC_Work_Item__c>();

	List<String> formsId = new List<String>();
	Map<Id, AC_Form__c> forms = new Map<Id, AC_Form__c>();
	List<AC_Form__c> formsToUpdate = new List<AC_Form__c>();

	// Constructor
	public AC_HTTPRequestHandler() {
		List<AC_Form_Setting__mdt> settings = [SELECT MasterLabel, HTTP_Request_Required__c, REST_Resource_Name__c, Work_Item_required__c FROM AC_Form_Setting__mdt];
		for (AC_Form_Setting__mdt setting : settings) {
			settingsMap.put(setting.MasterLabel, setting);
		}
	}

	public void bulkBefore() {
		Set<Id> ownerIDs = new Set<Id>();
		Set<Id> acFormsIDs = new Set<Id>();
		for (AC_HTTP_Request__c item : (List<AC_HTTP_Request__c>) Trigger.new) {
			ownerIDs.add(item.OwnerID);
			acFormsIDs.add(item.AC_Form__c);
		}

		ownersMap = new Map<Id, User>([SELECT Id, FirstName, LastName FROM User WHERE Id IN :ownerIDs]);
		formsMap = new Map<Id, AC_Form__c>([SELECT Id, Comments__c, Admin_Access__c  FROM AC_Form__c WHERE Id IN :acFormsIDs]);
	}
	
	public void bulkAfter() {
		for (SObject so : Trigger.new) {
			formsId.add(String.valueOf(so.get('AC_Form__c')));
		}
		forms = new Map<Id, AC_Form__c>([SELECT Id, Status__c FROM AC_Form__c WHERE Id IN :formsId]);
	}
		
	public void beforeInsert(SObject so) {
		AC_HTTP_Request__c newRequest = (AC_HTTP_Request__c) so;

		User owner = ownersMap.get(newRequest.OwnerID);
		AC_Form__c form = formsMap.get(newRequest.AC_Form__c);

		if (settingsMap.get(newRequest.Type__c).MasterLabel == 'Get Username') {
			newRequest.URL__c = settingsMap.get(newRequest.Type__c).REST_Resource_Name__c;

			jsonMap.put('firstName', owner.FirstName);
			jsonMap.put('lastName', owner.LastName);
			jsonMap.put('comments', form.Comments__c);

			newRequest.JSON_Request__c = JSON.serializePretty(jsonMap);

		} else if (settingsMap.get(newRequest.Type__c).MasterLabel == 'Group Assignment') {
			newRequest.URL__c = settingsMap.get(newRequest.Type__c).REST_Resource_Name__c;

			jsonMap.put('isAdmin', String.valueOf(form.Admin_Access__c));
			jsonMap.put('comments', form.Comments__c);

			newRequest.JSON_Request__c = JSON.serializePretty(jsonMap);

		}
	}
	
	public void beforeUpdate(SObject oldSo, SObject so) {
	}
	
	public void beforeDelete(SObject so) {	
	}
	
	public void afterInsert(SObject so) {
		AC_HTTP_Request__c newRequest = (AC_HTTP_Request__c) so;

		if (newRequest.Status__c == 'Queued') {
			AC_HTTPRequestUtils.processHTTPRequestInFuture(so.Id);
		}
	}
	
	public void afterUpdate(SObject oldSo, SObject so) {
		AC_HTTP_Request__c oldRequest = (AC_HTTP_Request__c) oldSo;
		AC_HTTP_Request__c newRequest = (AC_HTTP_Request__c) so;

		if (oldRequest.Status__c != 'Completed' && newRequest.Status__c == 'Completed') {
			if (settingsMap.get(newRequest.Type__c).Work_Item_required__c == true) {
				workitemsToInsert.add(new AC_Work_Item__c(AC_Form__c = newRequest.AC_Form__c, Status__c = 'Not started'));
			} else {
				AC_Form__c form = forms.get(newRequest.AC_Form__c);
				form.Status__c = 'Completed';
				formsToUpdate.add(form);
			}
		}
	}
	
	public void afterDelete(SObject so) {
	}
	
	public void andFinally() {
		if (workitemsToInsert.isEmpty() == false) {
			insert workitemsToInsert;
		}

		if (formsToUpdate.isEmpty() == false) {
			update formsToUpdate;
		}
	}
}