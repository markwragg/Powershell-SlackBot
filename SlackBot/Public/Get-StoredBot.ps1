function Get-StoredBot {
    [CmdletBinding()]
    Param()
    DynamicParam {
        
        $settings = @(
            ($true | select @{
                    N="Name"
                    E={"BotName"}
                },@{
                    N="SetScript"
                    E={
                        {
                            Read-StoredBotList
                        }
                    }
                }
            )
        )

        $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary

        $count = ($PSBoundParameters | measure).Count - 1
        $settings | %{
            $count++
            $attributes = New-Object System.Management.Automation.ParameterAttribute -Property @{ParameterSetName = "__AllParameterSets";Mandatory = $true;Position = $count;ValueFromPipeline = $true;ValueFromPipelineByPropertyName = $true}

            $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($attributes)

            $ValidateSet = New-Object System.Management.Automation.ValidateSetAttribute($(& $_.SetScript))
            $attributeCollection.Add($ValidateSet)

            $ThisParam = New-Object -Type System.Management.Automation.RuntimeDefinedParameter($_.Name, [string], $attributeCollection)

            $paramDictionary.Add($_.Name, $ThisParam)
        }

        return $paramDictionary 
    }

    begin {
        $settings | %{
            New-Variable -Name $_.Name -Value $PSBoundParameters[$_.Name]
        }
        $BotPath = "HKCU:\Software\Microsoft\Windows\PowerShell\Bots"
    }
    process{
        if ($_){
            [System.Management.Automation.PSSerializer]::DeSerialize((Get-ItemPropertyValue -Path $BotPath -Name $_.BotName))
        } else {
            [System.Management.Automation.PSSerializer]::DeSerialize((Get-ItemPropertyValue -Path $BotPath -Name $BotName))
        }
    }
    end {}
}