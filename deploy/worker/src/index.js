const ORIGIN = "https://dashdock-releases.pages.dev";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/^\/dashdock/, "") || "/";
    const target = ORIGIN + path + url.search;
    const upstream = await fetch(target, {
      method: request.method,
      headers: request.headers,
      redirect: "follow",
      cf: { cacheTtl: 60, cacheEverything: false },
    });
    const headers = new Headers(upstream.headers);
    headers.set("access-control-allow-origin", "*");
    if (url.pathname.endsWith("appcast.xml")) {
      headers.set("cache-control", "public, max-age=60");
    }
    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers,
    });
  },
};
