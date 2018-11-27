####
#
# Description: Script used to pull extract scan configurations, to include exclusions, from Tenable.io.
#
#
# Requirement: You must have tenable_io.xml on your system as this script will pull your Access Key and Secret Key from that file.
#              Place the file in a location that is secure yet this script has the ability read.
#
# Version: .1 Initial Script December  21, 2017
#               Initial file layout
#          .2 Modified December 22, 2017
#               Added scan info extraction
#          .3 Modified November 1, 2017
#               Modified plugin ID from 10180 (ping) to 19506 (Nessus Scan Information)
#          .4 Modified May 8, 2018
#               Added scanner data extraction
#          .5 Modified May 16, 2018
#               Add use of PSExcel Installation process:   Install-Module -Name PSExcel
#               Results saved in Excel Workbook
#
####

# Pull in any needed modules.
Import-Module PSExcel

# Import configuration settings
[xml]$ConfigFile = Get-Content C:\{path_to_file}\config\tenable_io.xml
$Tenableio = $ConfigFile.Settings.Access.Url
$access = $ConfigFile.Settings.Access.AccessKey
$secret = $ConfigFile.Settings.Access.SecretKey
$headers = "accessKey=$access; secretKey=$secret"

# Name and location of file that data will be saved too.
$excelFile =  "c:\temp\Tenable_io.XLSX"
Remove-Item -Path $excelfile

### Get list of scanners
$scaners = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/scanners -Header @{ "X-ApiKeys" = $headers }
$scaners = $($response.scanners | select name, enviroment, status, group, distro, platform, engine_version, id, load_plugin_set, type)
$scaners | Export-XLSX -Path $excelFile -WorksheetName Scanners -Table

### Get Scan Info.
$scans = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/scans -Header @{ "X-ApiKeys" = $headers }
$scans = $($response.scans | select name, id, shared, starttime, owner, timezone, schedule_uuid, enabled)
$scans | Export-XLSX -Path $excelFile -WorksheetName Scans -Table 

### Get List of Exclusions
$exclusions = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/exclusions -Header @{ "X-ApiKeys" = $headers }
$exclusions = $($response.exclusions | select-object name, id, members, description, schedule)
$exclusions | Export-XLSX -Path $excelFile -WorksheetName Exclusions -Table

### Get list of System Target Groups
$targetGroups = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/target-groups -Header @{ "X-ApiKeys" = $headers }
$targetGroups = $($response.target_groups | select name, id, members, creation_date, last_modification_date, acls)
$targetGroups | Export-XLSX -Path $excelFile -WorksheetName Target_Groups -Table

### Get List of Policies
$policies = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/policies -Header @{ "X-ApiKeys" = $headers }
$policies = $($response.policies | select name, id, owner, creation_date, last_modification_date,shared, visibility, template_uuid)
$policies | Export-XLSX -Path $excelFile -WorksheetName Policies -Table

### Get List of Scan Configurations to Include Names of Target Groups
$hashtable = @()
ForEach ($r in $scans) {
    $scanID = $r.id
    $response = Invoke-RestMethod -Method Get -Uri $Tenableio/editor/scan/$scanID  -Header @{ "X-ApiKeys" = $headers }
    # Get list of Target Group ID's
    $result = @($response.settings.basic.inputs[6].default)
    # Lookup each Target Group ID to get the name and members
    ForEach ($key in $result) {
        $targetName = @()
        ForEach ($key in $result) {
            $groupName = $targetGroups | Where-Object { $_.id -eq $key} | Select name
            $targetName += $groupName
        }
    # Joing the Target Groups together with a comma seperating them.
    $targetNames = $($targetName.name -join ',')
    # Add the collected data to the variable $row
    $row = new-object PSObject -property @{
    Scan_Name = $r.name;
    Scan_ID = $r.id;
    Target_Groups = $targetNames
    }
    }
# Add variable to our hashtable as a new row
$hashtable += $row
}

# Save the results that are in the hashtable to a CSV.
$hashtable | sort-object Scan_Name | select-object Scan_Name, Scan_ID, Target_Groups | Get-unique -AsString | Export-XLSX -Path $excelFile -WorksheetName Scan_Configurations -Table
