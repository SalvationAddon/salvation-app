import io from 'socket.io-client';
import charactersStore from '../stores/characters';
import chatStore, { insertNewMessage } from '../stores/chats';
import { Howl } from 'howler';
import toastr from 'toastr';

var sound = new Howl({
	src: ['/sounds/bike.mp3'],
});

function connect() {
	let socket = io();

	//wire up the necessary listeners
	socket.on('character-updates', (data) => {
		charactersStore.set(data);
	});

	// New whispers pushed from backend
	socket.on('chat-event', (data) => {
		// If this isn't a response from one of the characters in Salcation, alert
		// This is necessary as both responses and normal whispers come through this pipe
		if (!data.is_response) {
			toastr.info(`[${data.from}]: ${data.message}`, 'New Whisper!');
			sound.play();
		}
		insertNewMessage(data);
	});
}

export default {
	connect,
};
