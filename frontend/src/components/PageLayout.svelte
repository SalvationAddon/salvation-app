<script>
  import { link } from "svelte-spa-router";
  import Footer from "./Footer.svelte";
  export let pageTitle;
  export let loading;

  let menuVisible = false;
  function toggleMenu() {
    menuVisible = !menuVisible;
  }
</script>

<div class="">
  <nav class="bg-gray-800">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex items-center justify-between h-16">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <img
              class="h-8 w-8 object-contain"
              src="/img/owl_white.png"
              alt="Salvation" />
          </div>
          <div class="hidden md:block">
            <div class="ml-10 flex items-baseline">
              <a
                class:bg-gray-900={pageTitle == 'Dashboard'}
                href="/"
                use:link
                class="px-3 py-2 rounded-md text-sm font-medium text-white
                focus:outline-none focus:text-white focus:bg-gray-700">
                Dashboard
              </a>
              <a
                class:bg-gray-900={pageTitle == 'Chat Log'}
                href="/chat-log"
                use:link
                class="px-3 py-2 rounded-md text-sm font-medium text-white
                focus:outline-none focus:text-white focus:bg-gray-700">
                Chat Log
              </a>
            </div>
          </div>
        </div>

        <div class="-mr-2 flex md:hidden">
          <!-- Mobile menu button -->
          <button
            on:click={toggleMenu}
            class="inline-flex items-center justify-center p-2 rounded-md
            text-gray-400 hover:text-white hover:bg-gray-700 focus:outline-none
            focus:bg-gray-700 focus:text-white">
            <!-- Menu open: "hidden", Menu closed: "block" -->
            <svg
              class="block h-6 w-6"
              stroke="currentColor"
              fill="none"
              viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 6h16M4 12h16M4 18h16" />
            </svg>
            <!-- Menu open: "block", Menu closed: "hidden" -->
            <svg
              class="hidden h-6 w-6"
              stroke="currentColor"
              fill="none"
              viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    </div>

    <div
      class:hidden={!menuVisible}
      class:block={menuVisible}
      class="hidden md:hidden">
      <div class="px-2 pt-2 pb-3 sm:px-3">
        <a
          href="/"
          use:link
          class="block px-3 py-2 rounded-md text-base font-medium text-white
          bg-gray-900 focus:outline-none focus:text-white focus:bg-gray-700">
          Dashboard
        </a>
        <a
          href="/chat-log"
          use:link
          class="mt-1 block px-3 py-2 rounded-md text-base font-medium
          text-gray-300 hover:text-white hover:bg-gray-700 focus:outline-none
          focus:text-white focus:bg-gray-700">
          Chat Log
        </a>
      </div>
    </div>
  </nav>

  <header class="bg-white shadow-sm">
    <div class="max-w-7xl mx-auto py-4 px-4 sm:px-6 lg:px-8">
      <h1 class="text-lg leading-6 font-semibold text-gray-900">{pageTitle}</h1>
    </div>
  </header>
  <main>
    <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      {#if !loading}
        <slot />
      {:else}
        <div
          class="fixed bottom-0 inset-x-0 px-4 pb-6 sm:inset-0 sm:p-0 sm:flex
          sm:items-center sm:justify-center">
          <div class="fixed inset-0 transition-opacity">
            <div class="absolute inset-0 bg-gray-500 opacity-75" />
          </div>
          <div
            class="bg-white rounded-lg px-4 pt-5 pb-4 overflow-hidden shadow-xl
            transform transition-all sm:max-w-sm sm:w-full sm:p-6"
            role="dialog"
            aria-modal="true"
            aria-labelledby="modal-headline">
            <div>
              <div
                class="mx-auto flex items-center justify-center h-12 w-12
                rounded-full bg-green-100">
                <i class="fas fa-spin fa-sync-alt text-green-600" />
              </div>
              <div class="mt-3 text-center sm:mt-5">
                <h3
                  class="text-lg leading-6 font-medium text-gray-900"
                  id="modal-headline">
                  Please Wait...
                </h3>
                <div class="mt-2">
                  <p class="text-sm leading-5 text-gray-500">
                    Connecting to the Salvation Server
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      {/if}
    </div>
    <Footer />
  </main>

</div>
