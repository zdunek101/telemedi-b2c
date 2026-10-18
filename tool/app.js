// Telemedi B2C — narzędzie. Statyczna strona: czyta tool/data/*.json (agregaty) i tool/content/*.md.
"use strict";

const fmtInt = new Intl.NumberFormat("pl-PL", { maximumFractionDigits: 0 });
const fmt1 = new Intl.NumberFormat("pl-PL", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const fmt2 = new Intl.NumberFormat("pl-PL", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const pct = (num, den) => (den > 0 ? (100 * num) / den : null);
const fPct = (v) => (v == null ? "—" : fmt1.format(v) + "%");
const fPp = (v) => (v == null ? "—" : (v > 0 ? "+" : "") + fmt1.format(v) + " pp");
const fZl = (v) => (v == null ? "—" : fmt2.format(v) + " zł");
const growth = (a, b) => (a > 0 ? 100 * (b / a - 1) : null);
const fGrowth = (v) => (v == null ? "—" : (v > 0 ? "+" : "") + fmt1.format(v) + "%");
const cls = (v) => (v == null ? "" : v < 0 ? "neg" : v > 0 ? "pos" : "");
const el = (id) => document.getElementById(id);

const D = {};
Chart.defaults.maintainAspectRatio = false;
const charts = {};
let MARKERS = { cal: [], ev: [] };   // wspólna numeracja znaczników: K1… (kalendarz), Z1… (zdarzenia), po dacie

async function load() {
  const names = ["most", "cohorts", "funnel", "events", "cac", "meta"];
  const res = await Promise.all(names.map((n) => fetch(`data/${n}.json`, { cache: "no-cache" }).then((r) => r.json())));
  names.forEach((n, i) => (D[n] = res[i]));
  const md = await Promise.all(["priorytety", "nierozstrzygniete", "decisions"].map((n) => fetch(`content/${n}.md`, { cache: "no-cache" }).then((r) => r.text())));
  el("prio").innerHTML = marked.parse(md[0]);
  el("unk").innerHTML = marked.parse(md[1]);
  el("defs").innerHTML = marked.parse(md[2]);
  el("built").textContent = `Dane zbudowane: ${D.meta.zbudowano.replace("T", " ")}.`;
  MARKERS = {
    cal: D.events.kalendarz.slice().sort((a, b) => a.day.localeCompare(b.day)).map((c, i) => ({ id: "K" + (i + 1), day: c.day, opis: c.opis })),
    ev: D.events.zdarzenia.slice().sort((a, b) => a.od.localeCompare(b.od)).map((e, i) => ({ ...e, id: "Z" + (i + 1), day: e.od })),
  };
  initTabs();
  renderMost();
  initCohorts();
  initFunnel();
  initCac();
}

// ---------------- zakładki ----------------
function initTabs() {
  const show = (t) => {
    document.querySelectorAll(".tab").forEach((s) => s.classList.toggle("active", s.id === "tab-" + t));
    document.querySelectorAll("#tabs button").forEach((b) => b.classList.toggle("active", b.dataset.tab === t));
  };
  document.querySelectorAll("#tabs button").forEach((b) => b.addEventListener("click", () => { location.hash = b.dataset.tab; }));
  window.addEventListener("hashchange", () => show(location.hash.slice(1) || "wzrost"));
  show(location.hash.slice(1) || "wzrost");
}

function table(headers, rows, rowClass) {
  const th = headers.map((h) => `<th>${h}</th>`).join("");
  const tb = rows.map((r, i) => `<tr class="${rowClass ? rowClass(i) : ""}">${r.map((c) => (typeof c === "object" && c !== null ? `<td class="${c.c || ""}">${c.v}</td>` : `<td>${c}</td>`)).join("")}</tr>`).join("");
  return `<table><thead><tr>${th}</tr></thead><tbody>${tb}</tbody></table>`;
}

// znaczniki pionowe na osi dni: krótkie etykiety w trzech rzędach, opis w tabeli obok
function markerAnnotations(list, color, prefix) {
  const ann = {};
  list.forEach((m, i) => {
    ann[prefix + i] = { type: "line", xMin: m.day, xMax: m.day, borderColor: color, borderWidth: 1.2, borderDash: prefix === "cal" ? [4, 3] : [],
      label: { display: true, content: m.id, position: prefix === "cal" ? "end" : "start", yAdjust: (prefix === "cal" ? 1 : -1) * (i % 3) * 16, font: { size: 10, weight: "bold" },
               backgroundColor: color, padding: 2 } };
  });
  return ann;
}

// ---------------- WZROST ----------------
function renderMost() {
  const kpis = ["zamówienia", "przychód z konsultacji", "nowi pacjenci"];
  const unit = { "zamówienia": "", "przychód z konsultacji": " zł", "nowi pacjenci": "" };
  const steps = D.most.kroki;
  const byKpi = Object.fromEntries(kpis.map((k) => [k, steps.filter((r) => r.kpi === k).sort((a, b) => a.krok - b.krok)]));
  const clean = (k) => byKpi[k].filter((r) => !r.w_tym);
  const g = (r) => growth(r.p1, r.p2);
  const ord = clean("zamówienia"), rev = clean("przychód z konsultacji"), nowi = clean("nowi pacjenci");
  const free = byKpi["nowi pacjenci"].find((r) => r.w_tym);
  const range = [growth(...free.zakres.first), growth(...free.zakres.last)].sort((a, b) => a - b);
  const R = D.most.retencja_90;
  const retA = pct(R.a_powrot, R.a_pacjenci), retW = pct(R.w_powrot, R.w_pacjenci);

  el("answer").innerHTML = `<b class="lead">Czy wzrost jest prawdziwy? Tylko częściowo.</b>
    Po oczyszczeniu danych zamówienia rosną o <b>${fGrowth(g(ord[ord.length - 1]))}</b> zamiast ${fGrowth(g(ord[0]))},
    a przychód netto o <b>${fGrowth(g(rev[rev.length - 1]))}</b> zamiast ${fGrowth(g(rev[0]))}.
    Nowych pacjentów bez kanałów płatnych przybywa jednak tylko o <b>${fGrowth(g(free))}</b> (zakres ${fGrowth(range[0])} do ${fGrowth(range[1])}),
    a retencja spada: powrót 90 dni z ok. <b>${Math.round(retA)}%</b> (kohorty X 2024 – X 2025) do ok. <b>${Math.round(retW)}%</b> w kohortach z wiosny 2026 (III–VI).
    Wzrost jest w dużej części kupiony reklamą L4, która przyprowadza pacjentów rzadko wracających.
    <span class="small">Retencja: ${fmtInt.format(R.a_powrot)} / ${fmtInt.format(R.a_pacjenci)} i ${fmtInt.format(R.w_powrot)} / ${fmtInt.format(R.w_pacjenci)}.</span>`;

  const card = (label, s, extra) => {
    const first = s[0], last = s[s.length - 1];
    return `<div class="card"><div class="lbl">${label}: wzrost P2 / P1, dashboard → realnie</div>
      <div class="v">${fGrowth(g(first))} → ${fGrowth(g(last))}</div>
      <div class="d">realnie = ${last.opis}<br>${fmtInt.format(last.p1)} → ${fmtInt.format(last.p2)}${extra || ""}</div></div>`;
  };
  el("most-cards").innerHTML = card("zamówienia", ord) + card("przychód z konsultacji (zł)", rev)
    + `<div class="card"><div class="lbl">nowi pacjenci: wzrost P2 / P1</div>
       <div class="v">${fGrowth(g(nowi[0]))} → ${fGrowth(g(nowi[nowi.length - 1]))}</div>
       <div class="d">dashboard → nowa definicja (pierwsze nieanulowane zamówienie)</div>
       <div class="neg" style="margin-top:6px;font-size:16px;font-weight:600">w tym bez kanałów płatnych: ${fGrowth(g(free))}</div>
       <div class="d">${fmtInt.format(free.p1)} → ${fmtInt.format(free.p2)}; zakres przypisania ${fGrowth(range[0])} do ${fGrowth(range[1])}</div></div>`;

  kpis.forEach((k, ci) => {
    const s = byKpi[k];
    if (charts["most" + ci]) charts["most" + ci].destroy();
    charts["most" + ci] = new Chart(el("most-chart-" + ci), {
      type: "bar",
      data: { labels: s.map((r) => (r.w_tym ? "w tym bez płatnych" : r.opis.replace("dashboard: ", "dashboard ").replace(/\s*\(.*\)/, ""))),
        datasets: [{ data: s.map(g), backgroundColor: s.map((r, i) => (r.w_tym ? "#c62828" : i === 0 ? "#9db8e8" : "#1f6feb")) }] },
      options: { animation: false, plugins: { legend: { display: false },
          tooltip: { callbacks: { label: (c) => `wzrost ${fGrowth(c.raw)} (${fmtInt.format(s[c.dataIndex].p1)} → ${fmtInt.format(s[c.dataIndex].p2)})` } } },
        scales: { y: { beginAtZero: true, title: { display: true, text: "wzrost P2 / P1, %" } }, x: { ticks: { autoSkip: false, maxRotation: 30, minRotation: 0, font: { size: 10 } } } } },
    });
  });

  el("most-tables").innerHTML = kpis.map((k) => {
    const s = byKpi[k];
    const rows = s.map((r, i) => {
      const gr = g(r), prev = i > 0 ? g(s[i - 1]) : null;
      const opis = r.w_tym ? `<i>${r.opis}</i><br><span class="small">zakres: first ${fGrowth(growth(...r.zakres.first))}, last ${fGrowth(growth(...r.zakres.last))}</span>` : `${r.krok}. ${r.opis}`;
      return [opis, fmtInt.format(r.p1) + unit[k], fmtInt.format(r.p2) + unit[k], fGrowth(gr),
              { v: prev == null ? "" : fPp(gr - prev), c: prev == null ? "" : cls(gr - prev) }];
    });
    return `<div class="panel"><h3>${k}</h3>${table(["krok", "P1", "P2", "wzrost", "zmiana wzrostu"], rows)}</div>`;
  }).join("");

  const facts = [
    `W P2 <b>5 176</b> pierwszych zamówień miało kody nowych kampanii L4 (<code>L4SZYBKO20</code>, <code>TIKTOK25</code>). Pacjenci z tych kampanii wracają w 3–5% i dają ok. 32–39 zł marży w 180 dni, wobec 64–91 zł w większości pozostałych kampanii płatnych (zakładka CAC).`,
    `Do II 2026 spadek retencji to głównie mieszanka (kampanie L4); od III 2026 powrót spada także poza nimi (zakładka Kohorty, grupa „bez kampanii L4”).`,
    `Od 17.03.2026 Safari na iPhonie gubi nowych pacjentów w kroku konto: ok. 115 zamówień miesięcznie (Lejek → segment „przeglądarka: Safari”, krok „termin → konto”).`,
    `Od XI 2025 interniści rano (6–12): 90. percentyl czekania z ok. 12 do ok. 56 min. Kto czeka ≥ 15 min, wraca rzadziej (Niewiadome, N3).`,
  ];
  el("most-facts").innerHTML = facts.map((f) => `<li>${f}</li>`).join("");
}

// ---------------- KOHORTY ----------------
function initCohorts() {
  el("c-grp").innerHTML = D.cohorts.grupy.map((s) => `<option>${s}</option>`).join("");
  el("c-src").innerHTML = D.cohorts.zrodla.map((s) => `<option>${s}</option>`).join("");
  ["c-grp", "c-src", "c-metric", "c-smooth", "c-cal", "c-ev"].forEach((id) => el(id).addEventListener("change", renderCohorts));
  const cal = MARKERS.cal.map((c) => [`<b>${c.id}</b>`, c.day, "", `<span class="tag">kalendarz</span> ${c.opis}`]);
  const ev = MARKERS.ev.map((e) => [`<b>${e.id}</b>`, `${e.od}${e.do !== e.od ? " – " + e.do : ""}`, fmt1.format(e.max_z),
    `${e.lejek ? '<span class="tag">lejek</span> ' : ""}${e.opis.split("; ").slice(0, 3).join("; ")}${e.szeregi > 3 ? ` (+${e.szeregi - 3})` : ""}`]);
  el("c-events").innerHTML = `<div class="evlist">${table(["#", "dni", "max |z|", "co"], cal.concat(ev))}</div>
    <p class="small">Z = trwała zmiana średniej 28 dni przed / po w szeregu dziennym (|z| ≥ 5, ≥ 15%; placebo 0–1 fałszywych wykryć). Zmiany powrotu i marży od XI 2025 są stopniowe i nie przechodzą progu.</p>`;
  renderCohorts();
}

function rolling(num, den, w, valid) {
  // suma licznika i mianownika z ostatnich w dni (tylko dni z pełnym oknem), wynik = sum(num) / sum(den)
  const out = new Array(num.length).fill(null);
  for (let i = 0; i < num.length; i++) {
    if (!valid(i) || i < w - 1) continue;
    let n = 0, d = 0, ok = true;
    for (let j = i - w + 1; j <= i; j++) { if (!valid(j)) { ok = false; break; } n += num[j]; d += den[j]; }
    if (ok && d > 0) out[i] = { v: n / d, n, d };
  }
  return out;
}

function renderCohorts() {
  const grp = el("c-grp").value, src = el("c-src").value, metric = el("c-metric").value, w = +el("c-smooth").value;
  const S = D.cohorts.series[`${grp} | ${src}`], days = D.cohorts.days;
  if (charts.coh) { charts.coh.destroy(); charts.coh = null; }
  if (!S) { el("c-month").innerHTML = `<p class="small">Brak pacjentów w tej kombinacji grupy i źródła.</p>`; return; }
  const win = metric.replace(/\D/g, "");
  const last = D.cohorts.ostatni_dzien_pelnego_okna[win];
  const isMargin = metric.startsWith("marza");
  const num = isMargin ? S[metric] : S["r" + win], den = S["m" + win];
  const valid = (i) => days[i] <= last;
  const roll = rolling(num, den, w, valid);
  const lineData = roll.map((x) => (x ? (isMargin ? x.v : 100 * x.v) : null));
  const newRoll = days.map((_, i) => { if (i < w - 1) return null; let s = 0; for (let j = i - w + 1; j <= i; j++) s += S.nowi[j]; return s / w; });

  let ann = {};
  if (el("c-cal").checked) ann = { ...ann, ...markerAnnotations(MARKERS.cal, "rgba(178,106,0,.9)", "cal") };
  // domyślnie tylko najsilniejsze zdarzenia (|z| >= 10); pozostałe po zaznaczeniu checkboxa
  const evShown = el("c-ev").checked ? MARKERS.ev : MARKERS.ev.filter((e) => e.max_z >= 10);
  ann = { ...ann, ...markerAnnotations(evShown, "rgba(198,40,40,.75)", "ev") };

  const metricLabel = el("c-metric").selectedOptions[0].text;
  charts.coh = new Chart(el("c-chart"), {
    data: {
      labels: days,
      datasets: [
        { type: "bar", label: `nowi pacjenci / dzień${w > 1 ? ` (średnia ${w} dni)` : ""}`, data: w > 1 ? newRoll : S.nowi, backgroundColor: "rgba(31,111,235,.25)", yAxisID: "y", barPercentage: 1, categoryPercentage: 1 },
        { type: "line", label: metricLabel + (w > 1 ? ` (${w} dni)` : ""), data: lineData, borderColor: "#1a7f37", pointRadius: 0, borderWidth: 1.8, yAxisID: "y2", spanGaps: false },
      ],
    },
    options: {
      animation: false, interaction: { mode: "index", intersect: false },
      plugins: {
        annotation: { annotations: ann },
        tooltip: { callbacks: {
          label: (c) => {
            if (c.datasetIndex === 0) return `nowi: ${fmt1.format(c.raw)}`;
            const x = roll[c.dataIndex]; if (!x) return "brak pełnego okna";
            return isMargin ? `${metricLabel}: ${fZl(x.v)} (marża ${fmtInt.format(x.n)} zł / ${fmtInt.format(x.d)} pacjentów)`
                            : `${metricLabel}: ${fPct(100 * x.v)} (${fmtInt.format(x.n)} / ${fmtInt.format(x.d)})`;
          },
          afterBody: (items) => {
            const d = days[items[0].dataIndex];
            return MARKERS.cal.concat(MARKERS.ev).filter((m) => m.day === d).map((m) => `${m.id}: ${(m.opis || "").split("; ")[0]}`);
          },
        } },
      },
      scales: {
        x: { ticks: { maxTicksLimit: 24 } },
        y: { position: "left", title: { display: true, text: "nowi pacjenci" } },
        y2: { position: "right", grid: { drawOnChartArea: false }, title: { display: true, text: isMargin ? "zł na pacjenta" : "%" } },
      },
    },
  });

  const months = {};
  days.forEach((d, i) => {
    const m = d.slice(0, 7), r = (months[m] = months[m] || { nowi: 0, num: 0, den: 0 });
    r.nowi += S.nowi[i];
    if (valid(i)) { r.num += num[i]; r.den += den[i]; }
  });
  const rows = Object.entries(months).map(([m, r]) => [m, fmtInt.format(r.nowi),
    r.den ? `${fmtInt.format(r.num)} / ${fmtInt.format(r.den)}` : "—",
    r.den ? (isMargin ? fZl(r.num / r.den) : fPct(pct(r.num, r.den))) : "—"]);
  el("c-month").innerHTML = table(["miesiąc", "nowi", isMargin ? "marża / pacjenci (pełne okno)" : "licznik / mianownik (pełne okno)", metricLabel], rows);
}

// ---------------- LEJEK ----------------
const PRESETS = {
  p: ["2024-10-01", "2025-09-30", "2025-10-01", "2026-09-30"],
  safari: ["2026-02-17", "2026-03-16", "2026-03-17", "2026-04-13"],
  l4: ["2025-10-06", "2025-11-02", "2025-11-03", "2025-11-30"],
};
const KEYS = ["sesje", "k1", "k2", "k3", "k4", "k5"];

function initFunnel() {
  const steps = D.funnel.kroki;
  el("fd-seg").innerHTML = Object.keys(D.funnel.series).sort((a, b) => (a === "wszystko" ? -1 : b === "wszystko" ? 1 : a.localeCompare(b, "pl")))
    .map((s) => `<option${s === "przeglądarka: Safari" ? " selected" : ""}>${s}</option>`).join("");
  el("fd-step").innerHTML = steps.slice(1).map((s, i) => `<option value="${i + 1}"${i + 1 === 3 ? " selected" : ""}>${steps[i]} → ${s}</option>`).join("")
    + `<option value="tot">sesja → płatność (łącznie)</option>`;
  ["fd-seg", "fd-step", "fd-smooth", "fd-ev"].forEach((id) => el(id).addEventListener("change", renderFunnelDaily));
  const setPreset = () => {
    const p = PRESETS[el("f-preset").value]; if (!p) return;
    ["f-a1", "f-a2", "f-b1", "f-b2"].forEach((id, i) => (el(id).value = p[i]));
    renderFunnel();
  };
  el("f-preset").addEventListener("change", setPreset);
  ["f-a1", "f-a2", "f-b1", "f-b2"].forEach((id) => el(id).addEventListener("change", () => { el("f-preset").value = "custom"; renderFunnel(); }));
  el("f-split").addEventListener("change", renderFunnel);
  el("f-preset").value = "safari";
  setPreset();
}

function renderFunnelDaily() {
  const seg = el("fd-seg").value, step = el("fd-step").value, w = +el("fd-smooth").value;
  const S = D.funnel.series[seg], days = D.funnel.days;
  const num = step === "tot" ? S.k5 : S[KEYS[+step]], den = step === "tot" ? S.sesje : S[KEYS[+step - 1]];
  const roll = rolling(num, den, w, () => true);
  let ann = {
    boxA: { type: "box", xMin: el("f-a1").value, xMax: el("f-a2").value, backgroundColor: "rgba(31,111,235,.06)", borderWidth: 0 },
    boxB: { type: "box", xMin: el("f-b1").value, xMax: el("f-b2").value, backgroundColor: "rgba(31,111,235,.14)", borderWidth: 0 },
  };
  if (el("fd-ev").checked) ann = { ...ann, ...markerAnnotations(MARKERS.cal, "rgba(178,106,0,.9)", "cal"),
                                   ...markerAnnotations(MARKERS.ev.filter((e) => e.lejek), "rgba(198,40,40,.75)", "ev") };
  if (charts.fd) charts.fd.destroy();
  const label = el("fd-step").selectedOptions[0].text;
  charts.fd = new Chart(el("fd-chart"), {
    data: { labels: days, datasets: [
      { type: "line", label: `${label}, ${seg}${w > 1 ? ` (${w} dni)` : ""}`, data: roll.map((x) => (x ? 100 * x.v : null)), borderColor: "#1f6feb", pointRadius: 0, borderWidth: 1.8 },
    ] },
    options: { animation: false, interaction: { mode: "index", intersect: false },
      plugins: { annotation: { annotations: ann },
        tooltip: { callbacks: {
          label: (c) => { const x = roll[c.dataIndex]; return x ? `${fPct(100 * x.v)} (${fmtInt.format(x.n)} / ${fmtInt.format(x.d)})` : "—"; },
          afterBody: (items) => { const d = days[items[0].dataIndex]; return MARKERS.cal.concat(MARKERS.ev.filter((e) => e.lejek)).filter((m) => m.day === d).map((m) => `${m.id}: ${(m.opis || "").split("; ")[0]}`); },
        } } },
      scales: { x: { ticks: { maxTicksLimit: 24 } }, y: { title: { display: true, text: "% przejścia" } } } },
  });
}

function sumRange(series, from, to) {
  const days = D.funnel.days, out = Object.fromEntries(KEYS.map((k) => [k, 0]));
  days.forEach((d, i) => { if (d >= from && d <= to) KEYS.forEach((k) => (out[k] += series[k][i])); });
  return KEYS.map((k) => out[k]);
}

function renderFunnel() {
  const a = [el("f-a1").value, el("f-a2").value], b = [el("f-b1").value, el("f-b2").value];
  const split = el("f-split").value;
  const segs = Object.keys(D.funnel.series).filter((s) => (split === "wszystko" ? s === "wszystko" : s.startsWith(split + ":")));
  const steps = D.funnel.kroki;
  const blocks = [];
  let chartSeg = null;
  segs.forEach((seg) => {
    const A = sumRange(D.funnel.series[seg], a[0], a[1]), B = sumRange(D.funnel.series[seg], b[0], b[1]);
    if (!chartSeg) chartSeg = { seg, A, B };
    const rows = steps.map((name, i) => {
      if (i === 0) return [name, fmtInt.format(A[0]), "", fmtInt.format(B[0]), "", "", ""];
      const ca = pct(A[i], A[i - 1]), cb = pct(B[i], B[i - 1]);
      const diff = ca != null && cb != null ? cb - ca : null;
      // utracone płatności: sesje w B na wejściu kroku × (odsetek A − odsetek B) × dojście do płatności w B od tego kroku
      const down = B[i] > 0 ? B[5] / B[i] : 0;
      const lost = ca != null && cb != null ? B[i - 1] * (ca - cb) / 100 * down : null;
      return [`${steps[i - 1]} → ${name}`, fmtInt.format(A[i]), fPct(ca), fmtInt.format(B[i]), fPct(cb), { v: fPp(diff), c: cls(diff) },
              { v: lost == null ? "—" : fmtInt.format(Math.round(lost) || 0), c: cls(lost == null ? null : -Math.round(lost)) }];
    });
    const totA = pct(A[5], A[0]), totB = pct(B[5], B[0]);
    const lostTot = totA != null && totB != null ? B[0] * (totA - totB) / 100 : null;
    rows.push(["sesja → płatność (łącznie)", fmtInt.format(A[5]), fPct(totA), fmtInt.format(B[5]), fPct(totB), { v: fPp(totB - totA), c: cls(totB - totA) },
               { v: lostTot == null ? "—" : fmtInt.format(Math.round(lostTot) || 0), c: cls(lostTot == null ? null : -Math.round(lostTot)) }]);
    blocks.push(`<div class="panel"><h3>${seg}</h3>${table(["krok", "A: liczba", "A: przejście", "B: liczba", "B: przejście", "B − A", "utracone płatności w B"], rows)}</div>`);
  });
  const nd = (x) => Math.round((new Date(x[1]) - new Date(x[0])) / 864e5) + 1;
  el("f-tables").innerHTML = `<p class="small">A: ${a[0]} – ${a[1]} (${nd(a)} dni), B: ${b[0]} – ${b[1]} (${nd(b)} dni).
    Utracone płatności w B = sesje w B na wejściu kroku × (odsetek przejścia A − B) × odsetek sesji, które w B od tego kroku doszły do płatności. Ujemne = zyskane.
    Wiersz łączny = sesje B × (konwersja A − B); suma kroków może się od niego różnić, bo zmiany w krokach nakładają się.</p>` + blocks.join("");

  const conv = (X) => steps.slice(1).map((_, i) => pct(X[i + 1], X[i]));
  if (charts.fun) charts.fun.destroy();
  charts.fun = new Chart(el("f-chart"), {
    type: "bar",
    data: { labels: steps.slice(1).map((s, i) => `${steps[i]} → ${s}`),
      datasets: [{ label: `A (${chartSeg.seg})`, data: conv(chartSeg.A), backgroundColor: "#9db8e8" },
                 { label: `B (${chartSeg.seg})`, data: conv(chartSeg.B), backgroundColor: "#1f6feb" }] },
    options: { animation: false, plugins: { tooltip: { callbacks: { label: (c) => `${c.dataset.label}: ${fPct(c.raw)}` } } },
               scales: { y: { min: 0, max: 100, title: { display: true, text: "% przejścia" } } } },
  });
  renderFunnelDaily();
}

// ---------------- CAC ----------------
function initCac() { el("k-okno").addEventListener("change", renderCac); renderCac(); }

function renderCac() {
  const okno = +el("k-okno").value;
  const units = D.cac.jednostki.filter((u) => u.okno === okno);
  const isL4 = (j) => /l4_szybko|l4_15min/.test(j);
  el("k-groups").innerHTML = D.cac.grupy.filter((g) => g.okno === okno).map((g) => {
    const net = g.marza_na_pacjenta - g.cac;
    return `<div class="card"><div class="k"><b>${g.grupa}</b></div>
      <div class="lbl">marża ${okno} dni − CAC, na pacjenta</div>
      <div class="v ${net < 0 ? "neg" : ""}">${fZl(net)}</div>
      <div class="d">marża ${okno} dni ${fZl(g.marza_na_pacjenta)} − CAC ${fZl(g.cac)}<br>${fmtInt.format(g.pacjenci)} pacjentów, koszt ${fmtInt.format(g.koszt)} zł</div></div>`;
  }).join("");

  const paid = units.filter((u) => u.koszt > 0);
  if (charts.cac) charts.cac.destroy();
  charts.cac = new Chart(el("k-chart"), {
    type: "bar",
    data: { labels: paid.map((u) => u.jednostka.replace(" / paid_social", "").replace(" / cpc", "").replace(" / affiliate", "")),
      datasets: [{ label: "CAC (lnd)", data: paid.map((u) => u.cac_lnd), backgroundColor: "#c62828" },
                 { label: `marża ${okno} dni na pacjenta`, data: paid.map((u) => u.marza_na_pacjenta), backgroundColor: "#1a7f37" }] },
    options: { animation: false, indexAxis: "y",
      plugins: { tooltip: { callbacks: { label: (c) => `${c.dataset.label}: ${fZl(c.raw)}` } } },
      scales: { x: { title: { display: true, text: "zł na pacjenta" } } } },
  });

  const rows = units.map((u) => [u.jednostka, fmtInt.format(u.koszt) + " zł", fmtInt.format(u.pacjenci_lnd),
    u.koszt > 0 ? fZl(u.cac_lnd) : "0", u.koszt > 0 ? `${fmt2.format(Math.min(u.cac_first, u.cac_last))} – ${fmt2.format(Math.max(u.cac_first, u.cac_last))}` : "—",
    fZl(u.marza_na_pacjenta), fPct(u.powrot_pct), { v: fZl(u.marza_minus_cac), c: cls(u.marza_minus_cac) },
    u.marza_do_cac == null ? "—" : fmt2.format(u.marza_do_cac)]);
  el("k-table").innerHTML = `<div class="panel">${table(["kampania / kanał", "koszt", "pacjenci", "CAC", "zakres CAC (first / last)", `marża ${okno} dni / pacjent`, `powrót ${okno} dni`, "marża − CAC", "marża / CAC"],
    rows, (i) => (isL4(units[i].jednostka) ? "hl" : ""))}
    <p class="small">Wyróżnione: kampanie L4. Kanały bezpłatne bez kosztu w danych (organic, direct, polecenia); e-mail i SMS pominięte (poniżej 30 pacjentów).</p></div>`;
}

load().catch((e) => { document.querySelector("main").insertAdjacentHTML("afterbegin", `<p class="neg">Błąd ładowania danych: ${e}</p>`); console.error(e); });
