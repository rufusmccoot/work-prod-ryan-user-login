# work-UHG-CheckDailyFiles

This is something I run daily to get UHG reports over to AUP

1. Pulls the output from the most recently executed Azure pipeline
2. Writes the contents of the pipeline-creted ETL Report to a fileshare for Ralph


## Installation

Rename the `secrets.template.txt` file to `secrets.txt`

## Usage

This is the action scheduled in Task Scheduler:

```
cmd /k cd "C:\git\work-UHG-CheckDailyFiles\" && powershell .\checkdrive.ps1 && exit
```

We run it daily at ike 9:15am
