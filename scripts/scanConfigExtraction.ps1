####
#
# Description: Script used to pull extract scan configurations, to include exclusions, from Tenable.io.
#
# Use at your own risk. Script is not supported by Tenable.
#
# Requirement: You must have tenable_io.xml on your system as this script will pull your Access Key and Secret Key from that file.
#              Place the file in a location that is secure yet this script has the ability read.
#
# Version: .1 Initial Script December  21, 2017
#           Initial file layout
# Version: .2 Modified December 22, 2017
#           Added scan info extraction
# Version: .3 Modified November 1, 2017
#           Modified plugin ID from 10180 (ping) to 19506 (Nessus Scan Information)
# Version: .4 Modified May 8, 2018
#           Added scanner data extraction
# Version: .5 Modified May 16, 2018
#           Add use of PSExcel Installation process:   Install-Module -Name PSExcel
#           Results saved in Excel Workbook
# Version: .6 Modified November 27, 2018
#           Added worksheet assets to contain information about the assets T.io knows of. 
# Version: .7 Modified December 11, 2018
#           Added users, groups and access-groups.
#
####

Import-Module PSExcel

# Import configuration settings
# Uncomment and change directory path when running on a Mac system.
[xml]$ConfigFile = Get-Content /Users/bcook/Desktop/Powershell/tenable_io.xml
# Uncomment and change directory path when running on a Windows system.
#[xml]$ConfigFile = Get-Content c:\Users\Brian\Desktop\Powershell\tenable_io.xml
$Tenableio = $ConfigFile.Settings.Access.Url
$access = $ConfigFile.Settings.Access.AccessKey
$secret = $ConfigFile.Settings.Access.SecretKey
$headers = "accessKey=$access; secretKey=$secret"

#$excelFile =  "c:\temp\Tenable_io.XLSX"
$excelfile = "/Users/bcook/Desktop/Powershell/Tenable_io.XLSX"
Remove-Item -Path  $excelfile

### Get a list of the assets T.io knows of
$json = @{
  "chunk_size"= "1000"
}
$body = $json | ConvertTo-Json

# Time conversion
$origin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0

### Get list of access-groups
$ag = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/access-groups -Header @{ "X-ApiKeys" = $headers }
$ag = $($response.access_groups)
$ag | sort-object name | Export-XLSX -Path $excelFile -WorksheetName Access-Groups -Table

### Get list of groups
$groups = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/access-groups -Header @{ "X-ApiKeys" = $headers }
$groups = $($response.groups)
$groups | sort-object name | Export-XLSX -Path $excelFile -WorksheetName Groups -Table

### Get list of users
$users = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/users -Header @{ "X-ApiKeys" = $headers }
$users = $($response.users | select username, enabled, id, email, name, type, permission, login_fail_count,
login_fail_total, @{Name='lastlogin';Expression={($origin.AddSeconds($_.lastlogin))}})
$users | sort-object username | Export-XLSX -Path $excelFile -WorksheetName Users -Table

# Get list of assets
$asset = @()
$object = "assets/export"
$response = Invoke-RestMethod -Method POST -Uri $Tenableio/$object -Body $body -ContentType 'application/json' -Header @{ "X-ApiKeys" = $headers }
$file = $response.export_uuid
DO {
$object = "assets/export/$file/status"
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers }
Write-Host $response[0].status
  } #End of do
Until ($response[0].status -eq "finished")
ForEach ($i in $response.chunks_available) {
  $object = "assets/export/$file/chunks/$i"
  $response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers }
  $assets = $($response | select-object @{Name='hostnames';Expression={[string]::join(";",($_.hostnames))}},
    @{Name='netbios_names';Expression={[string]::join(";",($_.netbios_names))}}, 
    @{Name='fqdns';Expression={[string]::join(";",($_.fqdns))}},
    @{Name='operating_systems';Expression={[string]::join(";",($_.operating_systems))}},
    id, has_agent, @{Name='agent_names';Expression={[string]::join(";",($_.agent_names))}},
    @{Name='created_at';Expression={($origin.AddSeconds($_.created_at))}},
    @{Name='first_seen';Expression={($origin.AddSeconds($_.first_seen))}},
    @{Name='last_seen';Expression={($origin.AddSeconds($_.last_seen))}},
    @{Name='first_scan_time';Expression={($origin.AddSeconds($_.first_scan_time))}},
    @{Name='last_scan_time';Expression={($origin.AddSeconds($_.last_scan_time))}},
    @{Name='last_authenticated_scan_date';Expression={($origin.AddSeconds($_.last_authenticated_scan_date))}},
    @{Name='ipv4s';Expression={[string]::join(";",($_.ipv4s))}},
    @{Name='ipv6s';Expression={[string]::join(";",($_.ipv6s))}},
    @{Name='mac_addresses';Expression={[string]::join(";",($_.mac_addresses))}},
    @{Name='network_interfaces';Expression={[string]::join(";",($_.network_interfaces))}},
    @{Name='sources';Expression={[string]::join(";",($_.sources))}})
}
$assets | Export-XLSX -Path $excelFile -WorksheetName Assets -Table 

### Get list of scanners
$scaners = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/scanners -Header @{ "X-ApiKeys" = $headers }
$scaners = $($response.scanners | select name, 
@{Name='creation_date';Expression={($origin.AddSeconds($_.creation_date))}},
@{Name='last_connect';Expression={($origin.AddSeconds($_.last_connect))}},
@{Name='last_modification_date';Expression={($origin.AddSeconds($_.last_modification_date))}},
status, group, distro, platform, engine_version, id, loaded_plugin_set, type)
$scaners | Export-XLSX -Path $excelFile -WorksheetName Scaners -Table

### Get Scan Info.
$scans = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/scans -Header @{ "X-ApiKeys" = $headers }
$scans = $($response.scans | select name, id, shared,
@{Name='creation_date';Expression={($origin.AddSeconds($_.creation_date))}}, 
starttime, rrules, owner, timezone, schedule_uuid, enabled, status)
$scans | Export-XLSX -Path $excelFile -WorksheetName Scans -Table

### Get List of Exclusions
$exclusions = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/exclusions -Header @{ "X-ApiKeys" = $headers }
$exclusions = $($response.exclusions | select-object name, id, members, description,  
@{Name='creation_date';Expression={($origin.AddSeconds($_.creation_date))}}, 
@{Name='last_modification_date';Expression={($origin.AddSeconds($_.last_modification_date))}}, schedule.enabled,
@{Name='schedule.starttime';Expression={($origin.AddSeconds($_.schedule.starttime))}},
@{Name='schedule.endtime';Expression={($origin.AddSeconds($_.schedule.endtime))}})
$exclusions | Export-XLSX -Path $excelFile -WorksheetName Exclusions -Table

### Get list of System Target Groups
$targetGroups = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/target-groups -Header @{ "X-ApiKeys" = $headers }
$targetGroups = $($response.target_groups | select name, id, members, 
@{Name='creation_date';Expression={($origin.AddSeconds($_.creation_date))}}, 
@{Name='last_modification_date';Expression={($origin.AddSeconds($_.last_modification_date))}}, 
@{Name='acls';Expression={[string]::join(";",($_.acls))}})
$targetGroups | Export-XLSX -Path $excelFile -WorksheetName Target_Groups -Table

### Get List of Policies
$policies = @()
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/policies -Header @{ "X-ApiKeys" = $headers }
$policies = $($response.policies | select name, id, owner,
@{Name='creation_date';Expression={($origin.AddSeconds($_.creation_date))}}, 
@{Name='last_modification_date';Expression={($origin.AddSeconds($_.last_modification_date))}}, shared, visibility, template_uuid)
$policies | Export-XLSX -Path $excelFile -WorksheetName Policies -Table

### Get List of Scan Configurations to Include Names of Target Groups
$hashtable = @()
ForEach ($r in $scans) {
  if ($r.name -notmatch "^pvs*" -And $r.name -notmatch "^nnm*") {
     $scanID = $r.id
     Write-Host $scanID $r.name
     $response = Invoke-RestMethod -Method Get -Uri $Tenableio/editor/scan/$scanID -Header @{ "X-ApiKeys" = $headers }
     # Get list of Target Group ID's
     $result = @($response.settings.basic.inputs[6].default)
     # Lookup each Target Group ID to get the name and members
     ForEach ($key in $result) {
       $targetName = @()
       ForEach ($subkey in $result) {
         $groupName = $targetGroups | Where-Object { $_.id -eq $subkey} | Select name
         $targetName += $groupName
       }
     # Joining the Target Groups together with a comma separating them.
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
}

# Save the results that are in the hashtable to a CSV.
$hashtable | sort-object Scan_Name | select-object Scan_Name, Scan_ID, Target_Groups | Get-unique -AsString | Export-XLSX -Path $excelFile -WorksheetName Scan_Configurations -Table
