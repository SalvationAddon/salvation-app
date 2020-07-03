<script>
  import { wrap, push } from "svelte-spa-router";
  import { get } from "svelte/store";
  import axios from "axios";
  import toastr from "toastr";
  import NProgress from "nprogress";
  import ws from "./lib/websocket";
  import Footer from "./components/Footer.svelte";

  let password = "";

  async function doLogin() {
    NProgress.inc(0.4);
    let resp = await axios
      .post("/api/login", {
        password
      })
      .catch(function(e) {
        let msg = "Invalid Password";
        if (e.response && e.response.data.error) {
          msg = e.response.data.error;
        }
        toastr.error(msg, "Login Failed", {
          newestOnTop: true,
          progressBar: true,
          preventDuplicates: true
        });
        NProgress.done();
        return;
      });

    if (!resp) return;

    if (resp.status != 200) {
      toastr.error("Failed to login, invalid password", "Login Failed", {
        newestOnTop: true,
        progressBar: true,
        preventDuplicates: true
      });
      NProgress.done();
      return;
    }

    NProgress.done();
    document.cookie = "salvation_auth=" + resp.data.token + ";path=/;";

    // Kick off the overall socket connector
    ws.connect();

    // redirect to the dashboard
    push("/");
  }
</script>

<div
  class="min-h-screen flex items-center justify-center bg-gray-200 py-12 px-4
  sm:px-6 lg:px-8">
  <div class="max-w-md w-full">
    <div>
      <img
        class="object-contain h-24 w-full"
        src="/img/owl_gradient_transparent.png"
        alt="Salvation" />
      <h2
        class="mt-6 text-center text-3xl leading-9 font-extrabold text-gray-900">
        Please Login
      </h2>
    </div>
    <form
      class="mt-8"
      autocomplete="off"
      method="post"
      on:submit|preventDefault={doLogin}>
      <div class="rounded-md shadow-sm">
        <div class="-mt-px">
          <input
            autocomplete="off"
            aria-label="Password"
            name="password"
            type="password"
            bind:value={password}
            required
            class="appearance-none rounded-md relative block w-full px-3 py-2
            border border-gray-300 placeholder-gray-500 text-gray-900
            focus:outline-none focus:shadow-outline-blue focus:border-blue-300
            focus:z-10 sm:text-sm sm:leading-5"
            placeholder="Password" />
        </div>
      </div>

      <div class="mt-6">
        <button
          type="submit"
          class="group relative w-full flex justify-center py-2 px-4 border
          border-transparent text-sm leading-5 font-medium rounded-md text-white
          bg-indigo-600 hover:bg-indigo-500 focus:outline-none
          focus:border-indigo-700 focus:shadow-outline-indigo
          active:bg-indigo-700 transition duration-150 ease-in-out">
          <span class="absolute left-0 inset-y-0 flex items-center pl-3">
            <svg
              class="h-5 w-5 text-indigo-500 group-hover:text-indigo-400
              transition ease-in-out duration-150"
              fill="currentColor"
              viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0
                01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                clip-rule="evenodd" />
            </svg>
          </span>
          Sign in
        </button>
      </div>
    </form>
    <Footer />
  </div>

</div>
