// Static legal/support pages served by the proxy — the App Store requires a
// hosted privacy policy URL and a support URL. Self-contained HTML: the knot
// mark is an embedded data URI, the Alexander scene is inline SVG. No assets,
// no tracking, nothing logged beyond the standard request line.

import { LOGO_B64 } from "./logo.ts";

const STYLE = `
  body { background: #08090B; color: #EAEAEA; font: 16px/1.6 -apple-system, system-ui, sans-serif;
         max-width: 640px; margin: 0 auto; padding: 40px 24px 56px; }
  header { display: flex; align-items: center; gap: 14px; margin-bottom: 40px; }
  header img { width: 56px; height: auto; }
  header .word { color: #D4AF37; font-size: 20px; font-weight: 800; letter-spacing: 5px; }
  h1 { color: #D4AF37; font-size: 22px; letter-spacing: 2px; text-transform: uppercase; margin: 0 0 24px; }
  h2 { color: #D4AF37; font-size: 15px; letter-spacing: 1px; text-transform: uppercase; margin-top: 32px; }
  p, li { color: #C9CCD1; }
  a { color: #D4AF37; }
  .muted { color: #9A9FA5; font-size: 13px; }
  figure.alexander { margin: 56px 0 0; text-align: center; }
  figure.alexander svg { width: 100%; max-width: 520px; height: auto; }
  blockquote { margin: 18px auto 4px; color: #F1E4C3; font-size: 17px; font-style: italic; max-width: 420px; }
  figcaption { color: #9A9FA5; font-size: 12px; letter-spacing: 2px; text-transform: uppercase; }
`;

// Art Deco Alexander at Gordium: sunburst, stepped pedestal, the knot's two
// diamonds pulled apart, a blade through the gap, an angular figure in profile.
const ALEXANDER_SVG = `
<svg viewBox="0 0 640 330" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Art Deco scene of Alexander cutting the Gordian knot">
  <g stroke="#D4AF37" stroke-opacity="0.16" stroke-width="2">
    <line x1="346" y1="172" x2="600" y2="40"/><line x1="346" y1="172" x2="632" y2="110"/>
    <line x1="346" y1="172" x2="640" y2="185"/><line x1="346" y1="172" x2="610" y2="255"/>
    <line x1="346" y1="172" x2="520" y2="16"/><line x1="346" y1="172" x2="430" y2="8"/>
    <line x1="346" y1="172" x2="300" y2="6"/>
  </g>
  <g fill="#D4AF37">
    <rect x="298" y="248" width="96" height="13"/>
    <rect x="284" y="261" width="124" height="11"/>
    <rect x="270" y="272" width="152" height="9"/>
  </g>
  <g fill="none" stroke="#D4AF37" stroke-width="7" stroke-linejoin="miter">
    <path d="M 296 222 L 330 188 L 296 154 L 262 188 Z"/>
    <path d="M 396 196 L 430 162 L 396 128 L 362 162 Z"/>
  </g>
  <g stroke="#D4AF37" stroke-width="5" stroke-linecap="round">
    <line x1="333" y1="180" x2="326" y2="171"/>
    <line x1="337" y1="196" x2="330" y2="205"/>
    <line x1="359" y1="154" x2="366" y2="145"/>
    <line x1="355" y1="170" x2="362" y2="179"/>
  </g>
  <g fill="#F1E4C3">
    <polygon points="243,64 257,58 412,248 398,254"/>
    <polygon points="235,52 251,72 243,78 229,60"/>
  </g>
  <g fill="#D4AF37" fill-opacity="0.92">
    <polygon points="130,152 190,152 176,268 144,268"/>
    <polygon points="165,98 188,120 165,142 142,120"/>
    <polygon points="184,158 240,84 252,94 196,170"/>
  </g>
  <g stroke="#D4AF37" stroke-width="2">
    <line x1="60" y1="306" x2="580" y2="306"/>
  </g>
  <g fill="#D4AF37">
    <path d="M 320 300 L 326 306 L 320 312 L 314 306 Z"/>
    <path d="M 296 302 L 300 306 L 296 310 L 292 306 Z"/>
    <path d="M 344 302 L 348 306 L 344 310 L 340 306 Z"/>
  </g>
</svg>`;

function page(title: string, body: string, footer = ""): Response {
  const html = `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Gordian</title><style>${STYLE}</style></head>
<body>
<header><img src="data:image/png;base64,${LOGO_B64}" alt="Gordian knot mark"><span class="word">GORDIAN</span></header>
<h1>${title}</h1>${body}${footer}
<p class="muted" style="margin-top:32px">Gordian, a self-reflection exercise for faster decisions.</p>
</body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
}

const ALEXANDER_FIGURE = `
<figure class="alexander">
  ${ALEXANDER_SVG}
  <blockquote>&ldquo;Alexander did not untie the knot. He drew his sword and cut it.&rdquo;</blockquote>
  <figcaption>Gordium, 333 BC</figcaption>
</figure>`;

export function privacyPage(): Response {
  return page("Privacy Policy", `
<p class="muted">Effective July 21, 2026</p>
<p>Gordian is built so that your decisions stay yours. This policy describes everything the app touches, in full.</p>
<h2>What stays on your device</h2>
<p>Your dilemmas, your answers, your reflections, your decision history, and all statistics are stored only on your device. There are no accounts, no sign-ins, and no analytics or advertising SDKs in the app. Deleting the app deletes your history.</p>
<h2>What leaves your device</h2>
<p>When you start a session, the text of your dilemma (and later, your tapped answers with any spoken reflections you chose to add) is sent over an encrypted connection to our server so your session questions and verdict can be generated. This content is processed in memory to serve your request and is never stored on our servers. Our server logs contain only technical fields: a timestamp, the operation type, an anonymized device identifier (a one-way hash), latency, and an outcome code. Dilemma text can never appear in logs.</p>
<h2>The device identifier</h2>
<p>The app generates a random identifier on first launch. It is not linked to your identity, contacts, location, or any advertising system, and is used only to apply fair-use rate limits.</p>
<h2>Voice input</h2>
<p>If you use voice, speech is transcribed on-device by Apple's speech recognition. Audio never reaches our servers; only the resulting text, if you submit it with an answer.</p>
<h2>Purchases</h2>
<p>Subscriptions and purchases are processed entirely by Apple. We receive no payment details.</p>
<h2>Third parties</h2>
<p>Session content is processed by our infrastructure provider and a language-model provider as necessary to generate your session, under contractual terms that prohibit use of your content for anything else. No content is used to train models.</p>
<h2>Changes</h2>
<p>If this policy changes, the new version will be posted at this address with an updated effective date.</p>
`);
}

export function supportPage(): Response {
  return page("Support", `
<p>Gordian is a sixty-second self-reflection exercise: describe what you're stuck on, answer quick gut questions against the clock, and see your own lean reflected back.</p>
<h2>Common questions</h2>
<p><b>Do I need an account?</b> No. There is nothing to sign up for.</p>
<p><b>Where is my history?</b> Only on your device, under Logs. Deleting the app deletes it.</p>
<p><b>Why did a session need a connection?</b> Questions are written for your exact dilemma, which requires our server. If you're offline, retry when connected.</p>
<p><b>Why were sessions paused?</b> Gordian pauses itself when a dilemma describes harming yourself or someone else. If that pause was wrong, rephrase the dilemma. If any part of it was real: in the US, call or text 988.</p>
<p><b>How does the free week work?</b> Full access for 7 days from first launch, then a subscription or one-time lifetime unlock. Codes can be redeemed from Settings.</p>
<h2>Contact</h2>
<p>Reach us from the app's App Store page, or leave a review with your question. We read them.</p>
`, ALEXANDER_FIGURE);
}
