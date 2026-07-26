import { mount } from "@vue/test-utils";
import { createPinia } from "pinia";
import { nextTick } from "vue";
import { describe, expect, it } from "vitest";
import { createMemoryHistory, createRouter } from "vue-router";

import App from "../../src/App.vue";

describe("elder application shell", () => {
  it("mounts the production home route into the document entrypoint", async () => {
    document.body.innerHTML = '<div id="app"></div>';
    const { default: router } = await import("../../src/router");

    expect(router.resolve("/").matched).toHaveLength(1);

    await import("../../src/main");
    await router.isReady();
    await nextTick();

    expect(document.querySelector("#app .elder-app")).not.toBeNull();
    expect(document.querySelector("#app #home-title")?.textContent).toBe("反诈练习，慢慢来");

    document.body.innerHTML = "";
  });

  it("mounts the accessible home page at the root route", async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [{ path: "/", component: App }],
    });
    await router.push("/");
    await router.isReady();

    const wrapper = mount(App, {
      global: {
        plugins: [createPinia(), router],
      },
    });

    expect(router.currentRoute.value.fullPath).toBe("/");
    expect(wrapper.get("main").attributes("aria-labelledby")).toBe("home-title");
    expect(wrapper.get("#home-title").text()).toBe("反诈练习，慢慢来");
    expect(wrapper.get('a[href="#practice-guide"] span:first-child').text()).toBe("看看怎么练");
  });
});
