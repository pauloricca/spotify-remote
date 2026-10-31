export default {
  mounted() {
    this.previousFocus = document.activeElement;
    this.el.focus();
    this.trapFocus = (event) => {
      if (event.key !== "Tab") return;
      const elements = Array.from(this.el.querySelectorAll("button:not([disabled]), a[href], input, select"));
      const first = elements[0];
      const last = elements[elements.length - 1];
      if (!first) return;
      if (event.shiftKey && (document.activeElement === first || document.activeElement === this.el)) {
        event.preventDefault(); last.focus();
      } else if (!event.shiftKey && (document.activeElement === last || document.activeElement === this.el)) {
        event.preventDefault(); first.focus();
      }
    };
    this.el.addEventListener("keydown", this.trapFocus);
  },
  destroyed() {
    this.el.removeEventListener("keydown", this.trapFocus);
    if (this.previousFocus && this.previousFocus.isConnected) this.previousFocus.focus();
  },
};
