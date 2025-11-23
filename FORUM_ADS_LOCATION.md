# Forum Ads - Where They Are

## Location in App

Forum ads appear in **district forums** at the **top of the post list**.

### Navigation Path:
```
Home Screen → Tap District Marker → Forum Screen
(or)
Home Screen → Menu → Select District → Forum Screen
```

### Visual Layout:
```
┌─────────────────────────────┐
│  Forum: Bangsar            │ ← Navigation Bar
├─────────────────────────────┤
│                             │
│  🎯 [SPONSORED AD #1]      │ ← Forum Ads (max 2)
│     Title                   │
│     Description             │
│     [Tap to View]           │
│                             │
│  🎯 [SPONSORED AD #2]      │
│     Title                   │
│     Description             │
│     [Tap to View]           │
│                             │
├─────────────────────────────┤
│                             │
│  📌 [Pinned Post]          │ ← Sponsored Posts
│     (if any)                │
│                             │
├─────────────────────────────┤
│                             │
│  [Regular Post #1]         │ ← Regular Posts
│  [Regular Post #2]         │
│  [Regular Post #3]         │
│  ...                        │
│                             │
└─────────────────────────────┘
```

## How Forum Ads Appear

### Visual Design:
```
╔═══════════════════════════════════╗
║ 🏪 SPONSORED                      ║
║ ─────────────────────────────────║
║ McDonald's Special Offer         ║ ← Ad Title
║                                  ║
║ Buy 1 Get 1 Free Big Mac today! ║ ← Ad Content
║ Limited time offer in Bangsar.  ║
║                                  ║
║ 📞 +60 12-345-6789  📍 Address  ║ ← Contact Info
╚═══════════════════════════════════╝
```

**Styling:**
- Blue gradient background
- "SPONSORED" badge at top
- Border with blue tint
- Shows merchant name, title, content
- Optional: phone number, address
- Tap to see full details

## How to See Forum Ads

### Step 1: Create Forum Ad
```
Shop → Merchant Ads → + Create Ad

Settings:
- Type: 📝 Forum Post
- Title: "Special Offer Today!"
- Content: "Visit our store for amazing deals"
- Location: Select district center
- Coverage Area: Select "Bangsar, Kuala Lumpur"
- Budget: $10.00
```

### Step 2: View in Forum
```
Home Screen → Tap "Bangsar" district marker
(or)
Navigate to Bangsar forum
```

### Step 3: See the Ad
```
Forum opens → Ads appear at top (before posts)
- Shows up to 2 ads maximum
- Sorted by relevance/date
- Premium users don't see ads
```

## Conditions for Ads to Show

✅ **Must Have:**
1. Ad type = "Forum Post"
2. Ad status = "Active"
3. DistrictId matches forum district
4. Location within district (uses district coordinates)
5. Ad has budget remaining
6. Current date within ad start/end dates
7. User is NOT premium

## Console Logs to Check

When forum loads, you should see:
```
ForumScreen: Loading forum ads for Bangsar
AdService: Getting nearby ads for location (3.1234, 101.5678)
AdService: Found X ads with status=active
ForumScreen: Found 2 forum ads
```

If you see "Found 0 forum ads":
- Check ad's districtId matches forum
- Check ad status is "active"
- Check ad location is set
- Check ad hasn't exhausted budget

## Testing Checklist

- [ ] Create forum post ad
- [ ] Set districtId to specific district (e.g., "kl_bangsar")
- [ ] Set location to district center
- [ ] Set status to "active"
- [ ] Add budget ($10+)
- [ ] Open that district's forum
- [ ] See ad at top with blue gradient
- [ ] See "SPONSORED" badge
- [ ] Tap ad opens detail view
- [ ] Check console logs show "Found X forum ads"

## Why Ads Might Not Show

### Common Issues:

1. **Wrong District**
   - Ad's districtId doesn't match forum district
   - Solution: Create ad with correct district selection

2. **Premium User**
   - Premium users never see ads
   - Solution: Use non-premium account for testing

3. **No Budget**
   - Ad exhausted its budget
   - Solution: Add more budget to wallet

4. **Wrong Type**
   - Ad type is not "Forum Post"
   - Solution: Create new ad with Forum Post type

5. **Inactive Status**
   - Ad is paused or completed
   - Solution: Check ad status in Merchant Ads screen

6. **Location Mismatch**
   - Ad location is far from district
   - Solution: Set ad location to district center

## Code Location

The forum ads are rendered in: `lib/screens/forum_screen.dart`

Key sections:
- **Lines 231-242**: Ad loading with district coordinates
- **Lines 246-266**: Ad rendering (shows max 2 ads)
- **Lines 320-400**: `_SponsoredAdCard` widget definition

## Current Status

✅ **Fixed Issues:**
- Now uses district coordinates (not 0,0)
- Includes debug logging
- Filters by both location and districtId
- Properly styled with blue gradient

🎯 **Ready to Test:**
All forum ads should now display correctly when conditions are met!





