<script>
  import { onMount, onDestroy, setContext, getContext } from 'svelte';
  import { get } from 'svelte/store';
  import characterStore, { loadCharacters, removeCharacter } from '../stores/characters';
  import NProgress from 'nprogress';
  import axios from 'axios';
  import numeral from 'numeral';
  import PageLayout from '../components/PageLayout.svelte';
  let loading = true;
  let charList = [];
  let storeSubscription;

  onMount(async function() {
    // subscribe to changes to the character store
    storeSubscription = characterStore.subscribe((characters) => {
      loading = false;
      charList = characters;
    });
  });

  onDestroy(async function() {
    storeSubscription();
  });

  async function forceCharacterLogout(id) {
    NProgress.start();
    NProgress.set(0.4);
    let resp = await axios.put(`/api/characters/${id}/logout`);
    NProgress.done();
  }

  async function forceLogoutAll() {
    NProgress.start();
    NProgress.set(0.4);
    let resp = await axios.put(`/api/characters/logout`);
    NProgress.done();
  }

  async function deleteCharacter(id) {
    swal({
      title: 'Are you sure?',
      text: "This will remove the character from salvation's database.",
      icon: 'warning',
      buttons: true,
      dangerMode: true,
      buttons: ['Cancel', 'Yes, Delete It']
    }).then(async (shouldDelete) => {
      if (shouldDelete) {
        NProgress.start();
        NProgress.set(0.4);
        removeCharacter(id);
        NProgress.done();
      }
    });
  }

  function prettyXP(current, max) {
    let xp = Math.round((max / current) * 100);
    if (isFinite(xp)) {
      return xp;
    } else {
      return '100';
    }
  }

  function getAvatarImage(c) {
    return `/img/classes/${c}.png`;
  }

  function prettyGold(coins) {
    let g = coins / 100 / 100;
    if (g < 1) {
      return 0;
    }
    return numeral(g).format('0a');
  }

  function prettyFaction(faction) {
    if (faction == 'horde') {
      return `<span class="text-red-600">[H]</b>`;
    } else {
      return `<span class="text-blue-600">[A]</b>`;
    }
  }
</script>

<PageLayout pageTitle={'Dashboard'} {loading}>

  <div class="flex flex-col">
    <div class="flex justify-end mb-5">

      <span class="inline-flex rounded-md shadow-sm">
        <button
          type="button"
          on:click={forceLogoutAll}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm leading-5 font-medium rounded-md text-white bg-red-600 hover:bg-red-500 focus:outline-none
          focus:border-red-700 focus:shadow-outline-red active:bg-red-700 transition ease-in-out duration-150">
          <i class="fas fa-sign-out-alt" />
          &nbsp; Logout All
        </button>
      </span>

    </div>
    <div class="-my-2 py-2 overflow-x-auto sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <div class="align-middle inline-block min-w-full shadow overflow-hidden sm:rounded-lg border-b border-gray-200">
        <table class="min-w-full">
          <thead>
            <tr>
              <th class="px-6 py-3 border-b border-gray-200 bg-gray-50 text-left text-xs leading-4 font-medium text-gray-500 uppercase tracking-wider">Name</th>
              <th class="px-6 py-3 border-b border-gray-200 bg-gray-50 text-left text-xs leading-4 font-medium text-gray-500 uppercase tracking-wider">Location</th>
              <th class="px-6 py-3 border-b border-gray-200 bg-gray-50 text-left text-xs leading-4 font-medium text-gray-500 uppercase tracking-wider">XP</th>
              <th class="px-6 py-3 border-b border-gray-200 bg-gray-50 text-left text-xs leading-4 font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th class="px-6 py-3 border-b border-gray-200 bg-gray-50 text-left text-xs leading-4 font-medium text-gray-500 uppercase tracking-wider">Gold</th>
              <th class="px-6 py-3 border-b border-gray-200 bg-gray-50" />
            </tr>
          </thead>
          <tbody class="bg-white">
            {#if charList.length > 0}
              {#each charList as character}
                <tr class:bg-red-50={!character.online} class="hover:bg-gray-100">
                  <td class="px-6 py-4 whitespace-no-wrap border-b border-gray-200">
                    <div class="flex items-center">
                      <div class="flex-shrink-0 h-10 w-10">
                        <img class="h-10 w-10 rounded-full" src={getAvatarImage(character.class)} alt="" />
                      </div>
                      <div class="ml-4">
                        <div class="text-sm leading-5 font-medium text-gray-900">
                          {@html prettyFaction(character.faction)}
                          {character.name}
                        </div>
                        <div class="text-sm leading-5 text-gray-500">Level {character.level} {character.class}</div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-no-wrap border-b border-gray-200">
                    <div class="text-sm leading-5 text-gray-900">{character.realm}</div>
                    <div class="text-sm leading-5 text-gray-500">{character.zone} ({character.sub_zone})</div>
                  </td>
                  <td class="px-6 py-4 whitespace-no-wrap border-b border-gray-200">
                    {prettyXP(character.max_xp, character.xp)}
                    <span class="text-green-300">%</span>
                  </td>
                  <td class="px-6 py-4 whitespace-no-wrap border-b border-gray-200">
                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full {character.online ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
                      {character.online ? 'ONLINE' : 'OFFLINE'}
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-no-wrap border-b border-gray-200 text-sm leading-5 text-gray-500">
                    {prettyGold(character.coins)}
                    <span class="text-yellow-300 text-xs">g</span>
                    {Math.round((character.coins / 100) % 100)}
                    <span class="text-gray-400 text-xs">s</span>
                    {character.coins % 100}
                    <span class="text-yellow-500 text-xs">c</span>
                  </td>
                  <td class="px-6 py-4 whitespace-no-wrap text-right border-b border-gray-200 text-sm leading-5 font-medium">
                    <span class:hidden={character.online == false} class="ml-3 inline-flex rounded-md shadow-sm">
                      <button
                        on:click={forceCharacterLogout(character.id)}
                        type="submit"
                        class="inline-flex justify-center py-1 px-1 border border-transparent text-sm leading-5 font-sm rounded-md text-white bg-indigo-600 hover:bg-indigo-500
                        focus:outline-none focus:border-indigo-700 focus:shadow-outline-indigo active:bg-indigo-700 transition duration-150 ease-in-out">
                        <span>
                          <i class="fas fa-sign-out-alt" />
                          Logout
                        </span>

                      </button>
                    </span>
                    <span class:hidden={character.online == true} class="ml-3 inline-flex rounded-md shadow-sm">
                      <button
                        on:click={deleteCharacter(character.id)}
                        type="submit"
                        class="inline-flex justify-center py-1 px-1 border border-transparent text-sm leading-5 font-sm rounded-md text-white bg-red-600 hover:bg-red-500
                        focus:outline-none focus:border-red-700 focus:shadow-outline-red active:bg-red-700 transition duration-150 ease-in-out">
                        <span>
                          <i class="fas fa-times" />
                          Delete
                        </span>

                      </button>
                    </span>
                  </td>
                </tr>
              {/each}
            {:else}
              <tr>
                <td class="text-center" colspan="6">
                  <i class="fas fa-spinner fa-spin" />
                  No Characters Have Connected Yet!
                </td>
              </tr>
            {/if}
          </tbody>
        </table>
      </div>
    </div>
  </div>

</PageLayout>
