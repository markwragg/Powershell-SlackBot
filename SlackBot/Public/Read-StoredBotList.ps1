function Read-StoredBotList{
    Param()
    (Get-Item HKCU:\Software\Microsoft\Windows\PowerShell\Bots).GetValueNames()
}