
// prepares img requests before CloudFront sends them to Lambda

function handler(event) {

    // gets the request as usual
    const req = event.request;
    const accept = (req.headers.accept || { value: '' }).value;

    // checks wether the browser supports webp format, otherwise uses jpeg
    req.headers['x-img-fmt'] = { value: accept.includes('image/webp') ? 'webp' : 'jpeg' };

    // checks if the browser is asking for a specific width for the img and uses 640 if not
    let w = req.querystring.w ? parseInt(req.querystring.w.value, 10) : 640;

    if (isNaN(w)) w = 640;

    // we don't want to generate and use a new image for each request that's why we use one of the predefined sizes
    const snapped = [320, 640, 1024].find(s => s >= w) || 1024;

    // we replace the request size with the size we will be using, and return the request
    req.querystring = { w: { value: String(snapped) } };
    return req;
}