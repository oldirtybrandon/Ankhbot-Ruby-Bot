#!/usr/bin/env ruby

require 'config'
require_relative 'lib/ankhbot_client'

settings_location = File.expand_path('settings.yml', File.dirname(__FILE__))
Config.load_and_set_settings(settings_location)

# Let's START the bot!
# Make sure you update all the configs for the client in the settings.yml file

client = AnkhbotClient.new(name: Settings.bot_name, server: Settings.twitch_server, port: Settings.twitch_port,
  password: Settings.bot_password, channel: Settings.channel, ankhbot_directory: Settings.ankhbot_directory)
trap("INT"){client.quit}
client.run
