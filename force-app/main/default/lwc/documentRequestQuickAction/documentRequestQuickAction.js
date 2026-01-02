import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { createLogger } from "c/docReqLogger";
import createDocumentRequest from "@salesforce/apex/DocumentRequestService.createDocumentRequest";
import getRecipientInfoForLwc from "@salesforce/apex/DocumentRequestService.getRecipientInfoForLwc";
import getInternalDebugSettings from "@salesforce/apex/DocumentRequestService.getInternalDebugSettings";

export default class DocumentRequestQuickAction extends LightningElement {
  @api recordId;
  @api objectApiName;

  // Logger instance
  logger = createLogger("QuickAction", false);

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

  async connectedCallback() {
    this.logger.lifecycle("connectedCallback started");
    this.logger.log("Component initialized", {
      recordId: this.recordId,
      objectApiName: this.objectApiName
    });

    // Initialize debug settings first
    await this.initializeDebugSettings();

    this.loadRecipientInfo();
  }

  async initializeDebugSettings() {
    try {
      this.logger.debug("Fetching debug settings...");
      const settings = await getInternalDebugSettings();
      this.logger = createLogger("QuickAction", settings.enableDebug);
      this.logger.log("Debug settings initialized", {
        enabled: settings.enableDebug
      });
    } catch (error) {
      // Silently fail - logging will just be disabled
      console.warn("Failed to load debug settings:", error);
    }
  }

  async loadRecipientInfo() {
    this.logger.log("Loading recipient info...");
    this.isLoading = true;
    this.error = null;

    try {
      this.logger.apiStart("getRecipientInfoForLwc", {
        sourceRecordId: this.recordId,
        sourceObjectApiName: this.objectApiName
      });

      const result = await getRecipientInfoForLwc({
        sourceRecordId: this.recordId,
        sourceObjectApiName: this.objectApiName
      });

      this.logger.apiSuccess("getRecipientInfoForLwc", result);

      this.recipientName = result.name || "Recipient";
      this.recipientEmail = result.email || "";

      this.logger.log("Recipient info loaded", {
        name: this.recipientName,
        email: this.recipientEmail,
        hasEmail: !!this.recipientEmail
      });

      if (!this.recipientEmail) {
        this.error = "No email address found for the recipient on this record.";
        this.showForm = false;
        this.logger.warn("No recipient email found");
      } else {
        this.showForm = true;
        this.logger.log("Form displayed - ready for input");
      }
    } catch (err) {
      this.logger.apiError("getRecipientInfoForLwc", err);
      this.error = err.body?.message || "Failed to load recipient information";
      this.showForm = false;
    } finally {
      this.isLoading = false;
      this.logCurrentState();
    }
  }

  handleInstructionsChange(event) {
    this.requestInstructions = event.target.value;
    this.logger.debug("Instructions changed", {
      length: this.requestInstructions.length
    });
  }

  handleNotesChange(event) {
    this.internalNotes = event.target.value;
    this.logger.debug("Internal notes changed", {
      length: this.internalNotes.length
    });
  }

  handleExpirationChange(event) {
    this.expirationDays = event.target.value
      ? parseInt(event.target.value, 10)
      : null;
    this.logger.debug("Expiration days changed", {
      value: this.expirationDays
    });
  }

  async handleSubmit() {
    this.logger.action("handleSubmit");

    if (!this.requestInstructions) {
      this.error = "Request instructions are required.";
      this.logger.warn("Validation failed - instructions required");
      return;
    }

    this.isSubmitting = true;
    this.error = null;

    const params = {
      sourceRecordId: this.recordId,
      sourceObjectApiName: this.objectApiName,
      requestInstructions: this.requestInstructions,
      internalNotes: this.internalNotes,
      expirationDaysOverride: this.expirationDays
    };

    this.logger.log("Submitting document request", {
      ...params,
      requestInstructions: params.requestInstructions.substring(0, 50) + "..."
    });

    try {
      this.logger.apiStart("createDocumentRequest", params);
      const result = await createDocumentRequest(params);
      this.logger.apiSuccess("createDocumentRequest", result);

      this.createdRequestId = result.requestId;
      this.createdRequestName = result.requestName;
      this.sentToEmail = result.recipientEmail || this.recipientEmail;
      this.showForm = false;
      this.showSuccess = true;

      this.logger.log("Document request created successfully", {
        requestId: this.createdRequestId,
        requestName: this.createdRequestName,
        sentToEmail: this.sentToEmail
      });
    } catch (err) {
      this.logger.apiError("createDocumentRequest", err);
      this.error = err.body?.message || "Failed to create document request";
    } finally {
      this.isSubmitting = false;
      this.logCurrentState();
    }
  }

  handleCancel() {
    this.logger.action("handleCancel");
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  handleClose() {
    this.logger.action("handleClose");
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  logCurrentState() {
    this.logger.state({
      isLoading: this.isLoading,
      isSubmitting: this.isSubmitting,
      showForm: this.showForm,
      showSuccess: this.showSuccess,
      error: this.error,
      recipientName: this.recipientName,
      recipientEmail: this.recipientEmail,
      hasInstructions: !!this.requestInstructions,
      expirationDays: this.expirationDays
    });
  }
}
