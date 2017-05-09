function Register-BackgroundSlackbot {
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [String]$BotName,
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
            [pscredential][System.Management.Automation.Credential()]$Credential
    )
    $JobDefinition = @{
        Name = @("SlackBot", $BotName) -join " - "
        Trigger = New-JobTrigger -RepetitionInterval 0:5:0 -At (Get-Date) -RepeatIndefinitely $true
        ScriptBlock = [scriptblock]::Create("Import-Module SlackBot;`nInvoke-SlackBot -BotName '$BotName'")
        ScheduledJobOption = New-ScheduledJobOption -MultipleInstancePolicy IgnoreNew -RequireNetwork
        RunNow = $true
    }

    if ($Credential){
        $JobDefinition.Credential = $Credential
        $JobDefinition.ScheduledJobOption =  = New-ScheduledJobOption -MultipleInstancePolicy IgnoreNew -RequireNetwork -RunElevated
    }

    if (($Job = Get-ScheduledJob | Where-Object {$_.Name -match $JobDefinition.Name})){
        get-job | Where-Object {$_.Name -match $JobDefinition.Name} | Stop-Job
        $JobDefinition.Remove("Name")
        $Job | Set-ScheduledJob @JobDefinition
    } else {
        Register-ScheduledJob @JobDefinition
    }
}