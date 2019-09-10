# Invoke-SlackBot

## SYNOPSIS
Start a Slack Bot.

## SYNTAX

```
Invoke-SlackBot [[-Token] <String>] [[-LogPath] <String>] [[-PSSlackConfigPath] <String>] [<CommonParameters>]
```

## DESCRIPTION
Starts a long running script which connects to the Slack API via websockets to listen to and
respond to Slack messages.

## EXAMPLES

### EXAMPLE 1
```
Invoke-SlackBot
```

Starts the SlackBot which will look for Token.XML and PSSlackConfig.xml in the parent of the
current directory for credentials to the Slack API and config for the PSSlack module.

## PARAMETERS

### -Token
Your token for connecting to the Slack API.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Import-Clixml "$PSscriptPath\..\Token.xml")
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
A path where activity logs should be written, default: $Env:USERPROFILE\Logs\SlackBot.log

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: "$Env:USERPROFILE\Logs\SlackBot.log"
Accept pipeline input: False
Accept wildcard characters: False
```

### -PSSlackConfigPath
Path to the configuration file for the PSSlack module.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: "$PSscriptPath\..\PSSlackConfig.xml"
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
