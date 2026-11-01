
// The main CloudFront edge Function that handles the routing before CloudFront retrieves the requested content 
// It gets the request, inspects it and decide wether to reject it, redirect it or modify it

import cf from 'cloudfront';

// using KeyValue Store here to separate data from function code 
// allow CloudFront to access dynamic config data at the edge without replaying code
// we can change the settings without changing the function we just update the kvs when a redirection is needed 

const kvs = cf.kvs();

async function cfg(key, fallback) {
    try {
        return await kvs.get(key);
    } catch (e) {
        return fallback;
    }
}

async function handler(event) {
    const req = event.request;
    const ua = (req.headers['user-agent'] || { value: '' }).value;

    // 1. Block selected abusive clients
    if (/badbot|sqlmap|nikto/i.test(ua)) {
        return {
            statusCode: 403,
            statusDescription: 'Forbidden'
        };
    }

    // 2. Config-driven redirects
    const target = await cfg('redirect:' + req.uri, null);

    if (target) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                location: { value: target }
            }
        };
    }

    // 3. Normalize pretty URLs
    if (req.uri.endsWith('/')) {
        req.uri += 'index.html';
    } else if (!req.uri.split('/').pop().includes('.')) {
        req.uri += '/index.html';
    }

    // 4. Homepage geo-routing
    if (req.uri === '/index.html') {
        const country = (
            req.headers['cloudfront-viewer-country'] || { value: '' }
        ).value;

        const frList = (await cfg('geo:fr', 'FR')).split(',');

        if (frList.includes(country)) {
            req.uri = '/fr/index.html';
            return req;
        }

        // 5. A/B testing
        let bucket = req.cookies.ab && req.cookies.ab.value;

        if (bucket !== 'A' && bucket !== 'B') {
            const raw = await cfg('ab:b_percent', '50');
            const parsed = Number(raw);

            const pct = Number.isFinite(parsed)
                ? Math.max(0, Math.min(100, parsed))
                : 50;

            bucket = Math.random() * 100 < pct ? 'B' : 'A';

            return {
                statusCode: 302,
                statusDescription: 'Found',
                headers: {
                    location: { value: '/' },
                    'cache-control': { value: 'no-store' }
                },
                cookies: {
                    ab: {
                        value: bucket,
                        attributes: 'Path=/; Max-Age=2592000; Secure; HttpOnly; SameSite=Lax'
                    }
                }
            };
        }

        if (bucket === 'B') {
            req.uri = '/b/index.html';
        }
    }

    return req;
}
