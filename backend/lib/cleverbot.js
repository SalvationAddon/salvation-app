const url = require('url');
const axios = require('axios');

// getReply fetches a chat response from the CleverBot API
async function getReply(message) {
	try {
		let resp = await axios.get(`https://www.cleverbot.com/getreply`, {
			params: {
				key: process.env.cleverbot_key,
				input: message,
				cb_settings_tweak1: 0, // from sensible to wacky - no funny business here
				cb_settings_tweak2: 0, // from shy to talkative - we want a shy bot...
				cb_settings_tweak3: 3, // from self-centred to attentive - we want a self centered bot :)
			},
		});
		if (resp.data && resp.data.output) {
			return resp.data.output;
		}
	} catch (e) {
		console.log('Failed to send message to cleverbot-api');
		console.log(e);
		return false;
	}
}
exports.getReply = getReply;
