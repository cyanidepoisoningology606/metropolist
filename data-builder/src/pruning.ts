import type { Line, Station, RouteVariant, LineStop } from "./types";
import { log } from "./helpers";

export interface PrunedData {
  lines: Line[];
  stations: Station[];
  routeVariants: RouteVariant[];
  lineStops: LineStop[];
}

export function pruneData(
  lines: Line[],
  stations: Station[],
  routeVariants: RouteVariant[],
  lineStops: LineStop[],
  stationById: Map<string, Station>,
  referencedStationIds: Set<string>,
): PrunedData {
  // ── Step 7: Prune unused stations ──
  log("Step 7: Pruning unused stations...");

  const stationsBefore = stationById.size;
  let prunedStations = [...stationById.values()].filter((s) =>
    referencedStationIds.has(s.id),
  );
  log(`  → Kept ${prunedStations.length} of ${stationsBefore} stations (pruned ${stationsBefore - prunedStations.length})`);

  // ── Step 8: Prune lines with zero stations and upcoming lines ──
  log("Step 8: Pruning lines with zero stations and upcoming lines...");

  const linesWithStops = new Set(lineStops.map((ls) => ls.lineId));
  const linesBefore = lines.length;
  const removedLines = lines.filter(
    (l) => !linesWithStops.has(l.id) || l.status === "upcoming",
  );
  const keptLines = lines.filter(
    (l) => linesWithStops.has(l.id) && l.status !== "upcoming",
  );
  const keptLineIds = new Set(keptLines.map((l) => l.id));

  if (removedLines.length > 0) {
    const zeroStationCount = removedLines.filter((l) => !linesWithStops.has(l.id)).length;
    const upcomingCount = removedLines.filter((l) => l.status === "upcoming").length;
    log(`  → Removed ${removedLines.length} lines (${zeroStationCount} with zero stations, ${upcomingCount} upcoming) — kept ${keptLines.length} of ${linesBefore}`);
    for (const l of removedLines) {
      const reasons = [];
      if (!linesWithStops.has(l.id)) reasons.push("no stations");
      if (l.status === "upcoming") reasons.push("upcoming");
      log(`    - ${l.id} "${l.shortName}" [${l.mode}] (${reasons.join(", ")})`);
    }
  } else {
    log("  → Nothing to prune");
  }

  // Cascade: remove lineStops, routeVariants for pruned lines
  const lineStopsBefore = lineStops.length;
  const rvBefore = routeVariants.length;

  const prunedLineStops = lineStops.filter((ls) => keptLineIds.has(ls.lineId));
  const prunedRouteVariants = routeVariants.filter((rv) => keptLineIds.has(rv.lineId));

  if (lineStopsBefore !== prunedLineStops.length || rvBefore !== prunedRouteVariants.length) {
    log(`  → Cascade: lineStops ${lineStopsBefore}→${prunedLineStops.length}, routeVariants ${rvBefore}→${prunedRouteVariants.length}`);
  }

  // Re-prune stations no longer referenced
  const finalReferencedIds = new Set(prunedLineStops.map((ls) => ls.stationId));
  const stationsBefore2 = prunedStations.length;
  prunedStations = prunedStations.filter((s) => finalReferencedIds.has(s.id));
  if (stationsBefore2 !== prunedStations.length) {
    log(`  → Re-pruned stations: ${stationsBefore2}→${prunedStations.length}`);
  }

  return {
    lines: keptLines,
    stations: prunedStations,
    routeVariants: prunedRouteVariants,
    lineStops: prunedLineStops,
  };
}
