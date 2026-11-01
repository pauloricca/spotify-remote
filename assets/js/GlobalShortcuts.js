export default {
  mounted() {
    this.toggleHelp = () => {
      document.querySelector("#help").classList.toggle("closed");
      document.querySelector("#modal-overlay").classList.toggle("closed");
    };
    this.helpClick = (event) => {
      if (event.target.closest("#open-button, #close-button")) {
        event.preventDefault();
        this.toggleHelp();
      }
    };
    this.keydown = (event) => {
      if (event.ctrlKey || event.metaKey || event.altKey || event.target.closest("input, textarea, select, [contenteditable], [role=dialog]")) return;
      if (event.target.closest("button, a, summary") && event.key === " ") return;
      switch (event.key) {
        case " ": event.preventDefault(); this.pushEvent("toggle_play_pause", {}); break;
        case "a": this.pushEvent("prev", {}); break;
        case "d": this.pushEvent("next", {}); break;
        case "w": this.pushEvent("inc_volume", {}); break;
        case "s": this.pushEvent("dec_volume", {}); break;
        case "h": document.querySelector('.sidebar a[href="/"]').click(); break;
        case "?": this.toggleHelp(); break;
        case "Escape":
          document.querySelector("#help").classList.add("closed");
          document.querySelector("#modal-overlay").classList.add("closed");
          break;
        case "/": {
          event.preventDefault();
          const input = document.querySelector("#q");
          if (input) input.focus();
          else document.querySelector('.sidebar a[href="/search"]').click();
          break;
        }
        case "q": this.pushEvent("open_devices", {}); break;
        case "n": {
          const link = document.querySelector("#next-page");
          if (link) link.click();
          break;
        }
        case "p": {
          const link = document.querySelector("#previous-page");
          if (link) link.click();
          break;
        }
        default: break;
      }
    };
    document.addEventListener("click", this.helpClick);
    document.addEventListener("keydown", this.keydown);
  },
  destroyed() {
    document.removeEventListener("click", this.helpClick);
    document.removeEventListener("keydown", this.keydown);
  },
};
