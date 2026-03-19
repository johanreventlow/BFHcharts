# Analyse-kontekst filtreret til seneste del — Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Sikre at SPC-analysen (runs, crossings, outliers, centerline, n_points) kun baseres paa data efter seneste median-knaek, saa LLM-analysen afspejler den aktuelle proces.

**Architecture:** Fix i tre funktioner i BFHcharts. BFHddl, BFHllm og ddl er uaendrede.

**Tech Stack:** qicharts2 (qic_data$part), BFHcharts (spc_analysis.R, export_pdf.R)

---

## Godkendt: 2026-03-19

## Problem

Naar der er median-knaek (part_positions), beregner chartet korrekte centerline/kontrolgraenser per del. Men analyse-konteksten (sendt til BFHllm) bruger statistikker fra foerste del og datapunkter fra hele datasaettet.

| Aspekt | Chart viser | Analyse bruger |
|--------|-------------|----------------|
| Centerline | Seneste del | Foerste del |
| n_points | Seneste del visuelt | Alle raekker |
| Outliers | Hele datasaettet | Hele datasaettet |
| Runs/crossings | Per del | Foerste del |

## Loesning

### 1. bfh_extract_spc_stats() (export_pdf.R)

Aendr `summary[1, ]` til `summary[nrow(summary), ]` for at laese seneste part.

### 2. extract_spc_stats_extended() (export_pdf.R)

Filtrer outlier-taelling til seneste part via qic_data$part.

### 3. bfh_build_analysis_context() (spc_analysis.R)

Filtrer n_points og centerline til seneste part via qic_data$part.

## Aendrede filer

- BFHcharts/R/export_pdf.R (bfh_extract_spc_stats, extract_spc_stats_extended)
- BFHcharts/R/spc_analysis.R (bfh_build_analysis_context)

## Uaendrede pakker

- BFHddl, BFHllm, ddl — modtager automatisk korrekte data
