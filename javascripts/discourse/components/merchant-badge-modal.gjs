import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class MerchantBadgeModal extends Component {
  @tracked copiedCode = null;

  getCouponButtonLabel = (couponCode) => {
    if (this.copiedCode === couponCode) {
      return i18n(themePrefix("js.merchant.modal.copied"));
    }
    return i18n(themePrefix("js.merchant.modal.copy_code"));
  };

get merchant() {
    return this.args.model.merchant;
  }

  get sourceUrl() {
    return this.args.model.sourceUrl;
  }

  get hasCoupons() {
    return Array.isArray(this.merchant?.coupons) && this.merchant.coupons.length > 0;
  }

  get hasShopReview() {
    return this.merchant?.shop_review_topic_id > 0;
  }

  get shopReviewUrl() {
    return `/t/${this.merchant.shop_review_topic_id}`;
  }

  get title() {
    return i18n(themePrefix("js.merchant.modal.title"), {
      domain: this.merchant.domain
    });
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

  <template>
    <DModal @title={{this.title}} @closeModal={{@closeModal}}>
      <:body>
        <div class="merchant-modal">
          {{! Header: Domain and Verified Status }}
          <div class="merchant-modal__header">
            <h3 class="merchant-modal__domain">{{this.merchant.domain}}</h3>

            {{#if this.merchant.verified}}
              <span class="merchant-modal__verified-badge merchant-modal__verified-badge--verified">
                <span class="merchant-modal__icon">{{dIcon "far-check-circle"}}</span>
                <span>{{i18n (themePrefix "js.merchant.modal.verified")}}</span>
              </span>
            {{else}}
              <span class="merchant-modal__verified-badge merchant-modal__verified-badge--unverified">
                <span>{{i18n (themePrefix "js.merchant.modal.unverified")}}</span>
              </span>
            {{/if}}
          </div>

          {{! Source URL }}
          {{#if this.sourceUrl}}
            <div class="merchant-modal__source">
              <a href={{this.sourceUrl}} target="_blank" rel="noopener noreferrer" class="merchant-modal__source-link">
                {{this.sourceUrl}}
              </a>
            </div>
          {{/if}}

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
                        {{i18n (themePrefix "js.merchant.modal.coupon.expires")}}: {{coupon.expires_at}}
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

          {{! Shop Review Link }}
          {{#if this.hasShopReview}}
            <div class="merchant-modal__section">
              <a href={{this.shopReviewUrl}} class="merchant-modal__shop-review-link">
                {{dIcon "far-comment"}}
                <span>{{i18n (themePrefix "js.merchant.modal.shop_review")}}</span>
              </a>
            </div>
          {{/if}}
        </div>
      </:body>
    </DModal>
  </template>
}

