export function visibleViewportHeight(view = window, root = document.documentElement) {
  const heights = [
    view.innerHeight,
    root.clientHeight,
    view.visualViewport && view.visualViewport.height,
  ].filter(height => Number.isFinite(height) && height > 0);

  return Math.floor(Math.min(...heights));
}
