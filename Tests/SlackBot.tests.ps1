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
