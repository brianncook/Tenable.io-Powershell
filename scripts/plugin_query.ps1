####
#
# Description: Script to demonstrate using Tenable.io API's.
# 
#
# Requirement: You must have tenable_io.xml on your system as this script will pull your Access Key and Secret Key from that file. 
#              Place the file in a location that is secure yet this script has the ability read.
#
# Version: .1 Initial Script December 20, 2017
#		        Create report
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

function reportSeverity($authenticated, $exploitable, $severity, $title) {
  $outFile=($title + ".csv")
  $object = "workbenches/vulnerabilities?authenticated=$authenticated&exploitable=$exploitable&resolvable=false&severity=$severity"
  $response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers }
  $response.vulnerabilities | select plugin_id, plugin_name, plugin_family, severity, count, accepted_count, recasted_count | export-csv $outFile -noType
}

# Main script

## Create list of systems authentication is not using local admin privilege
echo "This query is to generate a CSV report based on the Tenable plugin ID"
echo "provided by the user. Feel free to search for the plugin ID in your"
echo "Tenable.io system or via the web page https://www.tenable.com/plugins."

$plugin = Read-Host -Prompt 'Input the Tenable vulnerability plugin ID'
$report = Read-Host -Prompt 'Input name to call report'
$export = listSystems csv vulnerabilities vuln_by_asset $plugin
Download-Report $export $report csv
