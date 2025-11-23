# Firestore Index Setup for Ad System

## Problem
Firestore queries that filter on one field and sort by another require a **composite index**.

The error "query needs index" means Firestore needs you to create an index for the query:
```
.where('merchantId', isEqualTo: merchantId)
.orderBy('createdAt', descending: true)
```

## Solution Options

### Option 1: Click the Link (Easiest) ✅
When you see the error in the console, Firestore provides a **direct link** to create the index:

1. Look for the error message in your debug console
2. It will say something like: `The query requires an index. You can create it here: [LINK]`
3. **Click that link** - it opens Firebase Console
4. Click "Create Index"
5. Wait 1-2 minutes for index to build
6. Done! Refresh your app

### Option 2: Manual Creation in Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Click "Firestore Database" in left menu
4. Click "Indexes" tab at the top
5. Click "Create Index"
6. Fill in:
   - **Collection ID**: `ads`
   - **Fields to index**:
     * Field: `merchantId`, Order: `Ascending`
     * Field: `createdAt`, Order: `Descending`
   - **Query scope**: Collection
7. Click "Create"
8. Wait for index to build (shows "Building..." then "Enabled")

### Option 3: Deploy via Firebase CLI (Advanced)
If you have Firebase CLI installed:

```bash
cd "C:\Users\htbac\OneDrive\Desktop\Road Mobile"
firebase deploy --only firestore:indexes
```

## Required Indexes

I've already created `firestore.indexes.json` with these indexes:

### 1. Merchant Ads Query
- **Collection**: `ads`
- **Fields**: `merchantId` (ASC), `createdAt` (DESC)
- **Purpose**: Load merchant's ads sorted by date

### 2. Active Ads Query  
- **Collection**: `ads`
- **Fields**: `status` (ASC), `createdAt` (DESC)
- **Purpose**: Get all active ads

### 3. Filtered Ads Query
- **Collection**: `ads`
- **Fields**: `type` (ASC), `districtId` (ASC)
- **Purpose**: Filter ads by type and location

### 4. Wallet Transactions Query
- **Collection**: `wallet_transactions`
- **Fields**: `merchantId` (ASC), `createdAt` (DESC)
- **Purpose**: Load transaction history

## Quick Fix (Recommended)

**Just click the link in the error message!** 🎯

The error will look like:
```
PERMISSION_DENIED: The query requires an index. 
You can create it here: https://console.firebase.google.com/...
```

Click it, press "Create", wait 1-2 minutes, and you're done!

## Verification

After creating the index:
1. Go back to your app
2. Navigate to Shop → Merchant Ads
3. Try creating an ad
4. The ads should now appear in the list!

## Troubleshooting

**Index still building?**
- Wait 1-2 minutes and refresh
- Index status shows on Firebase Console → Indexes tab

**Still getting errors?**
- Make sure you created the index for the correct project
- Check that Collection ID is exactly `ads` (case-sensitive)
- Verify field names match exactly

**Need to create multiple indexes?**
- Create them one by one as errors appear
- Or use the firestore.indexes.json file I created

---

**TIP**: For development, you can temporarily remove the `.orderBy()` from the query to test without indexes, but ordering by date is important for showing newest ads first!








