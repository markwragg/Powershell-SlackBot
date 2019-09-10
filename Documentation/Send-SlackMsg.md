# Send-SlackMsg

## SYNOPSIS
Sends simple message responses via the RTM API

## SYNTAX

```
Send-SlackMsg [-Text] <String> [-Channel] <Object> [[-ID] <Object>] [[-Timeout] <Object>] [<CommonParameters>]
```

## DESCRIPTION
Used for sending Slack Messages through the WebSocket that is established by Invoke-SlackBot.

## EXAMPLES

### EXAMPLE 1
```
Send-SlackMsg -Text 'Hello!' -Channel 12345
```

Sends the specified text to the specified channel.

### EXAMPLE 2
```
Send-SlackMsg -Text 'Goodbye!' -Channel 12345 -ID 1 -Timeout 10
```

Sends the specified text to the specified channel with specified ID and timeout settings.

## PARAMETERS

### -Text
The message text string to be sent.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Channel
The name or ID of the channel to send the message to.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ID
A unique ID for the message.
The current datetime's tick is used by default.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: (get-date).ticks
Accept pipeline input: False
Accept wildcard characters: False
```

### -Timeout
The number of seconds before sending the message should timeout.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 30
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
