import type { Station, RawRefLine, RawArret, RawArretLigne } from "./types";
import { parseCSV } from "./csv";
import { log, readFile } from "./helpers";

export interface Lookups {
  stationById: Map<string, Station>;
  quaiToStation: Map<string, string>;
  stationChildren: Map<string, string[]>;
  refByLineId: Map<string, RawRefLine>;
  replacementLineIds: Set<string>;
  arretById: Map<string, RawArret>;
  arretLignesByStopId: Map<string, RawArretLigne[]>;
  arretsRaw: RawArret[];
  arretsLignesRaw: RawArretLigne[];
}

export async function buildLookups(dataDir: string, gtfsDir: string): Promise<Lookups> {
  log("Step 1: Building lookup tables...");

  // 1a. GTFS stops.txt → stationById + quaiToStation
  log("  Parsing GTFS stops.txt...");
  const stopsRaw = parseCSV(await readFile(`${gtfsDir}/stops.txt`));

  const stationById = new Map<string, Station>();
  const quaiToStation = new Map<string, string>();
  const stationChildren = new Map<string, string[]>();

  for (const row of stopsRaw) {
    const locType = parseInt(row.location_type || "0") || 0;
    if (locType === 1) {
      const latitude = parseFloat(row.stop_lat);
      const longitude = parseFloat(row.stop_lon);
      if (!isFinite(latitude) || !isFinite(longitude)) continue;
      stationById.set(row.stop_id, {
        id: row.stop_id,
        name: row.stop_name,
        latitude,
        longitude,
        fareZone: row.zone_id || null,
        town: null,
        postalCode: null,
        isAccessible: row.wheelchair_boarding === "1",
        hasAudibleSignals: false,
        hasVisualSigns: false,
      });
      stationChildren.set(row.stop_id, []);
    } else if (locType === 0 && row.parent_station) {
      quaiToStation.set(row.stop_id, row.parent_station);
      const children = stationChildren.get(row.parent_station);
      if (children) {
        children.push(row.stop_id);
      } else {
        stationChildren.set(row.parent_station, [row.stop_id]);
      }
    }
  }
  log(`  → ${stationById.size} stations, ${quaiToStation.size} quais mapped`);

  // 1b. referentiel-des-lignes.json → refByLineId
  log("  Parsing referentiel-des-lignes.json...");
  const refRaw: RawRefLine[] = JSON.parse(
    await readFile(`${dataDir}/referentiel-des-lignes.json`),
  );
  const refByLineId = new Map<string, RawRefLine>();
  const replacementLineIds = new Set<string>();
  for (const r of refRaw) {
    const lineId = `IDFM:${r.id_line}`;
    if (r.type === "REPLACEMENT_LINE_TYPE") {
      replacementLineIds.add(lineId);
    } else {
      refByLineId.set(lineId, r);
    }
  }
  log(`  → ${refByLineId.size} referentiel entries (${replacementLineIds.size} replacement lines excluded)`);

  // 1c. arrets.json → arretById
  log("  Parsing arrets.json...");
  const arretsRaw: RawArret[] = JSON.parse(
    await readFile(`${dataDir}/arrets.json`),
  );
  const arretById = new Map<string, RawArret>();
  for (const a of arretsRaw) {
    arretById.set(a.arrid, a);
  }
  log(`  → ${arretById.size} arrets`);

  // 1d. arrets-lignes.json → arretLignesByStopId
  log("  Parsing arrets-lignes.json...");
  const arretsLignesRaw: RawArretLigne[] = JSON.parse(
    await readFile(`${dataDir}/arrets-lignes.json`),
  );
  const arretLignesByStopId = new Map<string, RawArretLigne[]>();
  for (const al of arretsLignesRaw) {
    const existing = arretLignesByStopId.get(al.stop_id);
    if (existing) {
      existing.push(al);
    } else {
      arretLignesByStopId.set(al.stop_id, [al]);
    }
  }
  log(`  → ${arretLignesByStopId.size} unique stop IDs in arrets-lignes`);

  return {
    stationById,
    quaiToStation,
    stationChildren,
    refByLineId,
    replacementLineIds,
    arretById,
    arretLignesByStopId,
    arretsRaw,
    arretsLignesRaw,
  };
}
