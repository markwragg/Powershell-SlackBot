$moduleName = 'SlackBot'
$projectRoot = Resolve-Path "$PSScriptRoot\.."
$moduleRoot = Split-Path (Resolve-Path "$projectRoot\$moduleName\$moduleName.psm1")

Import-Module "$(Resolve-Path "$projectRoot\$moduleName\$moduleName.psm1")"

Describe 'Unit Tests' {

    Context 'Parameter Input Tests' {

        It 'Invoke-SlackBot -Token requires an input' {
            { Invoke-SlackBot -Token } | Should Throw
        }
    }
}

Describe 'Integration Tests' {

    Context 'Module Tests' {

        It "Module '$moduleName' imports cleanly" {
            {Import-Module (Join-Path $moduleRoot "$moduleName.psm1") -force } | Should Not Throw
        }
    }
}
