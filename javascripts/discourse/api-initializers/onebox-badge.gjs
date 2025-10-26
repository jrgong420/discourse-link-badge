import { apiInitializer } from "discourse/lib/api";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import MerchantBadgeModal from "../components/merchant-badge-modal";

const BADGE_MARKER = "data-merchant-badges-added";

// Known affiliate redirect patterns: tracking host -> parameter names containing target URL
const TRACKING_PATTERNS = new Map([
  ["awin1.com", ["ued"]],
  ["t.adcell.com", ["param0"]],
]);

// Cache for merchant lookups (cleared on page navigation)
const merchantCache = new Map();

// Maximum recursion depth for nested redirect URLs
const MAX_REDIRECT_DEPTH = 2;

/**
 * Safely parse a URL string
 * @param {string} urlString - URL to parse
 * @returns {URL|null} - Parsed URL or null if invalid
 */
function safeParse(urlString) {
  if (!urlString || typeof urlString !== "string") {
    return null;
  }

  try {
    // Handle URLs without scheme (e.g., "www.example.com")
    if (!urlString.includes("://")) {
      if (urlString.startsWith("www.") || urlString.includes(".")) {
        urlString = `https://${urlString}`;
      } else {
        return null;
      }
    }
    return new URL(urlString);
  } catch {
    return null;
  }
}

/**
 * Normalize a URL hostname to match against merchant domains
 * @param {string} url - Full URL or hostname
 * @returns {string} - Normalized domain (e.g., "example.com")
 */
function normalizeDomain(url) {
  try {
    const hostname = url.includes("://")
      ? new URL(url).hostname
      : url.toLowerCase();
    // Remove www. prefix for matching
    return hostname.replace(/^www\./, "");
  } catch {
    return url.toLowerCase().replace(/^www\./, "");
  }
}

/**
 * Try to parse a candidate string as a URL, handling URL encoding
 * @param {string} candidate - Potential URL string (may be encoded)
 * @returns {string|null} - Decoded URL string or null
 */
function tryParseCandidateUrl(candidate) {
  if (!candidate || typeof candidate !== "string") {
    return null;
  }

  // Try as-is first
  if (candidate.includes("://")) {
    return candidate;
  }

  // Try decoding once (handles single encoding)
  try {
    const decoded = decodeURIComponent(candidate);
    if (decoded !== candidate && decoded.includes("://")) {
      return decoded;
    }
  } catch {
    // Invalid encoding, continue
  }

  // Check if it looks like a domain without scheme
  if (candidate.startsWith("www.") || /^[a-z0-9-]+\.[a-z]{2,}/i.test(candidate)) {
    return `https://${candidate}`;
  }

  return null;
}

/**
 * Extract nested target URL from known tracking redirect parameters
 * @param {URL} parsedUrl - Parsed redirect URL
 * @returns {string|null} - Extracted target URL or null
 */
function extractFromKnownParams(parsedUrl) {
  const host = normalizeDomain(parsedUrl.hostname);
  const paramNames = TRACKING_PATTERNS.get(host);

  if (!paramNames || paramNames.length === 0) {
    return null;
  }

  const params = new URLSearchParams(parsedUrl.search || "");

  for (const paramName of paramNames) {
    const values = params.getAll(paramName);
    for (const value of values) {
      const candidateUrl = tryParseCandidateUrl(value);
      if (candidateUrl) {
        return candidateUrl;
      }
    }
  }

  return null;
}

/**
 * Fallback: scan all query parameters for URL-like values
 * @param {URL} parsedUrl - Parsed URL
 * @returns {string|null} - First URL-like parameter value or null
 */
function extractFromAnyParam(parsedUrl) {
  const params = new URLSearchParams(parsedUrl.search || "");

  for (const [, value] of params) {
    const candidateUrl = tryParseCandidateUrl(value);
    if (candidateUrl) {
      return candidateUrl;
    }
  }

  return null;
}

/**
 * Extract candidate merchant URL from redirect URL or nested parameters
 * @param {string} url - Original URL (may be a redirect)
 * @param {number} depth - Current recursion depth
 * @returns {string|null} - Extracted target URL or null
 */
function extractCandidateUrl(url, depth = 0) {
  if (depth >= MAX_REDIRECT_DEPTH) {
    return null;
  }

  const parsed = safeParse(url);
  if (!parsed) {
    return null;
  }

  // Try known tracking patterns first
  let candidate = extractFromKnownParams(parsed);

  // Fallback to scanning all params if no known pattern matched
  if (!candidate) {
    candidate = extractFromAnyParam(parsed);
  }

  // If we found a nested URL, check if it's also a redirect (recurse)
  if (candidate) {
    const nestedParsed = safeParse(candidate);
    if (nestedParsed) {
      const nestedHost = normalizeDomain(nestedParsed.hostname);
      // If the nested URL is also a known tracking host, recurse
      if (TRACKING_PATTERNS.has(nestedHost)) {
        const deeperCandidate = extractCandidateUrl(candidate, depth + 1);
        return deeperCandidate || candidate;
      }
    }
    return candidate;
  }

  return null;
}

/**
 * Match a URL against merchant domains by hostname
 * @param {string} url - URL to match
 * @param {Array} merchants - Merchant configs
 * @returns {Object|null} - Matched merchant or null
 */
function matchByHost(url, merchants) {
  if (!url || !merchants || merchants.length === 0) {
    return null;
  }

  const domain = normalizeDomain(url);

  return merchants.find((merchant) => {
    const merchantDomain = normalizeDomain(merchant.domain);
    return domain === merchantDomain || domain.endsWith(`.${merchantDomain}`);
  });
}

/**
 * Find merchant config by domain (with nested redirect URL support)
 * @param {string} url - Link URL (may be a redirect)
 * @param {Array} merchants - Merchant configs from settings
 * @param {boolean} debug - Enable debug logging
 * @returns {Object|null} - Matched merchant or null
 */
function findMerchant(url, merchants, debug = false) {
  if (!url || !merchants || merchants.length === 0) {
    return null;
  }

  // Check cache first
  const cached = merchantCache.get(url);
  if (cached !== undefined) {
    if (debug) {
      // eslint-disable-next-line no-console
      console.log("[Merchant Matching] Cache hit:", { url, merchant: cached });
    }
    return cached;
  }

  // Try direct hostname match first (fast path)
  let merchant = matchByHost(url, merchants);

  if (merchant) {
    if (debug) {
      // eslint-disable-next-line no-console
      console.log("[Merchant Matching] Direct match:", { url, merchant });
    }
    merchantCache.set(url, merchant);
    return merchant;
  }

  // Try extracting nested URL from redirect parameters
  const candidateUrl = extractCandidateUrl(url);

  if (candidateUrl) {
    if (debug) {
      // eslint-disable-next-line no-console
      console.log("[Merchant Matching] Extracted nested URL:", { original: url, extracted: candidateUrl });
    }

    merchant = matchByHost(candidateUrl, merchants);

    if (merchant && debug) {
      // eslint-disable-next-line no-console
      console.log("[Merchant Matching] Nested match:", { candidateUrl, merchant });
    }
  }

  // Cache result (even if null)
  merchantCache.set(url, merchant || null);
  return merchant || null;
}

function buildMerchantBadges(merchant, showVerified, showCoupons, modal, sourceUrl, debugModal) {
  const verifiedOn = !!showVerified && !!merchant?.verified;
  const couponsCount = Array.isArray(merchant?.coupons) ? merchant.coupons.length : 0;
  const couponsOn = !!showCoupons && couponsCount > 0;

  if (!verifiedOn && !couponsOn) {
    return null;
  }

  const result = { leading: null, trailing: null };

  const clickHandler = (e) => {
    e.preventDefault();
    e.stopPropagation();

    if (debugModal) {
      // eslint-disable-next-line no-console
      console.log("[Merchant Modal] Click handler triggered", {
        merchant,
        sourceUrl,
        event: e,
      });
    }

    // Open modal with merchant data
    if (debugModal) {
      // eslint-disable-next-line no-console
      console.log("[Merchant Modal] Calling modal.show()", {
        component: "MerchantBadgeModal",
        model: { merchant, sourceUrl },
      });
    }

    modal.show(MerchantBadgeModal, {
      model: { merchant, sourceUrl },
    });

    if (debugModal) {
      // eslint-disable-next-line no-console
      console.log("[Merchant Modal] modal.show() called successfully");
    }
  };

  // Leading: Verified badge (circular), placed before link text
  if (verifiedOn) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "merchant-badge merchant-badge--verified";
    const label = i18n(themePrefix("js.merchant.verified_badge"));
    btn.setAttribute("aria-label", label);

    // Icon only inside a circle
    const iconName = settings.verified_badge_icon || "far-check-circle";
    btn.innerHTML = iconHTML(iconName);
    const svg = btn.querySelector("svg");
    if (svg) {
      svg.setAttribute("aria-hidden", "true");
    }

    if (settings.show_badge_labels) {
      const span = document.createElement("span");
      span.className = "merchant-badge__label";
      span.textContent = label;
      btn.appendChild(span);
    }

    btn.addEventListener("click", clickHandler);
    result.leading = btn;
  }

  // Trailing: Coupons chip with icon + numeric counter
  if (couponsOn) {
    const container = document.createElement("span");
    container.className = "merchant-badges"; // trailing container

    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "merchant-badge merchant-badge--coupons";
    const label = i18n(themePrefix("js.merchant.coupons_badge"), { count: couponsCount });
    btn.setAttribute("aria-label", label);

    // Icon span
    const iconName = settings.coupons_badge_icon || "tags";
    const iconSpan = document.createElement("span");
    iconSpan.className = "merchant-badge__icon";
    iconSpan.innerHTML = iconHTML(iconName);
    const svg = iconSpan.querySelector("svg");
    if (svg) {
      svg.setAttribute("aria-hidden", "true");
    }
    btn.appendChild(iconSpan);

    // Numeric counter
    const countSpan = document.createElement("span");
    countSpan.className = "merchant-badge__count";
    countSpan.textContent = String(couponsCount);
    btn.appendChild(countSpan);

    // Optional visible label (after count) if enabled
    if (settings.show_badge_labels) {
      const span = document.createElement("span");
      span.className = "merchant-badge__label";
      span.textContent = label;
      btn.appendChild(span);
    }

    btn.addEventListener("click", clickHandler);
    container.appendChild(btn);
    result.trailing = container;
  }

  return result;
}

export default apiInitializer((api) => {
  // Clear merchant cache on page navigation (SPA pattern)
  api.onPageChange(() => {
    merchantCache.clear();
  });

  // Get modal service once for all decorations
  const modal = api.container.lookup("service:modal");

  api.decorateCookedElement(
    (element, helper) => {
      const post = helper?.getModel?.();
      if (!post) {
        return;
      }

      const debugBadges = settings.debug_logging_badges;
      const debugModal = settings.debug_logging_modal;

      if (debugBadges) {
        // eslint-disable-next-line no-console
        console.log("[Merchant Badges] Decorator running", {
          merchants: settings.merchants,
          merchantCount: settings.merchants?.length,
          applyToOneboxes: settings.apply_to_oneboxes,
          applyToTextLinks: settings.apply_to_text_links,
        });
      }

      const merchants = settings.merchants || [];
      if (merchants.length === 0) {
        if (debugBadges) {
          // eslint-disable-next-line no-console
          console.log("[Merchant Badges] No merchants configured");
        }
        return;
      }

      const showVerified = settings.show_verified_badge;
      const showCoupons = settings.show_coupons_badge;

      if (debugBadges) {
        // eslint-disable-next-line no-console
        console.log("[Merchant Badges] Flags:", { showVerified, showCoupons });
      }


      // Process onebox links
      if (settings.apply_to_oneboxes) {
        const oneboxes = element.querySelectorAll("aside.onebox");

        if (debugBadges) {
          // eslint-disable-next-line no-console
          console.log("[Merchant Badges] Found oneboxes:", oneboxes.length);
        }

        oneboxes.forEach((onebox) => {
          // Find the main link in onebox header/source
          const link =
            onebox.querySelector(".source a[href]") ||
            onebox.querySelector("header a[href]") ||
            onebox.querySelector("a.onebox[href]");

          if (debugBadges) {
            // eslint-disable-next-line no-console
            console.log("[Merchant Badges] Onebox link:", link?.href);
          }

          if (link && !link.hasAttribute(BADGE_MARKER)) {
            const merchant = findMerchant(link.href, merchants, debugBadges);

            if (debugBadges) {
              // eslint-disable-next-line no-console
              console.log("[Merchant Badges] Merchant match:", merchant);
            }

            if (merchant) {
              link.setAttribute(BADGE_MARKER, "true");

              // Build badges DOM (leading verified + trailing coupons)
              const badges = buildMerchantBadges(merchant, showVerified, showCoupons, modal, link.href, debugModal);
              if (badges) {
                if (badges.leading) {
                  link.insertBefore(badges.leading, link.firstChild);
                }
                if (badges.trailing) {
                  link.appendChild(badges.trailing);
                }

                if (debugBadges) {
                  // eslint-disable-next-line no-console
                  console.log("[Merchant Badges] Rendered badges for:", link.href);
                }
              }
            }
          }
        });
      }

      // Process plain text links
      if (settings.apply_to_text_links) {
        const links = element.querySelectorAll(
          "a[href^='http']:not(.mention):not(.hashtag):not(.badge-category)"
        );

        if (debugBadges) {
          // eslint-disable-next-line no-console
          console.log("[Merchant Badges] Found text links:", links.length);
        }

        links.forEach((link) => {
          // Skip if already processed or inside onebox
          if (
            link.hasAttribute(BADGE_MARKER) ||
            link.closest("aside.onebox")
          ) {
            return;
          }

          if (debugBadges) {
            // eslint-disable-next-line no-console
            console.log("[Merchant Badges] Text link:", link.href);
          }

          const merchant = findMerchant(link.href, merchants, debugBadges);

          if (debugBadges) {
            // eslint-disable-next-line no-console
            console.log("[Merchant Badges] Merchant match:", merchant);
          }

          if (merchant) {
            link.setAttribute(BADGE_MARKER, "true");

            // Build badges DOM (leading verified + trailing coupons)
            const badges = buildMerchantBadges(merchant, showVerified, showCoupons, modal, link.href, debugModal);
            if (badges) {
              if (badges.leading) {
                link.insertBefore(badges.leading, link.firstChild);
              }
              if (badges.trailing) {
                link.appendChild(badges.trailing);
              }

              if (debugBadges) {
                // eslint-disable-next-line no-console
                console.log("[Merchant Badges] Rendered badges for:", link.href);
              }
            }
          }
        });
      }
    },
    { id: "merchant-badges-decorator" }
  );
});
