# TA-Autoruns
Technical Addon for Splunk to ingest Sysinternals' Autoruns output including the ability to only index changed entries.

This TA executes the Sysinternals Autoruns CLI utility and returns the results to be picked up by Splunk.

This TA was inspired by Palantir's AutorunsToWinEventLog (https://github.com/palantir/windows-event-forwarding),
but instead of creating a scheduled task and writing to the EventLog it uses a scripted input directly.

Make sure to download autorunsc64.exe from https://live.sysinternals.com/autorunsc64.exe and place it into the bin folder.
To enable the input copy default\inputs.conf into local and set disabled = false.

**Warning:** This script gets executed with a priority class of 'BelowNormal' to avoid performance impacts, still the scheduling of the script should be chosen wisely and impact to systems should be tested before using it on a large scale.

It's possible (and probably advised) to create a baseline and only log newly created or removed entries (you know...splunk and volume based licensing...)
Additionally the recreation of the baseline can be scheduled as well to work with retention policies.
The following example creates a new baseline every 7 days and logs changes every 4 hours.

```
[powershell://Autoruns]
script = . "$SplunkHome\etc\apps\TA-autoruns\bin\autoruns.ps1" -MaxBaselineAge 7:00:00:00
schedule = 0 */4 * * *
sourcetype = Autoruns
disabled = false
```
If you don't specify -MaxBaselineAge only changes will be logged per default:
```
[powershell://Autoruns]
script = . "$SplunkHome\etc\apps\TA-autoruns\bin\autoruns.ps1"
schedule = 0 */4 * * *
sourcetype = Autoruns
disabled = false
```
If you want to force the creation of a new baseline on every run you can pass the -Baseline argument
```
[powershell://Autoruns]
script = . "$SplunkHome\etc\apps\TA-autoruns\bin\autoruns.ps1 -Baseline"
schedule = 0 */4 * * *
sourcetype = Autoruns
disabled = false
```
