 ![salvation_dashboard](https://github.com/SalvationAddon/salvation-app/blob/master/img/salvation_owl.png?raw=true)

# WoW Salvation - CleverBot Setup

Clever Bot ([https://www.cleverbot.com/](https://www.cleverbot.com/)) is a chat AI that we use to auto respond to whispers as they come in to the game.  This is a paid tool
and you will need to purchase an API key here: [https://www.cleverbot.com/api](https://www.cleverbot.com/api) .

Setup is super easy, modify the `.env` file in the project and add your API key to the field `cleverbot_key`. 

### Configuration
At the time of writing CleverBot will by default, repond to whispers a maximum of 2 times within 30 minutes.  This can be adjusted though, by editing the `cleverbot_max_responses` setting in the `.env` file.


### Things To Know:
CleverBot can be silly sometimes, and won't always know the context of what the person may be talking about.  Luckily the design of CleverBot is to mimic a real person, so when asked "are you a bot" and the like, it will respond with things like "of course I'm a human.." etc.  
Just be mindful of how much you let the bot auto respond to people, as it could do more harm than good!