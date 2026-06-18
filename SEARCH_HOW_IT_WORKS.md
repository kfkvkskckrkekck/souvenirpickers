# How the Discover Search Works

## What Does the Search Find?

The Discover search **ONLY searches LISTINGS** (souvenirs), not pickers or users. It searches through:

### 1. **Listing Titles**
   - Example: "Test buton", "Breloc"

### 2. **Descriptions**
   - Example: "sccasc", "foarte frumos"

### 3. **Categories**
   - Example: "Crats", "accessorii", "Souvenirs", "Clothing", "Art"

### 4. **Regions/Locations**
   - Example: "Romania", "Paris", "Tokyo", "New York"

## How to Use the Search

### Option 1: Text Search (Main Search Bar)
Type any keyword and press Enter or click "Search":

**Examples that will work:**
- `buton` → finds "Test buton"
- `Breloc` → finds "Breloc"
- `Romania` → finds all listings from Romania
- `accessorii` → finds listings in that category
- `frumos` → finds listings with "frumos" in description

**What it searches:**
- Partial matches (case-insensitive)
- Searches across title, description, category, and region
- Uses "LIKE" search, so "rom" will match "Romania"

### Option 2: Filter-Based Search
Click the "Filters" button to use dropdown filters:

1. **Category Dropdown**
   - Shows all available categories from existing listings
   - Examples: "Crats", "accessorii"

2. **Region Dropdown**
   - Shows all available regions from existing listings
   - Example: "Romania"

3. **Price Range**
   - Min Price: Enter minimum (e.g., 0)
   - Max Price: Enter maximum (e.g., 10)

4. Click "Apply Filters" to search

### Option 3: Combined Search
You can use BOTH text search AND filters together:
- Type a keyword in the search bar
- Open filters and select category/region/price
- Click "Search" or "Apply Filters"

## What Happens When You Click "Discover"?

When you first open Discover (without searching), it shows:

1. **Trending Listings** (if available)
   - Based on view counts and activity from the last 7 days

2. **Recent Listings** (fallback)
   - If no trending data exists, shows newest available listings
   - Sorted by creation date (newest first)
   - Only shows available listings (available = true)

## Current Listings in Database

Based on your database, you have 2 listings:

| Title | Description | Category | Region | Price |
|-------|-------------|----------|--------|-------|
| Test buton | sccasc | Crats | Romania | $5.00 |
| Breloc | foarte frumos | accessorii | Romania | $1.99 |

## Search Examples You Can Try Right Now

1. **Search for "buton"** → Should return "Test buton"
2. **Search for "Breloc"** → Should return "Breloc"
3. **Search for "Romania"** → Should return both listings
4. **Search for "accessorii"** → Should return "Breloc"
5. **Filter by Category: "Crats"** → Should return "Test buton"
6. **Filter by Price: Min=0, Max=3** → Should return "Breloc" ($1.99)

## How the Search Algorithm Works

### Step 1: Text Search (if keyword entered)
1. First tries **full-text search** using PostgreSQL's search_vector
2. If that fails or returns nothing, falls back to **ILIKE search**
3. ILIKE searches: `title`, `description`, `category`, `region`

### Step 2: Filter Application
After text search, applies additional filters:
- Category (exact match)
- Region (exact match)
- Min Price (greater than or equal)
- Max Price (less than or equal)
- Available status (always true in Discover)

### Step 3: Sorting
Results are sorted by:
- **Price (ascending)** if "Price: Low to High" selected
- **Price (descending)** if "Price: High to Low" selected
- **Date (newest first)** by default

## Why You Might See No Results

1. **No listings in database** → Add listings as a Picker first
2. **All listings unavailable** → Only searches available=true listings
3. **Search term doesn't match** → Try broader terms or partial words
4. **Filters too restrictive** → Remove some filters
5. **Price range too narrow** → Widen the min/max price

## Searching for Pickers

**Important:** The Discover page does NOT search for pickers.

To search for pickers, use:
- **"Browse Pickers"** menu item → Shows all pickers
- **"Matched Pickers"** menu item → Shows pickers matched to your desires

## Technical Details

**Database Tables Used:**
- `listings` (main search target)
- `profiles` (joined for picker info)
- `search_history` (records your searches)
- `popular_searches` (tracks trending terms)
- `listing_views` (tracks which listings are viewed)

**Search Performance:**
- Uses database indexes for fast searching
- Full-text search vector for complex queries
- Fallback to pattern matching (ILIKE) if needed

**Privacy:**
- Search history is stored per user
- Anonymous users can search but history isn't saved
- Only available listings are shown to protect picker privacy

## Empty State Behavior

**When no results found:**
- Shows helpful message
- Offers "Clear Filters" button if filters are active
- Offers "Browse All Listings" button if no listings exist

**When page first loads:**
- Shows 12 trending listings (or recent if no trending data)
- Shows popular search terms if available
- Auto-loads categories and regions for filter dropdowns
