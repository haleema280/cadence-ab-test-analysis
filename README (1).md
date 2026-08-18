# Cadence Pricing Screen A/B Test — Verdict on Shipping Variant B

**Author:** Haleema Mahmood
**Test window:** 1 June 2026 00:00:00 UTC – 30 June 2026 23:59:59 UTC

## Headline number vs. reality

The growth thread quoted B converting at ~11.9% vs. A's ~8.7% — a **+3.3pp** lift, overall. That number is correct on the raw data. It is also **misleading**, because it hides a broken experiment.

## What was checked

Before trusting the lift, the two groups were tested for comparability:

- **Sample size split:** A got 30,000 unique first-time visitors, B got 28,000. Not fatal on its own, but not the 50/50 split expected from clean random bucketing.
- **Device mix split:** this is where it breaks down. A was 72% web / 28% mobile. B was 62% mobile / 38% web — almost the inverse of A. This lines up exactly with the team's warning that the bucketing service was redeployed mid-test with no confirmation that the split held afterward — the redeploy skewed *which device* visitors landed in, not just headcount.
- Each visitor was deduplicated to their **first** assignment only, and conversions were restricted to those occurring on/after that visitor's first assignment and on/before 30 June 23:59:59 — visitors with a later assignment row, or conversions outside the window, were excluded.

## The reversal

Mobile visitors convert far more often than web visitors regardless of variant (roughly double). Because B happened to receive disproportionately more mobile traffic, B's blended average gets pulled up — even though **A outperforms B inside every single device segment**:

| Segment | Variant A | Variant B | B − A |
|---|---|---|---|
| Overall (raw) | 8.68% | 11.94% | **+3.3pp** |
| Mobile only | 18.54% | 16.58% | **−2.0pp** |
| Web only | 4.83% | 4.35% | **−0.5pp** |
| Standardised to pooled device mix | 10.92% | 9.79% | **−1.1pp** |

This is a textbook **Simpson's Paradox**, caused by a sample-ratio mismatch on device that traces back to the mid-test bucketing redeploy. The aggregate number and the segmented numbers disagree because the aggregate is comparing two groups with different traffic compositions, not two groups with different pricing screens.

## Recommendation: **Do not ship Variant B.**

The lift growth is celebrating is a mix-shift artifact, not a pricing-screen effect. Standardised for device mix, **A is ahead of B by 1.1pp**, and A wins outright in both the mobile-only and web-only comparisons — the segments where the split, however skewed, was still internally randomized correctly.

**What to do instead:**
1. Hold the ship. Do not flip 100% of traffic to B on Monday.
2. Fix and verify the bucketing service — confirm the split is genuinely balanced by device (and ideally channel/country) before any test is trusted again.
3. Re-run the test with monitoring on the assignment split from day one, so a redeploy-induced skew like this one is caught mid-flight rather than after the fact.
4. If B is still believed to have promise, evaluate it fresh from the re-run — the current data does not support it.
