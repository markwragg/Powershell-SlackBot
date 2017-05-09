function Initialize-StoredBot {
    Param(
    
		[Parameter(Position=0,
			Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$true)]
			[string]$BotName,
        [Parameter(Position=1,
			Mandatory=$true)]
			[scriptblock]$BotDefinition,
		[Parameter(Position=2,
			Mandatory=$false,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$true)]
			[switch]$Force
    )
    DynamicParam {}

    begin {
        $RegPath = @('HKCU:','Software','Microsoft','Windows','PowerShell','Bots')

        0..($RegPath.Length-1) | ForEach-Object {
            $ThisLevel = (-join(($RegPath[0..$_] -join "\"),"\"))
            if (-not (Test-Path $ThisLevel)){
                Write-Verbose "Creating $ThisLevel"
                New-Item $ThisLevel -ItemType Directory | Out-Null
            }
        }
    }
    process{
        $PathQuery = @{
            Path = ($RegPath -join "\")
            Name = $BotName
            Value = ([System.Management.Automation.PSSerializer]::Serialize($BotDefinition))
        }

        if ($BotName -notin (Read-StoredBotList) -or $Force){
            if($Force) {
                Set-ItemProperty @PathQuery | Out-Null
            } else {
                $PathQuery.PropertyType = "String"
                New-ItemProperty @PathQuery | Out-Null
                
            }
        } else {
            @("Value","PropertyType") | ForEach-Object {
                $PathQuery.Remove($_)
            }
            
            $Exception = @{
                Message = (-join("A key with the name ",$BotName," already exists."))
                RecommendedAction = "Choose another name or use the -Force flag to overwrite."
                Category = "WriteError"
                CategoryTargetName = (@($PathQuery.Path,$PathQuery.Name) -join " - ")
                CategoryTargetType = "RegistryKey Property"
                TargetObject = Get-ItemPropertyValue @PathQuery
            }
            Write-Error @Exception
        }
    }
    end {}
}