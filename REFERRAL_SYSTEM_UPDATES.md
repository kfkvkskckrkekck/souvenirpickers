# Referral System Updates

## Fixed Issues

### 1. Missing Referral Code
**Problem:** Referral code was blank/not showing for some users.

**Solution:**
- Added automatic referral code generation if one doesn't exist
- When the page loads and no code is found, it automatically generates a unique 8-character code
- Shows a loading spinner while generating: "Generating your code..."
- Code is then displayed and can be copied

### 2. Role-Specific Rewards

The referral system now shows different reward structures based on whether you're a **Picker** or a **Collector/Client**.

---

## Picker Referral Rewards

When you're logged in as a **Picker**, the referral program now shows:

### Your Benefits:
- **Refer Other Pickers:** Earn €10 when they complete their first sale
- **Refer Collectors:** Earn €10 when they place their first order
- Credits can be used as platform credits (for future features like boosting listings, ads, etc.)

### What Your Referrals Get:
- **Pickers:** Priority verification and faster onboarding
- **Collectors:** €5 off their first order

### Updated Text:
- "Share your code with friends to help grow the SouvenirPickers community! Earn €10 when your referred picker completes their first sale, or when a referred collector places their first order."
- Available rewards: "Ready to use as platform credits"
- Social share text: "Join SouvenirPickers as a picker and start earning!"

---

## Collector/Client Referral Rewards

When you're logged in as a **Collector/Client**, the original system remains:

### Your Benefits:
- **Refer Friends:** Earn €10 when they complete their first order
- Credits can be used on your next order

### What Your Referrals Get:
- €5 off their first order

### Text:
- "Share your unique code with friends. They get €5 off their first order, and you earn €10 when they complete it!"
- Available rewards: "Ready to use on your next order"
- Social share text: "Join SouvenirPickers and get €5 off your first order!"

---

## How It Works (Updated)

### For Pickers:
1. **Share Your Code** - Send your unique referral code via social media or direct link
2. **They Join** - Your friend joins SouvenirPickers as a picker or collector
3. **You Earn Rewards** - Earn €10 when your referral completes their first sale or order

### For Collectors:
1. **Share Your Code** - Send your unique referral code to friends
2. **They Sign Up** - Your friend joins and gets €5 off their first order
3. **You Both Win** - When they complete their first order, you earn €10 in credits

---

## Technical Implementation

### Automatic Code Generation:
```typescript
const generateReferralCode = async () => {
  // Calls the database function to generate unique 8-char code
  // Inserts into referral_codes table
  // Reloads stats to display the new code
};
```

### Role Detection:
```typescript
const isPicker = profile?.user_type === 'picker';
```

### Dynamic UI:
- All reward descriptions change based on user role
- Social sharing messages adapt to the user type
- Help text explains relevant rewards for each role

---

## Next Steps

You may want to consider these enhancements:

1. **Picker-Specific Rewards Usage:**
   - Define how pickers can use their referral credits
   - Options: Premium subscription, listing boosts, featured placement, reduced fees

2. **Tiered Rewards:**
   - Offer increasing rewards for multiple referrals (e.g., 5 referrals = bonus €50)
   - VIP status for top referrers

3. **Leaderboard:**
   - Show top referrers on the platform
   - Monthly competitions with prizes

4. **Referral Analytics:**
   - Track conversion rates
   - Show which referrals became active users
   - Display earning potential

5. **Custom Rewards:**
   - Allow pickers to offer custom incentives from their earnings
   - Example: "Use my code and get priority service on your order!"
