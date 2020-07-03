<script>
  import { onMount, onDestroy, setContext, getContext } from 'svelte';
  import { fade } from 'svelte/transition';

  import { get } from 'svelte/store';
  import * as timeago from 'timeago.js';
  import swal from 'sweetalert';
  import PageLayout from '../components/PageLayout.svelte';
  import ChatRespondModal from '../components/ChatRespondModal.svelte';
  import chatLogStore from '../stores/chats';
  import characterStore, { isCharacterOnline } from '../stores/characters';

  let loading = true;

  // This will show the modal for responding to chats
  let showRespondModal = false;
  let respondToChat = null;

  // subscription for chat messages from the central store
  let storeSubscription;
  // Local state of chats
  let chatLog = [];

  // Simple interval for refreshing the chat timestamps "timeago" stuffs
  let timeRefreshInterval;
  let chatLogMutex = false;

  // On mount pull the chats from the store
  onMount(async function() {
    // subscribe to changes to the character store
    storeSubscription = chatLogStore.subscribe((chats) => {
      loading = false;
      chatLogMutex = true;
      chatLog = chats;
      chatLogMutex = false;
    });

    // Kick off a timer to refresh the time since messages arrived.. basically this forces a refresh of all chat elements 🤷‍♂️
    timeRefreshInterval = setInterval(() => {
      if (!chatLogMutex) {
        chatLog = chatLog;
      }
    }, 1000);
  });

  onDestroy(async function() {
    clearInterval(timeRefreshInterval);
    storeSubscription();
  });

  async function sendResponse(chat) {
    if (chat.is_response || chat.to == chat.from) {
      swal('Reply Message', "This is a reply sent from your character, you can't respond to your self!", 'warning');
      return;
    }

    // Check if this player is online
    let isOnline = await isCharacterOnline(chat.character_id);
    if (!isOnline) {
      swal('Character Offline', 'This character is offline and is unable to send messages currently.', 'warning');
      return;
    }

    respondToChat = chat;
    showRespondModal = true;
  }

  function closeResponseModal() {
    showRespondModal = false;
    respondToChat = null;
  }
</script>

<style>
  .timestamp-col {
    min-width: 6rem;
  }

  .chat-window {
    min-height: 500px;
  }
</style>

<PageLayout pageTitle={'Chat Log'} {loading}>

  <div class="flex flex-col">
    <div class="flex-wrap content-end justify-start mb-5">
      <div class="text-xl mb-3 p-4">Below are recent messages from all characters, you can click on a single message to send a response!</div>

      <div class="rounded-md bg-blue-50 p-4 mb-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3 flex-1 md:flex md:justify-between">
            <p class="text-sm leading-5 text-blue-700">
              <b>Note:</b>
              Purple messages are whispers from other players, Blue messages are resposnes you've sent. (If it has a robot icon it was an AutoResponse!) Most recent messages are at
              the top.
            </p>
          </div>
        </div>
      </div>

      <div class="chat-window rounded-md overflow-auto h-auto m-0 p-2 text-white text-sm bg-gray-800 leading-normal">
        {#each chatLog as chat}
          <div
            transition:fade|local
            on:click={sendResponse(chat)}
            class:text-blue-300={chat.is_response == true}
            class:cursor-pointer={chat.is_response == false}
            class:text-purple-300={chat.is_response == false}
            class:hover:bg-gray-600={chat.is_response == false}
            class="sm:flex-wrap md:flex text-purple-300 pt-2">

            <div class="flex-auto text-base">
              {#if chat.is_auto_responder}
                <span class="text-base">
                  <i class="fas fa-xs fa-w-14 fa-robot" />
                </span>
              {/if}
              <span class="text-base">[{chat.from}] To [{chat.to}]:</span>
              {chat.message}
            </div>
            <div class="flex-auto text-gray-100 mr-2 max-w-md timestamp-col sm:text-left md:text-right text-xs mt-1" title={Date(`${chat.timestamp} GMT`).toLocaleString()}>
              {timeago.format(Date.parse(`${chat.timestamp} GMT`))}
            </div>
          </div>
        {/each}
      </div>
    </div>
    {#if showRespondModal}
      <ChatRespondModal chat={respondToChat} {closeResponseModal} />
    {/if}
  </div>
</PageLayout>
