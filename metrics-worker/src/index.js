export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = {
      "Access-Control-Allow-Origin": "https://readers-retreat.wold-pm.com",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: cors });
    }

    // POST /api/track?path=stories/Foo.txt  (also used for the clone-button, path=__clone__)
    if (url.pathname === "/api/track" && request.method === "POST") {
      const path = url.searchParams.get("path");
      if (!path) return new Response("missing path", { status: 400, headers: cors });
      const key = "count:" + path;
      const current = parseInt((await env.METRICS.get(key)) || "0", 10);
      await env.METRICS.put(key, String(current + 1));
      return new Response("ok", { headers: cors });
    }

    // GET /api/counts -> sorted JSON of every tracked path, most-read first
    if (url.pathname === "/api/counts" && request.method === "GET") {
      const list = await env.METRICS.list({ prefix: "count:" });
      const results = [];
      for (const k of list.keys) {
        const val = await env.METRICS.get(k.name);
        results.push({ path: k.name.replace("count:", ""), views: parseInt(val || "0", 10) });
      }
      results.sort((a, b) => b.views - a.views);
      return new Response(JSON.stringify(results, null, 2), {
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    return new Response("not found", { status: 404, headers: cors });
  },
};
