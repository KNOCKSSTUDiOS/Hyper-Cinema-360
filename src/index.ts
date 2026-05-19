// NEBULA-WEB :: KNOCKSSTUDiOS
// Worker entry — asset-first SPA fallback.

export interface Env {
  ASSETS: Fetcher;
  ENVIRONMENT: string;
  BRAND: string;
  APP: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return env.ASSETS.fetch(request);
  },
} satisfies ExportedHandler<Env>;
