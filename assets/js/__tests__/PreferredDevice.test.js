import { preferredDevice, rememberDevice } from "../PreferredDevice";

beforeEach(() => window.localStorage.clear());
afterEach(() => jest.restoreAllMocks());

test("remembers the last selection across module reloads", () => {
  expect(preferredDevice()).toBeNull();
  rememberDevice("speaker1");
  rememberDevice("speaker2");
  jest.resetModules();
  expect(require("../PreferredDevice").preferredDevice()).toBe("speaker2");
});

test("unavailable browser storage does not interrupt playback", () => {
  jest.spyOn(Storage.prototype, "getItem").mockImplementation(() => { throw new Error("Blocked"); });
  jest.spyOn(Storage.prototype, "setItem").mockImplementation(() => { throw new Error("Blocked"); });
  expect(preferredDevice()).toBeNull();
  expect(() => rememberDevice("speaker1")).not.toThrow();
});
