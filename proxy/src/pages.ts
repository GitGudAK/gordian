// Static legal/support pages served by the proxy — the App Store requires a
// hosted privacy policy URL and a support URL. Inline HTML, no assets, no
// tracking, nothing logged beyond the standard request line.

const STYLE = `
  body { background: #08090B; color: #EAEAEA; font: 16px/1.6 -apple-system, system-ui, sans-serif;
         max-width: 640px; margin: 0 auto; padding: 48px 24px; }
  h1 { color: #D4AF37; font-size: 22px; letter-spacing: 2px; text-transform: uppercase; }
  h2 { color: #D4AF37; font-size: 15px; letter-spacing: 1px; text-transform: uppercase; margin-top: 32px; }
  p, li { color: #C9CCD1; }
  a { color: #D4AF37; }
  .muted { color: #9A9FA5; font-size: 13px; }
`;

function page(title: string, body: string): Response {
  const html = `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Gordian</title><style>${STYLE}</style></head>
<body><h1>${title}</h1>${body}
<p class="muted">Gordian — a self-reflection exercise for faster decisions.</p>
</body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
}

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
<p>Reach us from the app's App Store page, or leave a review with your question — we read them.</p>
`);
}
