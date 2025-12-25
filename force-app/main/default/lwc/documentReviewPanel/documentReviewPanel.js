import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getRequestDetails from "@salesforce/apex/DocumentRequestService.getRequestDetails";
import getRequestFiles from "@salesforce/apex/DocumentRequestService.getRequestFiles";
import approveFile from "@salesforce/apex/DocumentRequestService.approveFile";
import rejectFile from "@salesforce/apex/DocumentRequestService.rejectFile";
import commitApprovedFiles from "@salesforce/apex/DocumentRequestService.commitApprovedFiles";

export default class DocumentReviewPanel extends NavigationMixin(
  LightningElement
) {
  @api recordId;

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

  @wire(getRequestDetails, { documentRequestId: "$recordId" })
  wiredDetails(result) {
    this._wiredDetails = result;
    if (result.data) {
      this.requestDetail = result.data;
      this.error = null;
    } else if (result.error) {
      this.error =
        result.error.body?.message || "Failed to load request details";
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
    } else if (result.error) {
      this.error = result.error.body?.message || "Failed to load files";
    }
    this.isLoading = false;
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
    try {
      await approveFile({ contentVersionId: fileId });
      this.showToast("Success", "File approved", "success");
      await this.refreshData();
    } catch (error) {
      this.showToast(
        "Error",
        error.body?.message || "Failed to approve file",
        "error"
      );
    }
  }

  handleRejectFile(event) {
    this.fileToReject = event.target.dataset.id;
    this.rejectionReason = "";
    this.showRejectModal = true;
  }

  handleReasonChange(event) {
    this.rejectionReason = event.target.value;
  }

  closeRejectModal() {
    this.showRejectModal = false;
    this.fileToReject = null;
    this.rejectionReason = "";
  }

  async confirmReject() {
    if (!this.rejectionReason) {
      this.showToast("Error", "Please provide a rejection reason", "error");
      return;
    }

    try {
      await rejectFile({
        contentVersionId: this.fileToReject,
        rejectionReason: this.rejectionReason
      });
      this.showToast("Success", "File rejected", "success");
      this.closeRejectModal();
      await this.refreshData();
    } catch (error) {
      this.showToast(
        "Error",
        error.body?.message || "Failed to reject file",
        "error"
      );
    }
  }

  async handleApproveAll() {
    const pendingFiles = this.files.filter((f) => f.isPending);
    const results = await Promise.allSettled(
      pendingFiles.map((file) => approveFile({ contentVersionId: file.id }))
    );

    const failures = results
      .map((result, idx) => ({ result, file: pendingFiles[idx] }))
      .filter(({ result }) => result.status === "rejected");

    if (failures.length > 0) {
      failures.forEach(({ file }) => {
        this.showToast("Error", `Failed to approve ${file.title}`, "error");
      });
    }

    this.showToast("Success", "All pending files approved", "success");
    await this.refreshData();
  }

  async handleCommit() {
    this.isCommitting = true;
    try {
      await commitApprovedFiles({ documentRequestId: this.recordId });
      this.showToast("Success", "Files committed to source record", "success");
      await this.refreshData();
    } catch (error) {
      this.showToast(
        "Error",
        error.body?.message || "Failed to commit files",
        "error"
      );
    } finally {
      this.isCommitting = false;
    }
  }

  async refreshData() {
    await Promise.all([
      refreshApex(this._wiredDetails),
      refreshApex(this._wiredFiles)
    ]);
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  // File preview handlers
  handleViewFile(event) {
    const fileId = event.target.dataset.id;
    const file = this.files.find((f) => f.id === fileId);
    if (file) {
      this.previewFileUrl = file.previewUrl;
      this.previewFileName = file.title;
      this.previewFileId = fileId;
      this.previewDownloadUrl = file.downloadUrl;
      this.showPreviewModal = true;
    }
  }

  closePreviewModal() {
    this.showPreviewModal = false;
    this.previewFileUrl = "";
    this.previewFileName = "";
    this.previewFileId = null;
    this.previewDownloadUrl = "";
  }

  handleDownloadFile() {
    if (this.previewDownloadUrl) {
      window.open(this.previewDownloadUrl, "_blank");
    }
  }
}
