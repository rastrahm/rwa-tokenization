const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'RWA Tokenization · ERC-3643 — Rolando Strahm',
    'meta.description':
      'Tokenización RWA permissioned estilo ERC-3643/T-REX: Identity Registry, freeze/forced recovery, dividendos snapshot y compliance modular. Foundry · Solidity 0.8.24 · SWC.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Defensa',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 19 · PORTFOLIO WEB3',
    'hero.title': 'RWA TOKENIZATION<br>ERC-3643 / T-REX',
    'hero.role': 'Solidity 0.8.24 · Foundry · Compliance · SWC',
    'hero.sub':
      'Token permissioned de activos reales: Identity Registry, freeze/forced recovery, dividendos por snapshot y compliance modular — con gas documentado y auditoría SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Los RWA no son un ERC-20 abierto: exigen <strong>KYC on-chain</strong>, congelación legal y recuperación de wallets. Este módulo implementa ese stack permissioned (estilo <strong>ERC-3643 / T-REX</strong>) con Foundry, cerrando con <strong>gas</strong>, <strong>fuzz/invariantes</strong> y <strong>matriz SWC</strong>.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Token permissioned',
    'p1.desc':
      'RWAToken ERC-20 con Identity Registry: cada transfer exige isVerified; mint solo a wallets KYC.',
    'p1.l1': 'IdentityNotVerified en transfer',
    'p1.l2': 'Claims + trusted issuers (lab)',
    'p1.l3': 'AccessControl AGENT_ROLE',
    'p2.num': '// PILAR_02',
    'p2.title': 'Compliance & recovery',
    'p2.desc':
      'Pause, freeze total/parcial, forcedTransfer y módulos país / max balance sin romper totalSupply.',
    'p2.l1': 'ModularCompliance AND',
    'p2.l2': 'UnauthorizedAgent en forced',
    'p2.l3': 'Supply + frozen invariantes',
    'p3.num': '// PILAR_03',
    'p3.title': 'Yield + SWC',
    'p3.desc':
      'Dividendos pro-rata por snapshot (USDC lab), gas snapshot y auditoría SWC-100–136 con 0 vulnerabilidades explotables.',
    'p3.l1': 'CEI + ReentrancyGuardTransient',
    'p3.l2': '80 tests (unit/fuzz/invariant)',
    'p3.l3': '0 SWC vulnerables',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot paths medidos',
    'gas.lead':
      'Fase <strong>SOLV</strong>: baseline en <code>.gas-snapshot</code> y tradeoffs en <code>doc/GAS-ES.md</code>. El coste de transfer crece con topics × módulos; el lab mantiene N pequeño.',
    'gas.th1': 'Optimización / path',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'ReentrancyGuardTransient (claims)',
    'gas.r1b': 'Guard con tstore Cancun; sin SSTORE del guard clásico',
    'gas.r2a': 'Custom errors (RWAErrors)',
    'gas.r2b': 'Reverts compactos vs require con strings',
    'gas.r3a': 'Snapshots lazy (estilo ERC20Snapshot)',
    'gas.r3b': 'Sin copiar todos los balances al crear snapshot',
    'gas.r4a': 'immutable registries / modules',
    'gas.r4b': 'Menos SLOAD en Identity / compliance / distributor',
    'gas.r5a': 'transfer ≈ 98k · freezePartial ≈ 41k',
    'gas.r5b': 'Baseline KYC-only; compliance bound suma O(módulos)',
    'gas.r6a': 'forcedTransfer ≈ 117k · snapshot+claim ≈ 288k',
    'gas.r6b': 'Recovery + ciclo de dividendos medidos en Foundry',
    'gas.r7a': 'optimizer_runs 10_000 + via_ir',
    'gas.r7b': 'Inlining de hot paths; solc 0.8.24 Cancun',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz completa <strong>SWC-100 → SWC-136</strong> contra el stack RWA. Informe en <code>doc/SWC-AUDIT-ES.md</code> (estilo módulo 18). Conclusión: <strong>0 vulnerabilidades explotables</strong>.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el protocolo',
    'swc.r101': 'Overflow: Solidity 0.8.24; checks en frozenTokens / claims floor',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r107': 'Reentrancy: CEI + ReentrancyGuardTransient en claim',
    'swc.r115': 'Sin tx.origin: AccessControl / Ownable2Step',
    'swc.r121': 'Replay de yield: AlreadyClaimed one-shot por distribución',
    'swc.r123': 'Requirement: IdentityNotVerified / TransferNotCompliant / UnauthorizedAgent',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'Approve front-running',
    'swc.i1d':
      'Inherente a ERC-20 (RWA / USDC). Mitigación: approvals mínimas al distributor; flujos agent-gated.',
    'swc.i2t': 'KYC lab sin firmas',
    'swc.i2d':
      'Claims escritos por el owner de Identity + trusted issuers. Post-v1: ONCHAINID con firmas criptográficas.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases por dominio',
    'pr.lead':
      'Gates de autorización por dominio RWA (no el esquema 0–7 genérico): identity → token → locks → recovery → yield → compliance → solvencia.',
    'ph.1': 'Identity Registry + isVerified',
    'ph.2': 'RWAToken permissioned',
    'ph.3': 'Pause + freeze parcial',
    'ph.4': 'forcedTransfer recovery',
    'ph.5': 'Dividendos snapshot',
    'ph.6': 'ModularCompliance',
    'ph.7': 'Fuzz + SWC + gas',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'Campañas def.',

    'term.label': 'rolando@strahm:~/19-rwa-tokenization',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 80 passed',
    'term.3': 'cat doc/SWC-AUDIT-ES.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 4 · Mitigados/N/A: 32',
    'term.5': 'echo status',
    'term.6': 'MODULE_19_CLOSED · IDENT→SOLV_OK',

    'at.eyebrow': '// 06 — CAMPAÑAS DEFENSIVAS',
    'at.title': 'Compliance que debe fallar',
    'at.lead':
      'Cada campaña es un suite Foundry donde el “ataque” (transfer no-KYC, over-claim, país restringido) debe revertir. Sin PoCs ofensivos: integridad permissioned.',
    'cA.t': 'KYC gate',
    'cA.d': 'Transfer/mint sin isVerified → IdentityNotVerified.',
    'cB.t': 'Locks',
    'cB.d': 'Pause / freeze total y parcial; supply intacto.',
    'cC.t': 'Recovery',
    'cC.d': 'forcedTransfer solo agent; destino KYC.',
    'cD.t': 'Yield',
    'cD.d': 'Pro-rata exacto; sin double-claim ni over-claim.',
    'cE.t': 'Modules',
    'cE.d': 'País restringido / max balance → TransferNotCompliant.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'El mismo código está publicado en GitHub y GitLab. Contratos, tests, fases, auditoría SWC y gas snapshot.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — RWA · ERC-3643 · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'RWA Tokenization · ERC-3643 — Rolando Strahm',
    'meta.description':
      'Permissioned RWA tokenization (ERC-3643/T-REX style): Identity Registry, freeze/forced recovery, snapshot dividends, and modular compliance. Foundry · Solidity 0.8.24 · SWC.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Defense',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 19 · WEB3 PORTFOLIO',
    'hero.title': 'RWA TOKENIZATION<br>ERC-3643 / T-REX',
    'hero.role': 'Solidity 0.8.24 · Foundry · Compliance · SWC',
    'hero.sub':
      'Permissioned real-world asset token: Identity Registry, freeze/forced recovery, snapshot dividends, and modular compliance — with documented gas and a full SWC-100–136 audit.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'RWAs are not open ERC-20s: they need <strong>on-chain KYC</strong>, legal freezes, and wallet recovery. This module builds that permissioned stack ( <strong>ERC-3643 / T-REX</strong> style) with Foundry, closed out with <strong>gas</strong>, <strong>fuzz/invariants</strong>, and an <strong>SWC matrix</strong>.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'Permissioned token',
    'p1.desc':
      'ERC-20 RWAToken with an Identity Registry: every transfer requires isVerified; mint only to KYC wallets.',
    'p1.l1': 'IdentityNotVerified on transfer',
    'p1.l2': 'Claims + trusted issuers (lab)',
    'p1.l3': 'AccessControl AGENT_ROLE',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Compliance & recovery',
    'p2.desc':
      'Pause, total/partial freeze, forcedTransfer, and country / max-balance modules without breaking totalSupply.',
    'p2.l1': 'ModularCompliance AND',
    'p2.l2': 'UnauthorizedAgent on forced',
    'p2.l3': 'Supply + frozen invariants',
    'p3.num': '// PILLAR_03',
    'p3.title': 'Yield + SWC',
    'p3.desc':
      'Pro-rata snapshot dividends (lab USDC), gas snapshot, and SWC-100–136 audit with 0 exploitable findings.',
    'p3.l1': 'CEI + ReentrancyGuardTransient',
    'p3.l2': '80 tests (unit/fuzz/invariant)',
    'p3.l3': '0 vulnerable SWCs',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Measured hot paths',
    'gas.lead':
      '<strong>SOLV</strong> phase: baseline in <code>.gas-snapshot</code> and tradeoffs in <code>doc/GAS-EN.md</code>. Transfer cost grows with topics × modules; the lab keeps N small.',
    'gas.th1': 'Optimization / path',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'ReentrancyGuardTransient (claims)',
    'gas.r1b': 'Cancun tstore guard; no classic guard SSTORE',
    'gas.r2a': 'Custom errors (RWAErrors)',
    'gas.r2b': 'Compact reverts vs string requires',
    'gas.r3a': 'Lazy snapshots (ERC20Snapshot-style)',
    'gas.r3b': 'No full balance copy when creating a snapshot',
    'gas.r4a': 'immutable registries / modules',
    'gas.r4b': 'Fewer SLOADs in Identity / compliance / distributor',
    'gas.r5a': 'transfer ≈ 98k · freezePartial ≈ 41k',
    'gas.r5b': 'KYC-only baseline; bound compliance adds O(modules)',
    'gas.r6a': 'forcedTransfer ≈ 117k · snapshot+claim ≈ 288k',
    'gas.r6b': 'Recovery + dividend cycle measured in Foundry',
    'gas.r7a': 'optimizer_runs 10_000 + via_ir',
    'gas.r7b': 'Hot-path inlining; solc 0.8.24 Cancun',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full <strong>SWC-100 → SWC-136</strong> matrix against the RWA stack. Report in <code>doc/SWC-AUDIT-EN.md</code> (module-18 style). Conclusion: <strong>0 exploitable vulnerabilities</strong>.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the protocol',
    'swc.r101': 'Overflow: Solidity 0.8.24; frozenTokens / claim floor checks',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r107': 'Reentrancy: CEI + ReentrancyGuardTransient on claim',
    'swc.r115': 'No tx.origin: AccessControl / Ownable2Step',
    'swc.r121': 'Yield replay: AlreadyClaimed one-shot per distribution',
    'swc.r123': 'Requirement: IdentityNotVerified / TransferNotCompliant / UnauthorizedAgent',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'Approve front-running',
    'swc.i1d':
      'Inherent to ERC-20 (RWA / USDC). Mitigation: minimal distributor approvals; agent-gated flows.',
    'swc.i2t': 'Lab KYC without signatures',
    'swc.i2d':
      'Claims written by Identity owner + trusted issuers. Post-v1: ONCHAINID with cryptographic claim signatures.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Domain phases',
    'pr.lead':
      'Authorization gates by RWA domain (not the generic 0–7 scheme): identity → token → locks → recovery → yield → compliance → solvency.',
    'ph.1': 'Identity Registry + isVerified',
    'ph.2': 'Permissioned RWAToken',
    'ph.3': 'Pause + partial freeze',
    'ph.4': 'forcedTransfer recovery',
    'ph.5': 'Snapshot dividends',
    'ph.6': 'ModularCompliance',
    'ph.7': 'Fuzz + SWC + gas',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWCs',
    'st.4': 'Def. campaigns',

    'term.label': 'rolando@strahm:~/19-rwa-tokenization',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 80 passed',
    'term.3': 'cat doc/SWC-AUDIT-EN.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 4 · Mitigated/N/A: 32',
    'term.5': 'echo status',
    'term.6': 'MODULE_19_CLOSED · IDENT→SOLV_OK',

    'at.eyebrow': '// 06 — DEFENSIVE CAMPAIGNS',
    'at.title': 'Compliance that must fail',
    'at.lead':
      'Each campaign is a Foundry suite where the “attack” (non-KYC transfer, over-claim, restricted country) must revert. No offensive PoCs — permissioned integrity.',
    'cA.t': 'KYC gate',
    'cA.d': 'Transfer/mint without isVerified → IdentityNotVerified.',
    'cB.t': 'Locks',
    'cB.d': 'Pause / total & partial freeze; supply intact.',
    'cC.t': 'Recovery',
    'cC.d': 'forcedTransfer agent-only; verified destination.',
    'cD.t': 'Yield',
    'cD.d': 'Exact pro-rata; no double-claim or over-claim.',
    'cE.t': 'Modules',
    'cE.d': 'Restricted country / max balance → TransferNotCompliant.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'The same codebase is published on GitHub and GitLab: contracts, tests, phases, SWC audit, and gas snapshot.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — RWA · ERC-3643 · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('rwa-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('rwa-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);
