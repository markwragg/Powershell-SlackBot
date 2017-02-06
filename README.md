# Powershell-SlackBot

[![Build status](https://ci.appveyor.com/api/projects/status/au921phlu01ojnyf?svg=true)](https://ci.appveyor.com/project/markwragg/powershell-slackbot)

This project is a PowerShell implementation of a Chat Bot for Slack that utilises the Slack Real Time Messaging (RTM) API. This code is intended to provide a simple framework for anyone that wants to write a Chat Bot for a single Slack Team that is able to respond to Channel and Direct Messages. It would also be simple to extend the code to permit the Bot to respond to any other events exposed via the RTM API.

For more information about how and why this Bot was authored, see my blog post here: http://wragg.io/powershell-slack-bot-using-the-real-time-messaging-api/

## Requirements

This script uses the .NET class: System.Net.WebSockets.WebSocket. As such the code has to be run on Windows 8 / Server 2012 or newer operating systems.

## Getting Started

If you haven't already, you first need to log in to your Slack account and create a Bot under Custom Integrations > Bots. You then need the API token of your Bot which can be passed to Start-SlackBot as a paramater or read from an XML file created via `$Token | Export-CliXML`.

Once you have a token, clone the repo on a server/computer running Win 8 or 2012 or above and that has internet connectivity to the Slack API.

Run start-slackbot.ps1 "yourtoken"

-- Run with the -verbose switch for a more informative console.

The bot is currently configured to respond to any Direct Messages, or any conversation that includes @botname (whatever you named your Bot) as any word of the message.

## Extending the script

There are two obvious places to extend the script:

1. Add additional conditions in the `Switch($words)` statement and any code that you want executed when those conditions are matched. Currently it splits the message in to an Array of $words, you may want to instead match the full `.text` response of the message.

2. Add additional conditions in the `Switch($RTM)` statement to match other RTM API events. See the RTM API documentation for a full list of events: https://api.slack.com/rtm

## Contributions

I welcome contributions to this project.
