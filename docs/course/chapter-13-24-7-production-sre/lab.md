# Lab: Full Incident Lifecycle (24/7 SRE)

## Goal

Run one full lifecycle simulation:
- detect
- triage
- mitigate
- recover
- postmortem

## Scenario Input

Use one recent controlled scenario (recommended from Chapter 11/12):
- backend crash/panic pattern, or
- elevated 5xx with recurring incidents

## Step 1: Incident Declaration

Define:
- severity (SEV-1/SEV-2/SEV-3)
- blast radius
- IC and responder roles
- comms channel and update cadence

## Step 2: Evidence Collection

Capture:
- symptom metrics
- representative trace(s)
- correlated log evidence
- guardian incident id (if available)

## Step 3: Mitigation Decision

Choose one:
- rollback
- config change
- scale/traffic control
- observe-only with timebox

Record why this action is safest.

## Step 4: Recovery Verification

Confirm:
- metric recovery
- trace duration/error normalization
- no repeating critical logs for same fingerprint

## Step 5: Postmortem

Complete `postmortem-template.md`:
- timeline
- root/contributing factors
- what worked, what failed
- action items

## Hard Stop Conditions

- mitigation applied without evidence
- no assigned owner for critical action item
- incident closed without recovery verification

## Done When

- complete incident record exists
- postmortem is blameless and actionable
- at least one prevention action is accepted into backlog
