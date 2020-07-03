const Characters = require('../lib/characters');

// This worker sends out character statuses to the front end on a regular interval, and also cleans up any characters that haven't checked in
// within the specified timeout
let HeartbeatWorker = (function () {
	let running = false;
	let interval = 1000;
	let characterTimeout = 10000; // 10 second timeout, currently double heartbeat interval
	let intervalHandle = null;
	let io;

	function start(websocketServer) {
		io = websocketServer;
		running = true;
		setInterval(pulse, interval);
	}

	function stop() {
		running = false;
		clearInterval(intervalHandle);
	}

	function pulse() {
		//Timeout characters
		Characters.timeoutCharacters(characterTimeout);

		let chars = Characters.getAllCharacters();
		io.emit('character-updates', chars);
	}

	return {
		start,
		stop,
	};
})();

module.exports = HeartbeatWorker;
