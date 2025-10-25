# Debugging Guide - Merchant Badges Not Showing

## Quick Checks

### 1. Open Browser Console
Open your browser's developer console (F12 or Cmd+Option+I) and look for these log messages:

```
[Merchant Badges] Decorator running { merchants: [...], merchantCount: 1, ... }
[Merchant Badges] Found oneboxes: X
[Merchant Badges] Onebox link: https://...
[Merchant Badges] Merchant match: { domain: "...", ... }
[Merchant Badges] Rendering badges for: https://...
```

### 2. What the Logs Tell You

**If you see:**
- `[Merchant Badges] No merchants configured` → Settings not loading correctly
- `merchantCount: 0` → Theme settings not being read
- `Found oneboxes: 0` → No oneboxes detected in the post
- `Merchant match: null` → Domain matching failed

**If you don't see any logs:**
- Decorator not running at all
- Theme component not active
- JavaScript error preventing execution

### 3. Check Theme Component Status

1. Go to Admin → Customize → Themes
2. Find "Onebox Badge" component
3. Verify it's enabled/active
4. Check if it's added to your current theme

### 4. Verify Settings Are Saved

In Admin → Customize → Themes → Onebox Badge → Settings:
- Click "Edit" on the merchants setting
- Verify your merchant config is there
- Click "Save" again to ensure it's persisted

### 5. Test with a Simple Post

Create a new topic with just:
```
https://sensiseeds.com
```

This should create an onebox. Check console logs.

### 6. Check for JavaScript Errors

Look for any red errors in the console that might prevent the theme from loading.

## Common Issues

### Issue: Settings not loading (merchantCount: 0)

**Cause:** Theme settings object not available

**Fix:** The `settings` object should be globally available in theme components. If it's not, we may need to import it differently.

**Test:** In browser console, type:
```javascript
settings
```
You should see an object with your theme settings.

### Issue: No oneboxes found

**Cause:** Link didn't generate an onebox, or onebox HTML structure is different

**Fix:** 
1. Paste the full URL on its own line (not in markdown)
2. Wait for onebox to load
3. Inspect the HTML to see the actual structure

**Test:** In browser console:
```javascript
document.querySelectorAll('aside.onebox')
```

### Issue: Domain not matching

**Cause:** Domain normalization issue

**Test:** In browser console:
```javascript
// Check what domain is being extracted
new URL('https://sensiseeds.com').hostname
// Should return: "sensiseeds.com"

// Check if it matches your config
'sensiseeds.com'.replace(/^www\./, '')
// Should return: "sensiseeds.com"
```

### Issue: helper.renderGlimmer not working

**Cause:** API signature changed or not available

**Test:** Check if there are errors about `renderGlimmer` in console

## Next Steps

1. **Share console logs** - Copy all `[Merchant Badges]` logs from console
2. **Share HTML structure** - Right-click the onebox → Inspect, copy the HTML
3. **Check settings object** - In console, type `settings` and share the output
4. **Check for errors** - Share any red error messages from console

## Temporary Test Code

Add this to browser console to test if settings are accessible:

```javascript
console.log('Theme settings:', settings);
console.log('Merchants:', settings.merchants);
console.log('Apply to oneboxes:', settings.apply_to_oneboxes);
```

If `settings` is undefined, that's the root cause.

