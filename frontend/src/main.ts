import { createPinia } from "pinia";
import { createApp } from "vue";
import { RouterView } from "vue-router";

import router from "./router";
import "./styles/elder.css";

createApp(RouterView).use(createPinia()).use(router).mount("#app");
