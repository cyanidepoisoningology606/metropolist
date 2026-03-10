import type { Line, Station, RouteVariant, LineStop, Transfer, OutputData } from "./types";

/** Return a list of "field: old -> new" strings for every changed key. */
function fieldDiffs<T extends object>(
  prev: T,
  next: T,
  keys: (keyof T & string)[],
): string[] {
  const diffs: string[] = [];
  for (const k of keys) {
    const p = prev[k];
    const n = next[k];
    if (p !== n) {
      diffs.push(`${k}: ${JSON.stringify(p)} → ${JSON.stringify(n)}`);
    }
  }
  return diffs;
}

const LINE_KEYS: (keyof Line & string)[] = [
  "shortName", "longName", "mode", "submode", "color", "textColor",
  "operatorName", "networkName", "status", "isAccessible",
  "groupId", "groupName",
];

const STATION_KEYS: (keyof Station & string)[] = [
  "name", "fareZone", "town", "postalCode",
  "isAccessible", "hasAudibleSignals", "hasVisualSigns",
];

/** Minimum coordinate change (~1 m) to count as a real move. */
const GEO_EPSILON = 0.00001;

function stationFieldDiffs(prev: Station, next: Station): string[] {
  const diffs = fieldDiffs(prev, next, STATION_KEYS);
  const latDelta = Math.abs(prev.latitude - next.latitude);
  const lonDelta = Math.abs(prev.longitude - next.longitude);
  if (latDelta >= GEO_EPSILON || lonDelta >= GEO_EPSILON) {
    diffs.push(`latitude: ${prev.latitude} → ${next.latitude}`);
    diffs.push(`longitude: ${prev.longitude} → ${next.longitude}`);
  }
  return diffs;
}

const RV_KEYS: (keyof RouteVariant & string)[] = [
  "lineId", "direction", "headsign", "stationCount",
];

export function printDiff(previousData: OutputData, output: OutputData): void {
  const changelog: string[] = [];

  console.log("\n" + "─".repeat(60));
  console.log("  CHANGES SINCE LAST BUILD");
  console.log("─".repeat(60));

  // ── Lines diff ──────────────────────────────────────────────

  {
    const prevById = new Map(previousData.lines.map((l) => [l.id, l]));
    const nextById = new Map(output.lines.map((l) => [l.id, l]));

    const added = output.lines.filter((l) => !prevById.has(l.id));
    const removed = previousData.lines.filter((l) => !nextById.has(l.id));
    const modified: { line: Line; changes: string[] }[] = [];

    for (const next of output.lines) {
      const prev = prevById.get(next.id);
      if (!prev) continue;
      const changes = fieldDiffs(prev, next, LINE_KEYS);
      if (changes.length > 0) modified.push({ line: next, changes });
    }

    if (added.length === 0 && removed.length === 0 && modified.length === 0) {
      console.log(`\nLines: ${output.lines.length} (no changes)`);
    } else {
      const delta = output.lines.length - previousData.lines.length;
      const sign = delta > 0 ? "+" : "";
      console.log(`\nLines: ${previousData.lines.length} → ${output.lines.length} (${sign}${delta})`);

      if (added.length > 0) {
        console.log(`  New (${added.length}):`);
        for (const l of added) {
          console.log(`    + ${l.id} "${l.shortName}" [${l.mode}]`);
        }
        const byMode = new Map<string, Line[]>();
        for (const l of added) byMode.set(l.mode, [...(byMode.get(l.mode) ?? []), l]);
        for (const [mode, lines] of byMode) {
          const names = lines.map((l) => l.shortName).join(", ");
          changelog.push(`Added ${mode} line${lines.length > 1 ? "s" : ""}: ${names}`);
        }
      }

      if (removed.length > 0) {
        console.log(`  Deleted (${removed.length}):`);
        for (const l of removed) {
          console.log(`    - ${l.id} "${l.shortName}" [${l.mode}]`);
        }
        const byMode = new Map<string, Line[]>();
        for (const l of removed) byMode.set(l.mode, [...(byMode.get(l.mode) ?? []), l]);
        for (const [mode, lines] of byMode) {
          const names = lines.map((l) => l.shortName).join(", ");
          changelog.push(`Removed ${mode} line${lines.length > 1 ? "s" : ""}: ${names}`);
        }
      }

      if (modified.length > 0) {
        console.log(`  Modified (${modified.length}):`);
        for (const { line, changes } of modified) {
          console.log(`    ~ ${line.id} "${line.shortName}" [${line.mode}]`);
          for (const c of changes) {
            console.log(`        ${c}`);
          }
        }
        changelog.push(`Updated info for ${modified.length} line${modified.length > 1 ? "s" : ""}`);
      }
    }
  }

  // ── Stations diff ───────────────────────────────────────────

  {
    const prevById = new Map(previousData.stations.map((s) => [s.id, s]));
    const nextById = new Map(output.stations.map((s) => [s.id, s]));

    const added = output.stations.filter((s) => !prevById.has(s.id));
    const removed = previousData.stations.filter((s) => !nextById.has(s.id));
    const modified: { station: Station; changes: string[] }[] = [];

    for (const next of output.stations) {
      const prev = prevById.get(next.id);
      if (!prev) continue;
      const changes = stationFieldDiffs(prev, next);
      if (changes.length > 0) modified.push({ station: next, changes });
    }

    if (added.length === 0 && removed.length === 0 && modified.length === 0) {
      console.log(`\nStations: ${output.stations.length} (no changes)`);
    } else {
      const delta = output.stations.length - previousData.stations.length;
      const sign = delta > 0 ? "+" : "";
      console.log(`\nStations: ${previousData.stations.length} → ${output.stations.length} (${sign}${delta})`);

      if (added.length > 0) {
        console.log(`  New (${added.length}):`);
        for (const s of added) {
          console.log(`    + ${s.id} "${s.name}"${s.town ? ` (${s.town})` : ""}`);
        }
        changelog.push(`Added ${added.length} new station${added.length > 1 ? "s" : ""}`);
      }

      if (removed.length > 0) {
        console.log(`  Deleted (${removed.length}):`);
        for (const s of removed) {
          console.log(`    - ${s.id} "${s.name}"${s.town ? ` (${s.town})` : ""}`);
        }
        changelog.push(`Removed ${removed.length} station${removed.length > 1 ? "s" : ""}`);
      }

      if (modified.length > 0) {
        console.log(`  Modified (${modified.length}):`);
        for (const { station, changes } of modified) {
          console.log(`    ~ ${station.id} "${station.name}"${station.town ? ` (${station.town})` : ""}`);
          for (const c of changes) {
            console.log(`        ${c}`);
          }
        }
        const accChanges = modified.flatMap((m) => m.changes.map((c) => c.split(":")[0]));
        const hasGeo = accChanges.some((c) => c === "latitude" || c === "longitude");
        const hasAccessibility = accChanges.some((c) => c === "isAccessible" || c === "hasAudibleSignals" || c === "hasVisualSigns");
        const parts: string[] = [];
        if (hasGeo) parts.push("locations");
        if (hasAccessibility) parts.push("accessibility info");
        if (parts.length > 0) {
          changelog.push(`Updated station ${parts.join(" and ")} (${modified.length} station${modified.length > 1 ? "s" : ""})`);
        } else {
          changelog.push(`Updated ${modified.length} station${modified.length > 1 ? "s" : ""}`);
        }
      }
    }
  }

  // ── Route variants diff ─────────────────────────────────────

  {
    const lineNameById = new Map<string, string>();
    for (const l of output.lines) lineNameById.set(l.id, l.shortName);
    for (const l of previousData.lines) {
      if (!lineNameById.has(l.id)) lineNameById.set(l.id, l.shortName);
    }
    const rvLabel = (rv: RouteVariant) => {
      const lineName = lineNameById.get(rv.lineId) ?? rv.lineId;
      return `${rv.id} [${lineName}] → ${rv.headsign}`;
    };

    const prevById = new Map(previousData.routeVariants.map((rv) => [rv.id, rv]));
    const nextById = new Map(output.routeVariants.map((rv) => [rv.id, rv]));

    const added = output.routeVariants.filter((rv) => !prevById.has(rv.id));
    const removed = previousData.routeVariants.filter((rv) => !nextById.has(rv.id));
    const modified: { rv: RouteVariant; changes: string[] }[] = [];

    for (const next of output.routeVariants) {
      const prev = prevById.get(next.id);
      if (!prev) continue;
      const changes = fieldDiffs(prev, next, RV_KEYS);
      if (changes.length > 0) modified.push({ rv: next, changes });
    }

    if (added.length === 0 && removed.length === 0 && modified.length === 0) {
      console.log(`\nRoute variants: ${output.routeVariants.length} (no changes)`);
    } else {
      const delta = output.routeVariants.length - previousData.routeVariants.length;
      const sign = delta > 0 ? "+" : "";
      console.log(`\nRoute variants: ${previousData.routeVariants.length} → ${output.routeVariants.length} (${sign}${delta})`);

      if (added.length > 0) {
        console.log(`  New (${added.length}):`);
        for (const rv of added) {
          console.log(`    + ${rvLabel(rv)}`);
        }
      }

      if (removed.length > 0) {
        console.log(`  Deleted (${removed.length}):`);
        for (const rv of removed) {
          console.log(`    - ${rvLabel(rv)}`);
        }
      }

      if (modified.length > 0) {
        console.log(`  Modified (${modified.length}):`);
        for (const { rv, changes } of modified) {
          console.log(`    ~ ${rvLabel(rv)}`);
          for (const c of changes) {
            console.log(`        ${c}`);
          }
        }
      }

      if (added.length > 0 || removed.length > 0) {
        const parts: string[] = [];
        if (added.length > 0) parts.push(`${added.length} added`);
        if (removed.length > 0) parts.push(`${removed.length} removed`);
        changelog.push(`Route changes (${parts.join(", ")})`);
      }
    }
  }

  // ── Line stops diff (keyed by composite) ────────────────────

  {
    const lsKey = (ls: LineStop) => `${ls.routeVariantId}|${ls.stationId}|${ls.order}`;
    const prevKeys = new Set(previousData.lineStops.map(lsKey));
    const nextKeys = new Set(output.lineStops.map(lsKey));

    const addedCount = output.lineStops.filter((ls) => !prevKeys.has(lsKey(ls))).length;
    const removedCount = previousData.lineStops.filter((ls) => !nextKeys.has(lsKey(ls))).length;

    if (addedCount === 0 && removedCount === 0) {
      console.log(`\nLine stops: ${output.lineStops.length} (no changes)`);
    } else {
      const delta = output.lineStops.length - previousData.lineStops.length;
      const sign = delta > 0 ? "+" : "";
      console.log(`\nLine stops: ${previousData.lineStops.length} → ${output.lineStops.length} (${sign}${delta}, +${addedCount} new, -${removedCount} removed)`);
      changelog.push(`Updated stop sequences (${addedCount} added, ${removedCount} removed)`);
    }
  }

  // ── Transfers diff (keyed by station pair) ──────────────────

  {
    const trKey = (t: Transfer) => `${t.fromStationId}|${t.toStationId}`;
    const prevKeys = new Set(previousData.transfers.map(trKey));
    const nextKeys = new Set(output.transfers.map(trKey));

    const addedCount = output.transfers.filter((t) => !prevKeys.has(trKey(t))).length;
    const removedCount = previousData.transfers.filter((t) => !nextKeys.has(trKey(t))).length;

    if (addedCount === 0 && removedCount === 0) {
      console.log(`Transfers: ${output.transfers.length} (no changes)`);
    } else {
      const delta = output.transfers.length - previousData.transfers.length;
      const sign = delta > 0 ? "+" : "";
      console.log(`Transfers: ${previousData.transfers.length} → ${output.transfers.length} (${sign}${delta}, +${addedCount} new, -${removedCount} removed)`);
      changelog.push(`Updated transfer connections (${addedCount} added, ${removedCount} removed)`);
    }
  }

  console.log("─".repeat(60));

  // ── Changelog summary ────────────────────────────────────────
  if (changelog.length > 0) {
    console.log("\n  Changelog:");
    for (const entry of changelog) {
      console.log(`  • ${entry}`);
    }
  } else {
    console.log("\n  No data changes.");
  }
  console.log("");
}
