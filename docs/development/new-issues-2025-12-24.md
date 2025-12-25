1. URL and file path should be configurable in the custom metadata type.
2. The dialog had the wrong email (see screenshot)
3. On the Document Review Panel, we don't have a way to actually see the files that we are approving or rejecting.
   https://www.helenhomestead.com/secure-document-upload?token=d97f8461-fb9a-b240-96fa-fdbb7a3b24de

# New Issues

## URL Creation should be more configurable

### Base Domain and file path including file name should be configurable.

For example the URL should be broken up into https://{base domain}/{file path}/{file name}
If the following was the URL: https://www.helenhomestead.com/secure-document-upload?token=d97f8461-fb9a-b240-96fa-fdbb7a3b24de
The base domain would be www.helenhomestead.com
The file path would be /
The file name would be secure-document-upload
Add this to custom settings so that it can be configured by the administrator.

## Email sent Dialog should reflect the actual email address

Current looks like a default email of `recipient@example.com`
This should be the email referenced and sent via the actual email sending path of code.
Add this to custom settings so that it can be configured by the administrator.

## Document Review Panel should show the actual files that are being approved or rejected.

Currently, the panel shows a list of files that are being approved or rejected, but we don't have a way to actually see the files that we are approving or rejecting.
Please add UX to our current solution to allow users to review/view files.
