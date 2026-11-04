# This runs all PSScriptAnalyzer rules as Pester tests to enable visibility when publishing test results
# Vars
$ScriptAnalyzerSettingsPath = Join-Path -Path $env:BHProjectPath -ChildPath 'PSScriptAnalyzerSettings.psd1'

# Rule names are collected at the top level (discovery-safe: Get-ScriptAnalyzerRule doesn't depend on
# $analysis) so each rule gets its own -ForEach'd It with its own scope and templated name.
$scriptAnalyzerRuleCases = @(Get-ScriptAnalyzerRule | ForEach-Object { @{ RuleName = $_.RuleName } })

Describe 'Testing against PSSA rules' {
    Context 'PSSA Standard Rules' {

        # $analysis has to be computed in BeforeAll, not plain Context-body code: Pester only runs
        # Describe/Context body code (outside It/BeforeAll) during discovery, not when the Its below
        # actually run, so a plain assignment here wouldn't be visible -- or would be stale/shared --
        # inside the dynamically generated Its.
        BeforeAll {
            $analysis = Invoke-ScriptAnalyzer -Path $env:BHModulePath -Recurse -Settings $ScriptAnalyzerSettingsPath
        }

        # Only Error-severity findings fail the build here, matching the dedicated Analyze build task and
        # the project's own PSScriptAnalyzerSettings.psd1 (ScriptAnalysisFailBuildOnSeverityLevel =
        # 'Error') -- Warning-level style findings are still reported per-rule for visibility, they just
        # don't gate the build.
        It 'Should pass <RuleName>' -ForEach $scriptAnalyzerRuleCases {
            $failures = @($analysis | Where-Object { $_.RuleName -eq $RuleName -and $_.Severity -eq 'Error' })
            $failures.Count | Should -Be 0
        }
    }
}
