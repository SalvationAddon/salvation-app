var EventEmitter = require('events').EventEmitter;

let MessageBus = (function () {
	let cachedEvents = {};
	let messageBus = new EventEmitter();

	// this will remove any cached commands that haven't been picked up yet by clients after N number of seconds
	// Really this is just a simple buffer to save messages in-case the character losses connection for a few seconds
	function clearExpiredCache() {
		// iterate over each topic
		for (const topic in cachedEvents) {
			const events = cachedEvents[topic];
			for (const event of events) {
				let cachedMs = Date.now() - event.cached_time;
				if (cachedMs > 5000) {
					console.log(`Expiring cached command (${topic}) => `, event.payload.command);
					// filter the array and omit this event
					cachedEvents[topic] = events.filter(function (val) {
						return val != event;
					});
				}
			}
		}
	}
	setInterval(clearExpiredCache, 1000);

	// Subscribe creates a subscription to a specific topic for a single message
	// returns a promise
	function subscribe(topic, callBack) {
		// clear any existing subscriptions for this topic.. there should only be one per topic
		messageBus.removeAllListeners(topic);

		// Check for any queued messages first
		if (cachedEvents[topic] && cachedEvents[topic].length > 0) {
			let topicMessages = cachedEvents[topic];
			cachedEvents[topic] = []; // clear the cache
			let payloads = topicMessages.map(function (event) {
				return event.payload;
			});
			return callBack(payloads);
		}

		messageBus.once(topic, callBack);
	}

	function unsubscribe(topic, listener) {
		messageBus.removeListener(topic, listener);
	}

	function broadcast(payload) {
		if (messageBus.listenerCount('broadcast') > 0) {
			messageBus.emit('broadcast', payload);
		}
	}

	// Publish emits a message for a specific topic
	function publish(topic, payload) {
		// Check if there is a listerner for this topic
		if (messageBus.listenerCount(topic) == 0) {
			// Cache this message for later
			if (!cachedEvents[topic]) cachedEvents[topic] = [];
			cachedEvents[topic].push({
				cached_time: Date.now(),
				payload: payload,
			});
			return;
		}

		// Topic has at least one listener, publish message now
		return messageBus.emit(topic, payload);
	}

	return {
		subscribe,
		broadcast,
		publish,
		unsubscribe,
	};
})();

module.exports = MessageBus;
