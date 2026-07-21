// Minimal outbound-fetch interceptor. @cloudflare/vitest-pool-workers 0.18
// (vitest 4) dropped its undici fetchMock export; since the worker under test
// runs in the SAME isolate as the tests, stubbing globalThis.fetch intercepts
// the adapters' upstream calls. Unmatched requests throw (net-connect disabled).

type Matcher = (url: URL, req: Request) => boolean;
type Handler = (req: Request) => Response | Promise<Response>;

interface Registration {
  match: Matcher;
  handler: Handler;
  persist: boolean;
}

let registrations: Registration[] = [];
let installed = false;

export function installFetchMock(): void {
  if (installed) return;
  installed = true;
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const req = new Request(input, init);
    const url = new URL(req.url);
    const index = registrations.findIndex((r) => r.match(url, req));
    if (index === -1) {
      throw new Error(`unmocked outbound fetch: ${req.method} ${url.origin}${url.pathname}`);
    }
    const registration = registrations[index];
    if (!registration.persist) registrations.splice(index, 1);
    return registration.handler(req);
  }) as typeof fetch;
}

export function clearFetchMocks(): void {
  registrations = [];
}

function register(origin: string, handler: Handler, persist: boolean): void {
  registrations.push({ match: (url) => url.origin === origin, handler, persist });
}

/** Intercept the next matching request to this origin. */
export function mockOnce(origin: string, handler: Handler): void {
  register(origin, handler, false);
}

/** Intercept every matching request to this origin (until cleared). */
export function mockPersist(origin: string, handler: Handler): void {
  register(origin, handler, true);
}

export const GEMINI_ORIGIN = "https://generativelanguage.googleapis.com";
export const ANTHROPIC_ORIGIN = "https://api.anthropic.com";
