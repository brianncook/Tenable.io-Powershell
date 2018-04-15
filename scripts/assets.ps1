####
#
# Description: Script to demonstrate using Tenable.io API's.
# 
#
# Requirement: You must have tenable_io.xml on your system as this script will pull your Access Key and Secret Key from that file. 
#              Place the file in a location that is secure yet this script has the ability read.
#
# Version: .1 Initial Script September 25, 2017
#		            Create report
#		            Pull down report
#          .2 Modified October 26, 2017
#		            Modified the created report to filter on Ping plugin
#		            Added function assetList to pull unique UUID's and query every half second for asset information.
#          .3 Modified November 1, 2017
#		            Modified plugin ID from 10180 (ping) to 19506 (Nessus Scan Information)
# 
####

# Import configuration settings
# 
[xml]$ConfigFile = Get-Content C:\{path_to_file}\config\tenable_io.xml
$Tenableio = $ConfigFile.Settings.Access.Url
$access = $ConfigFile.Settings.Access.AccessKey
$secret = $ConfigFile.Settings.Access.SecretKey

# Header
$headers = "accessKey=$access; secretKey=$secret"

# Variables
$tempFile1="tenable_io.csv"
$outFile="assets.csv"

# Request a report to be generated
function listSystems($reportFormat, $reportValue, $Reportchapter)
{
$object = "workbenches/export?format=$reportFormat&report=$reportValue&chapter=$reportChapter&plugin_id=19506"
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers }
Write-Host $response[0].file
return $response[0].file
}

# Request a report to be generated
function Download-Report($file)
{
# Query Tenable.io to see if the requested file for status. 
DO {
$object = "workbenches/export/$file/status"
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers }
Write-Host $response[0].status
  } #End of do
Until ($response[0].status -eq "ready")

# Once the file is ready, pull down and save to the local system.
$object = "workbenches/export/$file/download"
Write-Host $object
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers } -OutFile $tempFile1
}

# Read vuln_by_asset report to generate asset list
function assetList ($outfile) 
{
if (Test-Path $outFile) {
 Remove-Item $outFile
}
# Read CSV 
$inputCsv = Import-Csv tenable_io.csv
$assets = $inputCsv."Asset UUID" | Sort-Object | Get-Unique
ForEach ($i in $assets)
{
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/workbenches/assets/$i/info -Header @{ "X-ApiKeys" = $headers }
$response.info | select id, @{Name='hostname';Expression={[string]::join(";",($_.hostname))}}, `
@{Name='netbios_name';Expression={[string]::join(";",($_.netbios_name))}}, `
@{Name='fqdn';Expression={[string]::join(";",($_.fqdn))}}, `
@{Name='ipv4';Expression={[string]::join(";",($_.ipv4))}}, `
@{Name='ipv6';Expression={[string]::join(";",($_.ipv6))}}, `
@{Name='mac_address';Expression={[string]::join(";",($_.mac_address))}}, `
@{Name='system_type';Expression={[string]::join(";",($_.system_type))}}, `
@{Name='has_agent';Expression={[string]::join(";",($_.has_agent))}}, `
@{Name='first_seen';Expression={[string]::join(";",($_.first_seen))}}, `
@{Name='last_seen';Expression={[string]::join(";",($_.last_seen))}}, `
@{Name='last_authenticated_scan_date';Expression={[string]::join(";",($_.last_authenticated_scan_date))}} | export-csv $outFile -noType -Append
Start-Sleep -m 500
# Cleanup previous file
if (Test-Path $tempFile1) {
 Remove-Item $tempFile1
}
}
}

# Main script
$export = listSystems csv vulnerabilities vuln_by_asset
Download-Report $export $tempFile1
assetList $outfile
