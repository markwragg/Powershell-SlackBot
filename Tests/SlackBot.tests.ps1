$moduleName = 'SlackBot'
$projectRoot = Resolve-Path "$PSScriptRoot\.."
$moduleRoot = Split-Path (Resolve-Path "$projectRoot\$moduleName\$moduleName.psm1")

Describe 'Integration Tests' {

    Context 'Module Tests' {

        It "Module '$moduleName' imports cleanly" {
            {Import-Module (Join-Path $moduleRoot "$moduleName.psm1") -Force } | Should Not Throw
        }
    }
}

Describe 'Private Function Tests' {

    @( Get-ChildItem -Path "$moduleRoot\Private\*.ps1" ) | ForEach-Object {
        . $_.FullName
    }

    Context 'Write-Log Tests' {

        It 'Write-Log -Message requires an input' {
            { Write-Log -Message } | Should Throw 'Missing an argument for parameter'
        }

        It 'Write-Log -Level should reject Test' {
            { Write-Log -Level Test } | Should Throw 'Cannot validate argument on parameter'
        }

        $TestLog   = "$PSScriptRoot\$moduleName.log"
        $LogLevels = @('Info','Warn','Error')

        ForEach ($Level in $LogLevels) {
            $Message = "Random number msg $(Get-Random)"

            It "Write-Log -Level $Level should work" {
                { Write-Log -Level $Level -Message $Message -Path $TestLog `
                                          -ErrorAction SilentlyContinue `
                                          -WarningAction SilentlyContinue } | Should Not Throw
            }
            It "$TestLog should contain '$Message'" {
                $TestLog | Should Contain $Message
            }
            It "$TestLog should contain '$Level'" {
                $TestLog | Should Contain $Level
            }
        }

        It "Write-Log -NoClobber should throw 'Log file $TestLog already exists'" {
            { Write-Log -NoClobber -Message "NoClobber Test" -Path $TestLog } | Should Throw "Log file $TestLog already exists, and you specified NoClobber"
        }

        Remove-Item $TestLog
    }

    Context 'ConvertFrom-UnixTime Tests' {

        It 'ConvertFrom-UnixTime -UnixTime requires an input' {
            { ConvertFrom-UnixTime -UnixTime } | Should Throw 'Missing an argument for parameter'
        }
        
        It 'ConvertFrom-UnixTime -UnixTime 456 should return a System.DateTime object' {
            ConvertFrom-UnixTime -UnixTime 456 | Should BeOfType System.DateTime
        }
        
        It 'ConvertFrom-UnixTime -UnixTime 123 should return 01/01/1970 00:02:03' {
            ConvertFrom-UnixTime -UnixTime 123 | Should Be '01/01/1970 00:02:03'
        }
    }
}

Describe 'Public Function Tests' {

    

    Write-Host "`t`Invoking SlackBot and waiting 5 seconds for it to connect.." -ForegroundColor Gray
    
    If ($env:TestToken) { $TestToken = $env:TestToken } Else { $TestToken = (Import-Clixml "$env:USERPROFILE\Token.xml") }
    
    $SlackBotJob = Start-Job { 
        Import-Module (Join-Path $moduleRoot "$moduleName.psm1") -Force
        Invoke-SlackBot -Token $env:TestToken -LogPath "$Env:USERPROFILE\Logs\SlackBot.log"
    }  
    
    $BotTestChannel = 'G3HAM2NTS'
    
    Start-Sleep 5

    Context 'Invoke-SlackBot Tests' {

        It 'Invoke-SlackBot -Token requires an input' {
            { Invoke-SlackBot -Token } | Should Throw
        }
        
        It 'Invoke-SlackBot should start cleanly' {
            { $SlackBotJob | Receive-Job -ErrorAction Stop } | Should Not Throw
        }
    }

    Context 'Send-SlackMsg Tests' {

        It 'Send-SlackMsg -Text requires an input' {
            { Send-SlackMsg -Text } | Should Throw
        }
        
        It 'Send-SlackMsg -Channel requires an input' {
            { Send-SlackMsg -Channel } | Should Throw
        }

    }

    $SlackBotJob | Stop-Job -PassThru | Remove-Job
}