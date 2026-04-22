const ORIGIN = "https://dashdock-releases.pages.dev";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const target = ORIGIN + url.pathname + url.search;
    const upstream = await fetch(target, {
      method: request.method,
      headers: request.headers,
      redirect: "follow",
    });
    const headers = new Headers(upstream.headers);
    headers.set("access-control-allow-origin", "*");
    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers,
    });
  },
};
