import { LightningElement } from "lwc";
import { createLogger } from "c/docReqLogger";
import validateToken from "@salesforce/apex/GuestDocumentUploadService.validateToken";
import uploadFiles from "@salesforce/apex/GuestDocumentUploadService.uploadFiles";
import getPublicDebugSettings from "@salesforce/apex/GuestDocumentUploadService.getPublicDebugSettings";

export default class GuestDocumentUpload extends LightningElement {
  // Logger instance
  logger = createLogger("GuestUpload", false);

  // State
  isLoading = true;
  isInvalid = false;
  isExpired = false;
  isValid = false;
  isUploading = false;
  isSuccess = false;

  // Token data
  token = null;
  requestNumber = "";
  requestDate = "";
  instructions = "";
  existingFileCount = 0;
  maxFileSizeMB = 5;
  maxFilesPerUpload = 10;
  allowedExtensions = [];

  // File handling
  selectedFiles = [];
  validationError = null;
  filesUploadedCount = 0;

  async connectedCallback() {
    this.logger.lifecycle("connectedCallback started");

    // Initialize debug settings first
    await this.initializeDebugSettings();

    this.extractTokenFromUrl();
    this.validateTokenAndLoad();
  }

  async initializeDebugSettings() {
    try {
      const settings = await getPublicDebugSettings();
      this.logger = createLogger("GuestUpload", settings.enableDebug);
      this.logger.log("Debug settings initialized", {
        enabled: settings.enableDebug
      });
    } catch (error) {
      // Silently fail - logging will just be disabled
      console.warn("Failed to load debug settings:", error);
    }
  }

  extractTokenFromUrl() {
    const urlParams = new URLSearchParams(window.location.search);
    this.token = urlParams.get("token");
    this.logger.log("Token extracted from URL", {
      tokenPresent: !!this.token,
      tokenLength: this.token?.length,
      fullUrl: window.location.href
    });
  }

  async validateTokenAndLoad() {
    this.logger.log("Starting token validation");

    if (!this.token) {
      this.logger.warn("No token found in URL");
      this.isLoading = false;
      this.isInvalid = true;
      this.logCurrentState();
      return;
    }

    try {
      this.logger.apiStart("validateToken", {
        token: this.token.substring(0, 8) + "..."
      });
      const result = await validateToken({ token: this.token });
      this.logger.apiSuccess("validateToken", result);

      if (result.isValid) {
        this.requestNumber = result.requestNumber;
        this.requestDate = result.requestDate;
        this.instructions = result.instructions;
        this.existingFileCount = result.existingFileCount || 0;
        this.maxFileSizeMB = result.maxFileSizeMB || 5;
        this.maxFilesPerUpload = result.maxFilesPerUpload || 10;
        this.allowedExtensions = result.allowedExtensions || [];
        this.isValid = true;

        this.logger.log("Token validated successfully", {
          requestNumber: this.requestNumber,
          existingFileCount: this.existingFileCount,
          maxFileSizeMB: this.maxFileSizeMB,
          maxFilesPerUpload: this.maxFilesPerUpload,
          allowedExtensions: this.allowedExtensions
        });
      } else {
        this.isInvalid = true;
        this.isExpired = result.isExpired || false;
        this.logger.warn("Token validation failed", {
          isExpired: this.isExpired
        });
      }
    } catch (error) {
      this.logger.apiError("validateToken", error);
      this.isInvalid = true;
    } finally {
      this.isLoading = false;
      this.logCurrentState();
    }
  }

  get acceptedFileTypes() {
    if (!this.allowedExtensions || this.allowedExtensions.length === 0) {
      return ".pdf,.jpg,.jpeg,.png,.doc,.docx,.xls,.xlsx";
    }
    return this.allowedExtensions.map((ext) => "." + ext).join(",");
  }

  get allowedExtensionsDisplay() {
    if (!this.allowedExtensions || this.allowedExtensions.length === 0) {
      return "pdf, jpg, png, doc, docx, xls, xlsx";
    }
    return this.allowedExtensions.join(", ");
  }

  get hasSelectedFiles() {
    return this.selectedFiles && this.selectedFiles.length > 0;
  }

  get uploadDisabled() {
    return !this.hasSelectedFiles || this.isUploading || this.validationError;
  }

  handleFileChange(event) {
    this.logger.action("handleFileChange", {
      fileCount: event.target.files?.length
    });
    this.validationError = null;
    const files = event.target.files;

    if (!files || files.length === 0) {
      this.logger.debug("No files selected");
      this.selectedFiles = [];
      return;
    }

    // Validate file count
    if (files.length > this.maxFilesPerUpload) {
      this.validationError = `Too many files selected. Maximum is ${this.maxFilesPerUpload}.`;
      this.logger.warn("File count validation failed", {
        selected: files.length,
        max: this.maxFilesPerUpload
      });
      this.selectedFiles = [];
      return;
    }

    const processedFiles = [];
    const maxSizeBytes = this.maxFileSizeMB * 1024 * 1024;

    this.logger.group("File Validation");
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      this.logger.debug(`Validating file ${i + 1}/${files.length}`, {
        name: file.name,
        size: file.size,
        type: file.type
      });

      // Validate file size
      if (file.size > maxSizeBytes) {
        this.validationError = `File "${file.name}" exceeds the maximum size of ${this.maxFileSizeMB} MB.`;
        this.logger.warn("File size validation failed", {
          fileName: file.name,
          fileSize: file.size,
          maxSize: maxSizeBytes
        });
        this.selectedFiles = [];
        this.logger.groupEnd();
        return;
      }

      // Validate file extension
      const extension = file.name.split(".").pop().toLowerCase();
      if (
        this.allowedExtensions.length > 0 &&
        !this.allowedExtensions.includes(extension)
      ) {
        this.validationError = `File type "${extension}" is not allowed.`;
        this.logger.warn("File extension validation failed", {
          fileName: file.name,
          extension: extension,
          allowedExtensions: this.allowedExtensions
        });
        this.selectedFiles = [];
        this.logger.groupEnd();
        return;
      }

      processedFiles.push({
        name: file.name,
        size: file.size,
        sizeDisplay: this.formatFileSize(file.size),
        file: file
      });
    }
    this.logger.groupEnd();

    this.selectedFiles = processedFiles;
    this.logger.log("Files validated successfully", {
      count: processedFiles.length,
      files: processedFiles.map((f) => ({ name: f.name, size: f.sizeDisplay }))
    });
  }

  formatFileSize(bytes) {
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
    return (bytes / (1024 * 1024)).toFixed(1) + " MB";
  }

  async handleUpload() {
    if (!this.hasSelectedFiles) {
      this.logger.warn("handleUpload called with no files selected");
      return;
    }

    this.logger.action("handleUpload", {
      fileCount: this.selectedFiles.length
    });
    this.isUploading = true;
    this.validationError = null;

    try {
      // Convert files to base64 in parallel
      this.logger.log("Converting files to base64...");
      const startTime = performance.now();

      const filesData = await Promise.all(
        this.selectedFiles.map(async (fileWrapper, index) => {
          this.logger.debug(
            `Converting file ${index + 1}/${this.selectedFiles.length}`,
            {
              name: fileWrapper.name
            }
          );
          const base64 = await this.readFileAsBase64(fileWrapper.file);
          return {
            fileName: fileWrapper.name,
            base64Data: base64,
            contentType: fileWrapper.file.type
          };
        })
      );

      const conversionTime = performance.now() - startTime;
      this.logger.log("Base64 conversion complete", {
        timeMs: conversionTime.toFixed(2),
        totalBase64Length: filesData.reduce(
          (sum, f) => sum + f.base64Data.length,
          0
        )
      });

      this.logger.apiStart("uploadFiles", {
        token: this.token.substring(0, 8) + "...",
        fileCount: filesData.length,
        fileNames: filesData.map((f) => f.fileName)
      });

      const result = await uploadFiles({
        token: this.token,
        filesJson: JSON.stringify(filesData)
      });

      this.logger.apiSuccess("uploadFiles", result);

      if (result.success) {
        this.filesUploadedCount = result.filesUploaded;
        this.isValid = false;
        this.isSuccess = true;
        this.logger.log("Upload completed successfully", {
          filesUploaded: this.filesUploadedCount
        });
      } else {
        this.validationError =
          result.errorMessage || "Upload failed. Please try again.";
        this.logger.warn("Upload returned failure", {
          errorMessage: result.errorMessage
        });
      }
    } catch (error) {
      this.logger.apiError("uploadFiles", error);
      this.validationError =
        error.body?.message || "An error occurred during upload.";
    } finally {
      this.isUploading = false;
      this.logCurrentState();
    }
  }

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const base64 = reader.result.split(",")[1];
        resolve(base64);
      };
      reader.onerror = (error) => {
        this.logger.error("FileReader error", { fileName: file.name, error });
        reject(error);
      };
      reader.readAsDataURL(file);
    });
  }

  handleUploadMore() {
    this.logger.action("handleUploadMore");
    this.isSuccess = false;
    this.isValid = true;
    this.selectedFiles = [];
    this.validationError = null;
    this.logCurrentState();
  }

  logCurrentState() {
    this.logger.state({
      isLoading: this.isLoading,
      isValid: this.isValid,
      isInvalid: this.isInvalid,
      isExpired: this.isExpired,
      isUploading: this.isUploading,
      isSuccess: this.isSuccess,
      tokenPresent: !!this.token,
      selectedFilesCount: this.selectedFiles.length,
      validationError: this.validationError
    });
  }
}
