function Send-Mail ($Body, $subjectExtra, $EmailTo) {
    $EmailFrom = "user@domain.dk"
    $EmailTo = $EmailTo 
    $Subject = "MS SQL backup" + $subjectExtra
    $SMTPServer = "mail.domain.dk" 
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587) 
    $SMTPClient.EnableSsl = $true 
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential("user@domain.dk", "<password here>"); 
    $SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)
}
$ErrorActionPreference = 'stop'
trap { 
    #this will run if terminating error occurs
    $ErrorActionPreference = 'Continue'

    $msgBody = "Der opstod en fejl med backup af SQL databaser.\n\nError: " + $error[0] + " Line number: " + $_.InvocationInfo.ScriptLineNumber
     Send-Mail -Body $msgBody -subjectExtra "Error" -EmailTo "kim@kimdamdev.dk"
     Send-Mail -Body $msgBody -subjectExtra "Error" -EmailTo "kimdamdev@outlook.dk"
    break
}$serverName = "OWNEROR-S1QRH4E"$backupDirectory = "C:\backupFiles\mssqlserver"$daysToStoreBackups = 9[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null $timestamp = Get-Date -format yyyyMMddHHmmss$server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $serverName$dbs = $server.Databases$limit = (Get-Date).AddDays(-15)
$path = $backupDirectory

# Delete files older than the $limit.
Get-ChildItem -Path $path -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force

# Delete any empty directories left behind after deleting the old files.
Get-ChildItem -Path $path -Recurse -Force | Where-Object { $_.PSIsContainer -and (Get-ChildItem -Path $_.FullName -Recurse -Force | Where-Object { !$_.PSIsContainer }) -eq $null } | Remove-Item -Force -Recurse$timestamp2 = Get-Date -format yyyyMMddHHmmss$folderBackupLocation = $backupDirectory + "\" + $timestamp2New-Item -ItemType directory -Path $folderBackupLocationforeach ($database in $dbs | where { $_.IsSystemObject -eq $False}){           $dbName = $database.Name                  $targetPath = $folderBackupLocation + "\" + $dbName + "_" + $timestamp + ".bak"             $smoBackup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup")            $smoBackup.Action = "Database"            $smoBackup.BackupSetDescription = "Full Backup of " + $dbName            $smoBackup.BackupSetName = $dbName + " Backup"            $smoBackup.Database = $dbName            $smoBackup.MediaDescription = "Disk"            $smoBackup.Devices.AddDevice($targetPath, "File")            $smoBackup.SqlBackup($server)             "backed up $dbName ($serverName) to $targetPath"               }
# where this script files and required files are located
[string] $ScriptDirectory = "C:\backupScripts\mssqlserver"

# source file path
[string] $SourceFileName = $folderBackupLocation

# destination file path
[string] $DestinationFileName = $folderBackupLocation + ".zip"

# password to protect the zip file being extracted
[string] $PasswordToZipFile = "<password here>"


# compression level
[string] $CompressionLevel = "-mx9"

## Switch -mx0: Don't compress at all. This is called "copy mode."
## Switch -mx1: Low compression. This is called "fastest" mode.
## Switch -mx3: Fast compression mode. Will automatically set various parameters.
## Switch -mx5: Same as above, but "normal."
## Switch -mx7: This means "maximum" compression.
## Switch -mx9: This means "ultra" compression. You probably want to use this.



function Write-ZipUsing7Zip([string]$FilesToZip, [string]$ZipOutputFilePath, [string]$Password, [ValidateSet('7z','zip','gzip','bzip2','tar','iso','udf')][string]$CompressionType = 'zip', [switch]$HideWindow)
{
    # validate for 7zip required files (7z.exe and 7z.dll)
    if (-not(Test-Path ($ScriptDirectory + "\7z.exe")))
    {
        throw "Could not find the 7zip.exe file."
    }
    elseif (-not(Test-Path ($ScriptDirectory + "\7z.dll")))
    {
        throw "Could not find the 7zip.dll file."
    }
   
    # Delete the destination zip file if it already exists (i.e. overwrite it).
    if (Test-Path $ZipOutputFilePath)
    {
        Remove-Item $ZipOutputFilePath -Force
    }
    
    $windowStyle = "Normal"
    if ($HideWindow)
    {
        $windowStyle = "Hidden"
    }
    
    # Create the arguments to use to zip up the files.
    # Command-line argument syntax can be found at: http://www.dotnetperls.com/7-zip-examples
    $arguments = "a -t$CompressionType ""$ZipOutputFilePath"" ""$FilesToZip"" $CompressionLevel"
   
    if (!([string]::IsNullOrEmpty($Password)))
    {
        $arguments += " -p$Password"
    }

    # Look for the 7zip executable.
    $pathTo7ZipExe = ($ScriptDirectory + "\7z.exe")
    
    # Zip up the files.
    $p = Start-Process $pathTo7ZipExe -ArgumentList $arguments -Wait -PassThru -WindowStyle $windowStyle       

    # If the files were not zipped successfully.
    if (!(($p.HasExited -eq $true) -and ($p.ExitCode -eq 0)))
    {
        throw ("There was a problem creating the zip file '$ZipOutputFilePath'.")
    }
}


Write-ZipUsing7Zip -FilesToZip $SourceFileName -ZipOutputFilePath $DestinationFileName -Password $PasswordToZipFile -CompressionType zip -HideWindow $false

Remove-Item -Recurse -Force $SourceFileName

Send-Mail -Body "Det lykkes at lave en backup af databaser" -subjectExtra "Success" -EmailTo "kim@kimdamdev.dk"
