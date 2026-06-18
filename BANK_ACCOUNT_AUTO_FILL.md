# Bank Account Auto-Fill System

Your payout bank account form now includes intelligent auto-fill functionality to make setup faster and easier.

## How It Works

### 1. IBAN Entry Auto-Fills Country & Currency

When you enter an IBAN number, the system automatically detects:
- **Country** from the first 2 letters (e.g., RO → Romania, DE → Germany)
- **Currency** based on the country (e.g., Romania → RON, Germany → EUR)

**Supported Countries:** 30+ European countries including Romania, Germany, France, UK, Poland, Sweden, Denmark, and more.

**Example:**
- Enter: `RO49BTRL...`
- Auto-fills: Country = "Romania", Currency = "RON"

### 2. US Routing Number Auto-Fills Bank Name

For US bank accounts, entering a routing number will automatically fill in the bank name.

**Supported Banks:**
- JPMorgan Chase (021...)
- Bank of America (026...)
- Wells Fargo (111...)
- Citibank (121...)
- Capital One (031...)
- US Bank (063...)
- PNC Bank (044...)
- TD Bank (091...)
- Fifth Third Bank (071...)
- Truist Bank (124...)

**Example:**
- Enter routing: `021000021`
- Auto-fills: Bank Name = "JPMorgan Chase", Country = "United States", Currency = "USD"

### 3. SWIFT Code Auto-Fills Bank Name & Country

Enter a SWIFT/BIC code to automatically fill in the bank name and country.

**Supported Banks:**
- HSBC UK (HSBCGB2L)
- Barclays (BARCGB22)
- Deutsche Bank (DEUTDEFF)
- BNP Paribas (BNPAFRPP)
- JPMorgan Chase UK (CHASGB2L)
- Citibank US (CITIUS33)
- Bank of America (BOFAUS3N)
- Wells Fargo (WFBIUS6S)
- Banca Transilvania (BTRLRO22)
- Raiffeisen Bank Romania (RZBBROBU)

**Example:**
- Enter SWIFT: `BTRLRO22`
- Auto-fills: Bank Name = "Banca Transilvania", Country = "Romania", Currency = "RON"

## Visual Indicators

Fields that have been auto-filled will show a green "Auto-filled" badge next to the field label. If you manually edit an auto-filled field, the badge disappears to indicate you've customized it.

## Saving Your Information

Once all required fields are complete:
1. Click "Save Bank Account"
2. Your information is securely encrypted and stored
3. The system validates your IBAN using checksum verification
4. You'll see a confirmation message when saved successfully

## Security

- All bank account information is encrypted at rest
- Data is only used for processing payouts
- You can update your information anytime
- Full IBAN validation ensures accuracy
