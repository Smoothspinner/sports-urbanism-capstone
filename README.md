# Predicting White Elephant Risk in Olympic and World Cup Venues Using Machine Learning
*Working title - DSE 6311 Capstone, Team Gamma*

**Team:** Brian Wrenn, Jonathan Layne, Martin Gotora

## Background
Some Olympic and World Cup venues fall out of use after their event, becoming
"white elephants" that consume public money with little return. Prior research
explains these failures after the fact, no work we have found tries to predict
them before construction begins.

## Why It Matters
Cities commit public money to venues years before they exist. An early-warning
model flags bad plans on paper, not after a half-built stadium. Prior work
(Alm et al. 2016; Müller 2015) explains venue failures after the fact; no study
we have found trains a predictive model and tests it on venues it never saw.

## Stakeholders
Host-city bid committees and government planning offices.

## Question
Can pre-construction information (design purpose, capacity, event type,
host-country income and corruption, bid-tied status, host-city population)
predict whether a venue stays in active use or becomes a white elephant?

## Hypothesis
Venues that are bid-tied, single-purpose, and hard to reach become white
elephants more often, because long-term use was never the point of building them.

## Prediction
Bid-tied status and design purpose will emerge as the strongest predictors,
and the model will outperform a naive baseline that always predicts "stays active."

## Where files go
- data/raw — original downloads, untouched, keep original filenames
- data/processed — cleaned tables our scripts produce
- data/external — reference pulls (e.g., Wikidata)
- source/data — cleaning and join scripts (numbered in run order: 01_, 02_...)
- source/models — modeling code
- reports — weekly deliverables (proposal, EDA, etc.)
