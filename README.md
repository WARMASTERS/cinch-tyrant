# Cinch-Tyrant

## Description

This is a Cinch plugin to enable your IRC bot to provide information about
[War Metal Tyrant](http://www.kongregate.com/games/synapticon/tyrant) by
Synapse Games.

## Dependencies

  * [Cinch](https://github.com/cinchrb/cinch) (IRC framework)
  * tyrant (Communication with Tyrant servers)

## Testing Dependencies

  * [cinch-test](https://github.com/jayferd/cinch-test)
  * [rspec](https://github.com/rspec/rspec)

## Install

  * Install the above dependencies:
    `gem install cinch` and `gem install tyrant`.
  * Build cinch-tyrant: `gem build cinch-tyrant.gemspec`
  * Install cinch-tyrant: `gem install cinch-tyrant`
  * Rename the example files `bot.example.rb`, `bot-config.example.rb`, and
    `settings.example.rb` by removing the `.example` portion:
    `rename .example.rb .rb *.example.rb`
  * Edit all settings in `settings.rb`, and add any Players necessary.
  * Edit all settings in `bot-config.rb`, and add any Factions necessary.
  * Enable any additional plugins by adding them to `bot.rb`: Add a `require`
    for it, include its class in `c.plugins.plugins`, and add any configuration
    options if necessary for that plugin.
  * Run it! `ruby bot.rb`

## Development

Send a pull request.
All pull requests must pass the tests (`rspec`).
New features should be accompanied with appropriate tests.
Filling in missing tests for existing features will also be appreciated.
