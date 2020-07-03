 ![salvation_dashboard](https://github.com/SalvationAddon/salvation-app/blob/master/img/salvation_owl.png?raw=true)

# WoW Salvation - System Overview

If you're here you're likely wanting to learn more about Salvation and how it's built, or because you want to run it somewhere other than Glitch. At a high level the system is comprised of 3 main components:

**Front End UI**: The main interface for using Salvation, this is pretty simple and can be built statically to host somewhere like an S3 bucket or web server. This is built using Svelte and the Tailwind css utility framework.

**API Server**: This is the main server that all the WoW instances will communicate with. Built with Node.js and Socket.io.

 - **Database**: Since it was intended to be run on Glitch I opeted to use **sqllite** as the database, which is very performant for uses like this.

**Salvation Bootstrapper Addon**: This is a very bare-bones WoW Addon that simply uses the HTTP client provided by EWT or LuaBox to fetch the actual Salvation LUA bundle from the API Server. This allows you to easily change the code and simply `/reload` your characters to get the latest code. No more copying & pasting add ons :raised_hands: .

The default setup for Salvation is to run the API Server, and the LUA build task (basically nodemon) at the same time using the `npm start` command, which uses `npm-run-all` package to run the 2 NPM scripts at the same time. To build the front-end just run `npm run-script frontend` and it will compile.

If you wanted to run Salvation anywhere outside of Glitch, you can literally clone down the repo, run the `npm start` command and access the ui at `http://{ip address}:3000`. There aren't any specific dependencies on the Glitch platform, so as long as you've configured Pushover and the `.env` file secrets correctly, you're set to go :grinning:.​

### WoW Addon

Now that we've covered the overall structure of the app, the first piece to talk about is the addon it self. Basically the bootstrapper addon connects to your Salvation instance and uses the configured password to authenticate characters once they login. After that it downloads the actual LUA code then executes it. Once the main logic is running It then opens up a single long-poll connection to wait for commands from the main system. It also is setup to send heartbeats to the system every few seconds just so the dashboard on the UI has the freshest information.

At the time of writing the addon only sends events to the server for whispers, I'd planned on building in alerts like Death, PVP encounters, epic/rare loot found, etc, but haven't really taken the time to get it done (PR's welcomed :wink:).

#### The addon can be downloaded here: https://github.com/SalvationAddon/salvation-bootstrapper/releases

