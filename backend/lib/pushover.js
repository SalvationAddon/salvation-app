let PushOver = require('pushover-notifications');

var push = new PushOver({
	user: process.env.pushover_user,
	token: process.env.pushover_token,
});

module.exports = push;
