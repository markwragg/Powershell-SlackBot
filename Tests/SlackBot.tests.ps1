# Top-of-file code (like Describe/Context bodies) only runs during Pester's discovery pass, not when
# the It blocks below actually execute -- wrapping it in a file-scoped BeforeAll makes it available at
# Run time too.
BeforeAll {
    $moduleName = 'SlackBot'
    $projectRoot = Resolve-Path "$PSScriptRoot/.."
    $moduleRoot = Split-Path (Resolve-Path "$projectRoot/$moduleName/$moduleName.psm1")
}

Describe 'Integration Tests' {

    Context 'Module Tests' {

        It 'Module imports cleanly' {
            { Import-Module (Join-Path $moduleRoot "$moduleName.psm1") -Force } | Should -Not -Throw
        }
    }
}

Describe 'Private Function Tests' {

    Context 'Write-Log Tests' {

        # Dot-sourced in each Context's own BeforeAll (rather than relying on a single Describe-level
        # BeforeAll) so this Context's functions don't depend on sibling Contexts -- some of which use
        # -ForEach below -- being discovered/run in a particular order.
        BeforeAll {
            @( Get-ChildItem -Path "$moduleRoot/Private/*.ps1" ) | ForEach-Object {
                . $_.FullName
            }

            $TestLog = "$PSScriptRoot/$moduleName.log"
        }

        AfterAll {
            Remove-Item $TestLog -ErrorAction SilentlyContinue
        }

        It 'Write-Log -Message requires an input' {
            { Write-Log -Message } | Should -Throw -ExpectedMessage '*Missing an argument for parameter*'
        }

        It 'Write-Log -Level should reject Test' {
            { Write-Log -Level Test } | Should -Throw -ExpectedMessage '*Cannot validate argument on parameter*'
        }

        # Cases are passed as hashtables (rather than a plain foreach loop) so each Level/Message pair
        # gets its own scope -- a plain loop would have all three Its' scriptblocks close over the same
        # loop variable, which Pester 5+'s separate discovery/run phases would resolve to only the final
        # level's value once the Its actually run.
        $LogLevelCases = @('Info', 'Warn', 'Error') | ForEach-Object {
            @{ Level = $_; Message = "Random number msg $(Get-Random)" }
        }

        It 'Write-Log -Level <Level> should work' -ForEach $LogLevelCases {
            { Write-Log -Level $Level -Message $Message -Path $TestLog `
                                      -ErrorAction SilentlyContinue `
                                      -WarningAction SilentlyContinue } | Should -Not -Throw
        }
        It 'Log file should contain the <Level> message' -ForEach $LogLevelCases {
            $TestLog | Should -FileContentMatch ([regex]::Escape($Message))
        }
        It 'Log file should contain the <Level> level text' -ForEach $LogLevelCases {
            $TestLog | Should -FileContentMatch $Level
        }

        It "Write-Log -NoClobber should throw 'Log file already exists'" {
            { Write-Log -NoClobber -Message "NoClobber Test" -Path $TestLog } | Should -Throw -ExpectedMessage "*Log file $TestLog already exists, and you specified NoClobber*"
        }
    }

    Context 'ConvertFrom-UnixTime Tests' {

        BeforeAll {
            @( Get-ChildItem -Path "$moduleRoot/Private/*.ps1" ) | ForEach-Object {
                . $_.FullName
            }
        }

        It 'ConvertFrom-UnixTime -UnixTime requires an input' {
            { ConvertFrom-UnixTime -UnixTime } | Should -Throw -ExpectedMessage '*Missing an argument for parameter*'
        }

        It 'ConvertFrom-UnixTime -UnixTime 456 should return a System.DateTime object' {
            ConvertFrom-UnixTime -UnixTime 456 | Should -BeOfType [System.DateTime]
        }

        It 'ConvertFrom-UnixTime -UnixTime 123 should return 1970-01-01 00:02:03' {
            # Compared against a DateTime rather than a culture-formatted string, which Should -Be
            # resolves unreliably across locales/comparisons.
            ConvertFrom-UnixTime -UnixTime 123 | Should -Be ([datetime]'1970-01-01 00:02:03')
        }
    }
}

Describe 'Public Function Tests' -Tag 'Integration' {

    # Everything here requires a live Slack connection, so it's excluded from the automated build
    # (see Build/Tasks/Test.ps1's -ExcludeTag 'Integration') and is only intended for manual/local runs.
    BeforeAll {
        @( Get-ChildItem -Path "$moduleRoot/Public/*.ps1" ) | ForEach-Object {
            . $_.FullName
        }

        Write-Host "`t`Invoking SlackBot and waiting 5 seconds for it to connect.." -ForegroundColor Gray

        If ($env:TestToken) { $TestToken = $env:TestToken } Else { $TestToken = (Import-Clixml (Join-Path -Path ([Environment]::GetFolderPath('UserProfile')) -ChildPath 'Token.xml')) }

        $SlackBotJob = Start-Job {
            Import-Module ("$Using:projectRoot/$Using:moduleName/$Using:moduleName.psm1") -Force
            Invoke-SlackBot -Token $env:TestToken -LogPath (Join-Path -Path (Join-Path -Path ([Environment]::GetFolderPath('UserProfile')) -ChildPath 'Logs') -ChildPath 'SlackBot.log')
        }

        Start-Sleep 5
    }

    AfterAll {
        $SlackBotJob | Stop-Job -PassThru | Remove-Job
    }

    $BotTestChannel = 'G3HAM2NTS'

    Context 'Invoke-SlackBot Tests' {

        It 'Invoke-SlackBot -Token requires an input' {
            { Invoke-SlackBot -Token } | Should -Throw
        }

        It 'Invoke-SlackBot should start cleanly' {
            { $SlackBotJob | Receive-Job -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'Send-SlackMsg Tests' {

        It 'Send-SlackMsg -Text requires an input' {
            { Send-SlackMsg -Text } | Should -Throw
        }

        It 'Send-SlackMsg -Channel requires an input' {
            { Send-SlackMsg -Channel } | Should -Throw
        }
    }
}

Describe 'Public Function Unit Tests' {

    BeforeAll {
        @( Get-ChildItem -Path "$moduleRoot/Public/*.ps1" ) | ForEach-Object {
            . $_.FullName
        }
        @( Get-ChildItem -Path "$moduleRoot/Private/*.ps1" ) | ForEach-Object {
            . $_.FullName
        }

        # Wait for a Task to complete without blocking on the (single) PowerShell thread.
        function Wait-Task ($Task) {
            While (!$Task.IsCompleted) { Start-Sleep -Milliseconds 10 }
            $Task
        }
    }

    Context 'Send-SlackMsg Tests' {

        BeforeAll {
            $LogPath = 'TestDrive:\SlackBot.log'
            $CT = New-Object System.Threading.CancellationToken
        }

        Context 'Without an open WebSocket' {

            BeforeEach {
                Mock Write-Log {}
            }

            It 'Logs an error and returns when $WS is not a ClientWebSocket' {
                $WS = $null
                Send-SlackMsg -Text 'Hello' -Channel 'C1'
                Should -Invoke Write-Log -Times 1 -Exactly -ParameterFilter { $Level -eq 'Error' -and $Message -like 'A WebSocket to Slack is not open*' }
            }
        }

        Context 'With a connected WebSocket' {

            BeforeAll {
                $Port = Get-Random -Minimum 20000 -Maximum 40000
                $Listener = New-Object System.Net.HttpListener
                $Listener.Prefixes.Add("http://localhost:$Port/")
                $Listener.Start()

                $Accept = $Listener.GetContextAsync()
                $WS = New-Object System.Net.WebSockets.ClientWebSocket
                $Connect = $WS.ConnectAsync("ws://localhost:$Port/", $CT)

                $Context = (Wait-Task $Accept).Result
                $ServerSocket = (Wait-Task $Context.AcceptWebSocketAsync([NullString]::Value)).Result.WebSocket
                Wait-Task $Connect | Out-Null

                function Receive-ServerMessage {
                    $Buffer = New-Object System.ArraySegment[byte] -ArgumentList @(, ([byte[]]::new(4096)))
                    $Result = (Wait-Task $ServerSocket.ReceiveAsync($Buffer, $CT)).Result
                    [System.Text.Encoding]::UTF8.GetString($Buffer.Array, 0, $Result.Count) | ConvertFrom-Json
                }
            }

            AfterAll {
                $WS.Dispose()
                $ServerSocket.Dispose()
                $Listener.Close()
            }

            BeforeEach {
                Mock Write-Log {}
            }

            It 'Sends the message as JSON over the socket' {
                Send-SlackMsg -Text 'Hello!' -Channel 'C1' -ID 42
                $Msg = Receive-ServerMessage

                $Msg.type    | Should -Be 'message'
                $Msg.text    | Should -Be 'Hello!'
                $Msg.channel | Should -Be 'C1'
                $Msg.id      | Should -Be 42
                Should -Invoke Write-Log -Times 0 -Exactly
            }

            It 'Uses the current ticks as the default ID' {
                Send-SlackMsg -Text 'Hi' -Channel 'C2'
                (Receive-ServerMessage).id | Should -BeGreaterThan 0
            }
        }

        Context 'With a WebSocket that is not connected' {

            BeforeAll {
                $WS = New-Object System.Net.WebSockets.ClientWebSocket
            }

            AfterAll {
                $WS.Dispose()
            }

            It 'Throws when the socket is not open' {
                { Send-SlackMsg -Text 'Hello' -Channel 'C1' -ErrorAction Stop } | Should -Throw
            }
        }
    }

    Context 'Invoke-SlackBot Tests' {

        BeforeAll {
            # Captured before New-Object is mocked, so the mock can pass other types through.
            $RealNewObject = Get-Command -Name New-Object -CommandType Cmdlet

            # Stand-in for the PSSlack module's command so it can be mocked.
            function Set-PSSlackConfig { param($Path, $Token) }

            function New-FakeWebSocket ([string[]]$Messages) {
                $Fake = [pscustomobject]@{
                    State    = 'Open'
                    Queue    = [System.Collections.Queue]::new($Messages)
                    Disposed = $false
                }
                $Done = [pscustomobject]@{ IsCompleted = $true; Result = $null }

                $Fake | Add-Member -MemberType ScriptMethod -Name ConnectAsync -Value { param($Uri, $Token) $Done }.GetNewClosure()
                $Fake | Add-Member -MemberType ScriptMethod -Name ReceiveAsync -Value {
                    param($Buffer, $Token)
                    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($this.Queue.Dequeue())
                    [array]::Copy($Bytes, $Buffer.Array, $Bytes.Count)
                    If ($this.Queue.Count -eq 0) { $this.State = 'Closed' }
                    [pscustomobject]@{ IsCompleted = $true; Result = [pscustomobject]@{ Count = $Bytes.Count } }
                }
                $Fake | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.Disposed = $true }
                $Fake
            }

            function Invoke-FakeBot ([string[]]$Messages) {
                $script:FakeWS = New-FakeWebSocket $Messages
                $script:WsCreated = 0
                { Invoke-SlackBot -Token 'xoxb-test' -LogPath 'TestDrive:\Bot.log' -PSSlackConfigPath 'TestDrive:\Config.xml' } | Should -Throw -ExpectedMessage 'end of test'
            }
        }

        BeforeEach {
            Mock Set-PSSlackConfig {}
            Mock Invoke-RestMethod { [pscustomobject]@{ URL = 'wss://example.test/ws'; self = [pscustomobject]@{ id = 'UBOT'; name = 'bot' } } }
            Mock Write-Log {}
            Mock Send-SlackMsg {}
            Mock Start-Sleep {}
            Mock New-Object { & $RealNewObject @PesterBoundParameters }
            # The first socket is the fake; a second connection attempt ends the otherwise endless loop.
            Mock New-Object {
                $script:WsCreated++
                If ($script:WsCreated -gt 1) { throw 'end of test' }
                $script:FakeWS
            } -ParameterFilter { $TypeName -eq 'System.Net.WebSockets.ClientWebSocket' }
        }

        It 'Configures PSSlack and starts an RTM session with the token' {
            Invoke-FakeBot @('{"type":"hello"}')
            Should -Invoke Set-PSSlackConfig -Times 1 -Exactly -ParameterFilter { $Token -eq 'xoxb-test' }
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            Should -Invoke Write-Log -ParameterFilter { $Message -eq 'I am bot' }
        }

        It 'Logs events it has no action for' {
            Invoke-FakeBot @('{"type":"presence_change"}')
            Should -Invoke Write-Log -ParameterFilter { $Message -eq 'No action specified for presence_change event' }
        }

        It 'Disposes of the websocket when finished' {
            Invoke-FakeBot @('{"type":"hello"}')
            $script:FakeWS.Disposed | Should -BeTrue
        }

        It 'Replies Hello! to a greeting sent in a DM' {
            Invoke-FakeBot @('{"type":"message","channel":"D123","text":"Hi there"}')
            Should -Invoke Send-SlackMsg -Times 1 -Exactly -ParameterFilter { $Text -eq 'Hello!' -and $Channel -eq 'D123' }
        }

        It 'Replies Goodbye! when mentioned in a channel' {
            Invoke-FakeBot @('{"type":"message","channel":"C123","text":"<@UBOT>  cya"}')
            Should -Invoke Send-SlackMsg -Times 1 -Exactly -ParameterFilter { $Text -eq 'Goodbye!' -and $Channel -eq 'C123' }
        }

        It 'Does not reply to words it does not recognise' {
            Invoke-FakeBot @('{"type":"message","channel":"D123","text":"what is the weather"}')
            Should -Invoke Send-SlackMsg -Times 0 -Exactly
        }

        It 'Ignores channel messages that do not mention the bot' {
            Invoke-FakeBot @('{"type":"message","channel":"C123","text":"hello"}')
            Should -Invoke Send-SlackMsg -Times 0 -Exactly
            Should -Invoke Write-Log -ParameterFilter { $Message -like 'Message ignored*' }
        }

        It 'Ignores messages that are replies to the bot' {
            Invoke-FakeBot @('{"type":"message","channel":"D123","text":"hello","reply_to":5}')
            Should -Invoke Send-SlackMsg -Times 0 -Exactly
        }

        It 'Handles a reconnect_url event and processes multiple messages' {
            Invoke-FakeBot @('{"type":"reconnect_url","url":"wss://new.test/ws"}', '{"type":"message","channel":"D1","text":"bye"}')
            Should -Invoke Send-SlackMsg -Times 1 -Exactly -ParameterFilter { $Text -eq 'Goodbye!' }
        }
    }
}
