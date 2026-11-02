import DismissibleAlert from "../DismissibleAlert";

let hook;
let close;

beforeEach(() => {
  jest.useFakeTimers();
  document.body.innerHTML = '<div data-message="Playback failed"><button>×</button></div>';
  hook = { ...DismissibleAlert, el: document.querySelector("div") };
  close = jest.fn();
  hook.el.querySelector("button").addEventListener("click", close);
  hook.mounted();
});

afterEach(() => {
  hook.destroyed();
  jest.useRealTimers();
});

test("dismisses the error after exactly ten seconds", () => {
  jest.advanceTimersByTime(9999);
  expect(close).not.toHaveBeenCalled();
  jest.advanceTimersByTime(1);
  expect(close).toHaveBeenCalledTimes(1);
});

test("unrelated LiveView updates do not postpone dismissal", () => {
  jest.advanceTimersByTime(5000);
  hook.updated();
  jest.advanceTimersByTime(5000);
  expect(close).toHaveBeenCalledTimes(1);
});

test("a new error gets its own ten seconds", () => {
  jest.advanceTimersByTime(5000);
  hook.el.dataset.message = "Another error";
  hook.updated();
  jest.advanceTimersByTime(9999);
  expect(close).not.toHaveBeenCalled();
  jest.advanceTimersByTime(1);
  expect(close).toHaveBeenCalledTimes(1);
});

test("removing a dismissed error cancels its timer", () => {
  hook.el.querySelector("button").click();
  hook.destroyed();
  jest.advanceTimersByTime(10000);
  expect(close).toHaveBeenCalledTimes(1);
});
