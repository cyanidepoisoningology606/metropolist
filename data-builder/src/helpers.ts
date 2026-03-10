import type { TransportMode } from "./types";

export function log(msg: string) {
  console.log(`[${new Date().toISOString().slice(11, 19)}] ${msg}`);
}

/** Read a file with a contextual error message if it's missing or unreadable. */
export async function readFile(path: string): Promise<string> {
  try {
    return await Bun.file(path).text();
  } catch (err) {
    throw new Error(
      `Failed to read file: ${path}\n${err instanceof Error ? err.message : String(err)}`,
    );
  }
}

export function mostCommon<T>(values: T[]): T | null {
  if (values.length === 0) return null;
  const counts = new Map<T, number>();
  for (const v of values) {
    counts.set(v, (counts.get(v) ?? 0) + 1);
  }
  let best: T = values[0];
  let bestCount = 0;
  for (const [v, c] of counts) {
    if (c > bestCount) {
      best = v;
      bestCount = c;
    }
  }
  return best;
}

export function normalizeName(s: string): string {
  return s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

/** Map referentiel transportmode + transportsubmode to our TransportMode */
export function mapRefMode(
  transportmode: string,
  transportsubmode: string | null,
  shortName: string,
): TransportMode {
  switch (transportmode) {
    case "metro":
      return "metro";
    case "tram":
      return "tram";
    case "bus":
      return "bus";
    case "cableway":
      return "cableway";
    case "funicular":
      return "funicular";
    case "rail": {
      if (transportsubmode === "suburbanRailway") return "train";
      if (transportsubmode === "regionalRail") return "regionalRail";
      if (transportsubmode === "railShuttle") return "railShuttle";
      // Known RER shortnames
      const rerNames = new Set(["A", "B", "C", "D", "E"]);
      if (rerNames.has(shortName.toUpperCase())) return "rer";
      if (transportsubmode === "local") return "train";
      return "rer";
    }
    default:
      console.warn(`[mapRefMode] Unknown transportmode "${transportmode}", defaulting to "bus"`);
      return "bus";
  }
}

/** Map GTFS route_type to our TransportMode (fallback) */
export function mapGTFSRouteType(
  routeType: number,
  submode: string | null,
  shortName: string,
): TransportMode {
  switch (routeType) {
    case 0:
      return "tram";
    case 1:
      return "metro";
    case 2: {
      if (submode === "suburbanRailway") return "train";
      if (submode === "regionalRail") return "regionalRail";
      const rerNames = new Set(["A", "B", "C", "D", "E"]);
      if (rerNames.has(shortName.toUpperCase())) return "rer";
      return "rer";
    }
    case 3:
      return "bus";
    case 5:
      return "cableway";
    case 7:
      return "funicular";
    default:
      console.warn(`[mapGTFSRouteType] Unknown route_type ${routeType}, defaulting to "bus"`);
      return "bus";
  }
}
