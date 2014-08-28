# Cinch-Tyrant

## Description

This is a Cinch plugin to enable your IRC bot to provide information about
[War Metal Tyrant](http://www.kongregate.com/games/synapticon/tyrant) by
Synapse Games.

## Dependencies

  * [Cinch](https://github.com/cinchrb/cinch) (IRC framework)
  * [tyrant](https://github.com/WARMASTERS/tyrant) (Communication with Tyrant servers)

## Testing Dependencies

  * [cinch-test](https://github.com/jayferd/cinch-test)
  * [rspec](https://github.com/rspec/rspec)
  * [simplecov](https://github.com/colszowka/simplecov)

## Install

  * Install the above dependencies:
    `gem install cinch` and `gem install tyrant`.
  * Build cinch-tyrant: `gem build cinch-tyrant.gemspec`
  * Install cinch-tyrant: `gem install cinch-tyrant`
  * Rename the example files `bot.example.rb`, `bot-config.example.rb`, and
    `settings.example.rb` by removing the `.example` portion:
    `rename .example.rb .rb *.example.rb`
  * Edit all settings in `settings.rb`, and add any Players necessary.
  * Edit all settings in `bot-config.rb`, add any Factions necessary, and add
    any desired plugins to BOT_PLUGINS.
  * You should not need to edit `bot.rb` after renaming it unless you have
    special needs with Cinch.
  * Run it! `ruby bot.rb`

## Development

Send a pull request.
All pull requests must pass the tests (`rspec`).
New features should be accompanied with appropriate tests.
Filling in missing tests for existing features will also be appreciated.
