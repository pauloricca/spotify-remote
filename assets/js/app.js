// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html";
import { Socket } from "phoenix";
import NProgress from "nprogress";
import { LiveSocket } from "phoenix_live_view";
import PlaybackPanel from "./PlaybackPanel";
import VolumeSlider from "./VolumeSlider";
import ProgressBar from "./ProgressBar";
import AudioPlayer from "./AudioPlayer";
import GlobalShortcuts from "./GlobalShortcuts";
import DismissibleAlert from "./DismissibleAlert";
import { preferredDevice } from "./PreferredDevice";
import StopKeyDownPropagation from "./StopKeyDownPropagation";
import { visibleViewportHeight } from "./Viewport";

window.spotifySDKReady = false;

// Silk can report different layout and visible heights while its toolbar changes.
const setVh = () => {
  const height = visibleViewportHeight();
  const vh = height * 0.01;
  document.documentElement.style.setProperty("--vh", `${vh}px`);
  document.documentElement.style.setProperty("--app-height", `${Math.floor(height)}px`);
};

setVh();
window.addEventListener("load", setVh);
window.addEventListener("resize", setVh);
window.addEventListener("orientationchange", setVh);
window.addEventListener("pageshow", setVh);
if (window.visualViewport) window.visualViewport.addEventListener("resize", setVh);

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  params: () => ({ _csrf_token: csrfToken, preferred_device: preferredDevice() }),
  hooks: {
    PlaybackPanel,
    ProgressBar,
    VolumeSlider,
    AudioPlayer,
    GlobalShortcuts,
    DismissibleAlert,
    StopKeyDownPropagation,
  },
});

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", () => NProgress.start());
window.addEventListener("phx:page-loading-stop", () => NProgress.done());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket;

window.onSpotifyWebPlaybackSDKReady = () => {
  const event = new Event("spotify.ready");
  window.dispatchEvent(event);
  window.spotifySDKReady = true;
};
