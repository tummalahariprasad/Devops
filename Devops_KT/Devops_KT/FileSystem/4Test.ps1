#################################################################################
#                                                                               #
#            Generate and export Concerto certificates (27-11-2019)             #
#                                                                               #
#################################################################################

cls

# Set trasnscript file

Start-Transcript -Path "C:\scripts\ExportCerts_log.txt"

###########################################################################################

# Enable SAN to a secure LDAP certificate, requires restarting ADCS

certutil -setreg policy\EditFlags +EDITF_ATTRIBUTESUBJECTALTNAME2
Write-Host
net stop certsvc
net start certsvc

# Wait for ADCS to restart

 write-host
 write-host "Please wait... (~1 Minute)"
 write-host

Write-Host -NoNewLine 

# Dispaly counter...

foreach($element in 1..25){

  Write-Host -NoNewLine  "${element} " -BackgroundColor "Green" -ForegroundColor "Black"

  Start-Sleep -Seconds 1

}

foreach($element in 26..50){

  Write-Host -NoNewLine  "${element} " -BackgroundColor "Yellow" -ForegroundColor "Black"

  Start-Sleep -Seconds 1

}

foreach($element in 51..100){

  Write-Host -NoNewLine  "${element} " -BackgroundColor "Red" -ForegroundColor "Black"

  Start-Sleep -Seconds 1

}
# Remove....

##########################################################################################


# Cleanup Certificate Request Files

Remove-Item c:\Scripts\webcert1.inf -ErrorAction silentlycontinue | Out-Null
Remove-Item c:\Scripts\webcert1.req -ErrorAction silentlycontinue | Out-Null
Remove-Item c:\Scripts\webcert1.cer -ErrorAction silentlycontinue | Out-Null

# Clear var.

Write-Host
$myserver =""

# Get user input

Write-Host
Do { $myServer = Read-Host -Prompt 'Enter Server Name'}
while ($myServer -eq "")
Write-Host

function CreateCert1
{
       Param(  [Parameter(Position=0,Mandatory=$true)][string] $CA_HOSTFQDN,
               [Parameter(Position=1,Mandatory=$true)][string] $CA_NAME,
               [Parameter(Position=2,Mandatory=$true)][string] $CERT_NAME
               )

Write-Host "CreateCert: Preparing Web Server Certificate request..."

Write-Host

$TemplateName = "WebServer"

Remove-Item c:\Scripts\webcert1.inf -ErrorAction silentlycontinue | Out-Null
Remove-Item c:\Scripts\webcert1.req -ErrorAction silentlycontinue | Out-Null

Add-Content c:\Scripts\webcert1.inf "[NewRequest]`r
Subject = `"CN=$myServer`"`r
Exportable = TRUE`r
RequestType = CMC`r
FriendlyName = `"$CERT_NAME`"`r  
[RequestAttributes]`r
CertificateTemplate = `"$TemplateName`"`r
[EnhancedKeyUsageExtension]`r
OID=1.3.6.1.5.5.7.3.1`r
OID=1.3.6.1.5.5.7.3.2"

certreq -new c:\Scripts\webcert1.inf c:\Scripts\webcert1.req | Out-Null
Write-Host  "CreateCert: Sending Certificate Request..."

$result =$myServer -as [IPAddress] -as [Bool]

if ($result -eq $true)
{
Write-Host "User has entered IP Address"
certreq -submit -attrib "SAN:DNS=$myserver&ipaddress=$myserver" c:\Scripts\webcert1.req c:\Scripts\webcert1.cer | Out-Null
}
else
{
Write-Host "User has entered FQDN"
certreq -submit -attrib "SAN:DNS=$myserver" c:\Scripts\webcert1.req c:\Scripts\webcert1.cer | Out-Null
}

certreq -accept c:\Scripts\webcert1.cer | Out-Null

ren c:\Scripts\webcert1.cer c:\Scripts\WebSRVCert.cer
remove-item c:\temp\*.cer
move c:\Scripts\WebSRVCert.cer c:\temp

# Cleanup Certificate Request Files

Remove-Item c:\Scripts\webcert1.inf -ErrorAction silentlycontinue | Out-Null
Remove-Item c:\Scripts\webcert1.req -ErrorAction silentlycontinue | Out-Null
Remove-Item c:\Scripts\webcert1.cer -ErrorAction silentlycontinue | Out-Null
}

# Run CreateCert1 function

CreateCert1 -CA_HOSTFQDN "$env:computername.$env:USERDNSDOMAIN" -CA_NAME "DomainCA" -CERT_NAME "Philips Concerto Certificate"

# Make sure that c:\temp exists

New-Item -ItemType Directory -Force -Path c:\Temp

# Definge vars for cert. export

$Password = "Philips1!"; #password to access certificate after exporting
$ExportPathRoot = "C:\Temp"

# Get Cert list to export

$CertListToExport = Get-ChildItem -Path cert:\LocalMachine\MY | ?{ $_.Subject -Like "CN=$myserver"} 

foreach($CertToExport in $CertListToExport | Sort-Object Subject)
{
    # Destination Certificate Name should be CN. 
    # Since subject contains CN, OU and other information,
    # extract only upto the next comma (,)

    $DestCertName=$myserver    
    $CertDestPath = Join-Path -Path $ExportPathRoot -ChildPath "$DestCertName.pfx"
    $SecurePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText

    # Export PFX certificate along with private key

    Export-PfxCertificate -Cert $CertToExport -FilePath $CertDestPath -Password $SecurePassword -Verbose
}

del c:\temp\*.rsp -Force
del c:\scripts\*.rsp -Force

# Export SRV *.cer

$cert1 = (Get-ChildItem -Path cert:\LocalMachine\My) | ?{ $_.Subject -Like "*CN=*-CA*" }| Select-Object -first 1
Export-Certificate -Cert $cert1 -FilePath C:\Temp\DomainCert.cer

Start c:\temp

Write-Host
Write-Host "Done..."
Write-Host

Stop-Transcript
