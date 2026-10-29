// 이어생각 웹 데모: 끊어둔 문장에서 이어 쓰고, 다음 문장을 끊어 두는 한 바퀴를 앱과 같은 순서로 해 본다.
// 규칙은 앱과 같다 — ContinueThinkingSheet: 생각을 적어야 '다음', 이어질 문장을 끊어둬야 '완료'로 닫힌다.
// 카드는 ThreadCardView 와 같다: 끊어둔 문장 → 지금까지의 흐름(핵심 + 직전 생각). 글자는 앱의 번역을 그대로 쓴다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const esc = s => s.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

  const PHASES = ["card", "thinking", "bridging"];
  let thread, phase, saved, thought;
  function reset() { thread = { bridge: T.bridge, last: T.last }; phase = "card"; saved = false; thought = ""; }
  reset();

  root.innerHTML = `
    <ol class="tf-steps">${[T.continue, T.thinking, T.bridging].map(s => `<li>${esc(s)}</li>`).join("")}</ol>
    <div class="tf-stage"></div>`;
  const stage = root.querySelector(".tf-stage"), steps = root.querySelectorAll(".tf-steps li");

  const badge = (cls, name) => `<span class="tf-badge ${cls}"><i></i>${esc(name)}</span>`;
  const bridge = label => `
    <div class="tf-bridge"><span class="tf-label">↳ ${esc(label)}</span><p>${esc(thread.bridge)}</p></div>`;
  const recap = () => `
    <div class="tf-recap">
      <span class="tf-muted tf-small">${esc(T.flow)}</span>
      <div>${badge("core", T.core)}<p>${esc(T.coreText)}</p></div>
      <div>${badge("note", T.note)} <span class="tf-muted tf-small">${esc(T.latest)}</span><p class="tf-muted">${esc(thread.last)}</p></div>
    </div>`;
  const writer = (label, example, button) => `
    <label class="tf-label" for="tf-input">${esc(label)}</label>
    <textarea id="tf-input" rows="3" placeholder="${esc(example)}"></textarea>
    <div class="tf-row">
      <button type="button" class="tf-chip" data-example="${esc(example)}">${esc(T.useExample)}</button>
      <button type="button" class="tf-primary" data-go disabled>${esc(button)}</button>
    </div>`;

  function render(focus) {
    steps.forEach((li, i) => li.classList.toggle("on", PHASES[i] === phase));
    if (phase === "card") {
      stage.innerHTML = `
        ${saved ? `<p class="tf-saved" role="status">${esc(T.later)}</p>` : ""}
        <div class="tf-card">
          <span class="tf-muted tf-small tf-head">${esc(T.resume)}</span>
          <h3>🧠 ${esc(T.thread)}</h3>
          ${bridge(T.bridgeName)}${recap()}
          <button type="button" class="tf-primary tf-wide" data-go>${esc(T.continue)}</button>
        </div>
        ${saved ? `<button type="button" class="tf-again" data-reset>${esc(T.again)}</button>` : ""}`;
    } else if (phase === "thinking") {
      stage.innerHTML = `<div class="tf-card">${bridge(T.leftOff)}${writer(T.thinking, T.ex1, T.next)}</div>`;
    } else {
      stage.innerHTML = `
        <div class="tf-card">
          <p class="tf-lock">🔒 ${esc(T.lock)}</p>
          <h3>${esc(T.bridgeTitle)}</h3>
          ${writer(T.bridgeLabel, T.ex2, T.done)}
        </div>`;
    }
    if (focus) (stage.querySelector("textarea") || stage.querySelector("[data-go]")).focus();
  }

  function go() {
    const input = stage.querySelector("textarea"), text = input ? input.value.trim() : "";
    if (phase === "card") phase = "thinking";
    else if (phase === "thinking") { if (!text) return; thought = text; phase = "bridging"; }
    else {
      if (!text) return;
      thread = { bridge: text, last: thought };   // 앱처럼 방금 쓴 생각이 직전 생각, 끊어둔 문장이 맨 위로
      phase = "card"; saved = true;
    }
    render(true);
  }

  root.addEventListener("input", e => {
    if (e.target.id === "tf-input") stage.querySelector("[data-go]").disabled = !e.target.value.trim();
  });
  root.addEventListener("click", e => {
    const ex = e.target.closest("[data-example]");
    if (ex) {
      const input = stage.querySelector("textarea");
      input.value = ex.dataset.example;
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.focus();
      return;
    }
    if (e.target.closest("[data-go]")) go();
    if (e.target.closest("[data-reset]")) { reset(); render(true); }
  });
  // 키보드: 입력란에서 ⌘/Ctrl + Enter 로 다음 단계
  root.addEventListener("keydown", e => {
    if (e.target.id === "tf-input" && e.key === "Enter" && (e.metaKey || e.ctrlKey)) { e.preventDefault(); go(); }
  });

  render(false);
})();
