<#
  We use this to verify UHG extracts ran correctly.
  It builds a report of the last executions and appends to $reportFile
#>

# Azure pipeline settings
$organization = "ryanunity"
$project = "TrackerPRO"
$artifactName = "drop"
$pipelineId = "3061"

$now = Get-Date
$nowdatetime = $now.ToString("MM/dd/yyyy hh:mm:ss tt")

# Log file setting, this is the file for AUP to look at to verify execution
$reportFile = "\\fs-est\Team_RSchaber\Active\Compliance\UHG_United Health Group\AutomationReports\DailyImportReports_$($now.ToString('yyyy-MM')).txt"
$uhgFolderOnRalphsDrive = Split-Path $reportFile

if (-not (Test-Path $uhgFolderOnRalphsDrive)) {
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host -Fore Red "Directory does not exist: $uhgFolderOnRalphsDrive"
Write-Host -Fore Red "Please verify the folder name or location."
Write-Host ""
Write-Host ""
Write-Host ""
throw
}

# Get credentials from secrets.txt
$secretsFile = "secrets.txt"
if (-Not (Test-Path $secretsFile)) {
    $logLines = @(
    ""
    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    "$nowdatetime - Secrets.txt was not found, cannot continue. Steve needs to fix this."
    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    ""
    )
    Add-Content -Path $reportFile -Value $logLines
    Write-Host -Fore Red "The file 'secrets.txt' was not found. Please create it in this folder"
    Read-Host -Prompt "Press enter to exit"
    exit 1
}
$secrets = Get-Content $secretsFile
$token = $secrets[5]
$clientId = $secrets[7]    # From Azure app registration
$tenantId = $secrets[9]    # From Azure app registration

# Convert $token to Base64 because the HTTP header needs it in that format
$tokenB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":" + $token))


# Function to display things to console while also logging the same strings
function fnLogAndDisplay {
    param(
        [string]$message,
        [string]$color = "White" # optional param to effect console message display, no effect on file logging
    )
    Add-content "$reportFile" $message
    Write-Host -Fore $color $message
}

# Function to download an Azure Pipeline artifact given a pipelineId and the filename we want to look at
function fnGet-ArtifactFromPipeline {
    param(
        [string]$pipelineId
    )

# Step 1: Find the latest runId given the pipelineId: "the latest execution of pipelineId 12345 was runId xyz"
#         Also get the build time so we can identify when it was created for client to download
    $latestRunUrl = "https://dev.azure.com/$organization/$project/_apis/build/builds?definitions=$pipelineId&`$top=1&api-version=6.0"
    $headers = @{ Authorization = "Basic $tokenB64" }
    $latestRunResponse = Invoke-RestMethod -Uri $latestRunUrl -Headers $headers
    $latestBuild = $latestRunResponse.value[0]
    $latestRunId = $latestBuild.id

$artifactName = "log.txt"
# Step 2: Download the artifact called drop given that latest runId
    $artifactUrl = "https://dev.azure.com/$organization/$project/_apis/build/builds/$latestRunId/artifacts?artifactName=drop&api-version=6.0"
    $artifactResponse = Invoke-RestMethod -Uri $artifactUrl -Headers $headers
    $downloadUrl = $artifactResponse.resource.downloadUrl
    $artifactName = "drop.zip"
    $artifactBaseName = [System.IO.Path]::GetFileNameWithoutExtension($artifactName)
    Invoke-RestMethod -Uri $downloadUrl -Headers $headers -OutFile $artifactName

# Step 3: Temp file system management - Unzip the artifactName.zip file to a temporary folder and extract the targetFile
    $destinationPath = "artifact_$pipelineId"
    Expand-Archive -Path $artifactName -DestinationPath $destinationPath -Force
    $sourceFilePath = Join-Path -Path $destinationPath -ChildPath $artifactBaseName
    $interface3Folder = Join-Path $sourceFilePath "03_DailyImports"

    $etlReportFile = Get-ChildItem -Path $interface3Folder -File -Filter "*ETLRPT*" | Select-Object -First 1

    $contents = Get-Content -Path $etlReportFile.FullName -Raw

    Write-Host ''
    Write-Host "$contents"
    Write-Host ''
    Write-Host -Fore Cyan "Logged to:"
    Write-Host -Fore Cyan "`'$reportFile`'"

    [System.IO.File]::AppendAllText(
        $reportFile,
        $contents + "`r`n`r`n"
    )

# Step 6: Cleanup. Remove the downloaded zip file and extracted contents
    if (Test-Path $artifactName) {
        Remove-Item -Path $artifactName -Force -Recurse
    }
    if (Test-Path $destinationPath) {
        Remove-Item -Path $destinationPath -Force -Recurse
    }
}

<# MAIN EXECUTION #>

# Get latest pipeline run
fnGet-ArtifactFromPipeline -pipelineId "$pipelineId"

# Keep console up for a bit
$howLongToShowLog = 120;
$logDisplayUntil = (Get-Date).AddSeconds($howLongToShowLog);
Write-Host "";
Write-Host -fore Green "Pausing for $howLongToShowLog seconds...";
Write-Host -fore Green "This screen will automatically close at $logDisplayUntil...";
Start-Sleep $howLongToShowLog;