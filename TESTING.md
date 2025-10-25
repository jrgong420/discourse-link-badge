# Phase 1 Testing Guide

## Setup

1. Install the theme component on your Discourse instance
2. Configure merchants in theme settings

## Sample Merchant Configuration

Add these merchants in the theme settings (Admin → Customize → Themes → Onebox Badge → Settings):

```yaml
merchants:
  - domain: "example.com"
    verified: true
    shop_review_topic_id: 0
    coupons:
      - code: "SAVE20"
        title: "20% off your first order"
        terms: "Valid for new customers only"
        expires_at: "2025-12-31"
      - code: "FREESHIP"
        title: "Free shipping"
        terms: "Orders over $50"
        expires_at: ""
  
  - domain: "shop.example.org"
    verified: false
    shop_review_topic_id: 0
    coupons:
      - code: "WELCOME10"
        title: "10% welcome discount"
        terms: ""
        expires_at: "2025-06-30"
  
  - domain: "verified-only.com"
    verified: true
    shop_review_topic_id: 0
    coupons: []
```

## Test Cases

### 1. Onebox Links

Create a post with these URLs (they should generate oneboxes):
- https://example.com
- https://www.example.com/products
- https://shop.example.org

**Expected:**
- Badges appear next to the onebox header link
- "Verified merchant" badge shows for example.com and verified-only.com
- "2 coupons available" shows for example.com
- "1 coupon available" shows for shop.example.org

### 2. Plain Text Links

Create a post with inline links:
```
Check out [this shop](https://example.com) for great deals!
Visit https://shop.example.org for more.
```

**Expected:**
- Badges appear after each link
- Same badge logic as oneboxes

### 3. Domain Matching

Test these variations:
- https://example.com
- https://www.example.com
- https://subdomain.example.com
- http://example.com (http vs https)

**Expected:**
- All should match and show badges

### 4. Toggle Settings

Test each toggle:
- `apply_to_oneboxes`: false → no badges on oneboxes
- `apply_to_text_links`: false → no badges on plain links
- `show_verified_badge`: false → verified badge hidden
- `show_coupons_badge`: false → coupon badge hidden

### 5. No Duplicates on Re-render

1. Create a post with merchant links
2. Edit the post
3. Navigate away and back to the topic

**Expected:**
- Badges appear only once per link
- No duplicate badges after edits/navigation

### 6. Badge Click (Phase 1 - Console Only)

1. Click any badge
2. Open browser console

**Expected:**
- Console log: "Badge clicked - modal will open in Phase 2" with merchant data
- No errors

### 7. Accessibility

1. Tab through the page
2. Focus should land on badges
3. Press Enter or Space on a focused badge

**Expected:**
- Visible focus outline on badges
- Keyboard activation works (console log appears)

### 8. Mobile View

Test on mobile or narrow viewport:

**Expected:**
- Badges don't break layout
- Badges remain readable and clickable

## Known Limitations (Phase 1)

- Modal does not open yet (Phase 2)
- Chat support not implemented yet (Phase 4)
- Clicking badge only logs to console

## Next Steps

After Phase 1 testing passes:
- Proceed to Phase 2: Modal skeleton
- Implement actual modal with DModal component

