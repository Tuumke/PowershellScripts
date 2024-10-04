#Requires -Version 5.1
#Requires -Modules AzureADPreview, ImportExcel
<#
.Synopsis
    Script to check Sign-In logs in error code
.DESCRIPTION
	Script to check Entra ID SignIn logs on sepcified error code. For example 90094 "Admin consent is required for the permissions requested by this application."
.NOTES
	Version: v0.5
	Author: Tuumke
	Contributors: purplemonkeymad, Certain-Community438

	CHANGELOG:
	v0.5 Changed variable name to signInLogProperties so it reflects better with the Get-command to avoid confusion
	v0.4 Make the script more readable after great feedback from purplemonkeymad (reddit)
	v0.3 Add check for AzureAD Connection and check for opened explorers
	v0.2 Added extra parameters
	v0.1 Initial Script


.PARAMETER ErrorCode
	ErrorCodes found in SignIn logs. Default is 90094 which is "Admin consent is required for the permissions requested by this application."
.PARAMETER StartDate
	Date from where to start. Not sure how far back you can with default licenses. I think max is 30 days? I've set the default to 30 days.
.PARAMETER Path
	Path where the script will store the export. Default is location where the script is stored
.PARAMETER Filename
	The filename of the export. Default is for example Check-SignInLogs-2024-10-04_09-06-33.xlsx

.EXAMPLE
	.\Check-SignInLogs.ps1 -ErrorCode 90094
.EXAMPLE
	.\Check-SignInLogs.ps1 -ErrorCode 90094 -StartDate "2024-10-04"
.EXAMPLE
	.\Check-SignInLogs.ps1 -ErrorCode 90094 -StartDate "2024-10-04" -Path "C:\temp"
.EXAMPLE
	.\Check-SignInLogs.ps1 -ErrorCode 90094 -StartDate "2024-10-04" -Path "C:\temp" -Filename "Whatever.xlsx"
#>

param
(
	[Parameter(Mandatory = $False)]
	[int]$ErrorCode = 90094,

	[Parameter(Mandatory = $False)]
	$StartDate = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd'),

	[Parameter(Mandatory = $False)]
	[string]$Path = $PWD,

	[Parameter(Mandatory = $False)]
	[string]$Filename = "Check-SignInLogs" + (Get-Date -Format 'yyyy-MM-dd_hh-mm-ss') + ".xlsx"
)

If(!$connection){
	$connection = AzureADPreview\Connect-AzureAD
}


## Check if the path has a trailinig slash or not. If not, we need one for a good folder path
if ($Path -match '[\\/]+$'){
	$export = $Path + $Filename
}else{
	$export = $Path + "\" + $Filename
}

$signInLogProperties = @(
	'userPrincipalName'
	'appDisplayName'
	'ipAddress'
	'clientAppUsed'
	@{Name = 'DeviceOS'; Expression = {$_.DeviceDetail.OperatingSystem}}
	@{Name = 'Location'; Expression = {$_.Location.City}}
	@{Name = 'Country'; Expression = {$_.Location.countryOrRegion}}
	@{Name = 'ErrorCode'; Expression = {$_.status.errorCode}}
	@{Name = 'failureReaseon'; Expression = {$_.status.failureReason}}
)

$logs = Get-AzureADAuditSignInLogs -Filter "status/errorCode eq $ErrorCode and createdDateTime gt $StartDate" | 
		Select-Object $signInLogProperties | 
		Sort-Object userPrincipalName
$logs | Export-Excel -Path $export -NoNumberConversion IPAddress -FreezeTopRow -AutoFilter -AutoSize

## Opening explorer on the location of the exported file
$explorers = (New-Object -ComObject 'Shell.Application').Windows() 
$explorersResults = New-Object -TypeName System.Collections.ArrayList
foreach($result in $explorers){
	if($result.Document.Folder.Self.Path -eq $Path){
		$customObject4 = [PSCustomObject]@{
			location = $result.Document.Folder.Self.Path
			explorerOpen = $true
		}
		[void]$explorersResults.Add($customObject4)
	}else{
		$customObject5 = [PSCustomObject]@{
			location = $result.Document.Folder.Self.Path
			explorerOpen = $false
		}
		[void]$explorersResults.Add($customObject5)
	}
}
if($explorersResults.explorerOpen -contains $True){
	Write-Host "You still have an open explorer on $Path"
}else{
	Write-Host "Opening Explorer"
	&explorer $Path
}
