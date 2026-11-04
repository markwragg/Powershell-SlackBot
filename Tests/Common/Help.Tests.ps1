# Taken with love from @juneb_get_help (https://raw.githubusercontent.com/juneb/PesterTDD/master/Module.Help.Tests.ps1)
# Import module. Checks whether it's already imported in this session (e.g. by the ImportStagingModule
# build task) rather than -ListAvailable (installed on PSModulePath) -- the staged module lives outside
# PSModulePath, so -ListAvailable never finds it and would otherwise always reimport the *source* module.
# Get-Help can't resolve comment-based help against the source module, because its .psm1 loader
# dot-sources each function from a separate file rather than containing the function bodies itself.
if (-not (Get-Module -Name $env:BHProjectName)) {
    Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
}
$commands = Get-Command -Module $env:BHProjectName -CommandType Cmdlet, Function -ErrorAction 'Stop' # Not alias

## When testing help, remember that help is cached at the beginning of each session.
## To test, restart session.

# Test cases are passed as hashtables (rather than relying on Pester's bare $_) so that nested -ForEach
# blocks further down don't shadow the outer command, and so Describe/It names can use <PropertyName>
# templating. A plain `foreach` here would have all of this file's dynamically generated Describes/Its
# close over the same loop variables, which Pester 5+'s separate discovery/run phases would resolve to
# only the final command's value once the Its actually run -- -ForEach gives each iteration its own scope.
$commandCases = @($commands | ForEach-Object {
        @{
            CommandName = $_.Name
            Command     = $_
        }
    })

Describe 'Test help for <CommandName>' -ForEach $commandCases {

    # Get-Help has to be called from inside an It/BeforeAll, not from plain Describe/Context body code --
    # Pester executes block bodies in a context where Get-Help resolves a command's Synopsis but comes
    # back empty for its Description/Examples/parameter help, even though the identical call works fine
    # from inside an It.
    BeforeAll {
        # The module-qualified command fails on Microsoft.PowerShell.Archive cmdlets
        $help = Get-Help $CommandName -ErrorAction SilentlyContinue
    }

    # If help is not found, synopsis in auto-generated help is the syntax diagram. The backticks make
    # the brackets literal to the -BeLike wildcard engine (which treats backtick as its own escape
    # character, independent of how the string itself is quoted) -- without them, [<CommonParameters>]
    # would be parsed as a character class matching any single one of those letters, which trivially
    # matches almost any text.
    It 'Should not be auto-generated' {
        $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'Gets description for <CommandName>' {
        $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example
    It 'Gets example code from <CommandName>' {
        ($help.Examples.Example | Select-Object -First 1).Code | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example description
    It 'Gets example help from <CommandName>' {
        ($help.Examples.Example.Remarks | Select-Object -First 1).Text | Should -Not -BeNullOrEmpty
    }

    Context 'Test parameter help for <CommandName>' {

        # Only depends on $Command (reflection metadata), not $help, so -- unlike $help above -- this is
        # safe to compute directly here rather than in a BeforeAll: it's needed up front to build the
        # per-parameter -ForEach cases below.
        # ProgressAction is a common parameter PowerShell 7.4+ added, so it only shows up under pwsh,
        # not Windows PowerShell 5.1 -- excluded here the same as the older common parameters below.
        $common = 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer',
        'OutVariable', 'PipelineVariable', 'ProgressAction', 'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'

        $parameters = $Command.ParameterSets.Parameters |
            Sort-Object -Property Name -Unique |
            Where-Object { $_.Name -notin $common }

        $parameterCases = @($parameters | ForEach-Object {
                @{
                    ParameterName = $_.Name
                    Parameter     = $_
                }
            })

        # Should be a description for every parameter
        It 'Gets help for parameter: <ParameterName>' -ForEach $parameterCases {
            $parameterHelp = $help.parameters.parameter | Where-Object Name -EQ $ParameterName
            $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
        }

        # Required value in Help should match IsMandatory property of parameter
        It 'Help for <ParameterName> parameter has correct Mandatory value' -ForEach $parameterCases {
            $parameterHelp = $help.parameters.parameter | Where-Object Name -EQ $ParameterName
            $codeMandatory = $Parameter.IsMandatory.ToString()
            $parameterHelp.Required | Should -Be $codeMandatory
        }

        # Shouldn't find extra parameters in help that don't exist in code. A single static It (rather
        # than one per extra parameter via -ForEach) because the set of documented parameter names can
        # only be read from $help, which -- like all $help access -- isn't available until Run time, by
        # which point Pester has already fixed the set of Its from the discovery pass.
        #
        # Recomputes $common/$parameters locally rather than reusing the Context-level variables above:
        # this plain It and the -ForEach'd Its above it don't reliably share that Context-level state --
        # $parameters read back here as empty even though the -ForEach'd Its (built from the same
        # variable) ran correctly -- so it's recomputed here from $Command, which is reliably available.
        It 'Does not document parameters that are missing from the code' {
            $common = 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer',
            'OutVariable', 'PipelineVariable', 'ProgressAction', 'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'

            $parameterNames = $Command.ParameterSets.Parameters |
                Where-Object { $_.Name -notin $common } |
                Select-Object -ExpandProperty 'Name' -Unique

            $helpParameterNames = $help.Parameters.Parameter |
                Where-Object { $_.Name -notin $common } |
                Select-Object -ExpandProperty 'Name' -Unique

            $ExtraHelpParameters = @($helpParameterNames | Where-Object { $_ -notin $parameterNames })
            $ExtraHelpParameters | Should -BeNullOrEmpty
        }
    }

    Context 'Help Links should be valid for <CommandName>' {

        # Should have a valid uri if one is provided.
        It 'Links should return a 200 status code' {
            $links = @($help.relatedLinks.navigationLink.uri | Where-Object { $_ })

            foreach ($link in $links) {
                $Results = Invoke-WebRequest -Uri $link -UseBasicParsing
                $Results.StatusCode | Should -Be '200' -Because "the link [$link] should be reachable"
            }
        }
    }
}
