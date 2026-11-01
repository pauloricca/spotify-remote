import TouchShelf from "../TouchShelf";

function shelf(count = 8) {
  document.body.innerHTML = `<section><div class="shelf-paging"><button data-shelf-prev></button><button data-shelf-next></button></div><div class="shelf-items" style="--visible-items:5;column-gap:20px">${Array.from({length: count}, (_, i) => `<button data-shelf-item>Album ${i}</button>`).join("")}</div></section>`;
  document.querySelectorAll("[data-shelf-item]").forEach(el => {
    el.getBoundingClientRect = () => ({width: 100});
  });
  const hook = {...TouchShelf, el: document.querySelector("section")};
  hook.mounted();
  return hook;
}

const visibleNames = () => [...document.querySelectorAll('[data-shelf-item][aria-hidden="false"]')].map(el => el.textContent);

test("all albums stay reachable through the last page without scrolling", () => {
  const hook = shelf();
  expect(visibleNames()).toEqual(["Album 0", "Album 1", "Album 2", "Album 3", "Album 4"]);
  expect(document.querySelector("[data-shelf-prev]").disabled).toBe(true);
  document.querySelector("[data-shelf-next]").click();
  expect(visibleNames()).toEqual(["Album 5", "Album 6", "Album 7"]);
  expect(document.querySelector("[data-shelf-next]").disabled).toBe(true);
  expect(document.querySelector('[data-shelf-item]').tabIndex).toBe(-1);
  document.querySelector("[data-shelf-prev]").click();
  expect(visibleNames()).toHaveLength(5);
  hook.destroyed();
});

test("resizing and live content updates never leave a blank page", () => {
  const hook = shelf();
  document.querySelector("[data-shelf-next]").click();
  document.querySelector(".shelf-items").style.setProperty("--visible-items", "3");
  window.dispatchEvent(new Event("resize"));
  expect(visibleNames()).toEqual(["Album 3", "Album 4", "Album 5"]);
  document.querySelectorAll('[data-shelf-item]').forEach((el, i) => { if (i >= 2) el.remove(); });
  hook.updated();
  expect(visibleNames()).toEqual(["Album 0", "Album 1"]);
  expect(document.querySelector(".shelf-paging").hidden).toBe(true);
  hook.destroyed();
});

test("empty shelves do not expose paging controls", () => {
  const hook = shelf(0);
  expect(document.querySelector(".shelf-paging").hidden).toBe(true);
  hook.destroyed();
});
