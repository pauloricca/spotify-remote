export default {
  mounted() {
    this.message = this.el.dataset.message;
    this.timer = setTimeout(() => this.el.querySelector("button").click(), 10000);
  },
  updated() {
    if (this.message !== this.el.dataset.message) {
      clearTimeout(this.timer);
      this.mounted();
    }
  },
  destroyed() {
    clearTimeout(this.timer);
  },
};
