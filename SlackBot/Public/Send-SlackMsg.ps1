Function Send-SlackMsg {
<#
.SYNOPSIS
  Sends simple message responses via the RTM API
.DESCRIPTION
  Used for sending Slack Messages through the WebSocket that is established by Invoke-SlackBot.
.PARAMETER Text
  The message text string to be sent.
.PARAMETER Channel
  The name or ID of the channel to send the message to.
.PARAMETER ID
  A unique ID for the message. The current datetime's tick is used by default.
.PARAMETER Timeout
  The number of seconds before sending the message should timeout.
.EXAMPLE
   Send-SlackMsg -Text 'Hello!' -Channel 12345
.EXAMPLE
   Send-SlackMsg -Text 'Goodbye!' -Channel 12345 -ID 1 -Timeout 10
#>  
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [Parameter(Mandatory=$true)]
        $Channel,
        
        $ID = (get-date).ticks,
        $Timeout = 30
    )
    
    If (!($WS -is [System.Net.WebSockets.ClientWebSocket])){
        Write-Log  -Level Error 'A WebSocket to Slack is not open via $WS.' -Path $LogPath
        Return
    }

    $Prop = @{'id'      = $ID;
              'type'    = 'message';
              'text'    = $Text;
              'channel' = $Channel}
            
    $Msg = (New-Object –TypeName PSObject –Prop $Prop) | ConvertTo-Json
            
    $Array = @()
    $Encoding = [System.Text.Encoding]::UTF8
    $Array = $Encoding.GetBytes($Msg)
           
    $Msg = New-Object System.ArraySegment[byte]  -ArgumentList @(,$Array)

    $Conn = $WS.SendAsync($Msg, [System.Net.WebSockets.WebSocketMessageType]::Text, [System.Boolean]::TrueString, $CT)
    $ConnStart = Get-Date

    While (!$Conn.IsCompleted) { 
        $TimeTaken = ((get-date) - $ConnStart).Seconds
        If ($TimeTaken -gt $Timeout) {
            Write-Log -Level Error "Message $ID took longer than $Timeout seconds and may not have been sent." -Path $LogPath
            Return
        }
        Start-Sleep -Milliseconds 100 
    }
   
}