import { LightningElement } from 'lwc';
import validateToken from '@salesforce/apex/GuestDocumentUploadService.validateToken';
import uploadFiles from '@salesforce/apex/GuestDocumentUploadService.uploadFiles';

export default class GuestDocumentUpload extends LightningElement {
    // State
    isLoading = true;
    isInvalid = false;
    isExpired = false;
    isValid = false;
    isUploading = false;
    isSuccess = false;

    // Token data
    token = null;
    requestNumber = '';
    requestDate = '';
    instructions = '';
    existingFileCount = 0;
    maxFileSizeMB = 5;
    maxFilesPerUpload = 10;
    allowedExtensions = [];

    // File handling
    selectedFiles = [];
    validationError = null;
    filesUploadedCount = 0;

    connectedCallback() {
        this.extractTokenFromUrl();
        this.validateTokenAndLoad();
    }

    extractTokenFromUrl() {
        const urlParams = new URLSearchParams(window.location.search);
        this.token = urlParams.get('token');
    }

    async validateTokenAndLoad() {
        if (!this.token) {
            this.isLoading = false;
            this.isInvalid = true;
            return;
        }

        try {
            const result = await validateToken({ token: this.token });
            
            if (result.isValid) {
                this.requestNumber = result.requestNumber;
                this.requestDate = result.requestDate;
                this.instructions = result.instructions;
                this.existingFileCount = result.existingFileCount || 0;
                this.maxFileSizeMB = result.maxFileSizeMB || 5;
                this.maxFilesPerUpload = result.maxFilesPerUpload || 10;
                this.allowedExtensions = result.allowedExtensions || [];
                this.isValid = true;
            } else {
                this.isInvalid = true;
                this.isExpired = result.isExpired || false;
            }
        } catch (error) {
            console.error('Token validation error:', error);
            this.isInvalid = true;
        } finally {
            this.isLoading = false;
        }
    }

    get acceptedFileTypes() {
        if (!this.allowedExtensions || this.allowedExtensions.length === 0) {
            return '.pdf,.jpg,.jpeg,.png,.doc,.docx,.xls,.xlsx';
        }
        return this.allowedExtensions.map(ext => '.' + ext).join(',');
    }

    get allowedExtensionsDisplay() {
        if (!this.allowedExtensions || this.allowedExtensions.length === 0) {
            return 'pdf, jpg, png, doc, docx, xls, xlsx';
        }
        return this.allowedExtensions.join(', ');
    }

    get hasSelectedFiles() {
        return this.selectedFiles && this.selectedFiles.length > 0;
    }

    get uploadDisabled() {
        return !this.hasSelectedFiles || this.isUploading || this.validationError;
    }

    handleFileChange(event) {
        this.validationError = null;
        const files = event.target.files;
        
        if (!files || files.length === 0) {
            this.selectedFiles = [];
            return;
        }

        // Validate file count
        if (files.length > this.maxFilesPerUpload) {
            this.validationError = `Too many files selected. Maximum is ${this.maxFilesPerUpload}.`;
            this.selectedFiles = [];
            return;
        }

        const processedFiles = [];
        const maxSizeBytes = this.maxFileSizeMB * 1024 * 1024;

        for (let i = 0; i < files.length; i++) {
            const file = files[i];
            
            // Validate file size
            if (file.size > maxSizeBytes) {
                this.validationError = `File "${file.name}" exceeds the maximum size of ${this.maxFileSizeMB} MB.`;
                this.selectedFiles = [];
                return;
            }

            // Validate file extension
            const extension = file.name.split('.').pop().toLowerCase();
            if (this.allowedExtensions.length > 0 && !this.allowedExtensions.includes(extension)) {
                this.validationError = `File type "${extension}" is not allowed.`;
                this.selectedFiles = [];
                return;
            }

            processedFiles.push({
                name: file.name,
                size: file.size,
                sizeDisplay: this.formatFileSize(file.size),
                file: file
            });
        }

        this.selectedFiles = processedFiles;
    }

    formatFileSize(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }

    async handleUpload() {
        if (!this.hasSelectedFiles) return;

        this.isUploading = true;
        this.validationError = null;

        try {
            // Convert files to base64
            const filesData = [];
            for (const fileWrapper of this.selectedFiles) {
                const base64 = await this.readFileAsBase64(fileWrapper.file);
                filesData.push({
                    fileName: fileWrapper.name,
                    base64Data: base64,
                    contentType: fileWrapper.file.type
                });
            }

            const result = await uploadFiles({
                token: this.token,
                filesJson: JSON.stringify(filesData)
            });

            if (result.success) {
                this.filesUploadedCount = result.filesUploaded;
                this.isValid = false;
                this.isSuccess = true;
            } else {
                this.validationError = result.errorMessage || 'Upload failed. Please try again.';
            }
        } catch (error) {
            console.error('Upload error:', error);
            this.validationError = error.body?.message || 'An error occurred during upload.';
        } finally {
            this.isUploading = false;
        }
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    handleUploadMore() {
        this.isSuccess = false;
        this.isValid = true;
        this.selectedFiles = [];
        this.validationError = null;
    }
}

