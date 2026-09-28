# work-SchoolsFirst-CheckMonthlyFiles

This is something I run a couple times per month to see what we've created for Schools First to pull from our SFS.

1. Maps a drive to SFS
2. Looks for client files to report creation date
3. Pulls the output from the most recently executed Azure pipeline
4. Logs SFS file creation date and pipeline-generated rowcounts to a place where AUP can access


## Installation

Rename the `secrets.template.txt` file to `secrets.txt`

## Usage

This is the action scheduled in Task Scheduler:

```
cmd /k cd "C:\git\work-SchoolsFirst-CheckMonthlyFiles\" && powershell .\checkdrive.ps1 && exit
```
