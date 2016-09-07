
function Send-Mail ($Body, $subjectExtra, $EmailTo) {
    $EmailFrom = "user@domain.dk"
    $EmailTo = $EmailTo 
    $Subject = "Mysql backup" + $subjectExtra
    $SMTPServer = "mail.kimdamdev.dk" 
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587) 
    $SMTPClient.EnableSsl = $true 
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential("user@domain.dk", "<password here>"); 
    $SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)
}
$ErrorActionPreference = 'stop'
trap { 
    #this will run if terminating error occurs
    $ErrorActionPreference = 'Continue'

    $msgBody = "Der opstod en fejl med backup af mysql databaser.\n\nError: " + $error[0] + " Line number: " + $_.InvocationInfo.ScriptLineNumber
     Send-Mail -Body $msgBody -subjectExtra "Error" -EmailTo "kim@kimdamdev.dk"
     Send-Mail -Body $msgBody -subjectExtra "Error" -EmailTo "kimdamdev@outlook.dk"
    break
}

$limit = (Get-Date).AddDays(-14)
$path = "C:\backupFiles\mysql\" 

# Delete files older than the $limit.
Get-ChildItem -Path $path -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force

# Delete any empty directories left behind after deleting the old files.
Get-ChildItem -Path $path -Recurse -Force | Where-Object { $_.PSIsContainer -and (Get-ChildItem -Path $_.FullName -Recurse -Force | Where-Object { !$_.PSIsContainer }) -eq $null } | Remove-Item -Force -Recurse


# Core settings - you will need to set these 
$mysql_server = "127.0.0.1"
$mysql_user = "root" 
$mysql_password = "<password here>" 
$backupstorefolder= "C:\backupFiles\mysql\" 
$dbName = "wikidb"

$pathtomysqldump = "C:\Program Files\MySQL\MySQL Server 5.6\bin\mysqldump.exe"

cls
# Determine Today´s Date Day (monday, tuesday etc)
$timestamp = Get-Date -format yyyyMMddHHmmss
Write-Host $timestamp 

[void][system.reflection.Assembly]::LoadFrom("C:\Program Files (x86)\MySQL\MySQL Connector Net 6.9.7\Assemblies\v4.5\MySql.Data.dll")

# Connect to MySQL database 'information_schema'
[system.reflection.assembly]::LoadWithPartialName("MySql.Data")
$cn = New-Object -TypeName MySql.Data.MySqlClient.MySqlConnection
$cn.ConnectionString = "SERVER=$mysql_server;DATABASE=information_schema;UID=$mysql_user;PWD=$mysql_password"
$cn.Open()

# Query to get database names in asceding order
$cm = New-Object -TypeName MySql.Data.MySqlClient.MySqlCommand
$sql = "SELECT DISTINCT CONVERT(SCHEMA_NAME USING UTF8) AS dbName, CONVERT(NOW() USING UTF8) AS dtStamp FROM SCHEMATA ORDER BY dbName ASC"
$cm.Connection = $cn
$cm.CommandText = $sql
$dr = $cm.ExecuteReader()

 $createFolder = $backupstorefolder + $timestamp
New-Item -ItemType Directory -Force -Path $createFolder
$createFolder

# Loop through MySQL Records
while ($dr.Read())
{
 # Start By Writing MSG to screen
 $dbname = [string]$dr.GetString(0)
 if($dbname -match $dbName)
 {
 write-host "Backing up database: " $dr.GetString(0)
 
 # Set backup filename and check if exists, if so delete existing
 $backupfilename = $timestamp + "\" + $timestamp + "_" + $dr.GetString(0) + ".sql"
 $backuppathandfile = $backupstorefolder + "" + $backupfilename
 If (test-path($backuppathandfile))
 {
 write-host "Backup file '" $backuppathandfile "' already exists. Existing file will be deleted"
 Remove-Item $backuppathandfile
 }
 
 $ErrorActionPreference = 'SilentlyContinue'

 # Invoke backup Command. /c forces the system to wait to do the backup
 cmd /c " `"$pathtomysqldump`" --routines -h $mysql_server -u $mysql_user -p$mysql_password $dbname > $backuppathandfile"
 $ErrorActionPreference = 'stop'
 $backuppathandfile
 If (test-path($backuppathandfile))
 {
 write-host "Backup created. Presence of backup file verified"
 }
 }
 
 
# Write Space
 write-host " "
}
 
# Close the connection
$cn.Close() 



# where this script files and required files are located
[string] $ScriptDirectory = "C:\backupScripts\mysql"

# source file path
[string] $SourceFileName = $createFolder

# destination file path
[string] $DestinationFileName = $createFolder + ".zip"

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

Send-Mail -Body $msgBody -subjectExtra "Success" -EmailTo "kim@kimdamdev.dk"
