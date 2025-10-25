import { apiInitializer } from "discourse/lib/api";
import { iconHTML } from "discourse-common/lib/icon-library";
import { i18n } from "discourse-i18n";

const BADGE_MARKER = "data-merchant-badges-added";

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
 * Find merchant config by domain
 * @param {string} url - Link URL
 * @param {Array} merchants - Merchant configs from settings
 * @returns {Object|null} - Matched merchant or null
 */
function findMerchant(url, merchants) {
  if (!url || !merchants || merchants.length === 0) {
    return null;
  }

  const domain = normalizeDomain(url);

  return merchants.find((merchant) => {
    const merchantDomain = normalizeDomain(merchant.domain);
    return domain === merchantDomain || domain.endsWith(`.${merchantDomain}`);
  });
}

function buildMerchantBadges(merchant, showVerified, showCoupons) {
  const verifiedOn = !!showVerified && !!merchant?.verified;
  const couponsCount = Array.isArray(merchant?.coupons) ? merchant.coupons.length : 0;
  const couponsOn = !!showCoupons && couponsCount > 0;

  if (!verifiedOn && !couponsOn) {
    return null;
  }

  const container = document.createElement("span");
  container.className = "merchant-badges";

  const clickHandler = (e) => {
    e.preventDefault();
    e.stopPropagation();
    // TODO: Phase 2 - open modal with merchant data
    // eslint-disable-next-line no-console
    console.log("[Merchant Badges] Clicked badge", {
      verifiedOn,
      couponsCount,
      merchantDomain: merchant?.domain,
    });
  };

  if (verifiedOn) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "merchant-badge merchant-badge--verified";
    const label = i18n(themePrefix("js.merchant.verified_badge"));
    btn.setAttribute("aria-label", label);

    // Inject icon
    const iconName = settings.verified_badge_icon || "far-check-circle";
    btn.innerHTML = iconHTML(iconName);
    const svg = btn.querySelector("svg");
    if (svg) {
      svg.setAttribute("aria-hidden", "true");
    }

    // Conditionally add text label
    if (settings.show_badge_labels) {
      const span = document.createElement("span");
      span.className = "merchant-badge__label";
      span.textContent = label;
      btn.appendChild(span);
    } else {
      btn.classList.add("merchant-badge--icon-only");
    }

    btn.addEventListener("click", clickHandler);
    container.appendChild(btn);
  }

  if (couponsOn) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "merchant-badge merchant-badge--coupons";
    const label = i18n(themePrefix("js.merchant.coupons_badge"), { count: couponsCount });
    btn.setAttribute("aria-label", label);

    // Inject icon
    const iconName = settings.coupons_badge_icon || "tags";
    btn.innerHTML = iconHTML(iconName);
    const svg = btn.querySelector("svg");
    if (svg) {
      svg.setAttribute("aria-hidden", "true");
    }

    // Conditionally add text label
    if (settings.show_badge_labels) {
      const span = document.createElement("span");
      span.className = "merchant-badge__label";
      span.textContent = label;
      btn.appendChild(span);
    } else {
      btn.classList.add("merchant-badge--icon-only");
    }

    btn.addEventListener("click", clickHandler);
    container.appendChild(btn);
  }

  return container;
}

export default apiInitializer((api) => {
  api.decorateCookedElement(
    (element, helper) => {
      const post = helper?.getModel?.();
      if (!post) {
        return;
      }

      // eslint-disable-next-line no-console
      console.log("[Merchant Badges] Decorator running", {
        merchants: settings.merchants,
        merchantCount: settings.merchants?.length,
        applyToOneboxes: settings.apply_to_oneboxes,
        applyToTextLinks: settings.apply_to_text_links,
      });

      const merchants = settings.merchants || [];
      if (merchants.length === 0) {
        // eslint-disable-next-line no-console
        console.log("[Merchant Badges] No merchants configured");
        return;
      }

      const showVerified = settings.show_verified_badge;
      const showCoupons = settings.show_coupons_badge;
      // eslint-disable-next-line no-console
      console.log("[Merchant Badges] Flags:", { showVerified, showCoupons });


      // Process onebox links
      if (settings.apply_to_oneboxes) {
        const oneboxes = element.querySelectorAll("aside.onebox");
        // eslint-disable-next-line no-console
        console.log("[Merchant Badges] Found oneboxes:", oneboxes.length);

        oneboxes.forEach((onebox) => {
          // Find the main link in onebox header/source
          const link =
            onebox.querySelector(".source a[href]") ||
            onebox.querySelector("header a[href]") ||
            onebox.querySelector("a.onebox[href]");

          // eslint-disable-next-line no-console
          console.log("[Merchant Badges] Onebox link:", link?.href);

          if (link && !link.hasAttribute(BADGE_MARKER)) {
            const merchant = findMerchant(link.href, merchants);
            // eslint-disable-next-line no-console
            console.log("[Merchant Badges] Merchant match:", merchant);

            if (merchant) {
              link.setAttribute(BADGE_MARKER, "true");

              // Build badges DOM
              const badges = buildMerchantBadges(merchant, showVerified, showCoupons);
              if (badges) {
                // Insert badges inside the link at the end
                link.appendChild(badges);
                // eslint-disable-next-line no-console
                console.log("[Merchant Badges] Rendered badges for:", link.href);
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

        // eslint-disable-next-line no-console
        console.log("[Merchant Badges] Found text links:", links.length);

        links.forEach((link) => {
          // Skip if already processed or inside onebox
          if (
            link.hasAttribute(BADGE_MARKER) ||
            link.closest("aside.onebox")
          ) {
            return;
          }

          // eslint-disable-next-line no-console
          console.log("[Merchant Badges] Text link:", link.href);

          const merchant = findMerchant(link.href, merchants);
          // eslint-disable-next-line no-console
          console.log("[Merchant Badges] Merchant match:", merchant);

          if (merchant) {
            link.setAttribute(BADGE_MARKER, "true");

            // Build badges DOM
            const badges = buildMerchantBadges(merchant, showVerified, showCoupons);
            if (badges) {
              // Insert badges inside the link at the end
              link.appendChild(badges);
              // eslint-disable-next-line no-console
              console.log("[Merchant Badges] Rendered badges for:", link.href);
            }
          }
        });
      }
    },
    { id: "merchant-badges-decorator" }
  );
});
