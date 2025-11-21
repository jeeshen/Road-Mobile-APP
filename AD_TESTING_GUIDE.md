# Ad System Testing Guide

## Quick Test Steps

### 1. Create a Test Ad

1. Open the app
2. Navigate to **Shop** screen (bottom tab)
3. Scroll down to "Premium & Ads" section
4. Tap **"Merchant Ads"**
5. Tap **"+ Create Ad"** button (top right)
6. Fill in the ad details:
   - **Ad Type:** Select "📱 Banner" for easiest testing
   - **Title:** e.g., "Test Coffee Shop"
   - **Content:** e.g., "Best coffee in town! Visit us today."
   - **Ad Location:** Tap to open map, then tap on your current location or nearby
   - **Trigger Radius:** Select **10.0 km** (largest radius for easier testing)
   - **Coverage Area:** Optional - select a district or leave as "None"
   - **Duration:** Select **7 days**
   - **Budget:** Enter **10.00** (provides ~100 impressions at $0.10 each)
7. Tap **"Create"** button (top right)

**Expected Result:** Ad is created successfully, you'll see it in your ads list.

### 2. Verify Ad in Navigation

1. Ensure you have **sufficient wallet balance** (use "+ Add Funds" if needed)
2. Make sure you're **not a premium user** (premium users don't see ads)
3. Go to **Home** screen (map view)
4. Select any destination and tap **"Start Navigation"**
5. Wait 5-10 seconds after navigation starts

**Expected Result:** 
- Console logs show: "NavigationScreen: Checking for ads at (...)"
- Console logs show: "AdService: Found X ads with status=active"
- If your location is within 10km of the ad location:
  - Console logs show: "NavigationScreen: Showing banner ad: Test Coffee Shop"
  - A banner appears at the top of the screen
  - Banner auto-hides after 8 seconds

### 3. Check Console Logs

Look for these key log messages to debug issues:

**When navigation starts:**
```
NavigationScreen: User is not premium, will check for ads
NavigationScreen: Checking for ads at (LAT, LNG)
```

**When ads are retrieved:**
```
AdService: Getting nearby ads for location (LAT, LNG)
AdService: Found X ads with status=active
AdService: Processing ad ID: TITLE at (LAT, LNG)
AdService: Ad ID distance: X.XXkm, radius: X.Xkm, within range: true/false
AdService: Returning X nearby ads
```

**When ads are shown:**
```
NavigationScreen: Found X nearby ads
NavigationScreen: Showing banner ad: TITLE
```

**If no ads show:**
```
NavigationScreen: Cannot check ads - position: true/false, premium: true/false
NavigationScreen: No banner ad to show (bannerAd: null, already shown: N/A)
AdService: Ad ID is not active (status: ..., spent: X/Y, date range: ...)
AdService: Ad ID distance: X.XXkm, radius: Y.Ykm, within range: false
```

## Common Issues & Solutions

### Issue: "Ad created but doesn't show"

**Possible Causes:**
1. **User is premium:** Premium users don't see ads
   - Solution: Use a non-premium account for testing
   
2. **User is too far from ad:** Distance > radius
   - Solution: Create ad with larger radius (10 km) or create ad at your exact location
   - Check logs for: "distance: X.XXkm, radius: Y.Ykm, within range: false"
   
3. **Ad is out of budget:** Spent >= Budget
   - Solution: Add more budget to the ad or create a new ad
   - Check logs for: "status: outOfBudget"
   
4. **Ad date range expired:**
   - Solution: Create a new ad with future dates
   - Check logs for date range
   
5. **GPS position not acquired yet:**
   - Solution: Wait a few seconds for GPS to lock
   - Check logs for: "Cannot check ads - position: false"

### Issue: "No ads in console logs"

**Possible Causes:**
1. **No ads created yet:** Create at least one ad
2. **All ads are paused:** Check ad status in Merchant Ads screen
3. **Firebase connection issue:** Check internet connection

### Issue: "Districts not loading"

**Possible Causes:**
1. **First time setup:** Districts need to be initialized
   - Solution: Wait a few seconds, they'll be auto-created
2. **Firebase connection issue:** Check internet connection
3. **Firestore rules:** Ensure read access to 'districts' collection

## Testing Checklist

- [ ] Can access Merchant Ads screen
- [ ] Can add funds to wallet
- [ ] Can create ad with location selection
- [ ] Can select district from grouped list
- [ ] Can clear district selection
- [ ] Ad appears in "My Ads" list after creation
- [ ] Ad shows correct status (Active)
- [ ] Can enter navigation mode
- [ ] Console shows ad retrieval logs
- [ ] Banner ad appears at top of navigation screen
- [ ] Banner ad auto-hides after 8 seconds
- [ ] Can dismiss banner ad manually
- [ ] Ad impressions are recorded (check ad stats)
- [ ] Wallet balance decreases as impressions are recorded

## Debug Mode (Advanced)

For debugging, you can temporarily modify the code:

### Show All Ads Regardless of Location

In `lib/services/ad_service.dart`, line ~40, change:
```dart
return isWithinRange;
```
to:
```dart
return true; // DEBUG: Show all ads regardless of distance
```

### Skip Premium Check

In `lib/screens/navigation_screen.dart`, line ~270, change:
```dart
final isPremium = await _premiumService.isPremiumUser(userId);
```
to:
```dart
final isPremium = false; // DEBUG: Force non-premium for testing
```

**Remember to revert these changes after testing!**

## Ad Analytics

To view ad performance:
1. Go to **Shop → Merchant Ads**
2. Each ad card shows:
   - 👁️ **Impressions:** How many times the ad was shown
   - 👆 **Clicks:** How many times the ad was clicked
   - 📊 **CTR:** Click-through rate (clicks/impressions)
   - **Budget:** Amount spent vs. total budget

## Support

If ads still don't show after following this guide:
1. Check all console logs for error messages
2. Verify ad status is "Active" (not Paused/Out of Budget)
3. Ensure user is not premium
4. Verify GPS is working and location is within ad radius
5. Try creating a new ad with very large radius (10 km) at your current location
6. Restart the app and try again

## Test Scenarios

### Scenario 1: Local Business Ad
- **Location:** Your current GPS position
- **Radius:** 0.5 km (500m)
- **District:** Your current district
- **Result:** Ad should show immediately when you start navigation

### Scenario 2: Wide Coverage Ad
- **Location:** City center
- **Radius:** 10 km
- **District:** None (location-based only)
- **Result:** Ad shows to anyone within 10km of city center

### Scenario 3: District-Targeted Ad
- **Location:** Anywhere in Kuala Lumpur
- **Radius:** 5 km
- **District:** KLCC
- **Result:** Ad shows to users in KLCC area within 5km of the location

## Performance Notes

- Ads are checked every 10 seconds during navigation
- Same ad won't show twice in one session (tracked in memory)
- Banner ads show for 8 seconds then auto-hide
- Voice ads play once when triggered
- Impressions cost $0.10, clicks cost $0.50
- Ads stop showing when budget is exhausted



