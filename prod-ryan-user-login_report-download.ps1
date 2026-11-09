<#
  Identifies the latest run of the prod-ryan-user-login pipeline and saves the report to Marta's Sharepoint for support
#>
# Azure pipeline settings
$organization = "ryanunity"
$project = "TrackerPRO"
$artifactName = "ryan_user_login_report" # The name of the artifact container, not necessarily the file
$pipelineId = "2601"
$finalDestination = "C:\Users\rc04729\OneDrive - Ryan LLC\Shortcuts\Marta Bauer's files - Hosted Users"
$logfile = ".\log.txt"

# Function to display things to console while also logging the same strings
function fnLogAndDisplay {
    param(
        [string]$message,
        [string]$color = "White" # optional param to effect console message display, no effect on file logging
    )
    $timeypoo = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $timestampedMessage = "$timeypoo - $message"
    Add-content "$logfile" $timestampedMessage
    Write-Host -Fore $color $timestampedMessage
}

fnLogAndDisplay -message "*********************************** BEGIN ***********************************"

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


# Function to download most recent Azure Pipeline artifact given a pipelineId
function fnGet-ArtifactFromPipeline {
    param(
        [string]$pipelineId
    )
# Step 1: Find the latest runId given the pipelineId: "the latest execution of pipelineId 12345 was runId xyz"
#         Also get the build time in case we need it
    $easternTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
    while ($true) {
        Write-Host -NoNewLine "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz') Checking to see if pipeline completed yet today   "

        $latestRunUrl                      = "https://dev.azure.com/$organization/$project/_apis/build/builds?definitions=$pipelineId&`$top=1&api-version=6.0"
        $headers                           = @{ Authorization = "Basic $tokenB64" }
        $latestRunResponse                 = Invoke-RestMethod -Uri $latestRunUrl -Headers $headers
        $latestBuild                       = $latestRunResponse.value | Select-Object -First 1

        if ($latestBuild) {
            $latestRunId                   = $latestBuild.id
            $latestRunTime                 = [datetime]::Parse($latestBuild.QueueTime)
            $latestRunTimeEastern          = [TimeZoneInfo]::ConvertTime($latestRunTime, $easternTimeZone)

            if ($latestBuild.Result -eq "failed") {
                Write-Host -Fore Red "[Pipeline failed]"
                $latestRunResultsURLForWebBrowser = "https://dev.azure.com/$organization/$project/_build/results?buildId=$latestRunId&view=results"
                $fileNameDatePrefix               = Get-Date -Format 'yyyy-MM-dd'
                $destinationFile                  = Join-Path -Path $finalDestination -ChildPath "$fileNameDatePrefix ryan_user_login_report ADO_PIPELINE_FAILED.csv"
                "The ADO pipeline failed today so there is no output to provide.`r`nResults:,$latestRunResultsURLForWebBrowser" | Set-Content -Path $destinationFile
                Write-Host ""
                fnLogAndDisplay -color Red -message "ADO pipeline failed today, created failure file at $destinationFile"
                fnShow-Results Red
                exit
            }

            if ($latestRunTimeEastern.Date -eq [TimeZoneInfo]::ConvertTime([datetime]::UtcNow, $easternTimeZone).Date) {
                Write-Host -ForegroundColor Cyan "[YES]"
                break
            }
            else {
                Write-Host -ForegroundColor Magenta "[NO]"
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz') Waiting ten minutes to check again"
            }
        }

        else {
            Write-Host -ForegroundColor Red "[NO, Looks like the pipeline has never ran]"
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz') Waiting ten minutes to check again"
        }

        # Wait ten minutes, then check again
        Start-Sleep -Seconds 600
    }

# Step 2: Download the artifact for $latestRunId
    New-Item -ItemType Directory -Path '.\temp' -Force | Out-Null
    $artifactUrl         = "https://dev.azure.com/$organization/$project/_apis/build/builds/$latestRunId/artifacts?artifactName=$artifactName&api-version=6.0"
    $artifactResponse    = Invoke-RestMethod -Uri $artifactUrl -Headers $headers
    $artifactDownloadUrl = $artifactResponse.resource.DownloadUrl
    $artifactZipFile     = ".\temp\$artifactName.zip"
    Invoke-RestMethod -Uri $artifactDownloadUrl -Headers $headers -OutFile $artifactZipFile

# Step 3: Temp file system management - Unzip the artifactZipFileName file to a temporary folder and extract
    $unzippedPath        = ".\temp\artifact_$pipelineId"
    Expand-Archive -Path $artifactZipFile -DestinationPath $unzippedPath -Force
    $unzippedFile        = Get-ChildItem -LiteralPath $unzippedPath -File -Recurse | Select-Object -First 1
    $unzippedFileName    = $unzippedFile.Name

# Step 4: Remame file per Marta: "2026-03-27 ryan_user_login_report.csv"
#         And store on OneDrive so it shows in her Sharepoint folder
    $fileNameDatePrefix = Get-Date -Date $latestRunTime -Format 'yyyy-MM-dd'
    $finalFileName      = "$fileNameDatePrefix $unzippedFileName"
    $destinationFile    = Join-Path -Path $finalDestination -ChildPath "$fileNameDatePrefix ryan_user_login_report.csv"
    Copy-Item -LiteralPath $unzippedFile.FullName -Destination $destinationFile -Force

# Step 5: Cleanup. Remove the downloaded zip file and extracted contents
    if (Test-Path '.\temp') {
        Remove-Item -Path '.\temp' -Force -Recurse
    }
}

# Function to show results
function fnShow-Results {
    param(
        [string]$color = "Green"
    )
    $howLongToShowLog = 120
    $logDisplayUntil = (Get-Date).AddSeconds($howLongToShowLog)
    Write-Host ""
    Write-Host -fore $color "Pausing for $howLongToShowLog seconds..."
    Write-Host -fore $color "This screen will automatically close at $logDisplayUntil..."
    fnLogAndDisplay -message "***********************************  END  ***********************************"
    Start-Sleep $howLongToShowLog
}

<# MAIN EXECUTION #>
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""

# Get latest pipeline run
fnGet-ArtifactFromPipeline -pipelineId "$pipelineId"
fnShow-Results
