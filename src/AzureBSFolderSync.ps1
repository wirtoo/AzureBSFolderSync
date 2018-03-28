<# Parameters #> 
Param ( 
    [Parameter(Mandatory=$true,Position=0)][String]$Path, 
    [Parameter(Mandatory=$false,Position=1)][String]$LogFilePath = "C:\AzureBSFolderSync.log"
) 

<# Global variables #> 
    $Global:AzureStorageAccountName = "StorageAccountName" 
    $Global:AzureStorageAccountKey = "StorageAccountAccessKey"
    $Global:AzureBlobContainerName = "BlobStorageContainerName"

 Function Write-Log 
    { 
        Param ( 
            [Parameter(Mandatory=$true,Position=0)][String]$Value
        ) 
         
        $date = ("[{0:yyyy-MM-dd HH:mm:ss}] " -f (Get-Date)) 
        "$($date)$($Value)" | Add-Content -Path $LogFilePath
    }

    Write-Log -Value "START"
    # Initiate the Azure Storage Context 
    $context = New-AzureStorageContext -StorageAccountName $Global:AzureStorageAccountName -StorageAccountKey $Global:AzureStorageAccountKey 
 
    # Check if the defined container already exists 
    try { 
        $azcontainer = Get-AzureStorageContainer -Name $Global:AzureBlobContainerName -Context $context -ErrorAction SilentlyContinue 
    } catch {} 
 
    If ($? -eq $false) { 
        # Something went wrong, check the last error message 
        If ($Error[0] -like "*Can not find the container*") { 
            # Container doesn't exist, create a new one 
            Write-Log -Value "Container `"$Global:AzureBlobContainerName`" does not exist, trying to create container"
            $azcontainer = New-AzureStorageContainer -Name $Global:AzureBlobContainerName -Context $context -ErrorAction SilentlyContinue 
 
            If ($azcontainer -eq $null) { 
                # Couldn't create container 
                Write-Log -Value "ERROR: could not create container `"$Global:AzureBlobContainerName`""
                return 
            } Else { 
                # OK, container created 
                Write-Log -Value "Container `"$Global:AzureBlobContainerName`" successfully created"
            } 
        } ElseIf ($Error[0] -like "*Container name * is invalid*") { 
            # Container name is invalid 
            Write-Log -Value "ERROR: container name `"$Global:AzureBlobContainerName`" is invalid"
        } ElseIf ($Error[0] -like "*(403) Forbidden*") { 
            # Storage Account key incorrect 
            Write-Log -Value "ERROR: could not connect to Azure storage, please check the Azure Storage Account key"
            return 
        } ElseIf ($Error[0] -like "*(503) Server Unavailable*") { 
            # Storage Account name incorrect 
            Write-Log -Value "ERROR: could not connect to Azure storage, please check the Azure Storage Account name"
            return 
        } ElseIf ($Error[0] -like "*Please connect to internet*") { 
            # No internet connection 
            Write-Log -Value "ERROR: no internet connection found, please connect to the internet"
            return 
        } 
    }

    # Retrieve the files in the given folder
    $files = @()
    $fileList = @()
    ForEach ($localpath in $Path) { 
        Write-Log -Value "Retrieving files from path $localpath" 
        ForEach ($item in (Get-ChildItem -Path $Path -Recurse)) { 
            # Check if the exclusions need to be checked 
            If ($files -notcontains $item) {
             $files += $item 
             $fileList += $item.FullName
            } 
        } 
    } 

    # Parse each file 
    Write-Log -Value "Found $($files.Count) files" 
   
    ForEach ($file in ($files | Sort-Object -Property FullName)) { 
        # Write log entry 
        Write-Log -Value "Handling file $($file.FullName)"
 
        # Get the blob name for this file 
        $blobname = $file.FullName 
 
        # Check if the BLOB already exists 
        $copyblob = $false 
        $azblob = Get-AzureStorageBlob -Blob $blobname -Container $Global:AzureBlobContainerName -Context $context -ErrorAction SilentlyContinue 
        If ($azblob -eq $null) { 
            # Blob doesn't exit, copy the file to Azure 
            Write-Log -Value "File does not exist on Azure" 
            $copyblob = $true 
        }
 
        If ($copyblob -eq $true) { 
            # Blob doesn't exist, upload the blob with lastwrite metadata 
            Write-Log -Value "Copying local file $($file.Name) to blob $blobname in container $Container" 
 
            try { 
                $output = Set-AzureStorageBlobContent -File $file.FullName -Blob $blobname -Container $Global:AzureBlobContainerName -Context $context -Force -ErrorAction SilentlyContinue 
            } catch { 
                Write-Log -Value "ERROR: Could not copy file to Azure blob $($blobname): $($_.Exception.Message)"
            } 
        } 
    }

    # Removing Azure Blobs which doesn't contain local destination folder
    ForEach($AzureBlob in (Get-AzureStorageBlob -Container $Global:AzureBlobContainerName -Context $context | Select Name)) {

        if ($fileList.Contains($AzureBlob.Name.Replace("/","\")) -ne $true) {
            Write-Log -Value "$($AzureBlob.Name) should be removed. Removing..."

            try { 
                Remove-AzureStorageBlob -Blob $AzureBlob.Name -Container $Global:AzureBlobContainerName -Context $context 
                Write-Log -Value "Successfully removed."
            } catch { 
                Write-Log -Value "ERROR: Could not remove Azure blob $($AzureBlob.Name): $($_.Exception.Message)"
            }
        }
    }

    Write-Log -Value "END"
