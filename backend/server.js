// Load in env settings (automatic in glitch, but for cases where this isn't running in glitch)
require('dotenv').config({ path: `${__dirname}/../.env` });

const express = require('express');
const jwt = require('jsonwebtoken');
const bodyParser = require('body-parser');
const expressCookies = require('cookie-parser');
let cookie = require('cookie');
const fs = require('fs');
const db = require('./lib/db');
const CharacterMonitor = require('./workers/characters');
const Characters = require('./lib/characters');
const ChatLog = require('./lib/chatlog');
const MessageBus = require('./messagebus');
const Cleverbot = require('./lib/cleverbot');
const NodeCache = require('node-cache');

const whisperCache = new NodeCache();
let io = null; // not the cleanest but for now it'll do.

let push = require('./lib/pushover');
let morgan = require('morgan');
let maxLongpollDuration = 25000;

async function main() {
	const app = express();
	let http = require('http').createServer(app);

	// Setup socket.io
	io = require('socket.io')(http);

	// Simple middleware to require a JWT for socket.io
	io.use(function (socket, next) {
		if (socket.request && socket.request.headers) {
			let parsedCookies = cookie.parse(socket.request.headers.cookie || '');
			if (parsedCookies.salvation_auth) {
				let isValid = validateJWT(parsedCookies.salvation_auth);
				if (!isValid) {
					return next(new Error('not authorized'));
				}
				return next();
			}
		}
		return next(new Error('not authorized'));
	});

	// Kick off the character monitor worker
	CharacterMonitor.start(io);

	// More middleware
	app.use(bodyParser.urlencoded({ extended: true }));
	app.use(bodyParser.json());
	app.use(expressCookies());
	app.use(morgan('combined'));
	// app.use((req, res, next) => {
	// 	res.set('Cache-Control', 'no-store');
	// 	next();
	// });
	app.use(express.static(`${__dirname}/../frontend/public`));

	/*
	 * API Routes for Addon
	 */

	// Handler to fetch the compiled LUA script for the addon
	app.all('/lua', (req, res) => {
		try {
			if (!req.query || req.query.password != process.env.application_password) {
				return res.status(403).send({ message: 'Invalid password' });
			}
			let file = fs.readFileSync(`${__dirname}/../lua/build/salvation.lua`, 'utf8');
			res.setHeader('Content-Type', 'text/plain');
			res.send('\n' + file);
		} catch (e) {
			console.log('Failed to fetch LUA for addon:', e);
			res.status(500).send('Failed to fetch LUA');
		}
	});

	// Endpoint used to check if the backend server is configured correctly
	// for now this is simply going to check if the necessary ENV options are set
	app.get('/api/check-config', (req, res) => {
		if (process.env.application_password == '') {
			res.send({ setup: false });
			return;
		}
		res.send({ setup: true });
	});

	// Endpoint used by the addon to login and validate the password before connecting
	app.post('/api/addon/login/:password', (req, res) => {
		if (req.params.password && req.params.password != process.env.application_password) {
			return res.status(403).send({ message: 'Invalid password' });
		}
		try {
			let upsertPayload = {
				name: req.body.name,
				level: req.body.level,
				class: req.body.class,
				coins: req.body.coins,
				// cords: req.body.cords, // May implement later?
				zone: req.body.zone,
				sub_zone: req.body.sub_zone,
				xp: req.body.xp,
				max_xp: req.body.max_xp,
				realm: req.body.realm,
				faction: req.body.faction,
			};

			Characters.upsert(upsertPayload);

			console.log(`Character online! ${req.body.name} - ${req.body.realm}`);
			res.send({ code: 200 });
		} catch (e) {
			console.log('Failed to login addon instance:', e);
			res.status(500).send('Failed to login');
		}
	});

	// Simple longpolling endpoint, this is where the addon will subscribe to events intended to be pushed to it
	// Commands, chat responses, etc
	app.get('/api/addon/events', (req, res) => {
		if (req.query.password && req.query.password != process.env.application_password) {
			return res.status(403).send({ message: 'Invalid password' });
		}
		try {
			let responded = false;

			let onEvent = function (payload) {
				if (!Array.isArray(payload)) {
					payload = [payload];
				}
				responded = true;
				res.send({ code: 200, events: payload });
			};

			MessageBus.subscribe(req.query.topic, onEvent);
			MessageBus.subscribe('broadcast', onEvent);

			// Cleanup the subscription just incase the connection drops or user closes game
			// Or if the max poll duration is met
			setTimeout(() => {
				if (!responded) {
					MessageBus.unsubscribe(req.query.topic, onEvent);
					res.send({ code: 200, message: 'no events before timeout' });
				}
			}, maxLongpollDuration);

			// Unlikely this will fire before the max poll duration timeout, but might as well
			req.on('close', () => {
				MessageBus.unsubscribe(req.query.topic, onEvent);
			});
		} catch (e) {
			console.log('Failed to process addon longpoll:', e);
			res.status(500).send('Internal Error');
		}
	});

	app.post('/api/addon/heartbeats', (req, res) => {
		if (req.query.password && req.query.password != process.env.application_password) {
			return res.status(403).send({ message: 'Invalid password' });
		}

		try {
			let char = Characters.upsert({
				name: req.body.name,
				level: req.body.level,
				class: req.body.class,
				coins: req.body.coins,
				// cords: req.body.cords, // May implement later
				zone: req.body.zone,
				sub_zone: req.body.sub_zone,
				xp: req.body.xp,
				max_xp: req.body.max_xp,
				realm: req.body.realm,
				faction: req.body.faction,
			});

			res.send({ code: 200 });
		} catch (e) {
			console.log('Failed to process heartbeat:', e);
			res.status(500).send('Failed to process heartbeat');
		}
	});

	app.post('/api/addon/whisper', async (req, res) => {
		if (req.query.password && req.query.password != process.env.application_password) {
			return res.status(403).send({ message: 'Invalid password' });
		}

		let character = Characters.getCharacter(req.body.name, req.body.realm);

		// remove server name from sender.. this is assuming all locales of the game have the format "character-servername"
		let sender = req.body.sender.split('-')[0];

		// front-end realtime updating gets it's own exception handler, as we'll ignore these failures for whatever reason, prioritizing push notices
		try {
			let character = Characters.getCharacter(req.body.name, req.body.realm);

			// Store this whisper in the database
			let chatEntry = ChatLog.createChatLogEntry({
				character_id: character.id,
				to: req.body.name,
				realm: req.body.realm,
				from: sender,
				is_response: 0,
				message: req.body.message,
			});

			// Broadcast to the front end users
			io.emit('chat-event', chatEntry);
		} catch (e) {
			console.log('Failed to save whisper to disk');
			console.log(e);
		}

		// if the user has a CleverBot key configured, let's send a response
		if (process.env.cleverbot_key != '') {
			setTimeout(() => {
				autoResponder({ sender, realm: req.body.realm, message: req.body.message, character });
			}, Math.floor((Math.random() * (10 - 5) + 5) * 1000)); // wait between 5-10 seconds
		}

		// Check if pushover is even enabled / configured.. if it's not then just respond here and return
		if (process.env.pushover_user == '' || process.env.pushover_token == '') {
			res.send({ code: 200 });
			return;
		}

		try {
			let msg = {
				// These values correspond to the parameters detailed on https://pushover.net/api
				// 'message' is required. All other values are optional.
				message: `A new whisper has been received!

<b>Character Name</b>: ${req.body.name}
<b>Realm</b>: ${req.body.realm}
<b>From</b>: ${req.body.sender}
------------------------------
<font color="#e134eb">${req.body.message}</font>
			`,
				title: `New Whisper - ${req.body.name}`,
				sound: 'magic',
				priority: 1,
				html: 1,
			};

			push.send(msg);
			res.send({ code: 200 });
		} catch (e) {
			console.log('Failed to process whisper alert:', e);
			res.status(500).send('Failed to process whisper alert');
		}
	});

	/*
	 * API Routes for WebUI
	 */

	// Handles user authentication, returning a JWT to be used with future requests from the front-end UI
	app.post('/api/login', (req, res) => {
		try {
			if (!req.body.password) {
				res.status(403);
				res.send({ error: 'Password is required' });
				return;
			}

			if (req.body.password != process.env.application_password) {
				res.status(403);
				res.send({ error: 'Invalid password, please try again!' });
				return;
			}

			// Get a token
			let token = generateJWT();
			res.send(
				JSON.stringify({
					token,
				})
			);
		} catch (e) {
			console.log('Failed to log user in:', e);
			res.status(500).send('Failed to login');
		}
	});

	app.get('/api/characters', requireValidJWT, (req, res) => {
		try {
			let characters = Characters.getAllCharacters();
			res.send({ characters: characters });
		} catch (e) {
			console.log('Failed to fetch characters:', e);
			res.status(500).send('Failed to fetch characters');
		}
	});

	app.delete('/api/characters/:id', requireValidJWT, async (req, res) => {
		try {
			Characters.deleteCharacter(req.params.id);
			let characters = Characters.getAllCharacters();
			res.send({ characters: characters });
		} catch (e) {
			console.log('Failed to delete character:', e);
			res.status(500).send('Failed to remove character');
		}
	});

	app.put('/api/characters/logout', requireValidJWT, async (req, res) => {
		try {
			MessageBus.broadcast({ command: 'logout' });
			res.send({ ok: true });
		} catch (e) {
			console.log('Failed to log character out:', e);
			res.status(500).send('Failed to log character out');
		}
	});

	app.put('/api/characters/:id/logout', requireValidJWT, async (req, res) => {
		try {
			let char = await Characters.getCharacterByID(req.params.id);
			MessageBus.publish(`${char.name}-${char.realm}`, { command: 'logout' });
			res.send({ ok: true });
		} catch (e) {
			console.log('Failed to log character out:', e);
			res.status(500).send('Failed to log character out');
		}
	});

	app.get('/api/chats', requireValidJWT, (req, res) => {
		try {
			let chatlog = ChatLog.getRecentChats();
			res.send({ chats: chatlog });
		} catch (e) {
			console.log('Failed to fetch chats:', e);
			res.status(500).send('Failed to fetch chats');
		}
	});

	app.post('/api/chats/:chat_id', requireValidJWT, async (req, res) => {
		try {
			// get the chat log entry and associated character
			let chatEntry = ChatLog.getChatByID(req.params.chat_id);
			let character = Characters.getCharacterByID(chatEntry.character_id);

			// Send the command to the specific character
			MessageBus.publish(`${character.name}-${character.realm}`, { command: 'send-whisper', to: chatEntry.from, message: req.body.response });

			// Store the response in the database (to and from name are reversed in this direction)
			let newChatEntry = ChatLog.createChatLogEntry({
				character_id: character.id,
				to: chatEntry.from,
				realm: character.realm,
				from: character.name,
				is_response: 1,
				message: req.body.response,
			});
			// Broadcast to the front end users
			io.emit('chat-event', newChatEntry);

			res.send({ sent: true, acked: false }); // maybe I'll add acknowledgement when a character sends a message as there is a small chance it won't get the command
		} catch (e) {
			console.log('Failed to fetch chats:', e);
			res.status(500).send('Failed to fetch chats');
		}
	});

	// listen for requests :)
	let listener = http.listen(process.env.PORT || 3000, () => {
		console.log(`Salvation is listening on port ${listener.address().port}`);
	});
}

// Start the app
main();

function generateJWT() {
	let token = jwt.sign(
		{
			// intentionally empty, this isn't a multi-tennant app so no reason to store user details :)
			//  A signed JWT will be more than enough to verify access
		},
		process.env.application_password
	);
	return token;
}

function requireValidJWT(req, res, next) {
	try {
		if (req.cookies && !req.cookies['salvation_auth']) {
			return res.status(401).send({ code: 401, error: 'Missing Authentication JWT' });
		}
		validateJWT(req.cookies['salvation_auth']);
		next();
	} catch (err) {
		return res.status(401).send({ code: 401, error: 'Missing Authentication JWT' });
	}
}

function validateJWT(token) {
	try {
		jwt.verify(token, process.env.application_password);
		return true;
	} catch (err) {
		return false;
	}
}

async function autoResponder({ sender, realm, message, character }) {
  
  let responseCap = process.env.cleverbot_max_responses || 2;
  
	// Check if this character has been responded to already
	let whisperCount = whisperCache.get(`${sender}-${realm}`); // Cache on full name+server
	if (whisperCount && whisperCount >= process.env.cleverbot_max_responses) {
		// Cache exists, so this person has been responded to the max number of times (2 in this case)
		console.log(`[AutoResponder] Ignoring whisper from ${sender}-${realm}: ${whisperCount}, maximum responses within 30minutes reached.`);
		return;
	}

	// Not in cache, send a response
	// Set default or increment
	if (whisperCount == undefined) {
		whisperCount = 1;
	} else {
		whisperCount += 1;
	}

	// Get the response from cleverbot and send it to the characters as a whisper command
	let resp = await Cleverbot.getReply(message);
	console.log(`[AutoResponder] Responding to ${sender}-${realm}: ${resp}`);

	MessageBus.publish(`${character.name}-${realm}`, { command: 'send-whisper', to: sender, message: resp });
	whisperCache.set(`${sender}-${realm}`, whisperCount, 1800); // cache for 30 minutes

	// Store the response in the database as an automatic response
	let newChatEntry = ChatLog.createChatLogEntry({
		character_id: character.id,
		to: sender,
		realm: character.realm,
		from: character.name,
		is_response: 1,
		is_auto_responder: 1,
		message: resp,
	});
	// Broadcast to the front end users
	io.emit('chat-event', newChatEntry);

	return;
}
