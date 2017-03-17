$LogPath = "$Env:USERPROFILE\Logs\SlackBot.log"

# Public functions
@( Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" ) | ForEach-Object {
    . $_.FullName
}

# Private functions
@( Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" ) | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function @(
    'Invoke-SlackBot',
    'Send-SlackMsg',
    'Write-Log'
)

Export-ModuleMember -Variable 'LogPath'