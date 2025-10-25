import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";

export default class MerchantBadges extends Component {
  constructor() {
    super(...arguments);
    // eslint-disable-next-line no-console
    console.log("[Merchant Badges] Component args:", {
      showVerifiedArg: this.args?.showVerified,
      showCouponsArg: this.args?.showCoupons,
      merchantVerified: this.args?.merchant?.verified,
      couponCount: this.args?.merchant?.coupons?.length || 0,
    });
  }

  openModal = (event) => {
    event.preventDefault();
    event.stopPropagation();

    // TODO: Phase 2 - open modal with merchant data
    // eslint-disable-next-line no-console
    console.log("Badge clicked - modal will open in Phase 2", this.merchant);
  };

  get merchant() {
    return this.args.merchant;
  }

  get showVerified() {
    return this.args.showVerified && this.merchant?.verified;
  }

  get showCoupons() {
    return (
      this.args.showCoupons &&
      this.merchant?.coupons &&
      this.merchant.coupons.length > 0
    );
  }

  get couponCount() {
    return this.merchant?.coupons?.length || 0;
  }

  <template>
    <span class="merchant-badges">
      {{#if this.showVerified}}
        <button
          type="button"
          class="merchant-badge merchant-badge--verified"
          aria-label={{i18n (themePrefix "merchant.verified_badge")}}
          {{on "click" this.openModal}}
        >
          {{i18n (themePrefix "merchant.verified_badge")}}
        </button>
      {{/if}}
      {{#if this.showCoupons}}
        <button
          type="button"
          class="merchant-badge merchant-badge--coupons"
          aria-label={{i18n
            (themePrefix "merchant.coupons_badge")
            count=this.couponCount
          }}
          {{on "click" this.openModal}}
        >
          {{i18n (themePrefix "merchant.coupons_badge") count=this.couponCount}}
        </button>
      {{/if}}
    </span>
  </template>
}

