# LAB 6: Wrap Up

**Previous:** [LAB 5: RiverPulse Analytics](../LAB5_riverpulse_analytics/LAB5.md)

## Overview

Recap what you built and how it maps to Confluent + Databricks for real-time payments ops.

## What you accomplished

1. Claimed a pre-provisioned Confluent + Databricks environment
2. Explored CDC (profiles + FX) and RiverFlow lifecycle streams
3. Built Flink data products: completed payments with FX TTJ + risk via external UDF
4. Enabled Tableflow (append + upsert)
5. Answered the three RiverPulse business questions in Genie

## Architecture reminder

Postgres (profiles, FX) → CDC → Kafka → Flink (join + TTJ + UDF) → Tableflow → Unity Catalog → Genie

## Phase 2 tease

Failed-payment / DLQ paths, stall-aware state, NSF/fraud branches, and `MATCH_RECOGNIZE` are intentionally out of Elevate Phase 1.

## Feedback

> [!IMPORTANT]
> **Your Feedback Helps!**
>
> Please help us improve this workshop by leaving your feedback in this [quick 2-minute survey](https://docs.google.com/forms/d/e/1FAIpQLSfoVUqUFTAxHKJop7t8TvfZ4gItQxJ1RaM4oy72DjtK-HWoJg/viewform?usp=pp_url&entry.179681974=FSI+Payments)!
>
> Your instructor may ask you to provide separate feedback as well.
>
> Thanks!


## Cleanup

Attendees do **not** need to clean up any accounts or infrastructure, as instructors will take care of that after the workshop.

Thank you for building out the RiverPay / RiverFlow / RiverPulse solution!
