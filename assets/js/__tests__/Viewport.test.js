import { visibleViewportHeight } from "../Viewport";

test("uses the visible height when browser chrome obscures the layout viewport", () => {
  expect(visibleViewportHeight({innerHeight: 800, visualViewport: {height: 704.8}}, {clientHeight: 800})).toBe(704);
});

test("uses the smaller document height when Silk reports an oversized visual viewport", () => {
  expect(visibleViewportHeight({innerHeight: 800, visualViewport: {height: 800}}, {clientHeight: 720})).toBe(720);
});

test("supports browsers without visualViewport and ignores unavailable measurements", () => {
  expect(visibleViewportHeight({innerHeight: 680}, {clientHeight: 0})).toBe(680);
  expect(visibleViewportHeight({innerHeight: 0, visualViewport: {height: 0}}, {clientHeight: 600})).toBe(600);
});
