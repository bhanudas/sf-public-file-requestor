import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';
import createDocumentRequest from '@salesforce/apex/DocumentRequestService.createDocumentRequest';

export default class DocumentRequestQuickAction extends LightningElement {
    @api recordId;
    @api objectApiName;

    isLoading = true;
    error = null;
    showForm = false;
    showSuccess = false;
    isSubmitting = false;

    recipientName = '';
    recipientEmail = '';
    requestInstructions = '';
    internalNotes = '';
    expirationDays = null;
    defaultExpirationDays = 7;
    maxFileSizeMB = 5;
    allowedExtensions = 'pdf, jpg, png, doc, docx';

    createdRequestId = null;
    createdRequestName = '';

    connectedCallback() {
        this.loadRecipientInfo();
    }

    async loadRecipientInfo() {
        this.isLoading = true;
        try {
            // For now, show the form with placeholder values
            // In production, this would query the config and recipient info
            this.showForm = true;
            this.recipientName = 'Loading...';
            this.recipientEmail = 'Loading...';
            
            // Simulated delay then show form
            setTimeout(() => {
                this.isLoading = false;
                // These would be populated from the Apex controller
                if (!this.recipientEmail || this.recipientEmail === 'Loading...') {
                    this.recipientName = 'Recipient';
                    this.recipientEmail = 'recipient@example.com';
                }
            }, 500);
        } catch (error) {
            this.error = error.body?.message || 'Failed to load recipient information';
            this.isLoading = false;
        }
    }

    handleInstructionsChange(event) {
        this.requestInstructions = event.target.value;
    }

    handleNotesChange(event) {
        this.internalNotes = event.target.value;
    }

    handleExpirationChange(event) {
        this.expirationDays = event.target.value ? parseInt(event.target.value, 10) : null;
    }

    async handleSubmit() {
        if (!this.requestInstructions) {
            this.error = 'Request instructions are required.';
            return;
        }

        this.isSubmitting = true;
        this.error = null;

        try {
            const result = await createDocumentRequest({
                sourceRecordId: this.recordId,
                sourceObjectApiName: this.objectApiName,
                requestInstructions: this.requestInstructions,
                internalNotes: this.internalNotes,
                expirationDaysOverride: this.expirationDays
            });

            this.createdRequestId = result.requestId;
            this.createdRequestName = result.requestName;
            this.showForm = false;
            this.showSuccess = true;
        } catch (error) {
            this.error = error.body?.message || 'Failed to create document request';
        } finally {
            this.isSubmitting = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}

