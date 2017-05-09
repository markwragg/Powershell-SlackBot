function Resolve-MessageCommand {
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$BotName,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$message,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            $Channel
    )

    $words = "$($message)".ToLower()
    while ($words -match "  "){
        $words = $words -replace "  "," "
    }
    $words = $words -split " " | Where-Object { $_ }

    
    & (Get-StoredBot -BotName $BotName)

    

}