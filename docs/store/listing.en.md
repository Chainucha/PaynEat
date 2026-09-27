# Store listing, English — PaynEat POS

Copy each field into Play Console → **Store presence → Main store listing** (language: English (United States) – en-US).
The full procedure is in [README.md](README.md) (Thai). Images are in [`assets/en/`](assets/en/) and
[`assets/icon-512.png`](assets/icon-512.png).

> This text is written for the **demo-mode build** (ticket 29a). Once ticket 29b lets the app connect to a
> restaurant's server, rewrite the "Important" paragraph of the full description before uploading that build.

## App name (30 characters max)

```
PaynEat POS
```

## Short description (80 characters max)

```
Free restaurant POS: take orders, kitchen screen, checkout and PromptPay QR
```

## Full description (4,000 characters max)

```
PaynEat POS is a point of sale for restaurants. Every feature is free and the code is open source. It is built for the busiest hour of service.

Important: this version runs in demo mode. The restaurant, menu and orders are made-up data kept on your device only. Pick a role on the sign-in screen and try it straight away, no sign-up needed. Connecting to a real restaurant's server comes in the next version.

Waiters
• A table map that shows free, seated and unpaid tables by colour
• Take orders at the table with spice level, add-ons and notes to the kitchen, priced for you
• Takeaway and delivery orders with queue numbers
• Move tables, merge and split bills
• Keep taking orders when the network drops; they reach the kitchen when it is back

Kitchen
• A kitchen screen on any tablet, with pending, cooking and ready columns
• Orders that wait too long are flagged
• High-contrast mode, readable under harsh kitchen lights

Cashier
• Change worked out for you; cash, PromptPay, card or transfer
• A PromptPay QR for the exact bill, ready for the customer to scan
• Receipts that show discounts, service charge and VAT, printable on the restaurant's receipt printer
• Tax invoices, refunds and end-of-shift cash counts
• Scan barcodes and scale labels with the camera; sell by weight

Owners
• Loyalty points, promotions, and ingredient stock deducted as dishes sell
• Sales reports and an audit trail of every change
• Thai, English and Korean

Privacy
The app sends nothing to its developer and shows no ads. Restaurant data stays on the restaurant's own server. The barcode scanner uses Google ML Kit, which sends diagnostic data to Google as the privacy policy explains.

Open source
All of the code is available under the Apache License 2.0 at github.com/SuruchBoss/PaynEat. A restaurant can run its own server on a PC in the shop with Docker, following the guide on the website.
```

## Images

| Play Console field | File |
|---|---|
| App icon (512 × 512) | `assets/icon-512.png` |
| Feature graphic (1024 × 500) | `assets/en/feature-graphic.png` |
| Phone screenshots (1080 × 1920) | `assets/en/phone-1.png` … `phone-5.png`, in order |
| 7-inch and 10-inch tablet screenshots (1920 × 1080) | `assets/en/tablet-1.png` … `tablet-3.png`, the same set for both |

## Other fields

- **App category**: Business
- **Contact email**: the address the owner answers users from (shown on the public store page)
- **Website**: `https://suruchboss.github.io/PaynEat/`
- **Privacy policy**: `https://suruchboss.github.io/PaynEat/privacy.en.html`
