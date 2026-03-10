import type { Station, RouteVariant, LineStop } from "./types";
import { parseCSV, streamCSVLines } from "./csv";
import { log, readFile } from "./helpers";

interface TripInfo {
  routeId: string;
  directionId: number;
  headsign: string;
}

export interface RoutesResult {
  routeVariants: RouteVariant[];
  lineStops: LineStop[];
  referencedStationIds: Set<string>;
}

export async function buildRoutes(
  gtfsDir: string,
  stationById: Map<string, Station>,
  quaiToStation: Map<string, string>,
): Promise<RoutesResult> {
  log("Step 5: Deriving route variants and line stops...");

  // 5a. Parse trips.txt
  log("  Parsing trips.txt...");
  const tripsRaw = parseCSV(await readFile(`${gtfsDir}/trips.txt`));

  const tripInfo = new Map<string, TripInfo>();
  // route_id → direction_id → headsign → trip_id[]
  const tripGroups = new Map<string, Map<number, Map<string, string[]>>>();

  for (const trip of tripsRaw) {
    const routeId = trip.route_id;
    const directionId = parseInt(trip.direction_id || "0") || 0;
    const headsign = trip.trip_headsign || "";
    const tripId = trip.trip_id;

    tripInfo.set(tripId, { routeId, directionId, headsign });

    if (!tripGroups.has(routeId)) tripGroups.set(routeId, new Map());
    const byDir = tripGroups.get(routeId)!;
    if (!byDir.has(directionId)) byDir.set(directionId, new Map());
    const byHeadsign = byDir.get(directionId)!;
    if (!byHeadsign.has(headsign)) byHeadsign.set(headsign, []);
    byHeadsign.get(headsign)!.push(tripId);
  }
  log(`  → ${tripInfo.size} trips parsed`);

  // 5b. First pass: count stop_time entries per trip_id
  log("  Pass 1: Counting stop_times per trip (streaming ~1GB)...");
  const tripStopCount = new Map<string, number>();
  let stopTimesTotal = 0;

  for await (const row of streamCSVLines(`${gtfsDir}/stop_times.txt`)) {
    const tripId = row.trip_id;
    tripStopCount.set(tripId, (tripStopCount.get(tripId) ?? 0) + 1);
    stopTimesTotal++;
    if (stopTimesTotal % 2_000_000 === 0) {
      log(`    ... ${(stopTimesTotal / 1_000_000).toFixed(1)}M rows counted`);
    }
  }
  log(`  → ${stopTimesTotal} stop_time entries counted across ${tripStopCount.size} trips`);

  // 5c. Select canonical trip per (route_id, direction_id, headsign)
  log("  Selecting canonical trips...");
  const canonicalTrips = new Set<string>();
  const canonicalTripMap = new Map<string, TripInfo>();

  for (const [routeId, byDir] of tripGroups) {
    for (const [directionId, byHeadsign] of byDir) {
      for (const [headsign, tripIds] of byHeadsign) {
        let bestTripId = tripIds[0];
        let bestCount = tripStopCount.get(bestTripId) ?? 0;

        for (let i = 1; i < tripIds.length; i++) {
          const count = tripStopCount.get(tripIds[i]) ?? 0;
          if (count > bestCount) {
            bestCount = count;
            bestTripId = tripIds[i];
          }
        }

        canonicalTrips.add(bestTripId);
        canonicalTripMap.set(bestTripId, { routeId, directionId, headsign });
      }
    }
  }
  log(`  → ${canonicalTrips.size} canonical trips selected`);

  // 5d. Second pass: collect stop sequences for canonical trips
  log("  Pass 2: Collecting stop sequences for canonical trips (streaming ~1GB)...");
  const tripStopSequences = new Map<string, { stopId: string; seq: number }[]>();
  let pass2Count = 0;

  for await (const row of streamCSVLines(`${gtfsDir}/stop_times.txt`)) {
    pass2Count++;
    if (pass2Count % 2_000_000 === 0) {
      log(`    ... ${(pass2Count / 1_000_000).toFixed(1)}M rows processed`);
    }

    const tripId = row.trip_id;
    if (!canonicalTrips.has(tripId)) continue;

    if (!tripStopSequences.has(tripId)) {
      tripStopSequences.set(tripId, []);
    }
    const seq = parseInt(row.stop_sequence);
    if (!isFinite(seq)) continue;
    tripStopSequences.get(tripId)!.push({ stopId: row.stop_id, seq });
  }
  log(`  → Collected stop sequences for ${tripStopSequences.size} canonical trips`);

  // 5e. Build RouteVariants and LineStops
  log("  Building route variants and line stops...");
  const routeVariants: RouteVariant[] = [];
  const lineStops: LineStop[] = [];
  const referencedStationIds = new Set<string>();
  const seenVariantIds = new Set<string>();

  for (const [tripId, group] of canonicalTripMap) {
    const stops = tripStopSequences.get(tripId);
    if (!stops || stops.length < 2) continue;

    stops.sort((a, b) => a.seq - b.seq);

    // Collapse quai → parent station & deduplicate consecutive
    const stationSequence: string[] = [];
    for (const stop of stops) {
      const parentStation = quaiToStation.get(stop.stopId) ?? stop.stopId;
      const resolvedStation = stationById.has(parentStation)
        ? parentStation
        : stationById.has(stop.stopId)
          ? stop.stopId
          : null;

      if (!resolvedStation) continue;

      if (
        stationSequence.length === 0 ||
        stationSequence[stationSequence.length - 1] !== resolvedStation
      ) {
        stationSequence.push(resolvedStation);
      }
    }

    if (stationSequence.length < 2) continue;

    const seqHash = Bun.hash(stationSequence.join(",")).toString(36).slice(0, 8);
    const variantId = `${group.routeId}:${group.directionId}:${seqHash}`;

    if (seenVariantIds.has(variantId)) continue;
    seenVariantIds.add(variantId);

    routeVariants.push({
      id: variantId,
      lineId: group.routeId,
      direction: group.directionId,
      headsign: group.headsign,
      stationCount: stationSequence.length,
    });

    for (let i = 0; i < stationSequence.length; i++) {
      const stationId = stationSequence[i];
      referencedStationIds.add(stationId);
      lineStops.push({
        lineId: group.routeId,
        stationId,
        routeVariantId: variantId,
        order: i,
        isTerminus: i === 0 || i === stationSequence.length - 1,
      });
    }
  }
  log(`  → ${routeVariants.length} route variants, ${lineStops.length} line stops`);

  return { routeVariants, lineStops, referencedStationIds };
}
