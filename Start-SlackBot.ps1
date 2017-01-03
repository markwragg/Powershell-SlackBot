[cmdletbinding()]
Param(
    $Token = (Import-Clixml Token.xml)  #So I don't accidentally put it on the internet
)

#Useful for converting the TS (timestamp) property of API events
Function ConvertFrom-UnixTime {
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Int32]$UnixTime
    )
    begin {
        $startdate = Get-Date –Date '01/01/1970' 
    }
    process {
        $timespan = New-Timespan -Seconds $UnixTime
        $startdate + $timespan
    }
}

#Sends simple message responses via the RTM API
Function Send-SlackMsg
{
    [cmdletbinding()]
    Param(
        $Text,
        $Channel,
        $ID = (get-date).ticks
    )
    
    $Prop = @{'id'      = $ID;
              'type'    = 'message';
              'text'    = $Text;
              'channel' = $Channel}
            
    $Reply = (New-Object –TypeName PSObject –Prop $Prop) | ConvertTo-Json
            
    $Array = @()
    $Reply.ToCharArray() | ForEach { $Array += [byte]$_ }          
    $Reply = New-Object System.ArraySegment[byte]  -ArgumentList @(,$Array)

    $Conn = $WS.SendAsync($Reply, [System.Net.WebSockets.WebSocketMessageType]::Text, [System.Boolean]::TrueString, $CT)
    While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }

    Return $ID
}

#Web API call starts the session and gets a websocket URL to use.
$RTMSession = Invoke-RestMethod -Uri https://slack.com/api/rtm.start -Body @{token="$Token"}
Write-Verbose "I am $($RTMSession.self.name)"

Try{

    Do{
        $WS = New-Object System.Net.WebSockets.ClientWebSocket                                                
        $CT = New-Object System.Threading.CancellationToken                                                   

        $Conn = $WS.ConnectAsync($RTMSession.URL, $CT)                                                  
        While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }

        Write-Verbose "Connected to $($RTMSession.URL)"

        $Size = 1024
        $Array = [byte[]] @(,0) * $Size
        $Recv = New-Object System.ArraySegment[byte] -ArgumentList @(,$Array)

        While ($WS.State -eq 'Open') {

            $RTM = ""
        
            Do {
                $Conn = $WS.ReceiveAsync($Recv, $CT)
                While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }

                $Recv.Array[0..($Conn.Result.Count - 1)] | ForEach { $RTM += [char]$_ }
       
            } Until ($Conn.Result.Count -lt $Size)

            Write-Verbose "$RTM"

            If ($RTM){
                $RTM = ($RTM | convertfrom-json)
                    
                Switch ($RTM){
                    {($_.type -eq 'message') -and (!$_.reply_to)} { 
                        
                        If ( ($_.text -Match "<@$($RTMSession.self.id)>") -or $_.channel.StartsWith("D") ){
                            #A message was sent to the bot
                            
                            # *** Responses go here, for example..***
                            $words = ($_.text.ToLower() -split " ")
                            
                            Switch ($words){
                                {@("hey","hello","hi") -contains $_} { Send-SlackMsg -Text 'Hello!' -Channel $RTM.Channel }
                                {@("bye","cya") -contains $_} { Send-SlackMsg -Text 'Goodbye!' -Channel $RTM.Channel }

                                default { Write-Verbose "I have no response for $_" }
                            }

                        }Else{
                            Write-Verbose "Message ignored as it wasn't sent to @$($RTMSession.self.name) or in a DM channel"
                        }
                    }
                    {$_.type -eq 'reconnect_url'} { $RTMSession.URL = $RTM.url }
                        
                    default { Write-Verbose "No action specified for $($RTM.type) event" }            
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
