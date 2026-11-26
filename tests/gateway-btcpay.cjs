// Feed actual `caddy adapt` JSON through stdin; no environment or secrets needed.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const config = JSON.parse(fs.readFileSync(0, 'utf8'));
let checks = 0;
function protectedRoute(route) {
    const routes = route.handle?.[0]?.routes;
    assert.ok(Array.isArray(routes), 'Expected explicit site subroute');
    const index = routes.findIndex(r => r.match?.some(m =>
        m.remote_ip?.ranges?.length === 1 && m.remote_ip.ranges[0] === '10.252.0.0/24'));
    assert.ok(index >= 0, 'Missing backend subnet guard');
    assert.deepEqual(routes[index].handle, [{handler: 'subroute', routes: [
        {handle: [{abort: true, handler: 'static_response'}]}
    ]}], 'Backend guard must abort, not proxy or redirect');
    // Only harmless headers may precede the guard. In particular, redirects
    // sort before handle by default and would prevent the abort from running.
    assert.ok(routes.slice(0, index).every(r => !r.match && r.handle?.every(h => h.handler === 'headers')),
        'Response or route can bypass backend guard');
}
const hosts = new Set();
for (const server of Object.values(config.apps.http.servers)) {
    for (const route of server.routes) {
        protectedRoute(route);
        checks++;
        for (const match of route.match || []) for (const host of match.host || []) hosts.add(host);
        const mutation = structuredClone(route);
        mutation.handle[0].routes.unshift({handle: [{handler: 'static_response', status_code: 301}]});
        assert.throws(() => protectedRoute(mutation), /bypass/, 'Test must reject early redirects');
        checks++;
    }
}
for (const host of ['napay.local', 'wallet.local', 'pos.localhost', 'btcpay.local']) {
    assert.ok(hosts.has(host), 'Expected site missing');
    checks++;
}
assert.ok(checks >= 20, 'Expected all HTTP and HTTPS sites');
console.log(`PASS ${checks} actual gateway configuration and negative controls`);
