 ![salvation_dashboard](https://github.com/SalvationAddon/salvation-app/blob/master/img/salvation_owl.png?raw=true)

# WoW Salvation - Setup Guide

As mentioned on the main Readme, Salvation was built in a way that easily runs on [Glitch.com](https://Glitch.com) which is what we'll cover below. If you want to run it elsewhere check out the [System Overview](./docs/Overview.md) to get an understanding of each of the components (it's not that complex).

**If a video would be helpful, let me know and I can throw one together for the below steps**

## Step 1: Create a Glitch.com Account

Signup for a glitch account, it's free to start (you can upgrade later if you need higher limits and want the app to run 24/7.. startups are super quick though).  Signup here: https://glitch.com/signin (create account at the bottom).



## Step 2: "Remix" the WoW Salvation Glitch App

On Glitch, remixing is basically for making a copy of the application (think fork) and getting your own instance of it quickly up and running.

Click this link to create a remix of Salvation: [![Remix on Glitch](https://cdn.glitch.com/2703baf2-b643-4da7-ab91-7ee2a2d00b5b%2Fremix-button.svg)](https://glitch.com/edit/#!/remix/wow-salvation)

Once done you'll be able to pick a fancy new name for your app in the following menu:

<img src="https://raw.githubusercontent.com/SalvationAddon/salvation-app/master/img/glitch_rename.png" alt="Glitch Rename" style="zoom:50%;" /> 



## Step 3: Configure Settings

Now that you've forked the app edit the `.env` file and set the password.  This password will be used to access the UI, and also for addon installations to access the system. 

If you want the bot to automatically respond to whispers, you can read [How To configure Clever Bot Here](CleverBot.md)


#### Optional Step: Pushover Configuration (Mobile device push alerts)

If you want to get alerts using Pushover on your mobile devices then go ahead and purchase the app on your device of choice (it is on the Android and iOS app stores).  While logged in to your Pushover account, in your browser go to https://pushover.net/apps/build and create an application  (You can call it whatever), and save the API Token that it gives you when you click "Create Application".  Take that API Token and put it in the `.env` file  at the specified key: `pushover_token`.

Now go back to the pushover home screen (https://pushover.net/) and if you're logged-in you should see your `User Key` in the top right.  Copy that key and put it in the `.env` file at the `pushover_user` key.



## Step 4: Install the Salvation-Addon

This is the step where you install the salvation addon to your WoW clients.  

Download the latest release of the WoW Add-on here: https://github.com/SalvationAddon/salvation-bootstrapper (Link in the readme of the latest release zip file).  Once downloaded simply un-zip the file and copy the `Salvation` folder to the wow `Addons` folder of choice.

🚨**Important Step!** 🚨

After installing the addon, please open the `main.lua` file and replace the variables at the top with what you configured previously.

- Change `api_endpoint` value of "CHANGE_ME" to the domain / IP of your app (If glitch it's `{your app name}.glitch.me`. (Currently the app only supports HTTPS so please make a ticket if this is an issue and I'll make a flag for this.)
- Change `password` to the password you configured above in the `.env` file!


Now that your app is up and running you should be able to visit it if you click the "show" drop down in the top left of glitch and click the "new window" button.  After logging in, go test the addon by launching wow with your LUA unlocker of choice and once logged in, your character should appear on the site!


---



# Self Hosted Setup - (More Technial)

If you want to run salvation elsewhere (digital ocean, your home, etc) It's pretty straight forward, below are the prerequisites:

- Recent Version of Node.js (At least the LTS version at a minimum)
- HTTPS Certificate or service like Cloudflare to terminate TLS. (This is a requirement in the addon, **If this is a big issue across the users I could technically make this configurable.. let me know**



That's really all, it's not containerized so if you want to run in a Docker container would be pretty simple.

To start the application just run `npm start` and it will run the LUA build script (this is unecessary if you don't want live-reloading of the LUA code) and the Express application which will host up the Front-end code as well as the API.



#### Modifying Front-End Code

If you modify any of the front-end code you'll need to run `npm run-script frontend` command to build a new UI bundle.  Currently I've just committed it to the repo as it pretty heavy to build each time the app starts (at least on glitch).



