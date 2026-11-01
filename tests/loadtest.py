
import os
import statistics
import sys
import time
from pathlib import Path
from urllib.parse import urljoin

import requests
from dotenv import load_dotenv


# Load environment variables from the project root.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

CDN_URL = os.getenv("CDN_URL", "").rstrip("/")
IMAGE_NAME = os.getenv("IMAGE_NAME", "photo1.jpg")

# Keep the experiment bounded.
MAX_REQUESTS = int(os.getenv("MAX_REQUESTS", "40"))
TIMEOUT = 15

# These widths are deliberately different but fall into
# the same normalized CloudFront width bucket (640).
WIDTHS = [321, 400, 500, 600]


def percentile(values, percent):
    """Return a percentile from a non-empty list of numbers."""
    ordered = sorted(values)
    index = round((percent / 100) * (len(ordered) - 1))
    return ordered[index]


def make_url(path):
    """Build a URL using the configured CloudFront domain."""
    return urljoin(CDN_URL + "/", path.lstrip("/"))


def request_once(session, url, follow_redirects=True):
    """Send one request and measure its response time."""
    start = time.perf_counter()

    try:
        response = session.get(
            url,
            timeout=TIMEOUT,
            allow_redirects=follow_redirects,
        )
        elapsed_ms = (time.perf_counter() - start) * 1000

        return {
            "status": response.status_code,
            "elapsed_ms": elapsed_ms,
            "x_cache": response.headers.get("X-Cache", "Not provided"),
            "pop": response.headers.get("x-amz-cf-pop", "Not provided"),
            "location": response.headers.get("Location", ""),
            "set_cookie": response.headers.get("Set-Cookie", ""),
            "error": None,
        }

    except requests.RequestException as exc:
        elapsed_ms = (time.perf_counter() - start) * 1000

        return {
            "status": None,
            "elapsed_ms": elapsed_ms,
            "x_cache": "Unavailable",
            "pop": "Unavailable",
            "location": "",
            "set_cookie": "",
            "error": str(exc),
        }


def run(mode, asset_path=None):
    if not CDN_URL:
        print("Error: CDN_URL is missing from your root .env file.")
        return

    if MAX_REQUESTS < 1 or MAX_REQUESTS > 500:
        print("Error: MAX_REQUESTS must be between 1 and 500.")
        return

    if mode not in {"raw", "normalized", "ab", "asset"}:
        print("Usage:")
        print("  python tests/loadtest.py raw")
        print("  python tests/loadtest.py normalized")
        print("  python tests/loadtest.py ab")
        print("  python tests/loadtest.py asset /assets/example.css")
        return

    if mode == "asset" and not asset_path:
        print("Error: provide an asset path, such as /assets/app.css")
        return

    print(f"\nMode: {mode}")
    print(f"CloudFront: {CDN_URL}")
    print(f"Maximum requests: {MAX_REQUESTS}")
    print("-" * 55)

    results = []
    session = requests.Session()

    try:
        for i in range(MAX_REQUESTS):

            if mode in {"raw", "normalized"}:
                prefix = "/img-raw/" if mode == "raw" else "/img/"
                width = WIDTHS[i % len(WIDTHS)]
                url = make_url(
                    f"{prefix}{IMAGE_NAME}?w={width}"
                )

            elif mode == "ab":
                url = make_url("/")
                
            else:
                url = make_url(asset_path)

            # Use a fresh session for each A/B request so that
            # previous assignment cookies do not influence it.
            if mode == "ab":
                with requests.Session() as fresh_session:
                    result = request_once(
                        fresh_session,
                        url,
                        follow_redirects=False,
                    )
            else:
                result = request_once(session, url)

            results.append(result)

            status = result["status"]
            cache = result["x_cache"]

            print(
                f"Request {i + 1:03d} | "
                f"Status: {status} | "
                f"Time: {result['elapsed_ms']:.1f} ms | "
                f"Cache: {cache}"
            )

            if mode == "ab":
                if result["location"]:
                    print(f"  Redirect: {result['location']}")
                if result["set_cookie"]:
                    print("  A/B assignment cookie received")

            # Small pause between requests.
            time.sleep(0.1)

    finally:
        session.close()

    # Calculate summary statistics.
    successful_responses = [
        r for r in results if r["status"] is not None
    ]

    latencies = [
        r["elapsed_ms"] for r in successful_responses
    ]

    cache_hits = sum(
        "hit" in r["x_cache"].lower()
        and "miss" not in r["x_cache"].lower()
        for r in successful_responses
    )

    server_errors = sum(
        r["status"] is not None and 500 <= r["status"] <= 599
        for r in results
    )

    request_failures = sum(
        r["error"] is not None for r in results
    )

    print("\n" + "=" * 55)
    print("LOAD TEST SUMMARY")
    print("=" * 55)

    print(f"Total requests:       {len(results)}")
    print(f"Successful responses: {len(successful_responses)}")
    print(f"Network failures:     {request_failures}")
    print(f"HTTP 5xx errors:      {server_errors}")
    print(f"Cache hits:           {cache_hits}")

    if successful_responses:
        hit_ratio = cache_hits / len(successful_responses) * 100
        print(f"Cache hit ratio:      {hit_ratio:.1f}%")

    if latencies:
        print(f"Average latency:      {statistics.mean(latencies):.1f} ms")
        print(f"p50 latency:          {percentile(latencies, 50):.1f} ms")
        print(f"p95 latency:          {percentile(latencies, 95):.1f} ms")

    print("=" * 55)


if __name__ == "__main__":
    selected_mode = sys.argv[1] if len(sys.argv) > 1 else ""

    selected_asset = (
        sys.argv[2] if len(sys.argv) > 2 else None
    )

    run(selected_mode, selected_asset)
