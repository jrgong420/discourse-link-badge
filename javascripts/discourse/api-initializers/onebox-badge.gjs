import { apiInitializer } from "discourse/lib/api";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import MerchantBadgeModal from "../components/merchant-badge-modal";

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
            const merchant = findMerchant(link.href, merchants);

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

          const merchant = findMerchant(link.href, merchants);

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
