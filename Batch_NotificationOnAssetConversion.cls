global class Batch_NotificationOnAssetConversion implements Database.Batchable<sObject>,Database.Stateful {
    global Set<Id> opportunitiesFailedToSendNotification;
    
    // Get all Shipped Assets
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        String query = ('SELECT End_Customer_Ship_To_Account__c,Id,Linked_Booking_Opportunity__c,Linked_Booking_Opportunity__r.Notify_Reseller_End_Customer__c,Linked_Booking_Opportunity__r.Owner.ContactId,Linked_Booking_Opportunity__r.SBQQ__PrimaryQuote__r.SBQQ__PrimaryContact__c,Product2Id,SerialNumber,Status FROM Asset WHERE Status = \'Shipped\' AND  Linked_Booking_Opportunity__c != null AND End_Customer_Ship_To_Account__c != null AND SerialNumber != null AND Linked_Booking_Opportunity__r.Notify_Reseller_End_Customer__c = null');
        return Database.getQueryLocator(query);
    }
    
    // Send Notification and Update it is notified on opportunity
    global void execute(Database.BatchableContext BC,List<Asset> assetList){
        opportunitiesFailedToSendNotification = NotificationOnAssetConversionHandler.getAssetsOfBookingOpportunity(assetList);  
    }
    
    // Send failed opportunity record ids
    global void finish(Database.BatchableContext BC){
        Messaging.EmailFileAttachment[] emailAttList = new List<Messaging.EmailFileAttachment>();
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, 
                            JobItemsProcessed,
                            TotalJobItems, CreatedBy.Email
                            FROM AsyncApexJob
                            WHERE Id = :bc.getJobId()];
        if(!opportunitiesFailedToSendNotification.isEmpty())
        {
            String attName = 'Notifications Not Sent to Resellers' + system.now().format('YYYYMMDDhhmm') + '.csv';
            String finalstr = 'OpportunityId,IsNotified\n';
            
            
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            for(Id oppId:opportunitiesFailedToSendNotification)
            {
                string recordString = '"'+oppId+'","'+'False'+'"\n';
                finalstr = finalstr +recordString;
            }
            efa.setFileName(attName);
            efa.setBody(Blob.valueOf(finalstr));
            emailAttList.add(efa);
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setSubject( 'PDDS Reseller Batch Run Status' );
            email.setToAddresses( new String[] {'sfadmin@demandblue.com'} );
            email.setHtmlBody( '<html> Attached Records are failed to send Notification :</html>');
            if(!emailAttList.isEmpty()){
                email.setFileAttachments(emailAttList);}
            
            // Sends the email
            Messaging.SendEmailResult [] r =Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
            
        }
        
    }
}