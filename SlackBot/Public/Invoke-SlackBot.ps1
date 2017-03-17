#Invokes an instance of a bot
Function Invoke-SlackBot {
    [cmdletbinding()]
    Param(
        $Token = (Import-Clixml Token.xml),  #So I don't accidentally put it on the internet
        $LogPath = "$Env:USERPROFILE\Logs\SlackBot.log"
    )
    
    Import-Module 'PSSlack'
    Set-PSSlackConfig -Path Windows.xml -Token $Token
    
    #Web API call starts the session and gets a websocket URL to use.
    $RTMSession = Invoke-RestMethod -Uri https://slack.com/api/rtm.start -Body @{token="$Token"}
    Write-Log "I am $($RTMSession.self.name)" -Path $LogPath

    Try{
        Do{
            $WS = New-Object System.Net.WebSockets.ClientWebSocket                                                
            $CT = New-Object System.Threading.CancellationToken                                                   

            $Conn = $WS.ConnectAsync($RTMSession.URL, $CT)                                                  
            While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }

           Write-Log "Connected to $($RTMSession.URL)" -Path $LogPath

            $Size = 1024
            $Array = [byte[]] @(,0) * $Size
            $Recv = New-Object System.ArraySegment[byte] -ArgumentList @(,$Array)

            While ($WS.State -eq 'Open') {

                $RTM = ""

                Do {
                    $Conn = $WS.ReceiveAsync($Recv, $CT)
                    While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }

                    $Recv.Array[0..($Conn.Result.Count - 1)] | ForEach-Object { $RTM = $RTM + [char]$_ }

                } Until ($Conn.Result.Count -lt $Size)

                Write-Log "$RTM" -Path $LogPath

                If ($RTM){
                    $RTM = ($RTM | convertfrom-json)

                    Switch ($RTM){
                        {($_.type -eq 'message') -and (!$_.reply_to)} { 

                            If ( ($_.text -Match "<@$($RTMSession.self.id)>") -or $_.channel.StartsWith('D') ){
                                #A message was sent to the bot

                                # *** Responses go here, for example..***
                                $words = ($_.text.ToLower() -split " ")

                                Switch ($words){
                                    {@("hey","hello","hi") -contains $_} { Send-SlackMsg -Text 'Hello!' -Channel $RTM.Channel }
                                    {@("bye","cya") -contains $_} { Send-SlackMsg -Text 'Goodbye!' -Channel $RTM.Channel }

                                    default { Write-Verbose "I have no response for $_" }
                                }

                            }Else{
                                Write-Log "Message ignored as it wasn't sent to @$($RTMSession.self.name) or in a DM channel" -Path $LogPath
                            }
                        }
                        {$_.type -eq 'reconnect_url'} { $RTMSession.URL = $RTM.url }

                        default { Write-Log "No action specified for $($RTM.type) event" -Path $LogPath }            
                    }
                }
            }   
        } Until (!$Conn)

    }Finally{

        If ($WS) { 
            Write-Verbose "Closing websocket"
            $WS.Dispose()
        }

    }

}


#Sends simple message responses via the RTM API
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
    $Msg.ToCharArray() | ForEach-Object { $Array += [byte]$_ }
           
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