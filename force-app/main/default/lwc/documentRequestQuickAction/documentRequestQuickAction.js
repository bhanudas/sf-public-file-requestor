import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import createDocumentRequest from "@salesforce/apex/DocumentRequestService.createDocumentRequest";
import getRecipientInfoForLwc from "@salesforce/apex/DocumentRequestService.getRecipientInfoForLwc";

export default class DocumentRequestQuickAction extends LightningElement {
  @api recordId;
  @api objectApiName;

  isLoading = true;
  error = null;
  showForm = false;
  showSuccess = false;
  isSubmitting = false;

  recipientName = "";
  recipientEmail = "";
  requestInstructions = "";
  internalNotes = "";
  expirationDays = null;
  defaultExpirationDays = 7;
  maxFileSizeMB = 5;
  allowedExtensions = "pdf, jpg, png, doc, docx";

  createdRequestId = null;
  createdRequestName = "";
  sentToEmail = "";

  connectedCallback() {
    this.loadRecipientInfo();
  }

  async loadRecipientInfo() {
    this.isLoading = true;
    this.error = null;
    try {
      const result = await getRecipientInfoForLwc({
        sourceRecordId: this.recordId,
        sourceObjectApiName: this.objectApiName
      });

      this.recipientName = result.name || "Recipient";
      this.recipientEmail = result.email || "";

      if (!this.recipientEmail) {
        this.error = "No email address found for the recipient on this record.";
        this.showForm = false;
      } else {
        this.showForm = true;
      }
    } catch (err) {
      this.error = err.body?.message || "Failed to load recipient information";
      this.showForm = false;
    } finally {
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
    this.expirationDays = event.target.value
      ? parseInt(event.target.value, 10)
      : null;
  }

  async handleSubmit() {
    if (!this.requestInstructions) {
      this.error = "Request instructions are required.";
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
      this.sentToEmail = result.recipientEmail || this.recipientEmail;
      this.showForm = false;
      this.showSuccess = true;
    } catch (err) {
      this.error = err.body?.message || "Failed to create document request";
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
