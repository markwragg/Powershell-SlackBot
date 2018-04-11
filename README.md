# Powershell-SlackBot

[![Build status](https://ci.appveyor.com/api/projects/status/au921phlu01ojnyf?svg=true)](https://ci.appveyor.com/project/markwragg/powershell-slackbot) ![Test Coverage](https://img.shields.io/badge/coverage-26%25-red.svg?maxAge=60) [![powershellgallery](https://img.shields.io/powershellgallery/v/slackbot.svg?maxAge=60)](https://www.powershellgallery.com/packages/slackbot)

This project is a PowerShell implementation of a Chat Bot for Slack that utilises the Slack Real Time Messaging (RTM) API. This code is intended to provide a simple framework for anyone that wants to write a Chat Bot for a single Slack Team that is able to respond to Channel and Direct Messages. It would also be simple to extend the code to permit the Bot to respond to any other events exposed via the RTM API.

For more information about how and why this Bot was authored, see my blog post here: http://wragg.io/powershell-slack-bot-using-the-real-time-messaging-api/

## Requirements

This script uses the .NET class: System.Net.WebSockets.WebSocket. As such the code has to be run on Windows 8 / Server 2012 or newer operating systems.

## Getting Started

If you haven't already, you first need to log in to your Slack account and create a Bot under Custom Integrations > Bots. You then need the API token of your Bot which can be passed to Invoke-SlackBot as a paramater or read from an XML file created via `$Token | Export-CliXML`.

This module is published in the Gallery so if you are running PowerShell 5, you can install the [SlackBot module from the PowerShell Gallery](https://www.powershellgallery.com/packages/SlackBot/1.0.16) via:

`Install-Module -Name SlackBot`

Alternatively download/clone the module folder from this repo on to server/computer running Win 8 or 2012 or above and that has internet connectivity to the Slack API. Copy the module to your modules directory and then load it with:

`Import-Module SlackBot`

Then start the Bot by executing:

`Invoke-SlackBot -token "yourtoken"`

The bot will generate a log file by default in your User Profile directory (C:\Users\youruser\) under \Logs, and all log messages will also appear in the console as either PowerShell standard Verbose, Warning or Error output.

The bot is currently configured to respond to any Direct Messages, or any conversation that includes @botname (whatever you named your Bot) as any word of the message.

## Extending the script

There are two obvious places to extend the script:

1. Add additional conditions in the `Switch($words)` statement and any code that you want executed when those conditions are matched. Currently it splits the message in to an Array of $words, you may want to instead match the full `.text` response of the message.

2. Add additional conditions in the `Switch($RTM)` statement to match other RTM API events. See the RTM API documentation for a full list of events: https://api.slack.com/rtm

## Contributions

I welcome contributions to this project.
