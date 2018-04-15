####
#
# Description: Script to demonstrate using Tenable.io API's.
#
# Requirement: You must have tenable_io.xml on your system as this script will pull your Access Key and Secret Key from that file. 
#              Place the file in a location that is secure yet this script has the ability read.
#
# Version: .1 Initial Script February 21, 2018
#		        Create report.
#
#####

# Import configuration settings
[xml]$ConfigFile = Get-Content C:\{path_to_file}\config\tenable_io.xml
$Tenableio = $ConfigFile.Settings.Access.Url
$access = $ConfigFile.Settings.Access.AccessKey
$secret = $ConfigFile.Settings.Access.SecretKey

# Header
$headers = "accessKey=$access; secretKey=$secret"

# Request a report to be generated
function listSystems($reportFormat, $reportValue, $Reportchapter, $pluginID) {
  $object = "workbenches/export?format=$reportFormat&report=$reportValue&chapter=$reportChapter&plugin_id=$pluginID"
  $response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers }
  Write-Host $response[0].outputs
  return $response[0].file
}

# Request a report to be generated
function Download-Report($inFile, $title, $fileExtension) {
  $outFile=($title + "." + $fileExtension)
  # Query Tenable.io to see if the requested file for status. 
  DO {
    $object = "workbenches/export/$inFile/status"
    $response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers }
    Write-Host $response[0].status
  }

  Until ($response[0].status -eq "ready")
  # Once the file is ready, pull down and save to the local system.
  $object = "workbenches/export/$inFile/download"
  Write-Host $object
  $response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers } -OutFile $outFile
}

## Windows Local Checks not run - Auth Failure report
echo "Generating authentication failure report (Plugin 21745). Local security checks have been disabled for this host because either the credentials supplied in the scan policy did not allow Nessus to log into it or some other problem occurred."
$export = listSystems csv vulnerabilities vuln_by_asset 21745
Download-Report $export windows_local_checks_not_run csv
