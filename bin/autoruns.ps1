# Author: @reg0bs
# https://github.com/reg0bs/TA-autoruns
# Credits go to the original authors: Chris Long (@Centurion), Andy Robbins (@_wald0) and of course to Mark Russinovich (@markrussinovich)

# This TA executes the Sysinternals Autoruns CLI utility and returns the results to be picked up by Splunk

param (
    [Parameter(Mandatory=$False)]
    [Timespan]
    $MaxBaselineAge,

    [Parameter(Mandatory=$False)]
    [Switch]
    $Baseline
)

$ErrorActionPreference = 'Continue'

$Timestamp =        Get-Date -Format o
$AutorunsExe =      Join-Path -Path $PSScriptRoot -ChildPath 'autorunsc64.exe'
$AutorunsCsv =      Join-Path -Path $PSScriptRoot -ChildPath 'autoruns.csv'
$AutorunsCsvTemp =  Join-Path -Path $PSScriptRoot -ChildPath 'autoruns-temp.csv'
$AutorunsState =    Join-Path -Path $PSScriptRoot -ChildPath 'autoruns-state.txt'

# Cleanup temporary files
if (Test-Path -Path $AutorunsCsvTemp) {
    Remove-Item -Path $AutorunsCsvTemp -Force
}

# Lower the priority of the script to avoid performance impacts
$Process = Get-Process -Id $pid
$Process.PriorityClass = 'BelowNormal'

# If autorunsc64.exe was not downloaded, show error and exit
if (!(Test-Path $AutorunsExe)) {
    Write-Ouput 'File not found: ' + $AutorunsExe + '. Please download from https://live.sysinternals.com/autorunsc64.exe and place it into the bin folder'
    exit -1
}

# If baseline is older then $MaxBaselineAge or $Baseline was specified then delete baseline to force a new one
if ((Test-Path -Path $AutorunsState) -and ($PSBoundParameters.ContainsKey('MaxBaselineAge')) -or $Baseline) {
    [DateTime]$BaselineDate = Get-Content -Path $AutorunsState
    $Now = Get-Date
    $BaselineAge = New-Timespan -Start $BaselineDate -End $Now
    if ($BaselineAge -gt $MaxBaselineAge) {
        Remove-Item -Path $AutorunsCsv -Force
    }
}

## autorunsc64.exe flags:
# -nobanner    Don't output the banner (breaks CSV parsing)
# -accepteula  Automatically accept the EULA
# -a *         Record all entries
# -c           Output as CSV
# -h           Show file hashes
# -s           Verify digital signatures
# -v           Query file hashes againt Virustotal (no uploading)
# -vt          Accept Virustotal Terms of Service
#  *           Scan all user profiles

# Start Autoruns and log results to CSV
Start-Process -FilePath $AutorunsExe -ArgumentList '-nobanner', '-accepteula', '-a *', '-c', '-h', '-s', '-v', '-vt', '*' -Wait -RedirectStandardOut $AutorunsCsvTemp -WindowStyle hidden
$Autoruns = Import-Csv -Path $AutorunsCsvTemp

# If previous results exist, output difference...
if (Test-Path -Path $AutorunsCsv -PathType Leaf) {
    $AutorunsPrev = Import-Csv -Path $AutorunsCsv
    $AutorunsDiff = Compare-Object -ReferenceObject $AutorunsPrev -DifferenceObject $Autoruns
    foreach ($Item in $AutorunsDiff) {
        if ($Item.SideIndicator -eq '=>') {
            $Item.InputObject | Add-Member -NotePropertyName action -NotePropertyValue created
        }
        elseif ($Item.SideIndicator -eq '<=') {
            $Item.InputObject | Add-Member -NotePropertyName action -NotePropertyValue deleted
        }
        Write-Output $Item.InputObject
    }
}
# ...else output the full list aka baseline
else {
    foreach ($Item in $Autoruns) {
        $Item  | Add-Member -NotePropertyName action -NotePropertyValue baseline
        Write-Output $Item
    }
    # Save timestamp of newly created baseline
    $Timestamp | Out-File $AutorunsState

}

# Set temporary file as baseline for the next run
Move-Item -Path $AutorunsCsvTemp -Destination $AutorunsCsv -Force