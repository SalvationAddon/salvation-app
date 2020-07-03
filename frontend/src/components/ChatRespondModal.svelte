<script>
  import NProgress from "nprogress";
  import axios from "axios";
  import { fade } from "svelte/transition";

  export let closeResponseModal;
  export let chat;
  let responseMessage;

  async function sendResponse() {
    NProgress.start();
    NProgress.set(0.4);
    let resp = await axios.post(`/api/chats/${chat.id}`, {
      response: responseMessage
    });
    NProgress.done();
    closeResponseModal();
  }
</script>

<div
  transition:fade
  class="fixed bottom-0 inset-x-0 px-4 pb-4 sm:inset-0 sm:flex sm:items-center
  sm:justify-center">
  <div class="fixed inset-0 transition-opacity">
    <div
      on:click={closeResponseModal}
      class="absolute inset-0 bg-gray-500 opacity-75" />
  </div>

  <!--
    Modal panel, show/hide based on modal state.

    Entering: "ease-out duration-300"
      From: "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
      To: "opacity-100 translate-y-0 sm:scale-100"
    Leaving: "ease-in duration-200"
      From: "opacity-100 translate-y-0 sm:scale-100"
      To: "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
  -->
  <div
    class="bg-white rounded-lg overflow-hidden shadow-xl transform
    transition-all sm:max-w-lg sm:w-full"
    role="dialog"
    aria-modal="true"
    aria-labelledby="modal-headline">
    <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
      <div class="sm:flex sm:items-start">
        <div
          class="mx-auto flex-shrink-0 flex items-center justify-center h-12
          w-12 rounded-full bg-green-100 sm:mx-0 sm:h-10 sm:w-10">
          <div class="text-green-600">
            <i class="fas fa-envelope-open-text" />
          </div>
        </div>
        <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
          <h3
            class="text-lg leading-6 font-medium text-gray-900"
            id="modal-headline">
            Message from: {chat.sender}
            <span class="text-gray-500">({chat.realm})</span>
          </h3>
          <div
            class="mt-2 sm:w-full text-sm rounded-md bg-gray-50 px-6 py-5
            text-purple-300 bg-gray-800 leading-normal">
            <p>{chat.message}</p>
          </div>
        </div>
      </div>
    </div>

    <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
      <div class="sm:flex sm:items-start">
        <div
          class="mx-auto flex-shrink-0 flex items-center justify-center h-12
          w-12 rounded-full bg-green-100 sm:mx-0 sm:h-10 sm:w-10">
          <div class="text-green-600">
            <i class="fas fa-reply" />
          </div>
        </div>
        <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
          <h3
            class="text-lg leading-6 font-medium text-gray-900"
            id="modal-headline">
            Response:
          </h3>
          <div class="w-full">
            <label for="response" class="sr-only">Message</label>
            <div class="relative rounded-md shadow-sm">
              <input
                id="response"
                bind:value={responseMessage}
                class="form-input block w-full sm:text-sm sm:leading-5"
                placeholder="Your nice response here..." />
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
      <span class="flex w-full rounded-md shadow-sm sm:ml-3 sm:w-auto">
        <button
          on:click={sendResponse}
          type="button"
          class="inline-flex justify-center w-full rounded-md border
          border-transparent px-4 py-2 bg-indigo-600 text-base leading-6
          font-medium text-white shadow-sm hover:bg-indigo-500
          focus:outline-none focus:border-indigo-700 focus:shadow-outline-indigo
          transition ease-in-out duration-150 sm:text-sm sm:leading-5">
          Send Response
        </button>
      </span>
      <span class="mt-3 flex w-full rounded-md shadow-sm sm:mt-0 sm:w-auto">
        <button
          on:click={closeResponseModal}
          type="button"
          class="inline-flex justify-center w-full rounded-md border
          border-gray-300 px-4 py-2 bg-white text-base leading-6 font-medium
          text-gray-700 shadow-sm hover:text-gray-500 focus:outline-none
          focus:border-blue-300 focus:shadow-outline-blue transition ease-in-out
          duration-150 sm:text-sm sm:leading-5">
          Cancel
        </button>
      </span>
    </div>
  </div>
</div>
