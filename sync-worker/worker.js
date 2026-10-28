// Cloudflare Worker + KV: хранилище прогресса по семейному коду.
// Деплой: wrangler kv namespace create PROGRESS → вписать id в wrangler.toml → wrangler deploy
export default {
  async fetch(req, env) {
    const cors = {'access-control-allow-origin':'*','access-control-allow-methods':'GET,PUT,OPTIONS','access-control-allow-headers':'content-type'};
    if (req.method === 'OPTIONS') return new Response(null, {headers: cors});
    const code = decodeURIComponent(new URL(req.url).pathname.slice(1));
    if (!/^[a-z0-9-]{6,40}$/.test(code)) return new Response('bad code', {status: 400, headers: cors});
    if (req.method === 'GET') {
      const v = await env.PROGRESS.get(code);
      return v ? new Response(v, {headers: {...cors, 'content-type': 'application/json'}}) : new Response('not found', {status: 404, headers: cors});
    }
    if (req.method === 'PUT') {
      const body = await req.text();
      if (body.length > 200000) return new Response('too large', {status: 413, headers: cors});
      try { JSON.parse(body) } catch { return new Response('bad json', {status: 400, headers: cors}) }
      await env.PROGRESS.put(code, body, {expirationTtl: 60*60*24*365});
      return new Response('ok', {headers: cors});
    }
    return new Response('method', {status: 405, headers: cors});
  }
}
