import type { Station, RawArret, RawArretLigne } from "./types";
import { log, mostCommon, normalizeName } from "./helpers";

interface ArretLigneEntry {
  stopId: string;
  lat: number;
  lon: number;
  commune: string | null;
  insee: string | null;
}

/** ~200m generous threshold in degrees at Paris latitude. */
const MAX_DIST_DEG = 0.003;

export function enrichStations(
  stationById: Map<string, Station>,
  arretsRaw: RawArret[],
  arretsLignesRaw: RawArretLigne[],
): void {
  log("Step 3-4: Enriching stations...");

  // Build name-based index from arrets-lignes
  const arretLignesByName = new Map<string, ArretLigneEntry[]>();
  for (const al of arretsLignesRaw) {
    const name = normalizeName(al.stop_name || "");
    if (!name) continue;
    const lat = parseFloat(al.stop_lat);
    const lon = parseFloat(al.stop_lon);
    if (!isFinite(lat) || !isFinite(lon)) continue;
    const entry: ArretLigneEntry = {
      stopId: al.stop_id,
      lat,
      lon,
      commune: al.nom_commune || null,
      insee: al.code_insee || null,
    };
    const existing = arretLignesByName.get(name);
    if (existing) existing.push(entry);
    else arretLignesByName.set(name, [entry]);
  }

  // Map arrets-lignes stop_id → arrets entry via "IDFM:{arrid}"
  const arretByIdfmId = new Map<string, RawArret>();
  for (const a of arretsRaw) {
    arretByIdfmId.set(`IDFM:${a.arrid}`, a);
  }

  // Enrich each GTFS station by matching arrets-lignes entries
  let enriched = 0;
  for (const [_stationId, station] of stationById) {
    const stationName = normalizeName(station.name);
    const candidates = arretLignesByName.get(stationName);
    if (!candidates) continue;

    const nearby = candidates.filter(
      (c) =>
        Math.abs(c.lat - station.latitude) < MAX_DIST_DEG &&
        Math.abs(c.lon - station.longitude) < MAX_DIST_DEG,
    );
    if (nearby.length === 0) continue;

    const towns: string[] = [];
    const postalCodes: string[] = [];
    let anyAccessible = station.isAccessible;
    let anyAudible = false;
    let anyVisual = false;

    for (const match of nearby) {
      if (match.commune) towns.push(match.commune);
      if (match.insee) postalCodes.push(match.insee);

      const arret = arretByIdfmId.get(match.stopId);
      if (arret) {
        if (arret.arraccessibility === "true") anyAccessible = true;
        if (arret.arraudiblesignals === "true") anyAudible = true;
        if (arret.arrvisualsigns === "true") anyVisual = true;
        if (arret.arrtown) towns.push(arret.arrtown);
        if (arret.arrpostalregion) postalCodes.push(arret.arrpostalregion);
        if (!station.fareZone && arret.arrfarezone) {
          station.fareZone = arret.arrfarezone;
        }
      }
    }

    station.isAccessible = anyAccessible;
    station.hasAudibleSignals = anyAudible;
    station.hasVisualSigns = anyVisual;
    station.town = mostCommon(towns);
    station.postalCode = mostCommon(postalCodes);
    enriched++;
  }
  log(`  → ${enriched} stations enriched with metadata`);
}
