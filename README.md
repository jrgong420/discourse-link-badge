# Discourse Link Badge

A Discourse theme component that adds customizable merchant badges to links in posts, oneboxes, and optionally chat messages. Display verified merchant status and available coupons with interactive modals.

## Features

- **Verified Merchant Badges**: Show a checkmark icon for trusted merchants
- **Coupon Badges**: Display available coupon count with an interactive modal
- **Flexible Placement**: Works on plain text links and onebox previews
- **Interactive Modals**: Click badges to view merchant details, copy coupon codes, and access shop reviews
- **Fully Customizable**: Configure merchants, icons, display options, and styling via theme settings
- **Accessible**: ARIA labels, keyboard navigation, and semantic HTML

## Installation

1. Go to **Admin** → **Customize** → **Themes** in your Discourse instance
2. Click **Install** → **From a git repository**
3. Enter the repository URL: `https://github.com/jrgong420/discourse-link-badge`
4. Click **Install**
5. Enable the theme component on your active theme

## Configuration

### Adding Merchants

Navigate to **Admin** → **Customize** → **Themes** → **Discourse Link Badge** → **Settings**

Configure merchants using the `merchants` setting (structured objects):

```yaml
domain: example.com
verified: true
user_id: 42                    # Optional: Discourse user ID for avatar/username display
title: "Example Shop"          # Optional: Fallback display name when no user_id
shop_review_topic_id: 123      # Optional: Topic ID for shop reviews (legacy)
shop_rating_topic_id: 456      # Optional: Topic ID for star rating calculation (Topic Ratings plugin)
coupons:
  - code: SAVE20
    title: 20% Off Sitewide
    terms: Minimum purchase $50
    expires_at: 2025-12-31
  - code: FREESHIP
    title: Free Shipping
    terms: Orders over $25
    expires_at: 2025-06-30
```

**New Fields:**
- `user_id` (integer, default: 0): Associate merchant with a Discourse user. When set, the modal displays the user's avatar and username (linked to their profile). If 0 or user not found, falls back to `title` or `domain`.
- `title` (string, default: ""): Fallback display name when `user_id` is not set or user lookup fails.
- `shop_rating_topic_id` (integer, default: 0): Topic ID where shop ratings are collected via the Topic Ratings plugin. The modal fetches this topic, calculates the average rating from all rating aspects, and displays it as stars next to the merchant name.

**Fields:**
- `domain` (required): Merchant domain (e.g., `example.com`, matches `www.example.com` and subdomains)
- `verified` (boolean): Show verified badge
- `shop_review_topic_id` (integer): Link to a Discourse topic with shop reviews
- `coupons` (array): List of coupon objects with `code`, `title`, `terms`, `expires_at`

### Display Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `apply_to_oneboxes` | boolean | `true` | Show badges on onebox previews |
| `apply_to_text_links` | boolean | `true` | Show badges on plain text links |
| `apply_to_chat` | boolean | `false` | Show badges in chat messages (experimental) |
| `show_verified_badge` | boolean | `true` | Display verified merchant icon |
| `show_coupons_badge` | boolean | `true` | Display coupon count badge |
| `show_badge_labels` | boolean | `true` | Show text labels next to icons |
| `hide_click_counter` | boolean | `false` | Hide Discourse's default click counter on badged links |

### Icon Customization

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `verified_badge_icon` | string | `far-check-circle` | FontAwesome icon for verified badge |
| `coupons_badge_icon` | string | `tags` | FontAwesome icon for coupons badge |

### Modal Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `modal_follow_link_label` | string | `""` | Custom label for the modal's primary "Follow Link" button (leave empty to use default translation) |

### Debug Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `debug_logging_badges` | boolean | `false` | Log badge decoration process to console |
| `debug_logging_modal` | boolean | `false` | Log modal interactions to console |

## Usage

Once configured, the theme automatically decorates matching merchant links:

### Plain Text Links
```markdown
Check out https://example.com for great deals!
```
Renders with verified badge and coupon count (if configured).

### Oneboxes
Paste a merchant URL on its own line to create an onebox preview with badges in the header.

### Interactive Modal
Click any badge to open a modal showing:
- Merchant profile (user avatar/username or title) and verification status
- Star rating (if configured via Topic Ratings plugin)
- Source URL with friendly link text
- Available coupons with copy-to-clipboard buttons and localized expiration dates
- Primary "Follow Link" button to open merchant URL in new tab

## Styling

The theme uses Discourse's CSS custom properties for seamless integration with any color scheme:

- Badges use `--tertiary`, `--success`, `--primary-low` colors
- Responsive design with mobile-optimized layouts
- Smooth hover animations and transitions

### Style Selection

Choose from four distinct visual styles via the `merchant_link_style` setting:

#### Pill (Default)
- Rounded badge with subtle shadow
- Elevated appearance with hover lift effect
- Best for prominent merchant highlighting
- Mobile-optimized with inline wrapping

#### Underline
- Minimal text-first approach
- Subtle underline with verified icon
- Transparent background
- Perfect for content-focused layouts

#### Label
- Soft filled label with small border radius
- Subtle background color (`--primary-very-low`)
- Clean, modern appearance
- Balanced between pill and ghost styles

#### Ghost
- Outline-only design with transparent background
- Minimal visual weight
- Hover reveals soft fill
- Ideal for ultra-clean, minimalist themes

All styles use Discourse core CSS variables for colors, spacing, and borders, ensuring compatibility with any color scheme.

### Custom CSS

To further customize styling, add CSS to your theme's `common/common.scss`:

```scss
// Example: Change verified badge color
.merchant-badge--verified {
  background-color: var(--love) !important;
}

// Example: Adjust badge spacing
a[data-merchant-badges-added="true"] {
  gap: var(--space-3) !important;
}
```

## Development

### Prerequisites
- Ruby ≥ 2.7
- Node.js ≥ 22
- pnpm (via Corepack)
- Discourse Theme CLI: `gem install discourse_theme`

### Setup
```bash
git clone https://github.com/jrgong420/discourse-link-badge.git
cd discourse-link-badge
pnpm install
discourse_theme watch .
```

### Testing
```bash
pnpm run lint        # Lint JavaScript and SCSS
pnpm run lint:fix    # Auto-fix linting issues
```

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile browsers (iOS Safari, Chrome Mobile)
- Requires JavaScript enabled
- Clipboard API for coupon copy functionality

## License

MIT License - see [LICENSE](LICENSE) file for details

## Support

- **Issues**: [GitHub Issues](https://github.com/jrgong420/discourse-link-badge/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jrgong420/discourse-link-badge/discussions)

## Changelog

### 1.0.0 (2025-10-26)
- Initial release
- Merchant badge decoration for text links and oneboxes
- Interactive modal with coupon management
- Verified merchant status display
- Configurable icons and display options
- Accessibility features (ARIA labels, keyboard navigation)
- Mobile-responsive design

## Credits

Developed by [jrgong](https://github.com/jrgong420)
