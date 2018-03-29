# AzureBSFolderSync (Azure Blob Storage Folder Sync)

## Use case
Script is designed to upload some software backups folder (e.g. Acronic Backup, Team Foundation Server etc.) to Azure Blob Storage.
So, the main point is that software manages the backup retention period.
When file is removed from the destination folder - it'll be removed from Azure.

## Requirements
1. Install Azure PowerShell modules, like described here https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps
2. Enable scripts execution in your system

## Usage
Run it with required permissions.
````
.\AzureBSFolderSync.ps1 -Path C:\DestinationFolder -Storage AzureStorageAccountName -Container AzureBSContainerName -Key AzureBSAccessKey -Log C:\LogFile.log
````
Parameter "-Log" isn't mandatory.

Also, you may execute the script from Task Scheduler.

Feel free to improve or correct it via pull requests.
