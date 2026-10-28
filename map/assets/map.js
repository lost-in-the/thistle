/* Optional, focus-scoped letter shortcuts. The server-rendered UI needs no JS. */
(() => {
  "use strict";
  const root = document.getElementById("workbench");
  const setting = document.getElementById("letter-shortcuts");
  if (!root || !setting) return;
  setting.closest("label").hidden = false;
  const storageKey = "thistle-map.letter-shortcuts";
  try { setting.checked = sessionStorage.getItem(storageKey) === "on"; } catch (_) {}
  setting.addEventListener("change", () => {
    try { sessionStorage.setItem(storageKey, setting.checked ? "on" : "off"); } catch (_) {}
  });
  root.addEventListener("keydown", (event) => {
    if (!setting.checked || event.defaultPrevented || event.repeat || event.isComposing ||
        event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) return;
    const target = event.target;
    if (!(target instanceof Element) || !root.contains(document.activeElement) ||
        target.closest("input, textarea, select, [contenteditable], [role=textbox], [role=combobox]")) return;
    if (window.getSelection && !window.getSelection().isCollapsed) return;
    const key = event.key.toLowerCase();
    if (key === "f") {
      const field = document.getElementById("find-query");
      if (field) { event.preventDefault(); field.focus(); }
    } else if (key === "s" || key === "g") {
      const link = root.querySelector(`[data-shortcut="${key}"]`);
      if (link) { event.preventDefault(); link.click(); }
    } else if (key === "j" || key === "k") {
      const links = Array.from(root.querySelectorAll("[data-result-link]"));
      if (!links.length) return;
      const index = links.indexOf(document.activeElement);
      const next = key === "j" ? Math.min(index + 1, links.length - 1) : Math.max(index - 1, 0);
      event.preventDefault();
      links[next].focus();
    }
  });
})();
