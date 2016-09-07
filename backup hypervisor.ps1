function Send-Mail ($Body, $subjectExtra, $EmailTo) {
    $EmailFrom = "user@domian.dk"
    $EmailTo = $EmailTo 
    $Subject = "VM Backup" + $subjectExtra
    $SMTPServer = "mail.domain.dk" 
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587) 
    $SMTPClient.EnableSsl = $true 
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential("user@domain.dk", "<your password here>"); 
    $SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)
}
$ErrorActionPreference = 'stop'
trap { 
    #this will run if terminating error occurs
    $ErrorActionPreference = 'Continue'

    $msgBody = "Der opstod en fejl med backup af VMs.\n\nError: " + $error[0] + " Line number: " + $_.InvocationInfo.ScriptLineNumber
     Send-Mail -Body $msgBody -subjectExtra "Error" -EmailTo "user@domain.dk"
     Send-Mail -Body $msgBody -subjectExtra "Error" -EmailTo "user2@domain.dk"

     runBackup
    break
}

[System.Threading.Thread]::CurrentThread.Priority = 'Lowest'

$logFilePath = "C:\backupscripts\logs\"
$backupPath = "c:\backups\"
$filedate = get-date -format "d-M-yyyy"
$randomId = Get-Random
$fileName = $filedate + "-id" + $randomId
$path = "C:\backups\" + $fileName
$networkBackupPath = "\\u110052.your-backup.de\backup\VMs"
$networkBackupPathWithFileFolderName = $networkBackupPath + "\" + $fileName

Function LogWrite
{
   Param ([string]$logstring)
   $timestamp = $(get-date -f MM-dd-yyyy_HH_mm_ss)
   $valueContent = $timestamp + " - " + $logstring

   $logFilePath = $logFilePath + $(get-date -f MM-dd-yyyy_HH_mm_ss) + "-vmbackup.log"
   Add-content $logFilePath -value $valueContent
}

Function Write-ZipUsing7Zip([string]$FilesToZip, [string]$ZipOutputFilePath, [string]$Password, [ValidateSet('7z','zip','gzip','bzip2','tar','iso','udf')][string]$CompressionType = 'zip', [switch]$HideWindow)
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
    $p = Start-Process $pathTo7ZipExe -ArgumentList $arguments -PassThru -WindowStyle $windowStyle       
    $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
    $p.WaitForExit()

    # If the files were not zipped successfully.
    if (!(($p.HasExited -eq $true) -and ($p.ExitCode -eq 0)))
    {
        throw ("There was a problem creating the zip file '$ZipOutputFilePath'.")
    }
}


Function runBackup() {
    net use "\\u110052.your-backup.de\backup" "<password here >" "/USER:<username here>"

    

    $limit = (Get-Date).AddDays(-7)
    $limit2 = (Get-Date).AddDays(-4)

    LogWrite -logstring "Starting VMs backup"

    # Delete in local

    # Delete files older than the $limit.
    Get-ChildItem -Path $backupPath -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force

    # Delete any empty directories left behind after deleting the old files.
    Get-ChildItem -Path $backupPath -Recurse -Force | Where-Object { $_.PSIsContainer -and (Get-ChildItem -Path $_.FullName -Recurse -Force | Where-Object { !$_.PSIsContainer }) -eq $null } | Remove-Item -Force -Recurse


    # Delete in network path

    # Delete files older than the $limit.
    Get-ChildItem -Path $networkBackupPath -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit2 } | Remove-Item -Force

    # Delete any empty directories left behind after deleting the old files.
    Get-ChildItem -Path $networkBackupPath -Recurse -Force | Where-Object { $_.PSIsContainer -and (Get-ChildItem -Path $_.FullName -Recurse -Force | Where-Object { !$_.PSIsContainer }) -eq $null } | Remove-Item -Force -Recurse

    LogWrite -logstring "Deleteing old backups in '" + $networkBackupPath + "'"

    LogWrite -logstring "Exporting 'Web server' in '" + $path + "'"
    Export-VM "Webserver" $path
    LogWrite -logstring "Export done"

    # where this script files and required files are located
    [string] $ScriptDirectory = "C:\backupscripts"

    # source file path
    [string] $SourceFileName = $path

    # destination file path
    [string] $DestinationFileName = $path + ".zip"

    # password to protect the zip file being extracted
    [string] $PasswordToZipFile = "<password encrypt>"


    # compression level
    [string] $CompressionLevel = "-mx7"

    ## Switch -mx0: Don't compress at all. This is called "copy mode."
    ## Switch -mx1: Low compression. This is called "fastest" mode.
    ## Switch -mx3: Fast compression mode. Will automatically set various parameters.
    ## Switch -mx5: Same as above, but "normal."
    ## Switch -mx7: This means "maximum" compression.
    ## Switch -mx9: This means "ultra" compression. You probably want to use this.





    LogWrite -logstring "Starting to zip '" + $SourceFileName + "' and destination is '" + $DestinationFileNam + "'"
    Write-ZipUsing7Zip -FilesToZip $SourceFileName -ZipOutputFilePath $DestinationFileName -Password $PasswordToZipFile -CompressionType zip -HideWindow $false
    LogWrite -logstring "Zipping is done"

    LogWrite -logstring "Uploading '" + $DestinationFileName + "' to '" + $pathToNetworkDrive + "'"
    $pathToNetworkDrive = $networkBackupPathWithFileFolderName + ".zip"
    Copy-Item -Path $DestinationFileName -Destination $pathToNetworkDrive
    LogWrite -logstring "Uploading done"

    LogWrite -logstring "Deleing '" + $SourceFileName + "'"
    Remove-Item -Path $SourceFileName -Force -Recurse

    LogWrite -logstring "VMs backup success"
    Send-Mail -Body "Det lykkes at lave en backup af VMs" -subjectExtra "Success" -EmailTo "kim@kimdamdev.dk"
}

runBackup