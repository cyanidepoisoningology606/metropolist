#!/usr/bin/env bun
/**
 * Metropolist Data Builder
 *
 * Reads raw IDFM open data + GTFS files and produces a single
 * `metropolist-data.json` ready to seed the iOS SwiftData database.
 *
 * Usage:  bun run build-data.ts
 */

import { log } from "./src/helpers";
import { buildLookups } from "./src/lookups";
import { buildLines } from "./src/lines";
import { enrichStations } from "./src/stations";
import { buildRoutes } from "./src/routes";
import { buildTransfers } from "./src/transfers";
import { pruneData } from "./src/pruning";
import { writeOutput, printSummary } from "./src/output";

// ─── Paths ───────────────────────────────────────────────────────────────────

const DATA = "./data";
const GTFS = `${DATA}/IDFM-gtfs`;
const OUTPUT_PATH = "./metropolist-data.json";

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const startTime = performance.now();
  log("Starting Metropolist data build...");

  // Step 1: Build lookup tables
  const lookups = await buildLookups(DATA, GTFS);

  // Step 2: Build lines
  const { lines: allLines } = await buildLines(
    GTFS,
    lookups.refByLineId,
    lookups.replacementLineIds,
  );

  // Steps 3-4: Enrich stations
  enrichStations(lookups.stationById, lookups.arretsRaw, lookups.arretsLignesRaw);

  // Step 5: Derive route variants and line stops
  const { routeVariants, lineStops, referencedStationIds } = await buildRoutes(
    GTFS,
    lookups.stationById,
    lookups.quaiToStation,
  );

  // Step 6: Build transfers
  const transfers = await buildTransfers(
    GTFS,
    lookups.stationById,
    lookups.quaiToStation,
  );

  // Steps 7-8: Prune unused data
  const linesWithStops = new Set(lineStops.map((ls) => ls.lineId));
  const prunedLines = allLines.filter(
    (l) => !linesWithStops.has(l.id) || l.status === "upcoming",
  );

  const pruned = pruneData(
    allLines,
    [],
    routeVariants,
    lineStops,
    lookups.stationById,
    referencedStationIds,
  );

  // Step 9: Sort, compare, and write output
  await writeOutput(
    pruned.lines,
    pruned.stations,
    pruned.routeVariants,
    pruned.lineStops,
    transfers,
    OUTPUT_PATH,
  );

  // Validation summary
  const elapsed = ((performance.now() - startTime) / 1000).toFixed(1);
  printSummary(
    pruned.lines,
    pruned.stations,
    pruned.routeVariants,
    pruned.lineStops,
    transfers,
    prunedLines,
    linesWithStops,
    elapsed,
  );
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
