# Screen inventory for the 2.0 design

Every surface the redesign must cover. "Now" = exists in the app today (class name), "New" = added in 2.0.

## App — first run and account
| Screen | Now / New |
|---|---|
| Splash | Now (native splash) |
| Onboarding (4 steps: scan, voice, settle, currency) | Now `NewOnboardingScreen` |
| Sign in (Apple, Google, email) | Now `LoginScreen` |
| Sign up | Now `SignUpModal` |
| Forgot password | Now (inside login) |
| Phone number (optional in 2.0, for contact matching) | Now `PhoneInputScreen` |
| Notification permission explainer | New |
| Tracking (ATT) explainer before the system prompt | New |
| Default currency and language picker | Now `CurrencySelectionSheet` |

## App — core
| Screen | Now / New |
|---|---|
| Home: balances, groups, friends, recent activity | Now `HomeScreen` (redesign) |
| Create bill sheet (scan, voice, manual) | Now `CreateBillSheet` |
| Scan receipt (camera, import, crop) | Now `ScanReceiptScreen`, `ImageSourceSheet` |
| Receipt review (AI result, edit lines, tax/tip) | Now `ReceiptResultView` |
| Manual entry | Now `ManualEntryScreen` |
| Add people (friends, contacts, QR, guests) | Now `AddMembersSheet`, `ScanFriendScreen`, `QrDialog` |
| Assign items (tap) | Now `SplitBillScreen`, `SimpleAssignmentSheet`, `ComplexAssignmentSheet`, `EditAssignmentSheet`, `AssignmentMethodSheet` |
| Voice assign | Now `VoiceCommandOverlay` |
| Split method (by item, equal, exact, percent, shares) | New |
| Bill summary and confirm | Now `BillSummaryConfirmScreen`, `EditBillSummaryDialog` |
| Share bill (link, QR, WhatsApp card) | Now `SuccessScreen` (redesign) |
| Bill details (host view, payment statuses, proofs, reminders) | Now `BillDetailsScreen` |
| Participant bill (my share, pay, proof) | Now `ParticipantBillScreen`, `ParticipantOptionsSheet` |
| Edit bill | Now `EditBillScreen` |
| Bill history | Now `CompletedBillsScreen` |
| Bill roulette (who pays) | Now (inside summary) |

## App — groups, balances, settle up (2.0)
| Screen | Now / New |
|---|---|
| Groups list | Now `GroupsScreen` (becomes Groups and trips) |
| Group / trip detail: balances, expenses, members, totals | New |
| Create group / trip (name, cover, currency, members) | Now `GroupSelectionSheet`, `GroupMemberSelectionDialog` (redesign) |
| Friend detail: balance with one person, shared bills | New |
| Settle up (simplified transfers) | New |
| Record payment (amount, method, proof) | New |
| Activity feed | New |
| Recurring bill setup | New |
| Multi-currency and FX view | New |
| Export (CSV/PDF) | New |
| Spending insights | New |

## App — profile and settings
| Screen | Now / New |
|---|---|
| Profile | Now `ProfileScreen` |
| Edit profile | Now `EditProfileScreen` |
| Payment methods (InstaPay, PayPal, Venmo, Revolut, UPI…) | Now `PaymentSettingsScreen` |
| Appearance (system/light/dark) | Now `ThemeModeSheet` |
| Language, currency | Now `SearchableSelectionSheet` |
| Notification preferences and reminder schedule | New |
| Privacy and data, delete account | Now (dialogs) |
| Help and contact | Now (dialogs) |

## App — monetization
| Screen | Now / New |
|---|---|
| Paywall (monthly $2.99, yearly $24.99, lifetime $59.99) | Now `PremiumModal`, `PremiumBottomSheet` (redesign) |
| Out of AI credits | Now `NoPointsDialog` |
| Rewarded ad prompt | Now `AdModal` |
| Subscription management | Now (profile) |

## App — notifications and admin
| Screen | Now / New |
|---|---|
| Notifications inbox | Now `NotificationsScreen` |
| Admin dashboard (users, bills) | Now `AdminDashboardScreen` |
| Admin user detail | Now `UserAdminDetailScreen` |
| Admin send notification | Now `SendNotificationSheet` |
| Admin analytics: usage, AI cost per feature/provider, errors | New |

## System states (all screens)
Empty states, loading skeletons, offline, errors, success toasts, permission denied (camera, mic, contacts), force update.

## Guest web (Flutter web, no account)
| Page | Now / New |
|---|---|
| Bill link landing: pick your name | Now `GuestSelectorView` |
| Personal link: "Hi Mona, your share is…" | New |
| Bill breakdown | Now `GuestBillScreen` |
| Pay: host methods, copy, open app links | Now (inside guest bill) |
| Upload proof | Now (inside guest bill) |
| Waiting for confirmation / confirmed | Now (status) |
| Bill not found / expired / settled | Now (states) |
| Get the app | Now `WebDownloadScreen` |

## Landing site (Django, omarmali.net/split-bill/)
| Page | Now / New |
|---|---|
| Home: hero, how it works, features, AI scan, voice, guests, balances, languages, screenshots, pricing, FAQ, download, footer | Now (redesign) |
| Privacy | Now |
| Terms | Now |
| Compare: vs Splitwise, vs Tricount, Settle Up alternatives | New |
| Use cases: trips, roommates, dinners, events | New |
| Help center / FAQ | New |
| Localized versions (22 locales, hreflang) | New |
