# LAB 6: Wrap Up

## Overview

Recap what you built and how it maps to Confluent + Databricks for real-time payments ops.

## What you accomplished

1. Claimed a pre-provisioned Confluent + Databricks environment
2. Explored CDC (profiles + FX) and RiverFlow lifecycle streams
3. Built Flink data products: completed payments with FX TTJ + risk via external UDF
4. Enabled Tableflow (append + upsert) and discussed TTL / right-to-forget
5. Answered the three RiverPulse business questions in Genie

## Architecture reminder

Postgres (profiles, FX) → CDC → Kafka → Flink (join + TTJ + UDF) → Tableflow → Unity Catalog → Genie

## Phase 2 tease

Failed-payment / DLQ paths, stall-aware state, NSF/fraud branches, and `MATCH_RECOGNIZE` are intentionally out of Elevate Phase 1.

## Feedback

Please complete the instructor’s feedback form.

## Cleanup

Attendees do **not** destroy shared Azure infra. Operators tear down per-attendee environments and shared roots after the session.

Thank you for building with RiverPay / RiverFlow / RiverPulse!
