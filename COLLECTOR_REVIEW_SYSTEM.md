# Collector Review System

The collector review system allows collectors to leave reviews for pickers after an order is delivered. This feature helps build trust in the marketplace and provides valuable feedback to pickers.

## Features Implemented

### 1. Review Submission
- **Who can review**: Collectors (clients) can review pickers after order delivery
- **When**: Reviews can be submitted once an order status is 'delivered'
- **Prevents duplicates**: Each collector can only submit one review per order
- **Rich content**: Reviews support:
  - Star ratings (1-5)
  - Text comments
  - Photo uploads
  - Video uploads

### 2. Review Display
- **Picker profiles**: All reviews are displayed on picker profiles
- **Order page**: Shows "Review Submitted" status after submission
- **Statistics**: Automatic calculation of:
  - Average rating
  - Total review count
  - Rating distribution (1-5 stars)
  - Verified purchase badges

### 3. Notifications
- **Picker notification**: When a collector submits a review, the picker receives a notification
- **Includes**: Star rating and order details
- **Real-time**: Notifications appear immediately in the picker's notification center

### 4. Interactive Features
- **Helpful votes**: Users can mark reviews as helpful or unhelpful
- **Picker responses**: Pickers can respond to reviews (one response per review)
- **Report system**: Users can report inappropriate reviews for moderation

## User Flow

### For Collectors:

1. Complete an order (order status becomes 'delivered')
2. Navigate to "My Orders" section
3. Find the delivered order
4. Click "Write Review" button
5. Fill out review form:
   - Select star rating (1-5)
   - Write comment (optional)
   - Upload photos (optional)
   - Upload video (optional)
6. Submit review
7. See "Review Submitted" confirmation
8. Button changes to show review status

### For Pickers:

1. Receive notification when collector submits review
2. View review on their profile
3. Can respond to the review if desired
4. Reviews affect overall picker rating and statistics

## Technical Implementation

### Database Tables

**reviews**
- Stores review content, ratings, media
- Links to orders, pickers, and collectors
- Tracks helpful votes and verification status

**review_votes**
- Tracks helpful/unhelpful votes
- Prevents duplicate votes per user

**review_statistics**
- Cached picker review metrics
- Updated automatically via triggers

**review_reports**
- Allows flagging inappropriate reviews
- Admin moderation system

### Security (RLS Policies)

- Collectors can only review their own orders
- Orders must be in 'delivered' status
- One review per order per collector
- All users can view non-hidden reviews
- Pickers can respond to reviews about them
- Vote and report permissions properly scoped

### Automatic Updates

**Triggers:**
1. `notify_picker_on_review`: Creates notification when review submitted
2. `update_review_statistics`: Updates picker statistics after review changes
3. `update_review_helpful_counts`: Updates helpful/unhelpful counts after votes

**Statistics Updated:**
- Total reviews
- Average rating
- Rating distribution
- Verified purchase count
- Response rate
- Average response time

## UI Components

### ReviewForm
- Modal dialog for submitting reviews
- Star rating selector with hover effects
- Text area for comments
- Image and video upload with previews
- Validation and error handling
- Success feedback

### ReviewsList
- Displays all reviews for a picker
- Shows reviewer info and verification badge
- Displays rating, comment, and media
- Helpful/unhelpful voting buttons
- Picker response section
- Image lightbox viewer

### OrdersView Integration
- "Write Review" button for delivered orders
- "Review Submitted" status indicator
- Success toast after submission
- Prevents duplicate reviews

## Benefits

### For Collectors:
- Share experiences with other users
- Help improve picker quality
- Hold pickers accountable
- Contribute to marketplace trust

### For Pickers:
- Build reputation and trust
- Receive valuable feedback
- Attract more collectors
- Improve service quality
- Respond to concerns

### For the Platform:
- Builds trust in the marketplace
- Quality control mechanism
- User engagement
- Social proof
- Data for recommendations

## Future Enhancements

Possible improvements:
- Review editing within 24 hours
- Review templates for common scenarios
- Review badges (Most Helpful, etc.)
- Review sorting and filtering
- Sentiment analysis
- Review reminders
- Review incentives
- Picker review highlights
- Review moderation dashboard

## Testing

To test the review system:

1. Create a test collector account
2. Create a test picker account
3. Create a listing as picker
4. Place an order as collector
5. Mark order as delivered (as picker)
6. Submit a review as collector
7. Verify picker receives notification
8. Check review appears on picker profile
9. Test helpful/unhelpful voting
10. Test picker response feature
