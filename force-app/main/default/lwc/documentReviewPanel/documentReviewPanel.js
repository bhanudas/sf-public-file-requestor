import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { createLogger } from "c/docReqLogger";
import getRequestDetails from "@salesforce/apex/DocumentRequestService.getRequestDetails";
import getRequestFiles from "@salesforce/apex/DocumentRequestService.getRequestFiles";
import approveFile from "@salesforce/apex/DocumentRequestService.approveFile";
import rejectFile from "@salesforce/apex/DocumentRequestService.rejectFile";
import commitApprovedFiles from "@salesforce/apex/DocumentRequestService.commitApprovedFiles";
import getInternalDebugSettings from "@salesforce/apex/DocumentRequestService.getInternalDebugSettings";

export default class DocumentReviewPanel extends NavigationMixin(
  LightningElement
) {
  @api recordId;

  // Logger instance
  logger = createLogger("ReviewPanel", false);
  debugInitialized = false;

  requestDetail = null;
  files = [];
  error = null;
  isLoading = true;
  isCommitting = false;

  showRejectModal = false;
  rejectionReason = "";
  fileToReject = null;

  // File preview modal state
  showPreviewModal = false;
  previewFileUrl = "";
  previewFileName = "";
  previewFileId = null;
  previewDownloadUrl = "";

  _wiredDetails;
  _wiredFiles;

  connectedCallback() {
    this.logger.lifecycle("connectedCallback started");
    this.logger.log("Component initialized", { recordId: this.recordId });
    this.initializeDebugSettings();
  }

  async initializeDebugSettings() {
    try {
      const settings = await getInternalDebugSettings();
      this.logger = createLogger("ReviewPanel", settings.enableDebug);
      this.debugInitialized = true;
      this.logger.log("Debug settings initialized", {
        enabled: settings.enableDebug
      });
      this.logger.log("Record ID", { recordId: this.recordId });
    } catch (error) {
      // Silently fail - logging will just be disabled
      console.warn("Failed to load debug settings:", error);
      this.debugInitialized = true;
    }
  }

  @wire(getRequestDetails, { documentRequestId: "$recordId" })
  wiredDetails(result) {
    this._wiredDetails = result;
    if (result.data) {
      this.requestDetail = result.data;
      this.error = null;
      this.logger.log("Request details loaded", {
        id: result.data.id,
        name: result.data.name,
        status: result.data.status,
        fileCount: result.data.fileCount,
        recipientEmail: result.data.recipientEmail
      });
    } else if (result.error) {
      this.error =
        result.error.body?.message || "Failed to load request details";
      this.logger.apiError("getRequestDetails (wire)", result.error);
    }
  }

  @wire(getRequestFiles, { documentRequestId: "$recordId" })
  wiredFiles(result) {
    this._wiredFiles = result;
    if (result.data) {
      this.files = result.data.map((file) => ({
        ...file,
        isPending: file.reviewStatus === "Pending_Review"
      }));
      this.error = null;
      this.logger.log("Files loaded", {
        count: this.files.length,
        files: this.files.map((f) => ({
          id: f.id,
          title: f.title,
          status: f.reviewStatus,
          size: f.contentSize
        }))
      });
    } else if (result.error) {
      this.error = result.error.body?.message || "Failed to load files";
      this.logger.apiError("getRequestFiles (wire)", result.error);
    }
    this.isLoading = false;
    this.logCurrentState();
  }

  get hasError() {
    return this.error != null;
  }

  get hasFiles() {
    return this.files && this.files.length > 0;
  }

  get noFilesToApprove() {
    return !this.files.some((f) => f.isPending);
  }

  get canCommit() {
    return (
      this.files.some((f) => f.reviewStatus === "Approved") &&
      this.requestDetail?.status !== "Approved"
    );
  }

  get statusClass() {
    const status = this.requestDetail?.status;
    if (status === "Approved") return "slds-badge_success";
    if (status === "Rejected" || status === "Expired")
      return "slds-badge_error";
    if (status === "Files_Received" || status === "Under_Review")
      return "slds-badge_warning";
    return "";
  }

  navigateToSourceRecord() {
    this.logger.action("navigateToSourceRecord", {
      sourceRecordId: this.requestDetail?.sourceRecordId
    });
    if (this.requestDetail?.sourceRecordId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: this.requestDetail.sourceRecordId,
          actionName: "view"
        }
      });
    }
  }

  async handleApproveFile(event) {
    const fileId = event.target.dataset.id;
    const file = this.files.find((f) => f.id === fileId);
    this.logger.action("handleApproveFile", {
      fileId,
      fileName: file?.title
    });

    try {
      this.logger.apiStart("approveFile", { contentVersionId: fileId });
      await approveFile({ contentVersionId: fileId });
      this.logger.apiSuccess("approveFile", { fileId });
      this.showToast("Success", "File approved", "success");
      await this.refreshData();
    } catch (error) {
      this.logger.apiError("approveFile", error);
      this.showToast(
        "Error",
        error.body?.message || "Failed to approve file",
        "error"
      );
    }
  }

  handleRejectFile(event) {
    const fileId = event.target.dataset.id;
    const file = this.files.find((f) => f.id === fileId);
    this.logger.action("handleRejectFile", {
      fileId,
      fileName: file?.title
    });
    this.fileToReject = fileId;
    this.rejectionReason = "";
    this.showRejectModal = true;
  }

  handleReasonChange(event) {
    this.rejectionReason = event.target.value;
    this.logger.debug("Rejection reason changed", {
      length: this.rejectionReason.length
    });
  }

  closeRejectModal() {
    this.logger.action("closeRejectModal");
    this.showRejectModal = false;
    this.fileToReject = null;
    this.rejectionReason = "";
  }

  async confirmReject() {
    this.logger.action("confirmReject", {
      fileId: this.fileToReject,
      reasonLength: this.rejectionReason.length
    });

    if (!this.rejectionReason) {
      this.showToast("Error", "Please provide a rejection reason", "error");
      this.logger.warn("Rejection reason required");
      return;
    }

    try {
      this.logger.apiStart("rejectFile", {
        contentVersionId: this.fileToReject,
        rejectionReason: this.rejectionReason
      });
      await rejectFile({
        contentVersionId: this.fileToReject,
        rejectionReason: this.rejectionReason
      });
      this.logger.apiSuccess("rejectFile", { fileId: this.fileToReject });
      this.showToast("Success", "File rejected", "success");
      this.closeRejectModal();
      await this.refreshData();
    } catch (error) {
      this.logger.apiError("rejectFile", error);
      this.showToast(
        "Error",
        error.body?.message || "Failed to reject file",
        "error"
      );
    }
  }

  async handleApproveAll() {
    const pendingFiles = this.files.filter((f) => f.isPending);
    this.logger.action("handleApproveAll", {
      pendingCount: pendingFiles.length,
      fileIds: pendingFiles.map((f) => f.id)
    });

    this.logger.log("Approving all pending files...");
    const results = await Promise.allSettled(
      pendingFiles.map((file) => approveFile({ contentVersionId: file.id }))
    );

    const failures = results
      .map((result, idx) => ({ result, file: pendingFiles[idx] }))
      .filter(({ result }) => result.status === "rejected");

    this.logger.log("Approve all results", {
      total: pendingFiles.length,
      succeeded: pendingFiles.length - failures.length,
      failed: failures.length
    });

    if (failures.length > 0) {
      failures.forEach(({ file, result }) => {
        this.logger.error(`Failed to approve ${file.title}`, result.reason);
        this.showToast("Error", `Failed to approve ${file.title}`, "error");
      });
    }

    this.showToast("Success", "All pending files approved", "success");
    await this.refreshData();
  }

  async handleCommit() {
    this.logger.action("handleCommit", { recordId: this.recordId });
    this.isCommitting = true;

    try {
      this.logger.apiStart("commitApprovedFiles", {
        documentRequestId: this.recordId
      });
      await commitApprovedFiles({ documentRequestId: this.recordId });
      this.logger.apiSuccess("commitApprovedFiles", {
        recordId: this.recordId
      });
      this.showToast("Success", "Files committed to source record", "success");
      await this.refreshData();
    } catch (error) {
      this.logger.apiError("commitApprovedFiles", error);
      this.showToast(
        "Error",
        error.body?.message || "Failed to commit files",
        "error"
      );
    } finally {
      this.isCommitting = false;
      this.logCurrentState();
    }
  }

  async refreshData() {
    this.logger.log("Refreshing data...");
    await Promise.all([
      refreshApex(this._wiredDetails),
      refreshApex(this._wiredFiles)
    ]);
    this.logger.log("Data refreshed");
  }

  showToast(title, message, variant) {
    this.logger.debug("Showing toast", { title, message, variant });
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  // File preview handlers
  handleViewFile(event) {
    const fileId = event.target.dataset.id;
    const file = this.files.find((f) => f.id === fileId);
    this.logger.action("handleViewFile", {
      fileId,
      fileName: file?.title,
      previewUrl: file?.previewUrl
    });

    if (file) {
      this.previewFileUrl = file.previewUrl;
      this.previewFileName = file.title;
      this.previewFileId = fileId;
      this.previewDownloadUrl = file.downloadUrl;
      this.showPreviewModal = true;
    }
  }

  closePreviewModal() {
    this.logger.action("closePreviewModal");
    this.showPreviewModal = false;
    this.previewFileUrl = "";
    this.previewFileName = "";
    this.previewFileId = null;
    this.previewDownloadUrl = "";
  }

  handleDownloadFile() {
    this.logger.action("handleDownloadFile", {
      downloadUrl: this.previewDownloadUrl
    });
    if (this.previewDownloadUrl) {
      window.open(this.previewDownloadUrl, "_blank");
    }
  }

  logCurrentState() {
    this.logger.state({
      isLoading: this.isLoading,
      isCommitting: this.isCommitting,
      hasError: this.hasError,
      error: this.error,
      hasFiles: this.hasFiles,
      fileCount: this.files.length,
      pendingCount: this.files.filter((f) => f.isPending).length,
      approvedCount: this.files.filter((f) => f.reviewStatus === "Approved")
        .length,
      rejectedCount: this.files.filter((f) => f.reviewStatus === "Rejected")
        .length,
      canCommit: this.canCommit,
      requestStatus: this.requestDetail?.status,
      showRejectModal: this.showRejectModal,
      showPreviewModal: this.showPreviewModal
    });
  }
}
