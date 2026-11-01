// Page each shelf with large buttons; never require a hover or a scrollbar.
export default {
  mounted() {
    this.page = 0;
    this.layout = () => {
      const items = this.el.querySelectorAll("[data-shelf-item]");
      const track = this.el.querySelector(".shelf-items");
      const paging = this.el.querySelector(".shelf-paging");
      const previous = this.el.querySelector("[data-shelf-prev]");
      const next = this.el.querySelector("[data-shelf-next]");
      if (!track || !items.length) {
        paging.hidden = true;
        return;
      }
      const style = getComputedStyle(track);
      const visible = parseInt(style.getPropertyValue("--visible-items"), 10);
      const gap = parseFloat(style.columnGap) || 0;
      const pages = Math.ceil(items.length / visible);
      this.page = Math.max(0, Math.min(this.page, pages - 1));
      const offset = this.page * visible * (items[0].getBoundingClientRect().width + gap);
      track.style.transform = `translateX(-${offset}px)`;
      paging.hidden = pages <= 1;
      previous.disabled = this.page === 0;
      next.disabled = this.page === pages - 1;
      items.forEach((item, index) => {
        const shown = index >= this.page * visible && index < (this.page + 1) * visible;
        item.tabIndex = shown ? 0 : -1;
        item.setAttribute("aria-hidden", String(!shown));
      });
    };
    this.onClick = (event) => {
      if (event.target.closest("[data-shelf-prev]")) this.page -= 1;
      else if (event.target.closest("[data-shelf-next]")) this.page += 1;
      else return;
      this.layout();
    };
    this.el.addEventListener("click", this.onClick);
    window.addEventListener("resize", this.layout);
    this.layout();
  },
  updated() { this.layout(); },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
    window.removeEventListener("resize", this.layout);
  },
};
