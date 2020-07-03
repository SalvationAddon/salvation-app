<script>
  import { onMount, setContext, getContext } from "svelte";
  import { get } from "svelte/store";
  import Router from "svelte-spa-router";
  import { wrap, push, location } from "svelte-spa-router";
  import swal from "sweetalert";
  import axios from "axios";
  import NProgress from "nprogress";
  import toastr from "toastr";
  import { routes } from "./router.js";
  import websocket from "./lib/websocket.js";
  import { loadCharacters } from "./stores/characters";
  import { loadChatLog } from "./stores/chats";

  axios.interceptors.response.use(
    response => {
      return response;
    },
    error => {
      if (error.response.status === 401) {
        // Check the route we're at is the login screen
        if (get(location) == "/login") return;

        document.cookie = "salvation_auth=; Max-Age=0";
        NProgress.done();
        toastr.error(
          "Invalid Credentials, please login again!",
          "Please Login",
          {
            newestOnTop: true,
            progressBar: true,
            preventDuplicates: true
          }
        );
        push("/login");
      }
      return error;
    }
  );

  // Check if the app is configured correctly..
  axios.get("/api/check-config").then(function(res) {
    if (res.data.setup != true) {
      swal({
        title: "Configuration Needed",
        text:
          "Please check the '.env' file and set a password for the app, as well as the Pushover tokens!",
        icon: "warning",
        closeOnClickOutside: false,
        closeOnEsc: false,
        buttons: false
      });
    }
  });

  onMount(async () => {
    websocket.connect();
    await loadCharacters(); // fetch initial load of characters
    await loadChatLog(); // fetch initial load of characters
  });
</script>

<style global>
  @import "@fortawesome/fontawesome-free/css/all.min.css";
  /* It's kind of hard to treeshake in a dynamic app like svelte, but I could have the rollup config wrong..   */
  /* purgecss start ignore */
  @import "toastr/build/toastr.css";
  @import "nprogress/nprogress.css";
  @tailwind base;
  @tailwind components;
  @tailwind utilities;
  @import "@tailwindcss/ui/dist/tailwind-ui.min.css";
  /* purgecss end ignore */

  #nprogress .bar {
    background: #2ddff1;
  }

  html {
    height: 100%;
  }
</style>

<main class="bg-gray-100">
  <Router {routes} />
</main>
