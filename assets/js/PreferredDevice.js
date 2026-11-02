const key = "tune.preferredDevice";

export const preferredDevice = () => {
  try {
    return window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
};

export const rememberDevice = (device) => {
  try {
    window.localStorage.setItem(key, device);
  } catch (_) {
    // Playback still works when browser storage is unavailable.
  }
};
