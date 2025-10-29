import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import avatar from "discourse/helpers/avatar";
import dIcon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { formatDate } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

// Cache for topic rating data (keyed by topic_id)
// Structure: { ratingValue: number, ratingCount: number }
const ratingCache = new Map();

export default class MerchantBadgeModal extends Component {
  @service store;

  @tracked copiedCode = null;
  @tracked merchantUser = null;
  @tracked userLoading = false;
  @tracked ratingValue = null;
  @tracked ratingLoading = false;

  getCouponButtonLabel = (couponCode) => {
    if (this.copiedCode === couponCode) {
      return i18n(themePrefix("js.merchant.modal.copied"));
    }
    return i18n(themePrefix("js.merchant.modal.copy_code"));
  };

  constructor() {
    super(...arguments);
    this.loadUserProfile();
    // Ratings temporarily disabled; only show link to review thread
  }

  get merchant() {
    return this.args.model.merchant;
  }

  get sourceUrl() {
    return this.args.model.sourceUrl;
  }

  get hasCoupons() {
    return Array.isArray(this.merchant?.coupons) && this.merchant.coupons.length > 0;
  }

  get title() {
    return i18n(themePrefix("js.merchant.modal.title"), {
      domain: this.merchant.domain
    });
  }

  get displayName() {
    if (this.merchantUser?.username) {
      return this.merchantUser.username;
    }
    return this.merchant.title || this.merchant.domain;
  }

  get profileUrl() {
    if (this.merchantUser?.username) {
      return `/u/${this.merchantUser.username}`;
    }
    return null;
  }

  get friendlyLinkLabel() {
    try {
      const url = new URL(this.sourceUrl);
      const hostname = url.hostname.replace(/^www\./, "");
      return i18n(themePrefix("js.merchant.modal.visit_domain"), { domain: hostname });
    } catch {
      return this.sourceUrl;
    }
  }

  get sourceText() {
    // Use anchor text if available, otherwise fall back to friendly label
    return this.args.model?.anchorText || this.friendlyLinkLabel;
  }

  get followButtonLabel() {
    const customLabel = settings.modal_follow_link_label?.trim();
    if (customLabel) {
      return customLabel;
    }
    return i18n(themePrefix("js.merchant.modal.follow_link"));
  }

  get hasRating() {
    return this.ratingValue !== null && this.ratingValue > 0;
  }

  get ratingAriaLabel() {
    if (!this.hasRating) {
      return "";
    }
    return i18n(themePrefix("js.merchant.modal.rating_label"), {
      rating: this.ratingValue.toFixed(1),
    });
  }

  get hasShopReviewTopic() {
    const topicId = this.merchant?.shop_review_topic_id;
    return topicId && topicId > 0;
  }

  get shopReviewUrl() {
    if (!this.hasShopReviewTopic) {
      return null;
    }
    return `/t/${this.merchant.shop_review_topic_id}`;
  }

  get shopReviewLinkText() {
    if (!this.hasShopReviewTopic) {
      return "";
    }

    // If we have rating data, show count-based text
    if (this.hasRating) {
      // Get the topic to extract rating count
      const topicId = this.merchant.shop_review_topic_id;
      const cachedTopic = this.getCachedTopic(topicId);
      const count = cachedTopic?.ratingCount || 0;

      if (count > 0) {
        return i18n(themePrefix("js.merchant.modal.reviews_count"), {
          count,
        });
      }
    }

    // Fallback: just "Ratings"
    return i18n(themePrefix("js.merchant.modal.reviews_link"));
  }

  get fullStars() {
    if (!this.hasRating) {
      return [];
    }
    const count = Math.floor(this.ratingValue);
    return Array(count).fill(0);
  }

  get hasHalfStar() {
    if (!this.hasRating) {
      return false;
    }
    const decimal = this.ratingValue - Math.floor(this.ratingValue);
    return decimal >= 0.25 && decimal < 0.75;
  }

  get emptyStars() {
    if (!this.hasRating) {
      return [];
    }
    const filled = Math.floor(this.ratingValue) + (this.hasHalfStar ? 1 : 0);
    const count = Math.max(0, 5 - filled);
    return Array(count).fill(0);
  }

  async loadUserProfile() {
    const userId = this.merchant?.user_id;
    if (!userId || userId <= 0) {
      return;
    }

    this.userLoading = true;
    try {
      // Try to fetch user via store
      const user = await this.store.find("user", userId);
      this.merchantUser = user;
    } catch (error) {
      // Fallback: user not found or no permission, will display title/domain
      // eslint-disable-next-line no-console
      console.warn("[Merchant Modal] Could not load user profile:", error);
    } finally {
      this.userLoading = false;
    }
  }

  getCachedTopic(topicId) {
    return ratingCache.get(topicId);
  }

  async loadRating() {
    const topicId = this.merchant?.shop_review_topic_id;
    if (!topicId || topicId <= 0) {
      return;
    }

    // Check cache first
    if (ratingCache.has(topicId)) {
      const cached = ratingCache.get(topicId);
      this.ratingValue = cached.ratingValue;
      return;
    }

    this.ratingLoading = true;
    try {
      const topic = await ajax(`/t/${topicId}.json`);
      const ratingData = this.calculateAverageRating(topic);
      this.ratingValue = ratingData.ratingValue;
      ratingCache.set(topicId, ratingData);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("[Merchant Modal] Could not load rating:", error);
      this.ratingValue = null;
    } finally {
      this.ratingLoading = false;
    }
  }

  calculateAverageRating(topic) {
    // Topic Ratings plugin stores rating data in custom_fields
    const customFields = topic?.custom_fields;
    if (!customFields) {
      return { ratingValue: null, ratingCount: 0 };
    }

    // Try to find rating aspects (plugin may serialize as JSON or individual fields)
    let aspects = [];

    // Check for serialized rating data
    if (customFields.rating_aspects) {
      try {
        const parsed =
          typeof customFields.rating_aspects === "string"
            ? JSON.parse(customFields.rating_aspects)
            : customFields.rating_aspects;

        if (Array.isArray(parsed)) {
          aspects = parsed.filter((v) => typeof v === "number" && v > 0);
        } else if (typeof parsed === "object") {
          aspects = Object.values(parsed).filter(
            (v) => typeof v === "number" && v > 0
          );
        }
      } catch {
        // Ignore parse errors
      }
    }

    // Fallback: look for individual rating_* fields
    if (aspects.length === 0) {
      aspects = Object.entries(customFields)
        .filter(
          ([key, value]) =>
            key.startsWith("rating_") &&
            typeof value === "number" &&
            value > 0
        )
        .map(([, value]) => value);
    }

    if (aspects.length === 0) {
      return { ratingValue: null, ratingCount: 0 };
    }

    const sum = aspects.reduce((acc, val) => acc + val, 0);
    const ratingValue = sum / aspects.length;

    // Get rating count from topic (number of posts/ratings)
    const ratingCount = topic.posts_count || aspects.length;

    return { ratingValue, ratingCount };
  }

  formatExpiryDate(dateString) {
    if (!dateString) {
      return null;
    }

    try {
      const date = new Date(dateString);
      if (isNaN(date.getTime())) {
        return dateString; // Invalid date, return as-is
      }

      return formatDate(date, { format: "medium" });
    } catch {
      return dateString; // Fallback to original string
    }
  }



  @action
  async copyCouponCode(code) {
    if (!navigator.clipboard) {
      return;
    }

    try {
      await navigator.clipboard.writeText(code);
      this.copiedCode = code;

      // Reset after 2 seconds
      setTimeout(() => {
        this.copiedCode = null;
      }, 2000);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("Failed to copy coupon code:", err);
    }
  }

  @action
  openLink() {
    if (this.sourceUrl) {
      window.open(this.sourceUrl, "_blank", "noopener,noreferrer");
    }
  }

  <template>
    <DModal @title={{this.title}} @closeModal={{@closeModal}}>
      <:body>
        <div class="merchant-modal">
          {{! Header: User Profile or Domain with Rating }}
          <div class="merchant-modal__header">
            <div class="merchant-modal__title-section">
              {{#if this.merchantUser}}
                <div class="merchant-modal__user">
                  <a href={{this.profileUrl}} class="merchant-modal__user-link" target="_blank" rel="noopener noreferrer">
                    {{avatar this.merchantUser imageSize="medium"}}
                    <span class="merchant-modal__username">
                      {{this.merchantUser.username}}
                    </span>
                  </a>
                  {{#if this.merchant.verified}}
                    <span
                      class="merchant-modal__verified-container"
                      title={{i18n (themePrefix "js.merchant.modal.verified")}}
                      aria-label={{i18n (themePrefix "js.merchant.modal.verified")}}
                    >
                      <span class="merchant-modal__verified-icon">{{dIcon "circle-check"}}</span>
                      <span class="merchant-modal__verified-label">{{i18n (themePrefix "js.merchant.modal.verified")}}</span>
                    </span>
                  {{/if}}
                </div>
              {{else}}
                <div class="merchant-modal__domain-wrapper">
                  <h3 class="merchant-modal__domain">{{this.displayName}}</h3>
                  {{#if this.merchant.verified}}
                    <span
                      class="merchant-modal__verified-container"
                      title={{i18n (themePrefix "js.merchant.modal.verified")}}
                      aria-label={{i18n (themePrefix "js.merchant.modal.verified")}}
                    >
                      <span class="merchant-modal__verified-icon">{{dIcon "circle-check"}}</span>
                      <span class="merchant-modal__verified-label">{{i18n (themePrefix "js.merchant.modal.verified")}}</span>
                    </span>
                  {{/if}}
                </div>
              {{/if}}

              {{#if this.hasShopReviewTopic}}
                <div class="merchant-modal__rating">
                  <a href={{this.shopReviewUrl}} class="merchant-modal__review-link" target="_blank" rel="noopener noreferrer">
                    {{i18n (themePrefix "js.merchant.modal.display_reviews")}}
                  </a>
                </div>
              {{/if}}
            </div>
          </div>

          {{! Coupons Section }}
          {{#if this.hasCoupons}}
            <div class="merchant-modal__section">
              <h4 class="merchant-modal__section-title">
                {{i18n (themePrefix "js.merchant.modal.coupons_heading")}}
              </h4>

              <div class="merchant-modal__coupons">
                {{#each this.merchant.coupons as |coupon|}}
                  <div class="merchant-modal__coupon">
                    <div class="merchant-modal__coupon-header">
                      <div class="merchant-modal__coupon-code-wrapper">
                        <code class="merchant-modal__coupon-code">{{coupon.code}}</code>

                        <DButton
                          @action={{this.copyCouponCode}}
                          @actionParam={{coupon.code}}
                          @icon="copy"
                          class="btn-small merchant-modal__copy-btn"
                          @translatedLabel={{this.getCouponButtonLabel coupon.code}}
                        />
                      </div>

                      {{#if coupon.title}}
                        <div class="merchant-modal__coupon-title">{{coupon.title}}</div>
                      {{/if}}
                    </div>

                    {{#if coupon.terms}}
                      <div class="merchant-modal__coupon-terms">
                        {{i18n (themePrefix "js.merchant.modal.coupon.terms")}}: {{coupon.terms}}
                      </div>
                    {{/if}}

                    {{#if coupon.expires_at}}
                      <div class="merchant-modal__coupon-expires">
                        {{i18n (themePrefix "js.merchant.modal.coupon.expires")}}: {{this.formatExpiryDate coupon.expires_at}}
                      </div>
                    {{/if}}
                  </div>
                {{/each}}
              </div>
            </div>
          {{else}}
            <div class="merchant-modal__section">
              <p class="merchant-modal__no-coupons">
                {{i18n (themePrefix "js.merchant.modal.no_coupons")}}
              </p>
            </div>
          {{/if}}

          {{! Footer: Source Link and Follow Button }}
          {{#if this.sourceUrl}}
            <div class="merchant-modal__footer">
              <div class="merchant-modal__source">
                {{this.sourceText}}
              </div>

              <DButton
                @action={{this.openLink}}
                @translatedLabel={{this.followButtonLabel}}
                @icon="external-link-alt"
                class="btn-primary merchant-modal__follow-btn"
              />
            </div>
          {{/if}}
        </div>
      </:body>
    </DModal>
  </template>
}

