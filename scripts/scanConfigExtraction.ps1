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
#
####

# Import configuration settings
[xml]$ConfigFile = Get-Content C:\{path_to_file}\tenable_io.xml
$Tenableio = $ConfigFile.Settings.Access.Url
$access = $ConfigFile.Settings.Access.AccessKey
$secret = $ConfigFile.Settings.Access.SecretKey
$headers = "accessKey=$access; secretKey=$secret"

# Names of files that data will be saved too.
$scanFile = "scans.csv"
$exclusionFile ="exclusions.csv"
$targetGroupFile = "target_groups.csv"
$policyFile = "policies.csv"
$scanDataFile = "scan_data.csv"

### Get Scan Info.
$scans = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/scans -Header @{ "X-ApiKeys" = $headers }
$scans = $($response.scans | select name, id, shared, starttime, owner, timezone, schedule_uuid, enabled)
$scans | export-csv $scanFile -noType

### Get List of Exclusions
$exclusions = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/exclusions -Header @{ "X-ApiKeys" = $headers }
$exclusions = $($response.exclusions | select-object name, id, members)
$exclusions | Export-Csv $exclusionFile -noType

### Get list of System Target Groups
$targetGroups = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/target-groups -Header @{ "X-ApiKeys" = $headers }
$targetGroups = $($response.target_groups | select name, id, members, creation_date, last_modification_date)
$targetGroups | Export-Csv $targetGroupFile -noType

### Get List of Policies
$policies = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/policies -Header @{ "X-ApiKeys" = $headers }
$policies = $($response.policies | select name, id, owner, members, creation_date, last_modification_date)
$policies | Export-Csv $policyFile -noType

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
$hashtable | sort-object Scan_Name | select-object Scan_Name, Scan_ID, Target_Groups | Get-unique -AsString | Export-Csv $scanDataFile -noType
